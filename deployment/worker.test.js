import test from 'node:test';
import assert from 'node:assert/strict';
import worker, {ResetCodes} from './worker.js';

const realFetch = globalThis.fetch;
test.afterEach(() => { globalThis.fetch = realFetch; });

test('forwards auth, encoded paths, query, method and body; never caches financial data', async () => {
  globalThis.fetch = async (url, options) => {
    assert.equal(String(url), 'https://backend.example/categories/by-name/Food%20and%20Drink?test=1');
    assert.equal(options.method, 'PUT');
    assert.equal(options.headers.get('Authorization'), 'Bearer test-token');
    assert.equal(options.headers.has('Cookie'), false);
    assert.equal(options.redirect, 'manual');
    assert.equal(await new Response(options.body).text(), '{"new_name":"Food"}');
    return new Response('{"ok":true}', {status: 201, headers: {'Cache-Control': 'public, max-age=3600'}});
  };
  const response = await worker.fetch(new Request('https://frontend.example/api/categories/by-name/Food%20and%20Drink?test=1', {
    method: 'PUT', headers: {Authorization: 'Bearer test-token', Cookie: 'private=1'}, body: '{"new_name":"Food"}'
  }), {API_ORIGIN: 'https://backend.example'});
  assert.equal(response.status, 201);
  assert.equal(response.headers.get('Cache-Control'), 'private, no-store');
});

test('preserves the existing /api/magic route without rewriting Flask', async () => {
  globalThis.fetch = async url => {
    assert.equal(String(url), 'https://backend.example/api/magic/entry');
    return new Response('{}');
  };
  await worker.fetch(new Request('https://frontend.example/api/api/magic/entry'), {API_ORIGIN: 'https://backend.example'});
});

test('nested frontend routes are handled by SPA assets', async () => {
  let requested;
  const response = await worker.fetch(new Request('https://frontend.example/dashboard/expenses'), {
    ASSETS: {fetch: async request => { requested = request.url; return new Response('flutter'); }}
  });
  assert.equal(requested, 'https://frontend.example/dashboard/expenses');
  assert.equal(await response.text(), 'flutter');
});

test('missing upstream never falls back to cached SPA HTML', async () => {
  const response = await worker.fetch(new Request('https://frontend.example/api/transactions'), {});
  assert.equal(response.status, 503);
  assert.match(response.headers.get('Content-Type'), /json/);
});

test('upstream failures and redirects remain private and same-origin', async () => {
  globalThis.fetch = async () => { throw new Error('offline'); };
  const request = new Request('https://frontend.example/api/auth/profile');
  assert.equal((await worker.fetch(request, {API_ORIGIN: 'https://backend.example'})).status, 502);
  globalThis.fetch = async () => new Response(null, {status: 308, headers: {Location: '/auth/profile/'}});
  const response = await worker.fetch(request, {API_ORIGIN: 'https://backend.example'});
  assert.equal(response.headers.get('Location'), 'https://frontend.example/api/auth/profile/');
});


test('reset endpoint rejects unauthenticated or malformed requests', async () => {
  const url = 'https://frontend.example/internal/reset-codes';
  assert.equal((await worker.fetch(new Request(url), {})).status, 401);
  const env = {RESET_STORE_SECRET: 'test'};
  assert.equal((await worker.fetch(new Request(url, {headers:{Authorization:'Bearer test'}}), env)).status, 405);
  assert.equal((await worker.fetch(new Request(url, {method:'POST', headers:{Authorization:'Bearer test'}, body:'{}'}), env)).status, 400);
});

test('reset state survives object recreation and prevents replay, brute force and expiry', async () => {
  let saved;
  const storage = {
    async get(){return saved ? structuredClone(saved) : undefined;},
    async put(key,value){saved=structuredClone(value);},
    async deleteAll(){saved=undefined;}, async setAlarm(){}, async deleteAlarm(){}
  };
  const ctx={storage,blockConcurrencyWhile:fn=>fn()};
  let object=new ResetCodes(ctx);
  const request=async (action,digest='a'.repeat(64))=>(await (await object.fetch(new Request('https://reset.internal/',{method:'POST',body:JSON.stringify({action,digest})}))).json()).ok;
  assert.equal(await request('issue'),true);
  object=new ResetCodes(ctx);
  assert.equal(await request('consume'),true);
  assert.equal(await request('consume'),false);
  await request('issue');
  for(let i=0;i<5;i++) assert.equal(await request('consume','b'.repeat(64)),false);
  assert.equal(await request('consume'),false);
  await request('issue'); saved.expires=Date.now()-1;
  assert.equal(await request('consume'),false);
});
