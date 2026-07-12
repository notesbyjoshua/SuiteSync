alter table public.suites
  add column if not exists floor smallint check (floor between 1 and 4),
  add column if not exists college text check (college in ('pauli_murray', 'benjamin_franklin'));

create or replace function public.admin_create_suite_with_location(
  suite_name text,
  suite_capacity smallint,
  suite_session text,
  suite_floor smallint,
  suite_college text
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

  if suite_floor not between 1 and 4 then raise exception 'Floor must be between 1 and 4'; end if;
  if suite_college not in ('pauli_murray', 'benjamin_franklin') then raise exception 'Invalid college'; end if;

  insert into public.suites (name, capacity, session, floor, college, created_by)
  values (trim(suite_name), suite_capacity, nullif(trim(suite_session), ''), suite_floor, suite_college, auth.uid())
  returning id into new_suite_id;

  return new_suite_id;
end;
$$;

revoke all on function public.admin_create_suite_with_location(text, smallint, text, smallint, text) from public;
grant execute on function public.admin_create_suite_with_location(text, smallint, text, smallint, text) to authenticated;

comment on column public.suites.floor is 'Residential college floor, from 1 through 4.';
comment on column public.suites.college is 'Pauli Murray or Benjamin Franklin residential college.';
