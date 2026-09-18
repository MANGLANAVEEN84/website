# UKPath — Documentation Index

This `DevGuide/` folder is split into small, linked documents instead of one giant file, so each team (dev, compliance, QA, DevOps) can work from their own doc without wading through the others. Every doc cross-links to the others where relevant — follow the links rather than duplicating content.

## How the docs relate to each other

```
┌──────────────────────┐        ┌──────────────────────────┐
│  Developer Guide       │◄──────►│  Compliance Guide           │
│  (architecture, data,  │  gate  │  (legal must-pass items,     │
│   API, modules, build)  │        │   compliance_approvals table)│
└──────────┬───────────┘        └──────────────────────────┘
           │
           │ references
           ▼
┌──────────────────────┐        ┌──────────────────────────┐
│  Security Guide        │        │  Deployment Guide            │
│  (technical controls:  │        │  (test vs prod envs, Docker,  │
│   auth, TLS, PCI, SCA) │        │   CI/CD, CodeMagic)           │
└──────────────────────┘        └──────────┬───────────────┘
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
| [UKPath-Developer-Guide.md](UKPath-Developer-Guide.md) | Developers | Architecture, data model, API surface, module build notes, scaling plan. This is the "how to build it" reference. |
| [UKPath-Compliance-Guide.md](UKPath-Compliance-Guide.md) | Founder/business + legal | Every legal/regulatory requirement (food business registration, Stripe KYB, ICO, data-source terms). Contains the `compliance_approvals` gate that **code must check before going live** — see rule below. |
| [UKPath-Security-Guide.md](UKPath-Security-Guide.md) | Developers + DevOps | Technical security controls: auth, TLS, secrets, PCI/SCA, rate-limiting, dependency hygiene. Separate from compliance because this is engineering work, not legal sign-off. |
| [UKPath-Deployment-Guide.md](UKPath-Deployment-Guide.md) | DevOps + developers | Test vs. production environments, the two Docker build variants, CI/CD pipeline, CodeMagic setup for mobile builds, promotion path from test → production. |
| [Testing/UKPath-Testing-Guide-Android.md](Testing/UKPath-Testing-Guide-Android.md) | QA / mobile dev | Android-specific test plan, CodeMagic build-and-install flow for local device testing. |
| [Testing/UKPath-Testing-Guide-iOS.md](Testing/UKPath-Testing-Guide-iOS.md) | QA / mobile dev | iOS-specific test plan, CodeMagic cloud build (no local Mac required) + TestFlight distribution. |
| [Testing/UKPath-Testing-Guide-Web.md](Testing/UKPath-Testing-Guide-Web.md) | QA / web dev | Web/browser test plan, CI-run automated tests, staging URL smoke tests. |

## The one rule that ties all of these together

**A feature that touches money, food, or personal data must not go live until its row(s) in the `compliance_approvals` table (defined in the [Compliance Guide](UKPath-Compliance-Guide.md#the-compliance_approvals-table)) are set to `true` by someone with real authority to confirm it — never by a developer during testing.** The three build-facing docs (Developer, Security, Deployment) all assume this gate exists and reference it; they don't repeat its legal detail, which lives only in the Compliance Guide. This is enforced in code — see [Section: Code-Enforced Compliance Gate](UKPath-Compliance-Guide.md#code-enforced-compliance-gate) — not just written down as a policy.

Work on the Developer Guide's modules can proceed in parallel with the Compliance Guide's approvals — they are two independent workstreams that meet at the gate above, not a strict "compliance first, then code" sequence.
