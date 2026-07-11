create extension if not exists pgcrypto;

create table if not exists public.survey_responses (
  id uuid primary key default gen_random_uuid(),
  preferred_name text not null check (char_length(preferred_name) between 1 and 80),
  email text not null unique check (email = lower(email) and char_length(email) <= 254),
  session text not null,
  age smallint not null check (age between 15 and 18),
  pronouns text check (pronouns is null or char_length(pronouns) <= 60),
  sleep_schedule text not null check (sleep_schedule in ('early', 'flexible', 'late')),
  tidiness smallint not null check (tidiness between 1 and 5),
  recharge_style text not null check (recharge_style in ('alone', 'mix', 'social')),
  suite_priorities text[] not null check (cardinality(suite_priorities) between 1 and 3),
  conflict_style text not null check (char_length(conflict_style) between 1 and 600),
  additional_notes text check (additional_notes is null or char_length(additional_notes) <= 1000),
  consented_at timestamptz not null,
  survey_version integer not null default 1,
  submitted_at timestamptz not null default now(),
  matching_status text not null default 'pending' check (matching_status in ('pending', 'matched', 'excluded')),
  suite_id uuid
);

alter table public.survey_responses enable row level security;

revoke all on table public.survey_responses from anon, authenticated;
grant insert on table public.survey_responses to anon, authenticated;

create policy "Applicants can submit survey responses"
on public.survey_responses
for insert
to anon, authenticated
with check (
  matching_status = 'pending'
  and suite_id is null
  and survey_version = 1
  and consented_at <= now()
);

comment on table public.survey_responses is
'Private YYGS suite preference responses. Browser clients may insert only; reads require server-side service-role access.';
