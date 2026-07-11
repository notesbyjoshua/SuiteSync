-- TEMPORARY TESTING MODE: allow unauthenticated survey submissions.
-- Replace this policy before accepting real applicant data.
alter table public.survey_responses
  alter column user_id drop not null;

drop policy if exists "Applicants can submit survey responses" on public.survey_responses;

grant insert on table public.survey_responses to anon, authenticated;

create policy "Applicants can submit survey responses"
on public.survey_responses
for insert
to anon, authenticated
with check (
  (
    (
      auth.uid() is null
      and user_id is null
    )
    or (
      auth.uid() = user_id
      and email = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
  )
  and matching_status = 'pending'
  and suite_id is null
  and survey_version = 1
  and consented_at <= now()
);

comment on policy "Applicants can submit survey responses" on public.survey_responses is
'Temporary testing policy permitting anonymous inserts. Restore authenticated-only access before launch.';
