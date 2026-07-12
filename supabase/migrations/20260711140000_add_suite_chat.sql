create table if not exists public.suite_messages (
  id uuid primary key default gen_random_uuid(),
  suite_id uuid not null references public.suites(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now()
);

alter table public.suite_messages enable row level security;
revoke all on table public.suite_messages from anon, authenticated;
grant select, insert on table public.suite_messages to authenticated;

create or replace function public.my_suite_id()
returns uuid language sql stable security definer set search_path = public as $$
  select suite_id from public.survey_responses
  where user_id = auth.uid() and matching_status = 'matched' and suite_id is not null
  limit 1;
$$;

create policy "Members can read their suite chat" on public.suite_messages
for select to authenticated using (suite_id = public.my_suite_id());

create policy "Members can send to their suite chat" on public.suite_messages
for insert to authenticated with check (suite_id = public.my_suite_id() and sender_user_id = auth.uid());

create or replace function public.claim_my_survey_response()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.survey_responses set user_id = auth.uid()
  where user_id is null and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''));
end;
$$;

create or replace function public.get_my_suite_context()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'suite', jsonb_build_object('id', s.id, 'name', s.name, 'floor', s.floor, 'college', s.college),
    'members', coalesce((select jsonb_agg(jsonb_build_object('user_id', r.user_id, 'preferred_name', r.preferred_name) order by r.preferred_name) from public.survey_responses r where r.suite_id = s.id and r.matching_status = 'matched'), '[]'::jsonb)
  )
  from public.suites s where s.id = public.my_suite_id();
$$;

revoke all on function public.my_suite_id() from public;
revoke all on function public.claim_my_survey_response() from public;
revoke all on function public.get_my_suite_context() from public;
grant execute on function public.my_suite_id(), public.claim_my_survey_response(), public.get_my_suite_context() to authenticated;

create index if not exists suite_messages_suite_created_idx on public.suite_messages (suite_id, created_at);

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'suite_messages') then
    alter publication supabase_realtime add table public.suite_messages;
  end if;
end $$;
