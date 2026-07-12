update public.survey_responses
set preferred_name = 'Samuel',
    biological_sex = 'male',
    pronouns = 'he/him',
    gender_identity = 'male',
    suite_id = null,
    matching_status = 'pending',
    matching_score = null,
    assigned_room_type = null
where lower(email) = 'samira@example.com';
