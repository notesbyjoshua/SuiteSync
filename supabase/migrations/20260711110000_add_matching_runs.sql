create table if not exists public.matching_runs (
  id uuid primary key default gen_random_uuid(),
  status text not null check (status in ('scheduled', 'awaiting_implementation', 'running', 'completed', 'failed', 'cancelled')),
  trigger_type text not null check (trigger_type in ('manual', 'scheduled')),
  scheduled_for timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  notes text
);

alter table public.matching_runs enable row level security;
revoke all on table public.matching_runs from anon, authenticated;
grant select on table public.matching_runs to authenticated;

create policy "Admins can view matching runs"
on public.matching_runs for select to authenticated
using (public.is_admin());

create or replace function public.admin_start_matching()
returns uuid language plpgsql security definer set search_path = public as $$
declare run_id uuid;
begin
  if not public.is_admin() then raise exception 'Admin access required' using errcode = '42501'; end if;
  insert into public.matching_runs (status, trigger_type, started_at, created_by, notes)
  values ('awaiting_implementation', 'manual', now(), auth.uid(), 'Algorithm worker has not been implemented.')
  returning id into run_id;
  return run_id;
end;
$$;

create or replace function public.admin_schedule_matching(requested_start timestamptz)
returns uuid language plpgsql security definer set search_path = public as $$
declare run_id uuid;
begin
  if not public.is_admin() then raise exception 'Admin access required' using errcode = '42501'; end if;
  if requested_start <= now() then raise exception 'Scheduled time must be in the future'; end if;
  insert into public.matching_runs (status, trigger_type, scheduled_for, created_by, notes)
  values ('scheduled', 'scheduled', requested_start, auth.uid(), 'Awaiting implementation of the scheduled algorithm worker.')
  returning id into run_id;
  return run_id;
end;
$$;

revoke all on function public.admin_start_matching() from public;
revoke all on function public.admin_schedule_matching(timestamptz) from public;
grant execute on function public.admin_start_matching() to authenticated;
grant execute on function public.admin_schedule_matching(timestamptz) to authenticated;
