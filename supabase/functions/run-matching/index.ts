import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { executeMatching } from '../_shared/matching.ts';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
Deno.serve(async request => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization) throw new Error('Authentication required');
    const url = Deno.env.get('SUPABASE_URL')!;
    const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } } });
    const { data: { user } } = await userClient.auth.getUser();
    const { data: allowed } = await userClient.rpc('is_admin');
    if (!user || !allowed) throw new Error('Admin access required');
    const service = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    return response(await executeMatching(service, user.id));
  } catch (error) { return response({ error: error instanceof Error ? error.message : 'Matching failed' }, 400); }
});
function response(value: unknown, status = 200) { return new Response(JSON.stringify(value), { status, headers: { ...cors, 'Content-Type': 'application/json' } }); }
