-- Add the expanded personal-information questions to an existing survey table.
-- Columns remain nullable for any responses submitted before this migration;
-- the current survey requires them for all new submissions.
alter table public.survey_responses
  add column if not exists biological_sex text,
  add column if not exists gender_identity text,
  add column if not exists ethnicity text,
  add column if not exists religious_belief text;

alter table public.survey_responses
  drop constraint if exists survey_responses_biological_sex_check,
  add constraint survey_responses_biological_sex_check
    check (biological_sex is null or biological_sex in ('male', 'female', 'non_binary', 'other')),
  drop constraint if exists survey_responses_pronouns_check,
  add constraint survey_responses_pronouns_check
    check (pronouns is null or pronouns in ('he/him', 'he/they', 'she/her', 'she/they', 'they/them', 'other', 'prefer_not_to_say')),
  drop constraint if exists survey_responses_gender_identity_check,
  add constraint survey_responses_gender_identity_check
    check (gender_identity is null or gender_identity in ('male', 'female', 'other', 'prefer_not_to_say')),
  drop constraint if exists survey_responses_ethnicity_check,
  add constraint survey_responses_ethnicity_check
    check (ethnicity is null or ethnicity in ('white', 'black', 'east_asian', 'other')),
  drop constraint if exists survey_responses_religious_belief_check,
  add constraint survey_responses_religious_belief_check
    check (religious_belief is null or religious_belief in ('christian', 'muslim', 'hindu', 'sikh', 'jewish', 'buddhist', 'atheist', 'non_denomination', 'agnostic', 'other', 'prefer_not_to_say'));
