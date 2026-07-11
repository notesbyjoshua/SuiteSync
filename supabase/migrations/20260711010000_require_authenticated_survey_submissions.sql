-- Upgrade an existing survey_responses table from anonymous to authenticated submissions.
alter table public.survey_responses
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

create unique index if not exists survey_responses_user_id_key
  on public.survey_responses (user_id)
  where user_id is not null;

drop policy if exists "Applicants can submit survey responses" on public.survey_responses;

revoke all on table public.survey_responses from anon, authenticated;
grant insert on table public.survey_responses to authenticated;

create policy "Applicants can submit survey responses"
on public.survey_responses
for insert
to authenticated
with check (
  auth.uid() = user_id
  and email = lower(coalesce(auth.jwt() ->> 'email', ''))
  and matching_status = 'pending'
  and suite_id is null
  and survey_version = 1
  and consented_at <= now()
);
