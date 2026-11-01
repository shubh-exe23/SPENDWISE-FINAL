# SpendWise deployment

## Architecture and cost

Cloudflare Workers Static Assets serves the existing Flutter release and forwards /api requests to the existing Flask app on Vercel Hobby in Singapore. The original Supabase PostgreSQL session pooler, schema and existing records are preserved. No Railway service is used. Vercel is verified Hobby; Cloudflare features were selected for Workers Free, but its account plan has not been independently confirmed. The previous Dockerfile and Gunicorn configuration remain useful for local/container deployments; Vercel does not use them.

Vercel Hobby was verified for team shubh-builds on 2026-09-30. This is a personal, non-commercial portfolio deployment within free-tier quotas, not unlimited hosting. No upgrade, billing activation, credits or paid compute was enabled. Cloudflare uses features available on Workers Free, including SQLite-backed Durable Objects. Free limits can cause requests to be rejected or service paused; cold starts are possible. Cloudflare billing metadata is not exposed to the existing OAuth token, so its dashboard plan still needs verification.

The existing Vercel project spendwise is an older Flutter site and was preserved. The new spendwise-api hosting project uses expense_tracker_backend/app.py directly; no duplicate backend implementation was created. The frontend stays on Cloudflare. Cloudflare Python compatibility was previously tested and rejected for the existing native dependencies; that investigation is complete.

