# SpendWise — Interview Reference

Source-based reference, 31 October 2026. All paths are relative to `C:\Flutter practice\SPENDWISE`. See [complete documentation](SPENDWISE_COMPLETE_TECHNICAL_DOCUMENTATION.md) for API contracts, schema, setup and limitations.

## A natural 2–3 minute explanation

“SpendWise is a personal finance application built with Flutter and a Flask REST backend. It lets users record income and expenses, track category budgets, view spending charts, create recurring entries and manage their own balances with friends after an outing.

“The Flutter app separates screens, models, controllers and services. For example, the home screen owns a TransactionController, which gets transaction data through ApiService. The service sends JSON requests with a JWT. Flask verifies the token, runs the route logic and uses SQLAlchemy models to access the configured relational database. PostgreSQL is the deployment target; the automated backend tests use isolated SQLite. After a successful write, the frontend reloads data and rebuilds the relevant views.

“A useful feature is Magic Entry. A user can type something like ‘Spent 500 on dinner yesterday.’ The active backend route builds a Gemini prompt using available categories, goal names, recent transactions and a few relevant categorization examples. It asks for structured JSON, normalizes the returned category, parses the amount and date, and saves a normal Transaction. It uses an external model rather than a custom-trained NLP model. I would verify the configured model before a live demonstration, because generation was not exercised in the documentation checks.

“Outing splitting is another feature I can explain mathematically. For each payer contribution, the Flutter code divides that amount equally across all current members and builds a pairwise ledger. It then offsets what each friend owes me against what I owe them. Only my personal net debts are saved, with the raw event history. Partial payments reduce a stored debt; this does not transfer money or automatically create an expense transaction.

“Goals are category budgets, not savings accounts: spending is derived by matching a transaction category to a goal name within its dates. Charts are also computed locally from loaded transactions. The backend scheduler creates recurring transaction records and notifications when subscriptions become due.

“The existing isolated checks pass, but there are concrete limitations. Some update/delete routes need ownership checks, the two clear-transaction routes have inconsistent period contracts, and editing outings can reset payment progress. Those are the first areas I would strengthen before a broader multi-user release.”

Use this as an explanation of the code. Claim personal authorship or deployment work only if it reflects your own contribution.

## Architecture and technology choices

- Flutter/Dart: shared UI code with async forms, local state and platform hosts. `setState`, callbacks and ValueNotifier provide the implemented state mechanism; do not claim Bloc/Provider.
- Flask blueprints: organize accounts, transactions, goals, outings and other REST routes by feature.
- SQLAlchemy: models, queries and session commits; PostgreSQL deployment, SQLite for isolated tests. No migration framework was found.
- JWT + Werkzeug: token-based login and hashed passwords. Authentication exists; authorization is incomplete on several mutations.
- Google Gemini: external structured extraction/few-shot prompting for Magic Entry, plus separate spending advice generation. No spaCy, NLTK or model training.
- fl_chart: transaction-derived donut/trend data. SharedPreferences: preferences/JWT, not the financial database.
- APScheduler/provider cron: periodic recurring-entry processing. FileSaver/csv/pdf: local statement exports.
- Node/Cloudflare Worker/Vercel: web asset serving, proxy and hosting configuration. Node is not the financial API backend. These roles explain the implementation; they are not verified statements about the author's original technology-selection rationale.

Deployed-web flow: Flutter → ApiService → outer `/api` Worker proxy → Flask/JWT/routes → SQLAlchemy → financial DB. Local direct clients can bypass the proxy. Magic/insights call Google from Flask. Reset codes use separate temporary memory/Durable Object storage.

## Source navigation and likely questions

