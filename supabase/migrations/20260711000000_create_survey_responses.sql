create extension if not exists pgcrypto;

create table if not exists public.survey_responses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  preferred_name text not null check (char_length(preferred_name) between 1 and 80),
  email text not null unique check (email = lower(email) and char_length(email) <= 254),
  track text not null,
  session text not null,
  age smallint not null check (age between 15 and 18),
  biological_sex text not null check (biological_sex in ('male', 'female', 'non_binary', 'other')),
  pronouns text not null check (pronouns in ('he/him', 'he/they', 'she/her', 'she/they', 'they/them', 'other', 'prefer_not_to_say')),
  gender_identity text not null check (gender_identity in ('male', 'female', 'other', 'prefer_not_to_say')),
  ethnicity text not null check (ethnicity in ('white', 'black', 'east_asian', 'central_asian', 'south_asian', 'southeast_asian', 'middle_eastern_north_african', 'hispanic_latino', 'indigenous', 'pacific_islander', 'multiracial', 'other', 'prefer_not_to_say')),
  religious_belief text check (religious_belief is null or religious_belief in ('christian', 'muslim', 'hindu', 'sikh', 'jewish', 'buddhist', 'atheist', 'non_denomination', 'agnostic', 'other', 'prefer_not_to_say')),
  extroversion smallint not null check (extroversion between 1 and 5),
  organization smallint not null check (organization between 1 and 5),
  room_type text not null check (room_type in ('single', 'double', 'no_preference')),
  bedtime_preference text not null check (bedtime_preference in ('21:00', '21:30', '22:00', '22:30', '23:00', '23:30', '00:00_or_later')),
  preferred_suitemates smallint not null check (preferred_suitemates between 0 and 8),
  floor_preference text not null check (floor_preference in ('higher', 'lower', 'no_preference')),
  college_preference text not null check (college_preference in ('pauli_murray', 'benjamin_franklin', 'no_preference')),
  sound_level smallint not null check (sound_level between 1 and 5),
  consented_at timestamptz not null,
  survey_version integer not null default 1,
  submitted_at timestamptz not null default now(),
  matching_status text not null default 'pending' check (matching_status in ('pending', 'matched', 'excluded')),
  suite_id uuid
);

alter table public.survey_responses enable row level security;

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

comment on table public.survey_responses is
'Private YYGS suite preference responses. Authenticated applicants may insert only for their own verified email; reads require server-side service-role access.';
