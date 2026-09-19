# UKPath — Production Deployment Guide

### Production Environment, Promotion Path & Release Builds

This guide covers how a build that has already passed testing gets promoted to production. Everything about the test environment, Docker dev loop, and CI-through-test-deploy lives in the separate [Test Environment Guide](../Test/UKPath-Test-Environment-Guide.md) — keep the two in sync (see "Staying in Sync" at the bottom) rather than letting either drift.

See the [Documentation Index](../README.md) for how this fits with the other docs.

---

## 1. The Production Environment

| | **Production environment** |
|---|---|
| Purpose | Real users |
| Database | Real data only |
| `compliance_approvals` rows | Only ever set `true` by an actual human sign-off — never seeded, never defaulted (see [Compliance Guide](../Compliance/UKPath-Compliance-Guide.md#code-enforced-compliance-gate)) |
| Payment provider | Live keys, real KYB-verified account |
| Third-party APIs | Production keys with monitored budget |
| Secrets | Own isolated secret store, separate from test (see [Test Environment Guide §1](../Test/UKPath-Test-Environment-Guide.md#1-the-test-environment)) |
| Mobile builds | CodeMagic (or App Store Connect/Play Console release track) builds signed for store release |
| URL | `ukpath.app` / `api.ukpath.app` |

The test column of this same comparison lives in the [Test Environment Guide §1](../Test/UKPath-Test-Environment-Guide.md#1-the-test-environment).

---

## 2. Promotion Path — Test → Production Only

Code and config are promoted **test → production**, never the reverse, and never by hand-editing production directly. A deploy to production should always be "the same artifact that already passed in test," not a fresh build from a developer's machine — the same `Dockerfile` image described in [Test Environment Guide §2](../Test/UKPath-Test-Environment-Guide.md#2-docker-strategy--two-dockerfiles-not-one), never a separately-built production image.

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

## 3. CI/CD — the Promotion Step

The [Test Environment Guide §3](../Test/UKPath-Test-Environment-Guide.md#3-ci-pipeline--through-test-deploy) covers PR checks and auto-deploy to test. From there:

- [ ] Promotion to production is a manual, explicit step — never automatic on merge
- [ ] Zero-downtime deploys (rolling restarts) — see [Scaling-and-Modular-Architecture.md §9](../Dev/Scaling-and-Modular-Architecture.md#9-scaling-nodejs-from-10k-to-1-lakh-users) for the scaling context this supports
- [ ] Centralized logging/monitoring (Grafana + Prometheus, or a hosted option) on production, so an anomaly is visible immediately after promotion, not discovered by a user report

---

## 4. Mobile Release Builds — CodeMagic

Test builds (development-signed, TestFlight/internal-track) are covered in the [Test Environment Guide §4](../Test/UKPath-Test-Environment-Guide.md#4-mobile-test-builds--codemagic). Release builds use the same `codemagic.yaml` file, committed to the same repo, but a different workflow and signing group:

```yaml
workflows:
  android-release-build:
    name: Android Release Build
    environment:
      groups:
        - android_release_env    # holds production secrets — separate from android_test_env
    scripts:
      - name: Install dependencies
        script: npm ci
      - name: Build Android release AAB
        script: cd android && ./gradlew bundleRelease
    artifacts:
      - android/app/build/outputs/**/*.aab
    publishing:
      google_play:
        credentials: $GOOGLE_PLAY_CREDENTIALS
        track: production

  ios-release-build:
    name: iOS Release Build
    environment:
      groups:
        - ios_release_env
      ios_signing:
        distribution_type: app_store
        bundle_identifier: com.ukpath.app
    scripts:
      - name: Install dependencies
        script: npm ci
      - name: Build iOS app
        script: xcodebuild -workspace ios/UKPath.xcworkspace -scheme UKPath archive
    publishing:
      app_store_connect:
        apple_id_credentials: $APP_STORE_CONNECT_CREDENTIALS
        submit_to_review: true
```

**Never reuse a test signing group (`android_test_env`, `ios_test_env`) for a release workflow** — this is the mobile-specific version of the "separate credentials per environment" rule from the [Security Guide §5](../Security/UKPath-Security-Guide.md#5-secrets--configuration).

---

## 5. Database & File Storage — Production (Cost vs. Performance)

The same low-cost-first principle from the [Test Environment Guide §1a](../Test/UKPath-Test-Environment-Guide.md#1a-database--file-storage--test-environment-low-cost-first) applies here — start on the cheapest tier that meets a real performance/security bar, and move up only when a measured metric (not a guess) says to, mirroring the staged approach in [Scaling-and-Modular-Architecture.md §9](../Dev/Scaling-and-Modular-Architecture.md#9-scaling-nodejs-from-10k-to-1-lakh-users).

### 5.1 Staged sizing (cost vs. users)

| Stage | PostgreSQL | Redis | File/blob storage | Rough monthly cost |
|---|---|---|---|---|
| 0–10K users | Single managed instance, smallest tier with automated backups (e.g. Railway/Supabase/Neon "Pro" tier, or AWS RDS `db.t4g.micro`) | Small managed instance or single container | Cloudflare R2 (pay-as-you-go, no egress fees) or S3 with a lifecycle policy to cheaper storage classes for old data | ~$25–75/mo total |
| 10K–50K users | Same instance, vertical bump (more CPU/RAM) + a read replica once read traffic (listings, guides, itineraries) outpaces writes | Managed Redis, sized for session + cache volume | R2/S3, same bucket, volume-based cost only | ~$150–400/mo total |
| 50K–1 lakh users | Add PgBouncer connection pooling in front of Postgres (see [Scaling-and-Modular-Architecture.md §9](../Dev/Scaling-and-Modular-Architecture.md#9-scaling-nodejs-from-10k-to-1-lakh-users)); consider a larger managed tier or move to a dedicated instance | Managed Redis cluster if cache traffic demands it | Same storage layer — R2/S3 cost scales with actual data volume, not a step-function like compute does | ~$500–1,500/mo total, mostly compute, not storage |

**Storage is the cheap part at this scale** — a few GB of listings/photos/PDFs costs pennies on R2/S3; compute (the database and app servers) is what actually drives the cost curve, which is why the staging above focuses there.

### 5.2 Performance and security, not just cost

- [ ] **Automated daily backups with point-in-time recovery (PITR)** enabled from day one in production — this is a security/availability requirement, not an optional add-on, and every managed Postgres provider above supports it on their lowest paid tier
- [ ] **Encryption at rest** for both the database and the storage bucket — enabled by default on R2/S3 and every managed Postgres provider listed above; confirm it's actually on, don't assume (see [Security Guide §2](../Security/UKPath-Security-Guide.md#2-data-handling))
- [ ] **Connection pooling** (PgBouncer) before the database becomes a bottleneck, not after — Node opens many short-lived connections and Postgres has a hard connection ceiling
- [ ] **Read replica** once read-heavy endpoints (listings search, itinerary templates) show real load — don't provision one speculatively before the metric says to
- [ ] Storage bucket access is **never public-by-default** — signed URLs / short-lived tokens for anything user-uploaded, per [Security Guide §2](../Security/UKPath-Security-Guide.md#2-data-handling)
- [ ] Same S3-compatible client/API used in test (§ [Test Environment Guide §1a](../Test/UKPath-Test-Environment-Guide.md#1a-database--file-storage--test-environment-low-cost-first)) — production just points at the real bucket via config, never a different code path

---

## Staying in Sync With the Test Environment Guide

This guide and the [Test Environment Guide](../Test/UKPath-Test-Environment-Guide.md) describe **one pipeline, split across two documents by environment** — not two independent pipelines. Whenever one of these changes, check the other:

| If you change... | ...also check |
|---|---|
| `Dockerfile` / `Dockerfile.base` | Test Environment Guide §2 — the image built there is exactly what gets promoted here, don't fork it |
| The promotion step in §3 | Test Environment Guide §3 — confirm the handoff point (what CI leaves off, this picks up) still matches |
| `codemagic.yaml` release workflows (§4) | Test Environment Guide §4 — same file, keep workflow names/secret group naming consistent so it's obvious which is which |
| Config/secrets conventions | Test Environment Guide §5 — production values differ, but the file shape (`.env.production` mirroring `.env.test`) must not diverge |
