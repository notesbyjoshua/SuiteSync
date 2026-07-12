-- Admin-only tools for supervising suite creation and assignments.
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

create or replace function public.is_admin(check_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users where user_id = check_user_id
  );
$$;

revoke all on function public.is_admin(uuid) from public;
grant execute on function public.is_admin(uuid) to authenticated;

revoke all on table public.admin_users from anon, authenticated;
grant select on table public.admin_users to authenticated;

drop policy if exists "Admins can view the admin roster" on public.admin_users;
create policy "Admins can view the admin roster"
on public.admin_users for select to authenticated
using (public.is_admin());

create table if not exists public.suites (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 1 and 80),
  session text,
  floor smallint check (floor between 1 and 4),
  college text check (college in ('pauli_murray', 'benjamin_franklin')),
  capacity smallint not null default 6 check (capacity between 4 and 6),
  status text not null default 'draft' check (status in ('draft', 'ready', 'released')),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.suite_members (
  suite_id uuid not null references public.suites(id) on delete cascade,
  response_id uuid not null unique references public.survey_responses(id) on delete cascade,
  assigned_by uuid not null references auth.users(id),
  assigned_at timestamptz not null default now(),
  primary key (suite_id, response_id)
);

alter table public.suites enable row level security;
alter table public.suite_members enable row level security;

alter table public.survey_responses
  drop constraint if exists survey_responses_suite_id_fkey;
alter table public.survey_responses
  add constraint survey_responses_suite_id_fkey
  foreign key (suite_id) references public.suites(id) on delete set null;

revoke all on table public.suites from anon, authenticated;
revoke all on table public.suite_members from anon, authenticated;
grant select on table public.suites, public.suite_members to authenticated;
grant select on table public.survey_responses to authenticated;

drop policy if exists "Admins can view survey responses" on public.survey_responses;
create policy "Admins can view survey responses"
on public.survey_responses for select to authenticated
using (public.is_admin());

drop policy if exists "Admins can view suites" on public.suites;
create policy "Admins can view suites"
on public.suites for select to authenticated
using (public.is_admin());

drop policy if exists "Admins can view suite members" on public.suite_members;
create policy "Admins can view suite members"
on public.suite_members for select to authenticated
using (public.is_admin());

create or replace function public.admin_create_suite(
  suite_name text,
  suite_capacity smallint default 6,
  suite_session text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_suite_id uuid;
begin
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  insert into public.suites (name, capacity, session, created_by)
  values (trim(suite_name), suite_capacity, nullif(trim(suite_session), ''), auth.uid())
  returning id into new_suite_id;

  return new_suite_id;
end;
$$;

create or replace function public.admin_assign_response(
  target_response_id uuid,
  target_suite_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target_capacity integer;
  current_members integer;
begin
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  select capacity into target_capacity
  from public.suites
  where id = target_suite_id
  for update;

  if target_capacity is null then
    raise exception 'Suite not found';
  end if;

  select count(*) into current_members
  from public.suite_members
  where suite_id = target_suite_id
    and response_id <> target_response_id;

  if current_members >= target_capacity then
    raise exception 'Suite is already at capacity';
  end if;

  delete from public.suite_members where response_id = target_response_id;
  insert into public.suite_members (suite_id, response_id, assigned_by)
  values (target_suite_id, target_response_id, auth.uid());

  update public.survey_responses
  set suite_id = target_suite_id, matching_status = 'matched'
  where id = target_response_id;

  if not found then raise exception 'Survey response not found'; end if;
end;
$$;

create or replace function public.admin_unassign_response(target_response_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  delete from public.suite_members where response_id = target_response_id;
  update public.survey_responses
  set suite_id = null, matching_status = 'pending'
  where id = target_response_id;
end;
$$;

revoke all on function public.admin_create_suite(text, smallint, text) from public;
revoke all on function public.admin_assign_response(uuid, uuid) from public;
revoke all on function public.admin_unassign_response(uuid) from public;
grant execute on function public.admin_create_suite(text, smallint, text) to authenticated;
grant execute on function public.admin_assign_response(uuid, uuid) to authenticated;
grant execute on function public.admin_unassign_response(uuid) to authenticated;

comment on table public.admin_users is 'Users authorized to supervise matching. Add the first admin through the SQL Editor or service role only.';
