# UKPath — Documentation Index

This `DevGuide/` folder is organized by **module/concern**, one folder per team's area, so each team (dev, compliance, QA, DevOps) works from their own docs without wading through the others. Every doc cross-links to the others where relevant — follow the links rather than duplicating content.

## Folder structure

```
DevGuide/
  README.md                 <- you are here
  Dev/                       <- architecture, data model, API, module build notes,
    README.md                   split further by platform so concentrating on one
    Architecture-and-API.md     platform means reading only that platform's doc
    Module-Build-Notes.md
    Scaling-and-Modular-Architecture.md
    Multi-Country-and-Maps.md
    Web/UKPath-Web-Guide.md
    Android/UKPath-Android-Guide.md
    Apple/UKPath-Apple-Guide.md
    Features/                <- transport data, grocery/delivery, payments/monetisation
  Security/                 <- technical controls (auth, TLS, PCI, SCA, secrets)
  Compliance/                <- legal must-pass items, the compliance_approvals gate
  Test/                       <- the test environment + one shared end-to-end test pack
    UKPath-Test-Environment-Guide.md
    Android/UKPath-Testing-Guide-Android.md
    iOS/UKPath-Testing-Guide-iOS.md
    Web/UKPath-Testing-Guide-Web.md
  Prod/                       <- production environment, promotion path, release builds
    UKPath-Production-Deployment-Guide.md
```

## How the docs relate to each other

```
┌──────────────────────┐        ┌──────────────────────────┐
│  Dev/ (by module &     │◄──────►│  Compliance/                 │
│  by platform: Web,     │  gate  │  (legal must-pass items,     │
│  Android, Apple)        │        │   compliance_approvals table)│
└──────────┬───────────┘        └──────────────────────────┘
           │
           │ references
           ▼
┌──────────────────────┐        ┌──────────────────────────┐
│  Security/              │        │  Test/  ◄──sync──►  Prod/     │
│  (technical controls:  │        │  (test env, Docker,          │
│   auth, TLS, PCI, SCA) │        │   shared E2E test pack)       │
└──────────────────────┘        │  (promotion) Prod/ (env,       │
                                  │   release builds)              │
                                  └──────────┬───────────────┘
                                            │
                     ┌──────────────────────┼──────────────────────┐
                     ▼                      ▼                      ▼
           ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
           │ Android Test   │       │  iOS Test      │       │  Web Test      │
           │ Guide          │       │  Guide         │       │  Guide         │
           └──────────────┘       └──────────────┘       └──────────────┘
```

## Documents

| Doc | Audience | Purpose |
|---|---|---|
| [Dev/README.md](Dev/README.md) | Developers | Index into the module- and platform-split developer docs (architecture, API, per-platform guides, feature specs). Start here for any build question. |
| [Security/UKPath-Security-Guide.md](Security/UKPath-Security-Guide.md) | Developers + DevOps | Technical security controls: auth, TLS, secrets, PCI/SCA, rate-limiting, dependency hygiene. Separate from compliance because this is engineering work, not legal sign-off. |
| [Compliance/UKPath-Compliance-Guide.md](Compliance/UKPath-Compliance-Guide.md) | Founder/business + legal | Every legal/regulatory requirement (food business registration, Stripe KYB, ICO, data-source terms). Contains the `compliance_approvals` gate that **code must check before going live** — see rule below. |
| [Test/UKPath-Test-Environment-Guide.md](Test/UKPath-Test-Environment-Guide.md) | DevOps + developers + QA | The test environment, Docker dev loop, CI through test-deploy, low-cost test database/storage setup, and the **shared end-to-end test pack** used by all three platforms. |
| [Test/Android/UKPath-Testing-Guide-Android.md](Test/Android/UKPath-Testing-Guide-Android.md) | QA / mobile dev | Android-specific test plan, CodeMagic build-and-install flow for local device testing. |
| [Test/iOS/UKPath-Testing-Guide-iOS.md](Test/iOS/UKPath-Testing-Guide-iOS.md) | QA / mobile dev | iOS-specific test plan, CodeMagic cloud build (no local Mac required) + TestFlight distribution. |
| [Test/Web/UKPath-Testing-Guide-Web.md](Test/Web/UKPath-Testing-Guide-Web.md) | QA / web dev | Web/browser test plan, CI-run automated tests, staging URL smoke tests. |
| [Prod/UKPath-Production-Deployment-Guide.md](Prod/UKPath-Production-Deployment-Guide.md) | DevOps + developers | Production environment, promotion path from test → production, release-signed mobile builds, production database/storage sizing (cost vs. performance). |

Android, iOS, and Web can be worked on **concurrently** — each testing guide runs against the same shared test-environment backend and none blocks the others (see [Test Environment Guide §1](Test/UKPath-Test-Environment-Guide.md#1-the-test-environment)).

## The one rule that ties all of these together

**A feature that touches money, food, or personal data must not go live until its row(s) in the `compliance_approvals` table (defined in the [Compliance Guide](Compliance/UKPath-Compliance-Guide.md#the-compliance_approvals-table)) are set to `true` by someone with real authority to confirm it — never by a developer during testing.** The build-facing docs (Dev, Security, Test, Prod) all assume this gate exists and reference it; they don't repeat its legal detail, which lives only in the Compliance Guide. This is enforced in code — see [Section: Code-Enforced Compliance Gate](Compliance/UKPath-Compliance-Guide.md#code-enforced-compliance-gate) — not just written down as a policy.

Work on the Dev modules can proceed in parallel with the Compliance Guide's approvals — they are two independent workstreams that meet at the gate above, not a strict "compliance first, then code" sequence.

## Keeping module-level docs in sync

Because concerns are deliberately split by module/platform (so you can read just the Web guide, or just the Android guide, without the rest), a change in one doc can make another go stale if it isn't checked at the same time. Each split area has its own "Staying in Sync" note for the specifics:
- [Dev/README.md](Dev/README.md#staying-in-sync--the-rule-for-keeping-these-docs-from-drifting) — module boundaries, platform-parity content, compliance-flag additions
- [Test/UKPath-Test-Environment-Guide.md](Test/UKPath-Test-Environment-Guide.md#staying-in-sync-with-the-production-deployment-guide) and [Prod/UKPath-Production-Deployment-Guide.md](Prod/UKPath-Production-Deployment-Guide.md#staying-in-sync-with-the-test-environment-guide) — the test/production pipeline, described across two docs by environment

As a general rule: **edit the doc that owns the fact, then follow its links outward to check anything that referenced the old version** — don't copy text between docs, since copies are what actually drift.

