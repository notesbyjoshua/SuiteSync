-- Franklin 201 is the named suite shown in the My Suite demo.
insert into public.suites (name, session, floor, college, single_rooms, double_rooms, capacity, created_by)
select 'Franklin 201', 'Session II', 2, 'benjamin_franklin', 1, 2, 5, user_id
from public.admin_users
limit 1
on conflict (name) do update set
  session = excluded.session,
  floor = excluded.floor,
  college = excluded.college,
  single_rooms = excluded.single_rooms,
  double_rooms = excluded.double_rooms,
  capacity = excluded.capacity;

-- This inventory lets applicants who request zero suitemates receive a true solo suite.
insert into public.suites (name, session, floor, college, single_rooms, double_rooms, capacity, created_by)
select 'Franklin 401', 'Session II', 4, 'benjamin_franklin', 1, 0, 1, user_id
from public.admin_users
limit 1
on conflict (name) do update set
  session = excluded.session,
  floor = excluded.floor,
  college = excluded.college,
  single_rooms = excluded.single_rooms,
  double_rooms = excluded.double_rooms,
  capacity = excluded.capacity;
