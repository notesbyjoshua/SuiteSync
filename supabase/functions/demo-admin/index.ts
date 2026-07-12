import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await request.json();
    if (body.password !== Deno.env.get('DEMO_ADMIN_PASSWORD')) {
      return new Response(JSON.stringify({ error: 'Incorrect demo password' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: admin } = await client.from('admin_users').select('user_id').limit(1).single();
    if (!admin) throw new Error('No administrator account is configured');

    if (body.action === 'load') {
      const [suites, responses, runs] = await Promise.all([
        client.from('suites').select('id,name,session,floor,college,capacity,status,suite_members(count)').order('name'),
        client.from('survey_responses').select('id,preferred_name,email,track,session,extroversion,organization,room_type,bedtime_preference,preferred_suitemates,floor_preference,college_preference,sound_level,submitted_at,matching_status,suite_id').order('submitted_at'),
        client.from('matching_runs').select('id,status,trigger_type,scheduled_for,started_at,created_at').order('created_at', { ascending: false }).limit(10),
      ]);
      if (suites.error || responses.error || runs.error) throw suites.error || responses.error || runs.error;
      return json({ suites: suites.data, responses: responses.data, runs: runs.data });
    }

    if (body.action === 'create_account') {
      const { data, error } = await client.auth.admin.createUser({ email: String(body.email).trim().toLowerCase(), password: String(body.accountPassword), email_confirm: true });
      if (error) throw error;
      return json({ userId: data.user.id });
    }

    if (body.action === 'create_suite') {
      const { error } = await client.from('suites').insert({ name: body.name, session: body.session || null, floor: body.floor, college: body.college, capacity: body.capacity, created_by: admin.user_id });
      if (error) throw error;
      return json({ success: true });
    }

    if (body.action === 'assign') {
      const { data: suite } = await client.from('suites').select('capacity,suite_members(count)').eq('id', body.suiteId).single();
      if (!suite || (suite.suite_members?.[0]?.count ?? 0) >= suite.capacity) throw new Error('Suite is already at capacity');
      await client.from('suite_members').delete().eq('response_id', body.responseId);
      const { error } = await client.from('suite_members').insert({ suite_id: body.suiteId, response_id: body.responseId, assigned_by: admin.user_id });
      if (error) throw error;
      await client.from('survey_responses').update({ suite_id: body.suiteId, matching_status: 'matched' }).eq('id', body.responseId);
      return json({ success: true });
    }

    if (body.action === 'unassign') {
      await client.from('suite_members').delete().eq('response_id', body.responseId);
      await client.from('survey_responses').update({ suite_id: null, matching_status: 'pending' }).eq('id', body.responseId);
      return json({ success: true });
    }

    if (body.action === 'start_matching') {
      const { error } = await client.from('matching_runs').insert({ status: 'awaiting_implementation', trigger_type: 'manual', started_at: new Date().toISOString(), created_by: admin.user_id, notes: 'Algorithm worker has not been implemented.' });
      if (error) throw error;
      return json({ success: true });
    }

    if (body.action === 'schedule_matching') {
      const scheduled = new Date(body.scheduledFor);
      if (Number.isNaN(scheduled.getTime()) || scheduled <= new Date()) throw new Error('Scheduled time must be in the future');
      const { error } = await client.from('matching_runs').insert({ status: 'scheduled', trigger_type: 'scheduled', scheduled_for: scheduled.toISOString(), created_by: admin.user_id, notes: 'Awaiting implementation of the scheduled algorithm worker.' });
      if (error) throw error;
      return json({ success: true });
    }

    throw new Error('Unknown action');
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Request failed' }, 400);
  }
});

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}