| Interviewer question | Exact source files and functions to open | Main point |
| --- | --- | --- |
| How does the app start? | `SpendWise/lib/main.dart::main`, `MyApp.build`; `SpendWise/lib/views/splashscreen.dart::initState` | Restore preferences, initialize notifications, token-presence navigation. Theme is currently forced dark. |
| Where is state managed? | `SpendWise/lib/views/homepage.dart::_loadData`; `SpendWise/lib/controllers/transaction_controller.dart::TransactionController` | Parent owns controller/list; async loads plus setState/callbacks, not a reactive framework. |
| How do you communicate with Flask? | `SpendWise/lib/services/api_service.dart::baseUrl`, `_headers`, `getTransactions`, `addTransaction` | Compile-time base URL, JSON, Bearer JWT; many failures collapse to empty/false. |
| How is login secured? | `expense_tracker_backend/routes/auth.py::register`, `login`; `expense_tracker_backend/config.py::Config` | Password hash, JWT identity, 30-day expiry, private configuration. |
| Explain transaction creation. | `SpendWise/lib/views/floatingactionbutton.dart::_onSave`; `SpendWise/lib/models/transaction.dart::toMap`; `expense_tracker_backend/routes/transactions.py::add_transaction` | Form → JSON → validation/conversion → ORM commit → reload. |
| How does JSON become UI data? | `SpendWise/lib/controllers/transaction_controller.dart::loadTransactions`; `SpendWise/lib/models/transaction.dart::fromMap`; `SpendWise/lib/views/homepage.dart::filtered` | Parse number/date/key conventions, filter models, rebuild. |
| Where is the database schema? | `expense_tracker_backend/models/database.py::db`; `expense_tracker_backend/models/transaction.py::Transaction`; `expense_tracker_backend/models/outing.py::Outing`, `OutingDebt` | Model-defined schema, owner FKs, outing/debt relationship, JSON history. |
| What AI/NLP technique is used? | `expense_tracker_backend/routes/magic.py::TransactionSchema`, `magic_entry` | Google genai SDK, literal gemini-3.6-flash setting, dynamic few-shot prompt + schema, not custom training. |
| Are there two Magic routes? | `expense_tracker_backend/routes/magic.py::magic_entry`; `expense_tracker_backend/routes/transactions.py::magic_entry`; `SpendWise/lib/services/api_service.dart::sendMagicEntry` | Flutter calls `/api/magic/entry`; legacy `/transactions/magic` has different model/response and no Flutter caller. |
| How do splits work? Complexity? | `SpendWise/lib/views/new_outings_page.dart::_calculateAndSave`, `OutingEvent`, `CalculatedDebt` | Equal contribution shares, N×N ledger, personal netting; O(E N²+N²) time/O(N²) space. |
| What happens on partial settlement? | `SpendWise/lib/views/outings_page.dart::_applyPayment`; `expense_tracker_backend/routes/outings.py::update_debt` | Subtract, tolerance<=0.01, optimistic UI, owner check/commit, reload on failure. |
| What is a goal? | `SpendWise/lib/views/goals.dart::_spentForGoal`, `_GoalFormState._submit`; `expense_tracker_backend/routes/goals.py::update_goal` | Category budget, date-filtered expense sum; no savings deposits. |
| How do budget alerts trigger? | `SpendWise/lib/controllers/notification_controller.dart::checkGoals`; `SpendWise/lib/services/notification_service.dart::showWarning`, `showExceeded` | Crossings relative to prior in-memory spending; first check suppressed, local permission required. |
| How do charts update? | `SpendWise/lib/views/analysis.dart::_filteredTransactions`, `_categorySpends`, `_buildTrendChart`, `_showingSections` | Client aggregation and fl_chart rebuild; no chart-write API. |
| What does AI analysis see? | `expense_tracker_backend/routes/analysis.py::get_insights`; `SpendWise/lib/views/analysis.dart::_generateInsights` | Fixed last-30-day aggregates/currency, separate from selected chart period. |
| How do recurring entries work? | `expense_tracker_backend/cron.py::check_and_process_subscriptions`, `add_months`; `expense_tracker_backend/app.py::scheduled_subscriptions` | Due query → transaction + notification → advance once/commit; PostgreSQL advisory lock. |
| How are reset codes stored? | `expense_tracker_backend/reset_store.py::issue_code`, `consume_code`, `_exchange`; `deployment/worker.js::ResetCodes` | Hash/HMAC, 10-minute TTL, five attempts, single use; console delivery only. |
| How does deployment routing work? | `deployment/worker.js::fetch`; `wrangler.jsonc`; `expense_tracker_backend/vercel.json` | Worker strips one prefix; Magic appears externally at `/api/api/magic/entry`. |
| Can you export transactions? | `SpendWise/lib/services/export_service.dart::exportToCSV`, `exportToPDF`; `SpendWise/lib/views/homepage.dart::_buildHome` | Exports selected filtered data via FileSaver; PDF amount text omits currency symbol. |
| What would you fix first? | `expense_tracker_backend/routes/transactions.py::update_transaction`, `delete_transaction`; `expense_tracker_backend/routes/goals.py::update_goal`; `expense_tracker_backend/routes/subscriptions.py::update_subscription`, `delete_subscription`; `expense_tracker_backend/app.py::clear_transactions` | Owner checks and destructive-clear contract mismatch; then outing payment preservation and validation. |
| What testing is actually present? | `expense_tracker_backend/tests/test_deployment.py::DeploymentTests`, `ServerlessTests`; `deployment/worker.test.js`; `SpendWise/test/widget_test.dart` | Six backend/seven Worker checks passed; Flutter test remains unrelated counter template. |

