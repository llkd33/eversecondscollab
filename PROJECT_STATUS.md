Everseconds – Development Status and TODOs

Last updated: 2025-09-05

Overview
- Monorepo structure:
  - `resale_marketplace_app` (Flutter): customer app with login (phone+password path, OTP flow, Kakao stub), chat, resale flows, products, transactions.
  - `resale_marketplace_web` (Next.js + Supabase): minimal admin login/dashboard using Supabase Auth (email/password).
  - `database` (Supabase SQL): schema, policies, and setup notes.
- Auth providers: Supabase (email/password active; phone provider may be disabled in some envs), local “test mode” session in the app for demoing features without a real account.

Current Status
- Flutter app
  - Phone+Password login implemented; falls back to email path when phone provider disabled.
  - OTP flow screens present; requires enabling Supabase Phone Auth to work end‑to‑end.
  - “테스트 계정으로 보기” button available on Login and on login-required screens to explore app in local test session (admin role) without real auth.
  - Hidden developer tool on Login: long‑press the logo → dialog to create/sign-in a real Supabase test account (`010-9999-0001` / `test1234`).
  - Core screens wired via `go_router`; protected areas use `AuthGuard`.
- Web (Next.js)
  - Admin login page uses `supabase.auth.signInWithPassword({ email, password })`.
  - Session middleware configured with `@supabase/ssr`.
- Database/Supabase
  - `users` table requires non-null `email` and unique `phone`.
  - RLS policies reference `auth.uid()`; roles: `일반`, `대신판매자`, `관리자`.

Known Issues / Decisions
- Phone signups disabled error: If Supabase Phone provider is off, direct phone sign-up returns `phone_provider_disabled`. The app now auto-falls back to email-based signup using a synthetic email (e.g., `u01099990001@everseconds.dev`).
- Web login accepts only email+password. Phone numbers won’t work there.
- Test mode grants admin‑like permissions in app; use only for development/demo.

TODOs (Prioritized)
1) Authentication
- [ ] Decide final strategy: Phone OTP vs Phone+Password vs Email for production.
- [ ] If OTP required, enable Phone provider in Supabase and set SMS settings; add resend limits and rate limiting.
- [ ] Implement Kakao login for real (OAuth flow, user linking).
- [ ] Web: support phone login (optional) or keep admin-only email login.

2) User Management
- [ ] Complete profile editing and validation (name, phone formatting, avatar upload).
- [ ] Enforce role-based access consistently (`관리자`, `대신판매자`, `일반`).

3) Product & Resale Flows
- [ ] Finalize product create/edit UX, image upload (Storage policy review).
- [ ] Resale request/apply flow end‑to‑end including fee logic and status transitions.

4) Chat & Transactions
- [ ] Persist chat, typing indicators; ensure RLS allows participants only.
- [ ] Transaction creation + state changes with checks (buyer/seller/reseller permissions).

5) Testing & Quality
- [ ] Add widget tests for Auth flows (mock Supabase).
- [ ] Basic integration test for login + guarded routes.
- [ ] Linting/formatting in CI; pre-commit hooks.

6) DevOps
- [ ] Supabase env management (.env separation for dev/stage/prod).
- [ ] CI for Flutter (build), Web (lint/build), DB migrations.

Supabase Configuration Checklist (Dev)
- Authentication → Providers
  - Email: enable; for local dev you may disable “Confirm email”.
  - Phone: enable to use OTP/phone sign-up; otherwise the app will use email fallback.
- Authentication → Policies
  - Ensure RLS policies from `database/schema.sql` are applied.
- Storage
  - Buckets for product images and profile images with appropriate RLS.

Testing Guide
- App test mode (no real account)
  - From `/login`, tap “테스트 계정으로 보기”.
  - Or trigger from any login-required screen/dialog.
  - Sign out to exit test mode.
- App with real Supabase account (dev)
  - Long‑press the round logo on the Login screen → Developer Tools → 실행 to create/sign in the test account `010-9999-0001` / `test1234`.
  - Alternatively, if Phone provider is enabled, use OTP or phone+password signup.
- Web admin
  - Use an admin email account; login via `/admin`.

Developer Commands
- Flutter
  - `cd resale_marketplace_app`
  - `flutter clean && flutter pub get && flutter run`
  - If multiple devices: `flutter devices`, then `flutter run -d <id>`
- Web
  - `cd resale_marketplace_web`
  - `npm install && npm run dev`
- Database
  - Apply SQL in Supabase SQL Editor using `database/README.md` instructions.

Release/Go‑Live Checklist
- [ ] Disable app test mode in production builds (hide UI or guard by env flag).
- [ ] Verify Supabase providers, SMTP/SMS credentials.
- [ ] Set production environment variables for web and app.
- [ ] Run smoke tests for auth, product create, chat, transaction.

---

If you need this broken into multiple focused docs (e.g., TESTING.md, AUTH.md), we can split it next.
