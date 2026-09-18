# UKPath — Deployment Guide

### Environments, Docker Strategy, CI/CD & CodeMagic

This guide covers how UKPath gets built, tested, and shipped — as a separate concern from *what* gets built (see the [Developer Guide](UKPath-Developer-Guide.md)). It answers: what environments exist, how Docker is used, how the pipeline moves code from a laptop to something a tester can actually install, and how that differs from production.

See the [Documentation Index](README.md) for how this fits with the other docs.

---

## 1. Environments — Two, Not One

Build **two** separate environments from day one. Treat "test" as a real, permanent environment, not a temporary scratch space — it's what every Testing Guide (Android/iOS/Web) runs its checks against before anything is allowed near production.

| | **Test environment** | **Production environment** |
|---|---|---|
| Purpose | QA, CI runs, manual testing, demoing to yourself/stakeholders | Real users |
| Database | Separate PostgreSQL instance/schema, seeded with fake data | Real data only |
| `compliance_approvals` rows | Can be seeded `true` for QA convenience (see [Compliance Guide](UKPath-Compliance-Guide.md#how-this-interacts-with-testing)) | Only ever set `true` by an actual human sign-off |
| Payment provider | Stripe **test mode** keys, GoCardless sandbox | Live keys, real KYB-verified account |
| Third-party APIs | Google Maps/TfL/National Rail test/dev keys where offered, or low-volume real keys with a hard budget cap | Production keys with monitored budget |
| Secrets | Separate `.env`/secret store from production — a leaked test key must never expose production | Own isolated secret store |
| Mobile builds | CodeMagic builds tagged/signed for internal testing (see §4) | CodeMagic (or App Store Connect/Play Console release track) builds signed for store release |
| URL | e.g. `test.ukpath.app` / `api-test.ukpath.app` | `ukpath.app` / `api.ukpath.app` |

**Promotion path:** code and config are promoted **test → production**, never the reverse, and never by hand-editing production directly. A deploy to production should always be "the same artifact that already passed in test," not a fresh build from a developer's machine.

```
 feature branch → PR → CI (lint, tests, security scan) → merge to main
        │
        ▼
 auto-deploy to TEST environment
        │
        ▼
 QA runs against TEST (Testing Guides: Android / iOS / Web)
        │
        ▼
 manual promotion approval (a person, not a script, clicks "promote")
        │
        ▼
 same build artifact deployed to PRODUCTION
```

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

### 2.3 `docker-compose.yml` for local/test stack

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

## 3. CI/CD Pipeline

- [ ] Every PR triggers: lint, unit tests, dependency vulnerability scan (see [Security Guide §6](UKPath-Security-Guide.md#6-dependency--build-security))
- [ ] Merge to `main` auto-builds the `Dockerfile` image and auto-deploys to the test environment
- [ ] Zero-downtime deploys (rolling restarts) — see [Developer Guide §9](UKPath-Developer-Guide.md#9-scaling-nodejs-from-10k-to-1-lakh-users) for the scaling context this supports
- [ ] Promotion to production is a manual, explicit step — never automatic on merge
- [ ] Centralized logging/monitoring (Grafana + Prometheus, or a hosted option) on both environments, so test-environment failures are visible before promotion is even attempted

---

## 4. Mobile Builds — Why CodeMagic

Without a local Mac (required for iOS builds) or wanting to avoid manually maintaining Android SDKs/emulators, **CodeMagic** (or a similar cloud CI for mobile — Bitrise/App Center are alternatives) is the practical answer: it builds both the iOS and Android app from the same repository in the cloud, signs the build, and hands you an installable artifact — no local Xcode/Android Studio build environment required.

### 4.1 What CodeMagic gives you concretely

- Builds triggered on push/PR, same as the web CI above
- iOS: builds and code-signs an `.ipa` in the cloud (solves the "no Mac" problem entirely) and can push straight to **TestFlight** for install on a real iPhone
- Android: builds an `.apk`/`.aab`, which can be downloaded directly and side-loaded onto a local Android device for testing, or pushed to the **Play Console internal testing track**
- Both platforms build from one `codemagic.yaml` config file committed to the repo, so the build process itself is version-controlled like everything else

### 4.2 Example `codemagic.yaml` skeleton

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

Keep separate workflows (and separate secret groups) for **test builds** vs **release builds** — same test/production separation principle as §1, applied to mobile signing credentials specifically.

### 4.3 The resulting local-testing loop

1. Push a branch → CodeMagic builds Android `.apk` and iOS `.ipa` automatically
2. Android: download the `.apk` artifact from the CodeMagic build page, side-load it onto your own Android phone via USB/`adb install` or a QR-code download link
3. iOS: CodeMagic pushes to TestFlight → install the TestFlight app on your iPhone → install the build from there (this is Apple's required distribution path for anything outside the App Store, short of a paid enterprise cert)
4. Both point at the **test environment** API (§1), never production, controlled by which secret group/env file the build uses

See the platform-specific [Testing Guides](Testing/) for the actual test plans run against these builds.

---

## 5. Config File Conventions

- [ ] `.env.example` committed with placeholder values for every variable the app needs; real `.env`/`.env.test`/`.env.production` are git-ignored
- [ ] One config file per environment, not one file with `if (env === 'production')` branches scattered through application code — inject via environment variables instead
- [ ] The `countries` config table from the [Developer Guide §10](UKPath-Developer-Guide.md#10-multi-country-support-build-for-uk-structure-for-everywhere) and any feature flags live in the database, not in a deployed static file — so enabling something doesn't require a redeploy