## Data flows to remember

1. Manual: home sheet → `_onSave` → Transaction.toMap → controller.addTransaction → ApiService → POST `/transactions` → Transaction INSERT/commit → home reload/fromMap/setState.
2. Magic: text → sendMagicEntry → POST `/api/magic/entry` → query categories/goals/history → prompt/schema/Gemini → normalize/parse → Transaction commit → unwrap/fromMap/checkGoals/reload.
3. Dashboard: `_loadData` → GET transactions/goals/notifications/profile → controller/models/preferences → getFiltered → income/expense/balance. No dashboard endpoint.
4. Goal update: `_submit` → PUT `/goals/<id>` → update/commit → callback/reload → recomputed category spending.
5. Outing: event form → pairwise calculation → parent payload → POST/PUT `/outings` → Outing/OutingDebt commit → reload. Settlement uses PUT `/outings/debt/<id>` only.
6. Charts: refreshed controller snapshot + period/series state → local aggregation → fl_chart. AI insights independently GET `/analysis/insights`.

## Numerical example and honest limitations

Me/A/B: Me pays 300, A pays 120. Each contribution is divided by three. A owes Me 100, Me owes A 40, so saved net receive from A is 60; B owes Me 100. My total net receive is 160 (=300−420/3). B's 40 owed to A is outside my saved debt list. This does not minimize group transfers.

Know these before a demo:

- Avoid week/month bulk-clear demonstration against real records: Settings label capitalization differs from app.py, so these filters can clear all user transactions.
- JWT alone is not record ownership. Several transaction/goal/subscription mutation handlers lack owner checks.
- Outing edit rebuilds debts with unsettled flags; nonpaying members may be lost because members are restored from payer keys. No immutable payment log.
- AI is external and not live-verified here; structured generation still needs stronger business validation/user review. Older Google SDK use emitted a deprecation warning.
- Amounts are floats, currency is display labeling, date rules differ, read failures can look empty, reset codes are logged rather than emailed.
- No claim of bank integration, custom NLP training, complete savings-goal contributions, minimum-transfer optimization or bug-free behavior is supported.

## Verification and a practical walkthrough

This documentation task ran six isolated backend tests and seven Worker tests successfully. It did not run Flutter builds/tests, live AI, native notifications, export rendering, production cron or live DB checks. The backend tests use in-memory SQLite and mock cron/shared-store operations where applicable.

For 15–20 minutes: spend about three minutes on the project explanation, four on a transaction/auth/database trace, four on Magic Entry and splitting, three on goals/analytics/cron, and the remaining time on tests and specific improvements. Open the source files above, not secret environment files. Before any demo, use disposable data and verify the selected API base URL and AI configuration.
