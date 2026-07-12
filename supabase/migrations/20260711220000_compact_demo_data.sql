-- Keep the populated suites and the successful matching run for a clean demo.
delete from public.suites as suite
where not exists (
  select 1 from public.suite_members as member where member.suite_id = suite.id
);

delete from public.matching_runs where status = 'failed';
