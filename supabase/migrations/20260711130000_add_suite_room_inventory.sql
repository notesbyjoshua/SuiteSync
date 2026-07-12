alter table public.suites
  add column if not exists single_rooms smallint check (single_rooms >= 0),
  add column if not exists double_rooms smallint check (double_rooms >= 0);

create or replace function public.admin_create_suite_with_rooms(
  suite_name text,
  suite_session text,
  suite_floor smallint,
  suite_college text,
  suite_single_rooms smallint,
  suite_double_rooms smallint
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_suite_id uuid;
  calculated_capacity smallint;
begin
  if not public.is_admin() then raise exception 'Admin access required' using errcode = '42501'; end if;
  if suite_floor not between 1 and 4 then raise exception 'Floor must be between 1 and 4'; end if;
  if suite_college not in ('pauli_murray', 'benjamin_franklin') then raise exception 'Invalid college'; end if;
  if suite_single_rooms < 0 or suite_double_rooms < 0 then raise exception 'Room counts cannot be negative'; end if;

  calculated_capacity := suite_single_rooms + (suite_double_rooms * 2);
  if calculated_capacity not between 4 and 6 then raise exception 'Room inventory must provide capacity for 4–6 students'; end if;

  insert into public.suites (name, capacity, session, floor, college, single_rooms, double_rooms, created_by)
  values (trim(suite_name), calculated_capacity, nullif(trim(suite_session), ''), suite_floor, suite_college, suite_single_rooms, suite_double_rooms, auth.uid())
  returning id into new_suite_id;
  return new_suite_id;
end;
$$;

revoke all on function public.admin_create_suite_with_rooms(text, text, smallint, text, smallint, smallint) from public;
grant execute on function public.admin_create_suite_with_rooms(text, text, smallint, text, smallint, smallint) to authenticated;

-- Remove the requested test suite without leaving applicants marked as matched.
update public.survey_responses
set suite_id = null, matching_status = 'pending'
where suite_id in (select id from public.suites where lower(trim(name)) = 'test suite 1');

delete from public.suites where lower(trim(name)) = 'test suite 1';

comment on column public.suites.single_rooms is 'Number of single-occupancy rooms in the suite.';
comment on column public.suites.double_rooms is 'Number of double-occupancy rooms in the suite.';
