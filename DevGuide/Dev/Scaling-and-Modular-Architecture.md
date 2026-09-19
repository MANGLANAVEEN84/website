# UKPath — Scaling & Modular Architecture

### Sections 9, 34 & 35 of the Developer Guide

See the [Dev docs index](README.md) for how this fits with the other module docs.

---

## 9. Scaling Node.js from 10K to 1 Lakh+ Users

Don't over-engineer early — but structure the code so each stage below is an incremental change, not a rewrite.

**Stage 1 — 0 to 10K users (where you start)**
- Single Node.js instance, managed PostgreSQL, Redis for caching/sessions
- Everything in one repo, one deploy

**Stage 2 — 10K to 50K users**
- [ ] Run Node in cluster mode (PM2) or as multiple containers behind a load balancer — Node is single-threaded per process, so you scale by running more processes, not by making one process "bigger"
- [ ] Move all session state to Redis so any app instance can handle any request (stateless app servers)
- [ ] Put a CDN (Cloudflare works well and has a generous free tier) in front of static assets and cacheable API responses
- [ ] Add a job queue (BullMQ + Redis) for anything that doesn't need to happen instantly — emails, service-request notifications, report generation — so the main API stays fast
- [ ] Add a database read replica once read traffic (listings, guides, itineraries) starts outpacing writes

**Stage 3 — 50K to 1 lakh users**
- [ ] Containerize with Docker; run on a managed container platform (AWS Fargate, Google Cloud Run, or Railway's autoscaling) rather than jumping straight to Kubernetes unless you have a dedicated DevOps hire — Kubernetes adds real operational overhead that isn't justified at this scale
- [ ] Add connection pooling in front of PostgreSQL (PgBouncer) — Node apps open a lot of short-lived DB connections and Postgres has a hard connection limit
- [ ] Centralized logging and monitoring (Grafana + Prometheus, or a hosted option like Better Stack) so you can see problems before users report them
- [ ] Proper CI/CD with zero-downtime deploys (rolling restarts) and staging environment before production — see the [Test Environment Guide](../Test/UKPath-Test-Environment-Guide.md) and [Production Deployment Guide](../Prod/UKPath-Production-Deployment-Guide.md)
- [ ] API rate limiting per user/IP to protect against abuse and runaway costs (especially on any endpoint that calls Google Maps)

**The honest takeaway:** horizontal scaling of stateless Node servers plus a solid cache layer gets you further than most people expect before the database itself becomes the bottleneck. Don't reach for microservices or Kubernetes just because "scale" is the goal — reach for them when a specific, measured bottleneck demands it.

---

## 34. Building This as a Truly Modular System (Plug-In, Not Tangled)

This is the most important structural instruction to give your developer, and it deserves to be explicit rather than assumed. The goal: **Payments, Transport, Grocery, SIM, Money Guidance, Emergency, Chat — each one is its own self-contained module that can be built, tested, replaced, or unplugged without touching the others**, and they all connect to one main site through clean, narrow interfaces.

### 34.1 The right pattern for your stage: a "modular monolith," not microservices

Section 9 above already advised against jumping to microservices before you have a measured reason to — that advice still holds. The way to get "swap modules independently" **without** the operational cost of running ten separate deployed services is a **modular monolith**: one deployed application, but internally organized so the module boundaries are as strict as if they were separate services. This gets you the plug-and-play property you're asking for now, and makes it genuinely easy to split any one module into its own real microservice later, specifically because the boundary was already clean.

### 34.2 The concrete rule for your developer

**Every module gets its own folder, and modules only talk to each other through an explicitly exported interface — never by reaching directly into another module's database tables, internal functions, or files.**

```
/src
  /modules
    /payments          <- Features/Payments-and-Monetisation.md: Stripe, GoCardless, Stripe Connect
      index.js          <- the ONLY file other modules are allowed to import from
      stripe-provider.js
      gocardless-provider.js
      db-models.js       <- payments' own tables; nobody else touches these directly
    /transport          <- Features/Transport-and-Reference-Data.md: routes, fares, flight data
      index.js
      route-lookup.js
      fare-calculator.js
    /grocery-catalog     <- Features/Grocery-and-Delivery.md §28: UKPath's own stocked items + Swindon fulfilment
      index.js
      catalog.js
      fare-bands.js
    /grocery-shopper      <- Features/Grocery-and-Delivery.md §30: personal-shopper courier model
      index.js
      shopper-orders.js
    /sim-guidance
    /money-guidance
    /emergency
    /chat                 <- Module-Build-Notes.md §8: Tawk.to integration
    /compliance            <- the approvals gate every other module checks
      index.js
      approvals.js
  /api                    <- the routes the app/website actually call
    grocery-routes.js      <- imports from modules/grocery-catalog and modules/payments,
                               never reaches into their internals directly
```

### 34.3 What "only talk through `index.js`" actually buys you

- **Swapping Stripe for another processor later** means rewriting `payments/stripe-provider.js` and `payments/index.js` — nothing in `grocery-routes.js` or any other module needs to change, because they only ever called the interface, never Stripe directly
- **A developer working on the transport module can't accidentally break payments** — there's no code path that lets them reach in and touch payment tables, because the folder boundary is enforced by what's exported, not just convention
- **Testing gets easier** — each module can be tested in isolation by mocking the narrow interface of the modules it depends on, rather than needing the whole system running. See the [Test Environment Guide's end-to-end test pack](../Test/UKPath-Test-Environment-Guide.md#6-end-to-end-regression-test-pack-shared-across-web-android-ios) for how this plays out in CI specifically
- **If Section 34.1's monolith ever needs to become real microservices** (once you're well past 1 lakh users and have a measured reason), the module boundaries in this structure map almost directly onto service boundaries — this is the concrete payoff of doing it this way now

### 34.4 The one discipline this requires from whoever's coding it

- [ ] Code review should explicitly check: "does this new code reach into another module's files/database directly, or does it go through that module's `index.js`?" — this is the rule that's easy to let slip under deadline pressure, and it's the whole point of the pattern
- [ ] Each module's `compliance_approvals` check lives inside that module, not scattered across the codebase — e.g. the grocery-catalog module checks `food_business_registered` internally before exposing its checkout function, rather than every caller having to remember to check it themselves — see the [Compliance Guide](../Compliance/UKPath-Compliance-Guide.md#code-enforced-compliance-gate)

---

## 35. Open Questions to Resolve Before Coding

- React Native vs. Flutter — depends on your team's existing skills
- Will listings (restaurants, SIM shops) be manually curated or sourced via a partner API/feed?
- Who fulfills paid "service requests" (SIM setup help, itinerary planning) — human staff or automated?
- Target launch cities (London-only MVP, or nationwide from day one)?
