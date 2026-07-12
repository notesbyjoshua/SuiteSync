-- Replace the original placeholder compatibility questions with the current survey.
alter table public.survey_responses
  add column if not exists extroversion smallint,
  add column if not exists organization smallint,
  add column if not exists room_type text,
  add column if not exists bedtime_preference text,
  add column if not exists preferred_suitemates smallint,
  add column if not exists floor_preference text,
  add column if not exists college_preference text,
  add column if not exists sound_level smallint;

alter table public.survey_responses
  alter column sleep_schedule drop not null,
  alter column tidiness drop not null,
  alter column recharge_style drop not null,
  alter column suite_priorities drop not null,
  alter column conflict_style drop not null;

alter table public.survey_responses
  add constraint survey_responses_extroversion_check check (extroversion is null or extroversion between 1 and 5),
  add constraint survey_responses_organization_check check (organization is null or organization between 1 and 5),
  add constraint survey_responses_room_type_check check (room_type is null or room_type in ('single', 'double', 'no_preference')),
  add constraint survey_responses_bedtime_preference_check check (bedtime_preference is null or bedtime_preference in ('21:00', '21:30', '22:00', '22:30', '23:00', '23:30', '00:00_or_later')),
  add constraint survey_responses_preferred_suitemates_check check (preferred_suitemates is null or preferred_suitemates between 0 and 8),
  add constraint survey_responses_floor_preference_check check (floor_preference is null or floor_preference in ('higher', 'lower', 'no_preference')),
  add constraint survey_responses_college_preference_check check (college_preference is null or college_preference in ('pauli_murray', 'benjamin_franklin', 'no_preference')),
  add constraint survey_responses_sound_level_check check (sound_level is null or sound_level between 1 and 5);
