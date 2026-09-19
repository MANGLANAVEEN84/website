# UKPath — Test Environment Guide

### The Test Environment, Docker Dev Loop & CI Through Test Deploy

This guide covers everything needed to build and test UKPath **before** anything is promoted to production. Production-specific concerns (the promotion step, release signing, production infra) live in the separate [Production Deployment Guide](../Prod/UKPath-Production-Deployment-Guide.md) — keep the two in sync (see "Staying in Sync" at the bottom) rather than letting either drift.

See the [Documentation Index](../README.md) for how this fits with the other docs. Platform-specific test plans live alongside this guide: [Android](Android/UKPath-Testing-Guide-Android.md), [iOS](iOS/UKPath-Testing-Guide-iOS.md), [Web](Web/UKPath-Testing-Guide-Web.md) — all three run against the one shared test backend described below, so they can be worked on **concurrently** without blocking each other.

---

## 1. The Test Environment

Treat "test" as a real, permanent environment, not a temporary scratch space — it's what every Testing Guide (Android/iOS/Web) runs its checks against before anything is allowed near production.

| | **Test environment** |
|---|---|
| Purpose | QA, CI runs, manual testing, demoing to yourself/stakeholders |
| Database | Separate PostgreSQL instance/schema, seeded with fake data |
| `compliance_approvals` rows | Can be seeded `true` for QA convenience (see [Compliance Guide](../Compliance/UKPath-Compliance-Guide.md#how-this-interacts-with-testing)) — production never does this |
| Payment provider | Stripe **test mode** keys, GoCardless sandbox |
| Third-party APIs | Google Maps/TfL/National Rail test/dev keys where offered, or low-volume real keys with a hard budget cap |
| Secrets | Separate `.env`/secret store from production — a leaked test key must never expose production |
| Mobile builds | CodeMagic builds tagged/signed for internal testing (see §4) |
| URL | e.g. `test.ukpath.app` / `api-test.ukpath.app` |

The production column of this same comparison — and the rule that code/config only ever flows test → production, never the reverse — lives in the [Production Deployment Guide §1](../Prod/UKPath-Production-Deployment-Guide.md#1-the-production-environment).

---

## 1a. Database & File Storage — Test Environment (Low-Cost First)

The goal here is a test environment that's **cheap enough to run continuously** without a second thought, but built on the same interfaces as production so nothing behaves differently when promoted. Cost is optimized here; performance and correctness are optimized in production (§ below and [Production Deployment Guide §5](../Prod/UKPath-Production-Deployment-Guide.md#5-database--file-storage--production-cost-vs-performance)).

| Need | Low-cost test option | Why this is fine for test |
|---|---|---|
| PostgreSQL | A single small managed instance (Railway/Supabase/Neon free or hobby tier, ~$0–10/mo) or the `docker-compose.yml` Postgres container (§2.3) for fully local work | Test data volume is small and disposable — no need for HA, read replicas, or large storage here |
| Redis (cache/sessions) | The `docker-compose.yml` Redis container, or a free-tier hosted Redis (Upstash free tier) | Same reasoning — ephemeral, resettable, ok to lose |
| File/blob storage (photos, offline map tiles, exported PDFs) | **Cloudflare R2 free tier** (10GB storage, zero egress fees) or a local **MinIO** container for fully offline dev | R2/MinIO are both S3-API-compatible, so the exact same SDK calls used against test also work against production's S3/R2 bucket — swapping is a config change, not a code change |
| Search/geo queries | PostgreSQL's built-in `GEOGRAPHY`/`PostGIS` extension rather than a separate search service | Avoids paying for and operating a second data store before you have a measured reason to (same "don't over-engineer early" principle as [Scaling-and-Modular-Architecture.md §9](../Dev/Scaling-and-Modular-Architecture.md#9-scaling-nodejs-from-10k-to-1-lakh-users)) |

**The rule that keeps this safe:** test storage must use the **same client library and API shape** as production (e.g. the AWS S3 SDK works unmodified against R2 or MinIO) — the cost-saving choice is which *provider* backs it, never a different *interface*, so a bug that only shows up against the "real" storage layer doesn't slip through untested.

- [ ] Test database and test storage bucket are wiped/reseeded on a schedule (or before each CI run) from the shared `/fixtures` described in §6.2 below — never accumulate years of stale test data
- [ ] No real user data, ever, in test storage or the test database — only synthetic/seeded fixtures, per [Compliance Guide](../Compliance/UKPath-Compliance-Guide.md#how-this-interacts-with-testing)

---

## 2. Docker Strategy — Two Dockerfiles, Not One

The problem worth solving explicitly: rebuilding all dependencies (`npm install`, etc.) on every single test run is slow and wastes time on every iteration. The fix is **two Docker setups with different jobs**, not one Dockerfile trying to do both:

### 2.1 `Dockerfile.dev` — rebuilds fresh, for active development

Use this while actively changing dependencies (adding a package, upgrading a version). It installs from scratch so it's always correct, at the cost of being slower.

```dockerfile
# Dockerfile.dev — rebuild everything each time; use when dependencies change
FROM node:20-slim

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .

EXPOSE 3000
CMD ["npm", "run", "dev"]
```

### 2.2 `Dockerfile.base` + `Dockerfile` — prebuilt dependency layer, for everyday testing

Split the dependency install into its own image, built rarely (only when `package.json` actually changes), and have the everyday app image build **on top of it** — so a normal code change never re-runs `npm ci`.

```dockerfile
# Dockerfile.base — build this only when package.json/package-lock.json changes
# Tag it e.g. ukpath/base:2026-09-18 and push to your container registry
FROM node:20-slim AS base
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
```

```dockerfile
# Dockerfile — everyday build, reuses the prebuilt base image's node_modules layer
FROM ukpath/base:2026-09-18
WORKDIR /app
COPY . .

EXPOSE 3000
CMD ["npm", "start"]
```

**Why this matters in practice:** as long as `package.json` hasn't changed, rebuilding `Dockerfile` only re-copies source code — Docker's layer cache skips the dependency install entirely, so a test-loop rebuild takes seconds instead of minutes. Only rebuild and re-push `Dockerfile.base` when dependencies actually change, not on every commit.

**This is also the exact image that gets promoted to production** — see [Production Deployment Guide §2](../Prod/UKPath-Production-Deployment-Guide.md#2-promotion-path--test--production-only), never a separately-built production image.

### 2.3 `docker-compose.yml` for the local/test stack

```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile        # swap to Dockerfile.dev while changing deps
    env_file: .env.test
    ports:
      - "3000:3000"
    depends_on:
      - db
      - redis

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ukpath_test
      POSTGRES_PASSWORD: localtest
    ports:
      - "5432:5432"

  redis:
    image: redis:7
    ports:
      - "6379:6379"
```

Run `docker compose up` for a full local test stack that matches the deployed test environment as closely as practical.

---

## 3. CI Pipeline — Through Test Deploy

- [ ] Every PR triggers: lint, unit tests, dependency vulnerability scan (see [Security Guide §6](../Security/UKPath-Security-Guide.md#6-dependency--build-security))
- [ ] Merge to `main` auto-builds the `Dockerfile` image and auto-deploys to the test environment
- [ ] Centralized logging/monitoring (Grafana + Prometheus, or a hosted option) on the test environment, so failures are visible before promotion is even attempted

What happens **after** a build passes here — the manual promotion step into production — is covered in the [Production Deployment Guide §3](../Prod/UKPath-Production-Deployment-Guide.md#3-cicd--the-promotion-step).

---

## 4. Mobile Test Builds — CodeMagic

Without a local Mac (required for iOS builds) or wanting to avoid manually maintaining Android SDKs/emulators, **CodeMagic** (or a similar cloud CI for mobile — Bitrise/App Center are alternatives) is the practical answer for **test builds**: it builds both the iOS and Android app from the same repository in the cloud, signs the build for internal testing, and hands you an installable artifact — no local Xcode/Android Studio build environment required. Release-signed builds for the App Store/Play Store are a separate workflow — see [Production Deployment Guide §4](../Prod/UKPath-Production-Deployment-Guide.md#4-mobile-release-builds--codemagic).

### 4.1 What CodeMagic gives you concretely, for testing

- Builds triggered on push/PR, same as the web CI above
- iOS: builds and code-signs a **development-signed** `.ipa` in the cloud (solves the "no Mac" problem entirely) and can push straight to **TestFlight** for install on a real iPhone
- Android: builds a debug `.apk`, which can be downloaded directly and side-loaded onto a local Android device for testing, or pushed to the **Play Console internal testing track**
- Both platforms build from one `codemagic.yaml` config file committed to the repo, so the build process itself is version-controlled like everything else

### 4.2 Example `codemagic.yaml` skeleton — test workflows

```yaml
workflows:
  android-test-build:
    name: Android Test Build
    environment:
      groups:
        - android_test_env      # holds test-env secrets, not production
    scripts:
      - name: Install dependencies
        script: npm ci
      - name: Build Android debug APK
        script: cd android && ./gradlew assembleDebug
    artifacts:
      - android/app/build/outputs/**/*.apk

  ios-test-build:
    name: iOS Test Build
    environment:
      groups:
        - ios_test_env
      ios_signing:
        distribution_type: development
        bundle_identifier: com.ukpath.app
    scripts:
      - name: Install dependencies
        script: npm ci
      - name: Build iOS app
        script: xcodebuild -workspace ios/UKPath.xcworkspace -scheme UKPath archive
    publishing:
      testflight:
        apple_id_credentials: $APP_STORE_CONNECT_CREDENTIALS
```

Keep separate workflows (and separate secret groups) for **test builds** here vs **release builds** in the Production Deployment Guide — same test/production separation principle as §1, applied to mobile signing credentials specifically. The release-signed equivalents of these two workflows live in [Production Deployment Guide §4](../Prod/UKPath-Production-Deployment-Guide.md#4-mobile-release-builds--codemagic).

### 4.3 The resulting local-testing loop

1. Push a branch → CodeMagic builds Android `.apk` and iOS `.ipa` automatically
2. Android: download the `.apk` artifact from the CodeMagic build page, side-load it onto your own Android phone via USB/`adb install` or a QR-code download link
3. iOS: CodeMagic pushes to TestFlight → install the TestFlight app on your iPhone → install the build from there (this is Apple's required distribution path for anything outside the App Store, short of a paid enterprise cert)
4. Both point at the **test environment** API (§1), never production, controlled by which secret group/env file the build uses

See the platform-specific Testing Guides for the actual test plans run against these builds: [Android](Android/UKPath-Testing-Guide-Android.md), [iOS](iOS/UKPath-Testing-Guide-iOS.md), [Web](Web/UKPath-Testing-Guide-Web.md).

---

## 5. Config File Conventions (Shared With Production)

- [ ] `.env.example` committed with placeholder values for every variable the app needs; real `.env.test`/`.env.production` are git-ignored
- [ ] One config file per environment, not one file with `if (env === 'production')` branches scattered through application code — inject via environment variables instead
- [ ] The `countries` config table from [Multi-Country-and-Maps.md §10](../Dev/Multi-Country-and-Maps.md#10-multi-country-support-build-for-uk-structure-for-everywhere) and any feature flags live in the database, not in a deployed static file — so enabling something doesn't require a redeploy

---

## 6. End-to-End Regression Test Pack (Shared Across Web, Android, iOS)

This is the tool/process that catches "changing module X quietly broke module Y" — even when only one client (say, the website) is actually built yet. It's deliberately **one shared test pack**, not three separate ad-hoc ones, so all three platforms sit on the same guarantees and the same test data.

### 6.1 Why a shared pack, not three independent ones

If Android, iOS, and Web each maintain their own tests against their own understanding of the API, they drift — one platform's tests pass against an API contract another platform never agreed to. The fix: **one `/test-pack` used by all three**, so a backend change that breaks an assumption is caught once, centrally, rather than three times (or not at all) per-platform.

```
/test-pack
  /api                 <- platform-agnostic: hits the real test-environment API directly
    listings.spec.js
    itineraries.spec.js
    compliance-gate.spec.js   <- the one every checkout-touching module must pass
  /fixtures             <- shared seed data + mock responses, used by API tests AND all 3 clients
    users.json
    listings.json
    compliance_approvals.json
  /web        (Playwright/Cypress)
  /android    (Espresso or Detox, depending on RN vs. native choice)
  /ios        (XCTest/Detox)
  coverage-matrix.md    <- §6.2 below
```

### 6.2 The module × platform coverage matrix (the actual "don't break other modules" mechanism)

Keep a living table — `coverage-matrix.md` in the pack above — tracking, per module (from [Scaling-and-Modular-Architecture.md §34](../Dev/Scaling-and-Modular-Architecture.md#34-building-this-as-a-truly-modular-system-plug-in-not-tangled)), whether an automated test exists yet for each platform:

| Module | API contract test | Web E2E | Android E2E | iOS E2E |
|---|---|---|---|---|
| Onboarding (auth) | ✅ | ✅ | ⬜ not built yet | ⬜ not built yet |
| Food & Grocery listings | ✅ | ✅ | ⬜ | ⬜ |
| Compliance gate (checkout block) | ✅ | ✅ | ⬜ | ⬜ |
| Emergency (offline-cached) | ✅ | n/a | ⬜ | ⬜ |

**The point of this table:** a module can have a ✅ API contract test long before any mobile client exists — that's what actually protects it. When the Android/iOS client for a module gets built later, its row just gets its `⬜` filled in; nothing about the existing API test or other modules' rows needs to change. This is how "even if we don't build all three at once" still gets covered — the backend contract is tested first and always, the platform E2E layer fills in per-platform as each one is actually built.

### 6.3 The test pyramid this pack implements

1. **Unit tests** — inside each module's own folder (per [Scaling-and-Modular-Architecture.md §34.2](../Dev/Scaling-and-Modular-Architecture.md#342-the-concrete-rule-for-your-developer)), run on every PR, fastest feedback
2. **API/contract tests** (`/test-pack/api`) — platform-agnostic, hit the real test-environment API, run on every PR regardless of which platform triggered it. **This is the layer that catches cross-module breakage early**, since it doesn't need any client UI to exist
3. **Platform E2E tests** (`/test-pack/web`, `/android`, `/ios`) — exercise the actual UI on each platform against the shared test environment; added as each platform's screens are actually built, tracked via §6.2's matrix
4. **Post-deploy smoke test** — a tiny subset of #3, run automatically right after every test-environment deploy (see [Web Testing Guide §5](../Test/Web/UKPath-Testing-Guide-Web.md#5-automated-testing-in-ci)), confirming the deploy itself didn't break the basics

### 6.4 The rule that keeps this useful as modules get built incrementally

- [ ] **Any developer who finishes a module adds its API/contract test to `/test-pack/api` in the same PR** — not as a follow-up "someday" task. This is what makes the guarantee real: the day Module X ships, Module Y's existing tests immediately tell you if X broke it, because they all run together in CI on every PR
- [ ] Shared `/fixtures` are the single source of test data for all three platforms — a fixture change is one PR, not three separately-maintained mocks silently drifting apart
- [ ] CI blocks merge if **any** test in `/test-pack/api` fails, regardless of which platform folder the PR touches — this is what actually enforces "passed to other modules as well," not just a convention
- [ ] The coverage matrix (§6.2) is reviewed whenever a new platform screen ships, so a module's real coverage state is always visible at a glance rather than assumed


---

## Staying in Sync With the Production Deployment Guide

This guide and the [Production Deployment Guide](../Prod/UKPath-Production-Deployment-Guide.md) describe **one pipeline, split across two documents by environment** — not two independent pipelines. Whenever one of these changes, check the other:

| If you change... | ...also check |
|---|---|
| `Dockerfile` / `Dockerfile.base` (§2) | Production Deployment Guide §2 — production runs the exact same image, never a separate build |
| The CI steps in §3 | Production Deployment Guide §3 — the promotion step picks up wherever §3 here leaves off |
| `codemagic.yaml` test workflows (§4) | Production Deployment Guide §4 — release workflows share the same repo file, just different signing groups |
| `.env.example` / config conventions (§5) | Production Deployment Guide — production secrets follow the same shape, different values |
