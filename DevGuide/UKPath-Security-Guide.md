# UKPath — Security Guide

### Technical Security Controls (Engineering Work, Not Legal Sign-Off)

This is separate from the [Compliance Guide](UKPath-Compliance-Guide.md): that document tracks legal/regulatory approvals a human must sign off on; this document tracks the technical controls developers implement and QA verifies. A feature can be legally compliant but still technically insecure, or vice versa — both gates must pass. See the [Documentation Index](README.md) for how all docs relate.

---

## 1. Transport & Auth

- [ ] HTTPS/TLS everywhere, HSTS enabled — no plain-HTTP endpoint anywhere, including internal service-to-service calls
- [ ] JWT with short expiry (e.g. 15 min access token) + refresh tokens stored securely (httpOnly, secure cookies — never `localStorage`)
- [ ] Firebase Auth/Auth0 handles Google/Apple sign-in — don't hand-roll OAuth flows
- [ ] Guest sessions use a device-generated anonymous ID only — no PII collected for guest mode
- [ ] Apple Sign-In is mandatory alongside any other third-party login, per App Store rules — already satisfied by Google + Apple

## 2. Data Handling

- [ ] No table stores DOB, passport numbers, addresses (beyond delivery use), or card numbers — enforced by schema design (see [Developer Guide §2](UKPath-Developer-Guide.md#2-core-data-model)), not just application logic
- [ ] Raw card numbers never touch UKPath's own servers — Stripe Checkout/Elements handles this; UKPath only stores Stripe's tokenized references
- [ ] Encrypt at rest for anything that is stored (PostgreSQL disk encryption, S3/blob server-side encryption)
- [ ] Data deletion endpoint for user-requested account/data removal (supports UK GDPR right-to-erasure — the legal requirement lives in the Compliance Guide, the endpoint itself is this doc's concern)

## 3. API Hardening

- [ ] Rate-limit auth and service-request endpoints (protects against credential stuffing and abuse)
- [ ] API rate limiting per user/IP generally, especially on any endpoint that calls a paid third-party API (Google Maps) — protects against runaway cost, not just abuse
- [ ] Input validation/sanitization on every endpoint — especially anything that ends up in a SQL query (use parameterized queries/ORM, never string-concatenated SQL) or is rendered back to a client (XSS)
- [ ] CORS locked down to known app/website origins, not `*`
- [ ] Log affiliate redirects for revenue tracking only, not for user behavior profiling — keep the logging schema intentionally narrow

## 4. Payments (Technical Side)

The legal KYB/registration requirements live in the [Compliance Guide §4](UKPath-Compliance-Guide.md#4-payments-compliance); the technical controls are:
- [ ] PCI DSS scope minimized by using Stripe Checkout/Elements (Stripe is Level 1 PCI DSS certified) — never build a custom card form that touches raw card data
- [ ] Strong Customer Authentication (SCA) flows left intact — do not attempt to bypass or "simplify" the Stripe-provided authentication step
- [ ] Stripe webhook signatures verified on every incoming webhook (prevents spoofed payment-confirmation events)
- [ ] Manual-capture flows (personal-shopper model) have a server-side check that the authorized amount and final captured amount stay within an expected tolerance before auto-settling

## 5. Secrets & Configuration

- [ ] No API keys, DB credentials, or Stripe secret keys committed to the repository — use environment variables, injected via the deployment pipeline (see [Deployment Guide](UKPath-Deployment-Guide.md))
- [ ] Separate credentials per environment (test vs. production) — a leaked test-environment key should never grant access to production data
- [ ] Secrets rotated on a schedule and immediately if a leak is suspected
- [ ] `.env` files are git-ignored; only `.env.example` (with placeholder values) is committed

## 6. Dependency & Build Security

- [ ] Automated dependency vulnerability scanning in CI (`npm audit` / GitHub Dependabot or equivalent) on every PR
- [ ] Lockfiles (`package-lock.json`) committed so builds are reproducible and not silently pulling a compromised newer version
- [ ] Docker images built from pinned base image versions (see [Deployment Guide](UKPath-Deployment-Guide.md#docker-strategy)), not `:latest`, so a build today produces the same environment as a build next month

## 7. Mobile-Specific

- [ ] App Tracking Transparency (ATT) prompt on iOS if any analytics/ad tracking is used
- [ ] Deep links / App Links validated server-side (don't trust a deep link's parameters blindly — validate before acting on them, e.g. before opening a payment or service-request screen)
- [ ] No sensitive data (tokens, cached personal data) written to device logs in release builds

## 8. Incident Response Basics

- [ ] A documented process (even a short one) for what happens if a data breach or key leak is suspected — who gets notified, how quickly, and that ICO notification timelines (legal side, Compliance Guide) are met
- [ ] Centralized logging/monitoring (see [Deployment Guide](UKPath-Deployment-Guide.md)) so an anomaly (spike in failed auth attempts, unusual API volume) is visible before it becomes a bigger incident

---

## How This Interacts With Testing

Security checks are part of the automated CI pipeline described in the [Deployment Guide](UKPath-Deployment-Guide.md#cicd-pipeline) and the platform-specific [Testing Guides](Testing/) — dependency scans and basic auth/rate-limit tests should run on every PR against the test environment, not only before launch.
