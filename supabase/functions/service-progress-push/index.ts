type ProgressNotification = {
  id: string;
  user_id: string;
  service_request_id: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
};

type DatabaseWebhookPayload = {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: string;
  schema: string;
  record: ProgressNotification;
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  });

function base64Url(value: string | Uint8Array): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

async function createGoogleAccessToken(): Promise<string> {
  const email = Deno.env.get('FCM_CLIENT_EMAIL');
  const privateKeyPem = Deno.env.get('FCM_PRIVATE_KEY')?.replaceAll('\\n', '\n');
  if (!email || !privateKeyPem) throw new Error('FCM credentials are not configured.');

  const privateKeyBytes = Uint8Array.from(
    atob(privateKeyPem.replace(/-----[^-]+-----/g, '').replaceAll(/\s/g, '')),
    (character) => character.charCodeAt(0),
  );
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    privateKeyBytes,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const now = Math.floor(Date.now() / 1000);
  const unsignedJwt = `${base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${base64Url(
    JSON.stringify({
      iss: email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  )}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(unsignedJwt),
  );
  const assertion = `${unsignedJwt}.${base64Url(new Uint8Array(signature))}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const tokenBody = await tokenResponse.json();
  if (!tokenResponse.ok || typeof tokenBody.access_token !== 'string') {
    throw new Error(`Could not obtain an FCM access token: ${JSON.stringify(tokenBody)}`);
  }
  return tokenBody.access_token;
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return jsonResponse({ error: 'Method not allowed' }, 405);

  const webhookSecret = Deno.env.get('PUSH_WEBHOOK_SECRET');
  if (!webhookSecret || request.headers.get('x-push-webhook-secret') !== webhookSecret) {
    return jsonResponse({ error: 'Unauthorized' }, 401);
  }

  const projectId = Deno.env.get('FCM_PROJECT_ID');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!projectId || !supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Push sender configuration is incomplete.' }, 500);
  }

  let payload: DatabaseWebhookPayload;
  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid webhook payload.' }, 400);
  }
  if (payload.table !== 'service_progress_notifications' || !payload.record?.user_id) {
    return jsonResponse({ error: 'Unsupported notification event.' }, 400);
  }

  const supabaseHeaders = {
    apikey: serviceRoleKey,
    authorization: `Bearer ${serviceRoleKey}`,
  };
  const tokenUrl = new URL('/rest/v1/push_device_tokens', supabaseUrl);
  tokenUrl.searchParams.set('select', 'fid');
  tokenUrl.searchParams.set('user_id', `eq.${payload.record.user_id}`);
  const tokensResponse = await fetch(tokenUrl, { headers: supabaseHeaders });
  if (!tokensResponse.ok) {
    return jsonResponse({ error: 'Could not load recipient device tokens.' }, 502);
  }
  const devices = (await tokensResponse.json()) as Array<{ fid: string }>;
  if (devices.length === 0) return jsonResponse({ sent: 0 });

  const accessToken = await createGoogleAccessToken();
  const results = await Promise.all(
    devices.map(async ({ fid }) => {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
        {
          method: 'POST',
          headers: {
            authorization: `Bearer ${accessToken}`,
            'content-type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              fid,
              notification: {
                title: payload.record.title,
                body: payload.record.body,
              },
              data: Object.fromEntries(
                Object.entries(payload.record.data ?? {}).map(([key, value]) => [
                  key,
                  String(value),
                ]),
              ),
              android: { priority: 'high' },
              apns: {
                payload: { aps: { sound: 'default' } },
              },
            },
          }),
        },
      );
      const responseBody = await response.json().catch(() => ({}));
      const errorCode = responseBody?.error?.details?.find(
        (detail: { errorCode?: string }) => detail.errorCode,
      )?.errorCode;
      if (errorCode === 'UNREGISTERED') {
        const deleteUrl = new URL('/rest/v1/push_device_tokens', supabaseUrl);
        deleteUrl.searchParams.set('fid', `eq.${fid}`);
        await fetch(deleteUrl, { method: 'DELETE', headers: supabaseHeaders });
      }
      return response.ok;
    }),
  );

  return jsonResponse({ sent: results.filter(Boolean).length, attempted: results.length });
});
