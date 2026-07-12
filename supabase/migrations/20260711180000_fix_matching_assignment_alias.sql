create or replace function public.apply_matching_assignments(assignment_data jsonb, matching_run_id uuid, actor_user_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare assignment_item jsonb;
begin
  if jsonb_array_length(assignment_data) = 0 then raise exception 'No assignments supplied'; end if;
  if exists (select 1 from jsonb_array_elements(assignment_data) as elements(elem) group by elem->>'response_id' having count(*) > 1) then raise exception 'Duplicate applicant assignment'; end if;
  if exists (
    select 1 from (
      select (elem->>'suite_id')::uuid suite_id, count(*) assigned
      from jsonb_array_elements(assignment_data) as elements(elem) group by (elem->>'suite_id')::uuid
    ) counts join public.suites s on s.id = counts.suite_id where counts.assigned > s.capacity
  ) then raise exception 'Assignment exceeds suite capacity'; end if;

  delete from public.suite_members;
  update public.survey_responses set suite_id = null, matching_status = 'pending', matching_score = null where matching_status <> 'excluded';
  update public.suites set housing_group = null;

  for assignment_item in select elem from jsonb_array_elements(assignment_data) as elements(elem) loop
    insert into public.suite_members (suite_id, response_id, assigned_by)
    values ((assignment_item->>'suite_id')::uuid, (assignment_item->>'response_id')::uuid, actor_user_id);
    update public.survey_responses set suite_id = (assignment_item->>'suite_id')::uuid, matching_status = 'matched', matching_score = (assignment_item->>'score')::numeric
    where id = (assignment_item->>'response_id')::uuid;
    update public.suites set housing_group = assignment_item->>'housing_group' where id = (assignment_item->>'suite_id')::uuid;
  end loop;
end;
$$;
