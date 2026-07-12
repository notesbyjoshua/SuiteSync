-- Return the admin dashboard to its pre-matching state for the demo recording.
-- The protected Franklin 201 roster remains enforced by the matching function.
delete from public.suite_members where true;

update public.survey_responses
set suite_id = null,
    matching_status = 'pending',
    matching_score = null,
    assigned_room_type = null
where matching_status <> 'excluded';

update public.suites set housing_group = null where true;

delete from public.matching_runs where true;