References: [Vercel Flask](https://vercel.com/docs/frameworks/backend/flask), [Hobby](https://vercel.com/docs/plans/hobby), [daily cron limits](https://vercel.com/docs/cron-jobs/usage-and-pricing), [Cloudflare Durable Objects Free](https://developers.cloudflare.com/durable-objects/platform/pricing/).

## Deployment state

Backend project: shubh-builds/spendwise-api. Production deployment is Ready.
Backend: https://spendwise-api-ten.vercel.app
Frontend: https://spendwise.subhayan-spendwise.workers.dev
The original SpendWise Flutter release is already built and validated; no UI rebuild is required for an upstream origin change.

## Configuration

Vercel root: expense_tracker_backend. Native Flask detection uses app.py and the existing requirements.txt; .python-version selects Python 3.14. vercel.json sets sin1, a 60-second maximum, and a daily cron. .vercelignore excludes local environments, tests, credentials and bytecode. No table creation occurs on import.

Production environment variables are uploaded privately from the ignored .env:
- DATABASE_URL: existing Supabase session pooler; config requires TLS.
- JWT_SECRET_KEY: generated private signing key; sign in again after cutover.
- GEMINI_API_KEY: existing Google credential.
- CRON_SECRET: protects the subscription job.
- RESET_STORE_SECRET: shared only by Flask and the Cloudflare reset-code endpoint.
- RESET_STORE_URL: frontend origin plus /internal/reset-codes.
- CORS_ORIGINS: exact Cloudflare origin and http://localhost:5173.
- ENABLE_SCHEDULER=false: Vercel cron replaces process-local background threads.

Cloudflare secrets: API_ORIGIN (Vercel production HTTPS origin) and RESET_STORE_SECRET. No backend secrets are compiled into Flutter. The frontend uses /api and the proxy removes that prefix, preserving existing routes. The legacy /api/magic/entry route therefore remains /api/api/magic/entry externally. Authenticated responses are private/no-store. Static assets are revalidated or briefly cached, and frontend paths fall back to index.html.

## Serverless adaptations

The authenticated /internal/cron/subscriptions endpoint invokes the existing recurring-bill function once daily using Vercel Hobby cron (00:00 UTC schedule, execution may vary within the hour). A PostgreSQL transaction advisory lock prevents overlapping invocations. The original recurrence and catch-up logic is unchanged. Do not run an additional production scheduler against the same database.

Password-reset codes must survive function instance changes. reset_store.py uses the authenticated Cloudflare endpoint with a per-email SQLite-backed Durable Object containing only a hashed email key and HMAC code digest. Codes expire after ten minutes, allow five attempts and are consumed once. No financial data is stored there, and the Supabase schema is unchanged. Local development retains an in-memory fallback; Vercel fails closed if the shared store is missing.

## Tests

Run from the repository root:

```powershell
./expense_tracker_backend/venv/Scripts/python.exe -m unittest discover -s expense_tracker_backend/tests -v
npm run test:proxy
npx wrangler deploy --dry-run
```

Six backend and seven Worker tests pass. Backend tests force isolated SQLite before loading configuration, never production data. They cover registration/login, private headers, expense CRUD, dashboard reads, CORS, authenticated cron, shared reset-store routing, expiry, replay and attempt limits. Worker tests cover API forwarding/redirects/failures, SPA handling and reset authorization/state lifecycle. Cloudflare dry-run passes with 61 existing build assets and the SQLite Durable Object binding.

Previously completed: Flutter release builds, Python 3.14 Linux dependency resolution, read-only Supabase connectivity and expected eight tables, local browser welcome/login rendering and nested-path fallback, and frontend artifact scanning for credentials/old URLs. These checks were preserved rather than repeated without cause.

## Existing application limitations

Password-reset codes are logged by the existing application, not emailed; no email provider was added. The legacy Google SDK/model settings need live verification. Existing record-ownership gaps in some update/delete routes should be fixed before offering an unrestricted multi-user financial service. These are pre-existing application issues, not claims of successful production security testing.

A previously hardcoded database credential remains in Git history; removing it from current sources does not remove historical copies. Rotate that credential separately before sharing history further. Previously tracked compiled Python files are removed from Git tracking but retained locally.

## Provider cleanup

railway.json was removed because it was migration-only and never successfully deployed. The application has no Railway dependency. No Render configuration or Render URL was found in the sources. Existing external Render services, if any, have not been deleted; retire them only after the new public application is verified. No commit or push has been performed.


## Public verification completed on 2026-09-30

- Vercel deployment dpl_CRNLxXWaNFjh89eBdZnUHeFrkonr is Ready; Flask bundle 57.19 MB, runtime region sin1. Build used Python 3.14. Its first attempt exposed UTF-16 requirements.txt; converted to UTF-8 with all 59 dependency pins unchanged.
- Cloudflare version 48e51474-156b-41e4-a435-611167d40b99 deployed the existing release plus proxy and shared reset-code binding. No Flutter UI changes or rebuild were needed in this continuation.
- Actual Cloudflare -> Vercel -> Supabase signup, login, profile, transaction list, goals, notifications, subscriptions, categories and outings passed.
- Expense create, edit, read-back and delete passed using only a new synthetic account. Two additional synthetic chart transactions displayed the expected income 1000, expense 123.45 and balance 876.55; both were removed after verification. One empty test account remains, and the browser was logged out. No existing records were changed or removed.
- Browser welcome/login, dashboard, trend chart, category breakdown, refresh with persistent login, and direct nested URL loading passed. Nested URLs boot the existing application; this does not add named-route restoration. No warning/error console entries were observed during these flows.
- CORS accepts the exact production frontend and rejects an untrusted origin. Unauthenticated transaction and cron requests return 401. Unknown API routes return 404 rather than HTML fallback. Responses have private/no-store caching.
- Live reset-store authorization, issue, consume and replay rejection passed with synthetic hashes, without touching real user reset codes.
- Requests for backend /.env, /app.py and /requirements.txt returned 404. The Flutter release scan found no actual private secret values, old LAN address, Railway URL or Render URL. Source/configuration inspection confirms production API calls use the same-origin /api proxy; a full browser HAR was not captured.
- Most observed warm proxied API requests took approximately 390-665 ms from this computer. The first proxied health check took 1969 ms. These are observations, not a cold-start or latency guarantee.
- Existing-user credentials were not supplied, so existing-user login was not tested. AI report/magic-entry generation and the production recurring-bill job were not invoked; a forced cron run could mutate existing financial records. Cron authentication/invocation routing is covered by isolated tests.

## Files changed in the free-hosting continuation

- Root .gitignore: ignore Vercel local state.
- wrangler.jsonc: shared reset-code Durable Object binding/migration and endpoint routing.
- deployment/worker.js and worker.test.js: authenticated shared reset store and regression tests; prior proxy behavior preserved.
- deployment/README.md: replaced obsolete paid-hosting instructions with this report.
- expense_tracker_backend/vercel.json, .python-version and .vercelignore: native Flask deployment configuration.
- expense_tracker_backend/.gitignore: Vercel/secret exclusions while retaining .env.example.
- expense_tracker_backend/requirements.txt: encoding/line endings only; no version changes.
- expense_tracker_backend/app.py, config.py and cron.py: serverless scheduler guard, protected daily job, bounded DB pooling and overlapping-job lock.
- expense_tracker_backend/reset_store.py and routes/auth.py: shared expiring single-use reset codes for serverless instances.
- expense_tracker_backend/Dockerfile and .dockerignore: include the reset helper for retained local/container deployment support.
- expense_tracker_backend/.env.example and tests/test_deployment.py: new variable names and focused isolated tests.
- expense_tracker_backend/railway.json: removed unused migration-only configuration.
- Ignored local .env updated with generated cron/reset secrets and shared-store URL; Vercel CLI created ignored .vercel metadata and .env.local. No secret values are listed here.

Earlier Flutter API/notification/icon changes, package files, build helper, cache headers, local container configuration and tracked-bytecode removals were preserved. No commit or push was performed.

## Remaining manual checks

Confirm Cloudflare Workers & Pages -> Plans shows Free. The OAuth token cannot read billing subscriptions (403), and the user has not checked the dashboard yet. No paid plan, card, credit purchase or billing activation was requested or performed. Vercel Hobby is confirmed. Free quotas still apply.

For a broader production launch, address the pre-existing ownership gaps, historical credential exposure, log-only password reset delivery and unverified legacy AI configuration described above. There is no required hosting activation left, and this live deployment no longer requires Render or Railway. Existing old hosting services were not deleted.
