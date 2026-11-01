export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/internal/reset-codes') return handleResetStore(request, env);
    if (url.pathname !== '/api' && !url.pathname.startsWith('/api/')) {
      return env.ASSETS.fetch(request);
    }
    const headers = new Headers({'Content-Type': 'application/json', 'Cache-Control': 'private, no-store'});
    if (!env.API_ORIGIN) return new Response(JSON.stringify({error: 'API is not configured'}), {status: 503, headers});
    let origin;
    try {
      origin = new URL(env.API_ORIGIN);
      if (origin.protocol !== 'https:' || origin.username || origin.password || origin.pathname !== '/' || origin.search || origin.hash) throw new Error();
    } catch {
      return new Response(JSON.stringify({error: 'Invalid API configuration'}), {status: 503, headers});
    }
    // Prefix removal keeps every Flask route unchanged, including its existing /api routes.
    const target = new URL(origin.origin);
    target.pathname = url.pathname.slice(4) || '/';
    target.search = url.search;
    const forwarded = new Headers(request.headers);
    forwarded.delete('host');
    forwarded.delete('cookie'); // Flask authentication uses the Authorization header.
    try {
      const upstream = await fetch(target, {
        method: request.method, headers: forwarded,
        body: ['GET', 'HEAD'].includes(request.method) ? undefined : request.body,
        redirect: 'manual', signal: AbortSignal.timeout(115000),
      });
      const response = new Response(upstream.body, upstream);
      response.headers.set('Cache-Control', 'private, no-store');
      response.headers.set('X-Content-Type-Options', 'nosniff');
      const location = response.headers.get('Location');
      if (location) {
        const redirected = new URL(location, target);
        if (redirected.origin === origin.origin) {
          response.headers.set('Location', url.origin + '/api' + redirected.pathname + redirected.search + redirected.hash);
        }
      }
      return response;
    } catch {
      return new Response(JSON.stringify({error: 'API temporarily unavailable'}), {status: 502, headers});
    }
  }
};


function equalSecret(a, b) {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return difference === 0;
}

const privateJson = (data, status = 200) => Response.json(data, {
  status, headers: {'Cache-Control': 'private, no-store'}
});

export async function handleResetStore(request, env) {
  const secret = env.RESET_STORE_SECRET;
  if (!secret || !equalSecret(request.headers.get('Authorization') || '', 'Bearer ' + secret)) {
    return privateJson({error: 'Unauthorized'}, 401);
  }
  if (request.method !== 'POST') return privateJson({error: 'Method not allowed'}, 405);
  let body;
  try {
    const text = await request.text();
    if (text.length > 1024) return privateJson({error: 'Payload too large'}, 413);
    body = JSON.parse(text);
    if (!['issue', 'consume'].includes(body.action) || !/^[a-f0-9]{64}$/.test(body.key) || !/^[a-f0-9]{64}$/.test(body.digest)) throw new Error();
  } catch {
    return privateJson({error: 'Invalid request'}, 400);
  }
  const object = env.RESET_CODES.get(env.RESET_CODES.idFromName(body.key));
  return object.fetch(new Request('https://reset.internal/', {method: 'POST', body: JSON.stringify(body)}));
}

// SQLite-backed Durable Objects are available on Workers Free. Only an HMAC of
// each short-lived reset code is stored; all financial data stays in Supabase.
export class ResetCodes {
  constructor(ctx) { this.ctx = ctx; }
  async fetch(request) {
    const body = await request.json();
    return this.ctx.blockConcurrencyWhile(async () => {
      const storage = this.ctx.storage;
      if (body.action === 'issue') {
        const expires = Date.now() + 600000;
        await storage.put('code', {digest: body.digest, expires, attempts: 0});
        await storage.setAlarm(expires);
        return privateJson({ok: true});
      }
      const code = await storage.get('code');
      if (!code || code.expires <= Date.now()) {
        await storage.deleteAll();
        return privateJson({ok: false});
      }
      const ok = equalSecret(code.digest, body.digest);
      code.attempts += 1;
      if (ok || code.attempts >= 5) {
        await storage.deleteAll();
        await storage.deleteAlarm();
      } else {
        await storage.put('code', code);
      }
      return privateJson({ok});
    });
  }
  async alarm() {
    const code = await this.ctx.storage.get('code');
    if (code && code.expires > Date.now()) await this.ctx.storage.setAlarm(code.expires);
    else await this.ctx.storage.deleteAll();
  }
}
