-- Reproducible demo applicants for showing the matching workflow.
do $$
declare
  joshua_id uuid;
  samira_id uuid;
  alex_id uuid;
  mateo_id uuid;
begin
  select id into joshua_id from auth.users where lower(email) = 'joshuabie2010@gmail.com' limit 1;
  select id into samira_id from auth.users where lower(email) = 'samira@example.com' limit 1;
  select id into alex_id from auth.users where lower(email) = 'alex@example.com' limit 1;
  select id into mateo_id from auth.users where lower(email) = 'mateo@example.com' limit 1;

  if joshua_id is null or samira_id is null or alex_id is null or mateo_id is null then
    raise exception 'Create all four demo Auth users before applying the demo seed';
  end if;

  insert into public.survey_responses (
    user_id, preferred_name, email, track, session, age, biological_sex, pronouns,
    gender_identity, ethnicity, religious_belief, extroversion, organization,
    room_type, bedtime_preference, preferred_suitemates, floor_preference,
    college_preference, sound_level, consented_at, survey_version, matching_status
  ) values
    (joshua_id, 'Joshua', 'joshuabie2010@gmail.com', 'Innovations in Science & Technology', 'Session II', 16, 'male', 'he/him', 'other', 'central_asian', null, 4, 4, 'double', '22:30', 3, 'lower', 'benjamin_franklin', 3, now(), 1, 'pending'),
    (samira_id, 'Samira', 'samira@example.com', 'Politics, Law & Economics', 'Session II', 16, 'female', 'she/her', 'other', 'south_asian', 'muslim', 4, 4, 'double', '22:30', 3, 'lower', 'benjamin_franklin', 3, now(), 1, 'pending'),
    (alex_id, 'Alex', 'alex@example.com', 'Solving Global Challenges', 'Session II', 17, 'male', 'he/they', 'other', 'east_asian', null, 4, 3, 'double', '23:00', 3, 'lower', 'benjamin_franklin', 3, now(), 1, 'pending'),
    (mateo_id, 'Mateo', 'mateo@example.com', 'Innovations in Science & Technology', 'Session II', 17, 'male', 'he/him', 'other', 'hispanic_latino', 'christian', 3, 4, 'double', '22:30', 3, 'no_preference', 'benjamin_franklin', 3, now(), 1, 'pending')
  on conflict (email) do update set
    user_id = excluded.user_id, preferred_name = excluded.preferred_name, track = excluded.track,
    session = excluded.session, age = excluded.age, biological_sex = excluded.biological_sex,
    pronouns = excluded.pronouns, gender_identity = excluded.gender_identity,
    ethnicity = excluded.ethnicity, religious_belief = excluded.religious_belief,
    extroversion = excluded.extroversion, organization = excluded.organization,
    room_type = excluded.room_type, bedtime_preference = excluded.bedtime_preference,
    preferred_suitemates = excluded.preferred_suitemates, floor_preference = excluded.floor_preference,
    college_preference = excluded.college_preference, sound_level = excluded.sound_level,
    suite_id = null, matching_status = 'pending', matching_score = null;

  insert into public.suites (name, session, floor, college, single_rooms, double_rooms, capacity, created_by)
  values
    ('Session II Franklin Demo', 'Session II', 2, 'benjamin_franklin', 2, 2, 6, joshua_id),
    ('Session II Murray Demo', 'Session II', 3, 'pauli_murray', 0, 2, 4, joshua_id)
  on conflict (name) do update set
    session = excluded.session, floor = excluded.floor, college = excluded.college,
    single_rooms = excluded.single_rooms, double_rooms = excluded.double_rooms,
    capacity = excluded.capacity;
end;
$$;
