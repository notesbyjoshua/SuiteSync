alter table public.suites drop constraint if exists suites_capacity_check;
alter table public.suites add constraint suites_capacity_check check (capacity between 1 and 9);
alter table public.survey_responses add column if not exists assigned_room_type text check (assigned_room_type in ('single', 'double'));

create or replace function public.admin_create_suite_with_rooms(
  suite_name text, suite_session text, suite_floor smallint, suite_college text,
  suite_single_rooms smallint, suite_double_rooms smallint
) returns uuid language plpgsql security definer set search_path = public as $$
declare new_suite_id uuid; calculated_capacity smallint;
begin
  if not public.is_admin() then raise exception 'Admin access required' using errcode = '42501'; end if;
  calculated_capacity := suite_single_rooms + (suite_double_rooms * 2);
  if calculated_capacity not between 1 and 9 then raise exception 'Room inventory must provide capacity for 1–9 students'; end if;
  insert into public.suites (name, capacity, session, floor, college, single_rooms, double_rooms, created_by)
  values (trim(suite_name), calculated_capacity, suite_session, suite_floor, suite_college, suite_single_rooms, suite_double_rooms, auth.uid())
  returning id into new_suite_id; return new_suite_id;
end $$;

-- Ensure enough Session II demo applicants exist in each housing group.
insert into public.survey_responses (preferred_name,email,track,session,age,biological_sex,pronouns,gender_identity,ethnicity,extroversion,organization,room_type,bedtime_preference,preferred_suitemates,floor_preference,college_preference,sound_level,consented_at,matching_status)
values
('Ethan','ethan.demo@example.com','Innovations in Science & Technology','Session II',16,'male','he/him','male','white',3,4,'double','22:30',3,'lower','benjamin_franklin',3,now(),'pending'),
('Liam','liam.demo@example.com','Politics, Law & Economics','Session II',17,'male','he/him','male','black',4,3,'single','23:00',3,'no_preference','benjamin_franklin',3,now(),'pending'),
('Maya','maya.demo@example.com','Solving Global Challenges','Session II',16,'female','she/her','female','east_asian',4,4,'double','22:30',3,'lower','pauli_murray',2,now(),'pending'),
('Priya','priya.demo@example.com','Innovations in Science & Technology','Session II',17,'female','she/her','female','south_asian',3,5,'single','22:00',3,'higher','pauli_murray',2,now(),'pending'),
('Sofia','sofia.demo@example.com','Politics, Law & Economics','Session II',16,'female','she/her','female','hispanic_latino',4,3,'double','23:00',3,'no_preference','pauli_murray',3,now(),'pending'),
('Jordan','jordan.demo@example.com','Solving Global Challenges','Session II',17,'other','they/them','other','multiracial',3,4,'no_preference','22:30',3,'higher','benjamin_franklin',3,now(),'pending'),
('Avery','avery.demo@example.com','Innovations in Science & Technology','Session II',16,'non_binary','they/them','other','white',4,4,'double','23:00',3,'no_preference','benjamin_franklin',3,now(),'pending'),
('Noor','noor.demo@example.com','Politics, Law & Economics','Session II',17,'other','they/them','other','middle_eastern_north_african',3,5,'single','22:00',3,'lower','pauli_murray',2,now(),'pending')
on conflict (email) do update set session='Session II', suite_id=null, matching_status='pending', matching_score=null;

-- Use distinct housing groups for the four named demo accounts.
update public.survey_responses set gender_identity='male' where lower(email) in ('joshuabie2010@gmail.com','alex@example.com');
update public.survey_responses set preferred_name='Samuel', biological_sex='male', pronouns='he/him', gender_identity='male' where lower(email)='samira@example.com';
update public.survey_responses set gender_identity='other' where lower(email)='mateo@example.com';

-- Provide at least one available Session II suite for each housing group.
insert into public.suites (name,session,floor,college,single_rooms,double_rooms,capacity,created_by)
select name,'Session II',floor,college,singles,doubles,singles+doubles*2,(select user_id from public.admin_users limit 1)
from (values
('Session II Franklin North',2,'benjamin_franklin',2,2),
('Session II Murray North',2,'pauli_murray',2,2),
('Session II Franklin South',3,'benjamin_franklin',2,2),
('Session II Murray South',3,'pauli_murray',2,2)
) as demo(name,floor,college,singles,doubles)
on conflict (name) do nothing;

-- Persist the room produced by the matcher alongside each suite assignment.
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

  delete from public.suite_members where true;
  update public.survey_responses set suite_id = null, matching_status = 'pending', matching_score = null, assigned_room_type = null where matching_status <> 'excluded';
  update public.suites set housing_group = null where true;

  for assignment_item in select elem from jsonb_array_elements(assignment_data) as elements(elem) loop
    insert into public.suite_members (suite_id, response_id, assigned_by)
    values ((assignment_item->>'suite_id')::uuid, (assignment_item->>'response_id')::uuid, actor_user_id);
    update public.survey_responses set
      suite_id = (assignment_item->>'suite_id')::uuid,
      matching_status = 'matched',
      matching_score = (assignment_item->>'score')::numeric,
      assigned_room_type = assignment_item->>'assigned_room_type'
    where id = (assignment_item->>'response_id')::uuid;
    update public.suites set housing_group = assignment_item->>'housing_group' where id = (assignment_item->>'suite_id')::uuid;
  end loop;
end;
$$;
