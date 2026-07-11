-- Bootstrap the first SuiteSync administrator from an existing Auth account.
do $$
declare
  admin_user_id uuid;
begin
  select id into admin_user_id
  from auth.users
  where lower(email) = lower('joshuabie2010@gmail.com')
  limit 1;

  if admin_user_id is null then
    raise exception 'The initial admin Auth account does not exist';
  end if;

  insert into public.admin_users (user_id)
  values (admin_user_id)
  on conflict (user_id) do nothing;
end;
$$;
