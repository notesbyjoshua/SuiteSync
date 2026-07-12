-- Expand ethnicity options used by the applicant dropdown.
alter table public.survey_responses
  drop constraint if exists survey_responses_ethnicity_check;

alter table public.survey_responses
  add constraint survey_responses_ethnicity_check check (
    ethnicity is null or ethnicity in (
      'white',
      'black',
      'east_asian',
      'south_asian',
      'southeast_asian',
      'middle_eastern_north_african',
      'hispanic_latino',
      'indigenous',
      'pacific_islander',
      'multiracial',
      'other',
      'prefer_not_to_say'
    )
  );
