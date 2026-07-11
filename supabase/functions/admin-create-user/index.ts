import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) throw new Error('Authentication required');

    const url = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
    const adminClient = createClient(url, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) throw new Error('Authentication required');

    const { data: allowed, error: roleError } = await userClient.rpc('is_admin');
    if (roleError || !allowed) throw new Error('Admin access required');

    const { email, password } = await request.json();
    if (typeof email !== 'string' || typeof password !== 'string') throw new Error('Email and password are required');
    if (password.length < 8) throw new Error('Password must contain at least 8 characters');

    const { data, error } = await adminClient.auth.admin.createUser({
      email: email.trim().toLowerCase(),
      password,
      email_confirm: true,
    });
    if (error) throw error;

    return new Response(JSON.stringify({ userId: data.user.id, email: data.user.email }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 201,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Could not create user';
    const status = message.includes('Admin access') ? 403 : message.includes('Authentication') ? 401 : 400;
    return new Response(JSON.stringify({ error: message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status,
    });
  }
});
