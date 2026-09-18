# UKPath — Testing Guide: Web

This doc is scoped to the website only, so it can run **concurrently** with [Android testing](UKPath-Testing-Guide-Android.md) and [iOS testing](UKPath-Testing-Guide-iOS.md) — all three share the same test-environment backend (see [Deployment Guide](../UKPath-Deployment-Guide.md#1-environments--two-not-one)) and don't block each other.

See the [Documentation Index](../README.md) for how this fits with the other docs.

---

## 1. What Backend This Runs Against

Web testing runs against the **test environment** — deployed at `test.ukpath.app` / `api-test.ukpath.app` (or the local `docker compose` stack from [Deployment Guide §2.3](../UKPath-Deployment-Guide.md#23-docker-composeyml-for-localtest-stack)) — never production.

## 2. Getting a Build to Test (No CodeMagic Needed — Web Deploys Directly)

Unlike the mobile apps, the website doesn't need a cloud mobile-build service — the [CI/CD pipeline](../UKPath-Deployment-Guide.md#3-cicd-pipeline) already auto-deploys every merge to `main` to the test environment. To test a specific branch before merge:
1. Open the PR — most hosting setups (Vercel/Netlify-style, or the Docker-based deploy from the Deployment Guide) can produce a **preview URL per branch/PR**, isolated from the shared test environment
2. Otherwise, run `docker compose up` locally using `Dockerfile.dev` while iterating (see [Deployment Guide §2.1](../UKPath-Deployment-Guide.md#21-dockerfiledev--rebuilds-fresh-for-active-development))

## 3. Test Matrix — Browsers & Viewports

Since a large share of visitors land on the website from a phone browser before ever downloading the app (per [Developer Guide §8.4](../UKPath-Developer-Guide.md#84-making-the-website-feel-like-the-same-app)), **mobile-web is not a secondary check here — test it first.**

| Priority | Target | Why |
|---|---|---|
| Must test | Mobile Safari on iOS (real iPhone or simulator) | Largest share of India→UK searchers likely arrive via mobile search/social links |
| Must test | Mobile Chrome on Android | Same reasoning, Android side |
| Must test | Desktop Chrome | Most common desktop browser |
| Should test | Desktop Safari, desktop Firefox | Secondary but non-trivial share |
| Should test | A narrow viewport (~360px) and a wide desktop viewport (~1440px+) | Confirms responsive breakpoints, not just "it works on my laptop" |

## 4. Functional Test Areas

- [ ] **Google/Apple sign-in on web** — confirms a user's saved itinerary follows them between phone and desktop, per [Developer Guide §8.4](../UKPath-Developer-Guide.md#84-making-the-website-feel-like-the-same-app)
- [ ] **SEO content pages** (city guides, "how to..." articles) render correctly server-side (view page source, not just the rendered DOM, to confirm SSR is actually working for crawlers)
- [ ] **Affiliate comparison pages** (SIM, money) — outbound links resolve to the correct tracked affiliate URL (see [Developer Guide §22](../UKPath-Developer-Guide.md#22-admin-only-reference-affiliatepartner-programs-not-for-user-facing-display)), and no partner/commission data is ever visible in page source or network responses
- [ ] **Itinerary builder (lite web version)** — matches the app's data via the same backend API, confirm an itinerary created on web appears correctly if the same account logs into the app
- [ ] **Emergency contacts page** loads fast and correctly even on a throttled/slow connection (simulate via browser dev tools network throttling)
- [ ] **Checkout flows**, if surfaced on web — same [compliance gate](../UKPath-Compliance-Guide.md#code-enforced-compliance-gate) behavior as the mobile apps; confirm the web client shows a sensible "not yet available" message rather than a raw 503
- [ ] **Cookie consent banner** appears and functions correctly (UK GDPR requirement, web-specific — the app doesn't need this the same way)

## 5. Automated Testing in CI

- [ ] Unit tests run on every PR (per [Deployment Guide §3](../UKPath-Deployment-Guide.md#3-cicd-pipeline))
- [ ] A smoke-test suite (e.g. Playwright/Cypress) runs against the deployed test environment after every merge to `main`, covering: homepage loads, sign-in works, one listing page loads, one affiliate link resolves
- [ ] Lighthouse/performance budget check in CI, since SEO ranking and mobile-first performance are core to the website's acquisition strategy (per [Developer Guide §5](../UKPath-Developer-Guide.md#5-website-vs-app-split))

## 6. Non-Functional Checks

- [ ] Responsive, mobile-first layout — verify with real devices from §3, not just browser dev-tools resizing
- [ ] Shared design system consistency — same colors/typography/icons as the app (per [Developer Guide §8.4](../UKPath-Developer-Guide.md#84-making-the-website-feel-like-the-same-app)); flag any drift back to whoever owns the design system doc
- [ ] No sensitive tokens or partner data exposed in browser dev tools (Network tab, `localStorage`, page source) — see [Security Guide §2](../UKPath-Security-Guide.md#2-data-handling)

## 7. Reporting Results

Log defects against the module/page they belong to, and record the deployed test-environment build/commit hash tested, so a fix can be verified against the same build lineage — same convention as the [Android](UKPath-Testing-Guide-Android.md#7-reporting-results) and [iOS](UKPath-Testing-Guide-iOS.md#7-reporting-results) guides.
