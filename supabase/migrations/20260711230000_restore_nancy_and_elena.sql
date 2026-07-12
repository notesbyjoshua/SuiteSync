-- Nancy and Elena are valid Session II demo applicants; the earlier exclusion was temporary.
update public.survey_responses
set session = 'Session II',
    gender_identity = 'female',
    suite_id = null,
    matching_status = 'pending',
    matching_score = null,
    assigned_room_type = null
where lower(email) in ('elenayzhan@gmail.com', 'xun96325@gmail.com');
