-- Keep older test submissions for reference but exclude them from the controlled demo run.
update public.survey_responses
set suite_id = null, matching_status = 'excluded', matching_score = null
where lower(email) not in (
  'joshuabie2010@gmail.com',
  'samira@example.com',
  'alex@example.com',
  'mateo@example.com'
);

update public.survey_responses
set suite_id = null, matching_status = 'pending', matching_score = null
where lower(email) in (
  'joshuabie2010@gmail.com',
  'samira@example.com',
  'alex@example.com',
  'mateo@example.com'
);
