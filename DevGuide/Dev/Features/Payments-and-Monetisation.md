# UKPath — Payments & Monetisation

### Sections 22, 24, 31, 32 & 33 of the Developer Guide

See the [Dev docs index](../README.md) for how this fits with the other module docs.

---

## 22. Admin-Only Reference: Affiliate/Partner Programs (Not for User-Facing Display)

**This section is for your business/dev team only — never surface commission rates, partner names framed as "sponsored," or this table itself in the user-facing app.** Users should just see a normal-looking link to Booking.com, Uber, etc.; which of those pay you a commission is your business's internal information, not something to disclose in-app (beyond whatever generic affiliate-disclosure language your legal/compliance sign-off requires you to include somewhere in your terms).

| Partner | Program type | What triggers a payout | Typical rate (verify current terms before relying on this) |
|---|---|---|---|
| Booking.com | Affiliate (via Awin network) | Completed hotel stay | ~4% of accommodation booking value |
| TripAdvisor | Affiliate (via Awin/CJ/Travelpayouts) | Click-through from your site to their booking partners — **no booking required**, just the click-out | Minimum 50% revenue share on the click-out value (typically £0.24–£0.40 per click, so volume matters more than rate here) |
| Trainline | Affiliate (via Awin/FlexOffers) | Completed ticket sale | Rate not publicly fixed — apply and check your dashboard |
| Uber / Uber Eats | Uber's own affiliate program | First trip or first order from a referred new user (acquisition-focused, not ongoing) | Rate negotiated per-partner, not publicly fixed |
| Wise, Revolut | Referral/partner programs (both actively run one) | Varies — typically new account sign-up or first transaction | Check their current partner/referral pages directly — these change often |
| Deliveroo, Just Eat, Foodhub | Likely available via affiliate networks (Awin/CJ) for driving new customers | New customer acquisition, typically | Not confirmed publicly — apply directly to check |

**How to use this table:** it's a starting checklist for someone on your team to actually apply to each program and confirm current rates — treat every number here as "last verified via search, re-check before building commission logic around it," not as contract terms. Once confirmed, store the actual agreed rate and tracking link format in your own internal `partners` table (not hardcoded in app code, since rates and links change).

```sql
-- Admin-only table, never exposed via any user-facing API endpoint
partners
  id UUID PRIMARY KEY
  partner_name VARCHAR
  program_type VARCHAR         -- 'affiliate_network', 'direct_referral'
  tracking_link_template VARCHAR
  commission_notes TEXT        -- rate, payout trigger, last verified date
  is_active BOOLEAN
```

This keeps monetization data cleanly separated from your public API and content tables — the same `country_code`-tagged `listings` a user sees can carry a `partner_id` foreign key behind the scenes, so a restaurant or booking link resolves to the right tracked affiliate URL without any of this ever being queryable by a user-facing endpoint.

---

## 24. Admin-Only Research: Transport Aggregators & Discount Coach Operators

### 24.1 Rome2Rio / Omio — how the "one search, all transport" model actually works

Rome2Rio is a single search box that returns every way to get from A to B — flights, trains, buses, ferries, driving, even walking — pulled from thousands of operators worldwide.
- **It was acquired by Omio in 2019** (Omio itself is Europe's leading multi-modal *booking* platform — Rome2Rio does the route/price discovery, Omio does the actual ticket sale). They now operate as one group.
- **Revenue model**: affiliate commission on bookings made through the platform, advertising, and paid "premium listing" placement for transport/accommodation partners — the same three levers UKPath already has in its own monetisation plan.
- **It doesn't build its own timetables from scratch** — it integrates with thousands of operators' own data feeds/APIs. Rome2Rio historically offered developers **free API access** to embed multi-modal route search into third-party sites. Worth checking their current developer terms directly — if that access still exists, it may be far cheaper to **embed Rome2Rio's route search inside the itinerary module** than to build your own multi-modal route engine from scratch.

### 24.2 FlixBus — the discount coach operator, and how UK coach discounts work generally

FlixBus is cheap, wide UK/Europe coverage, grown rapidly by **partnering with existing local coach operators** rather than only running its own fleet.

**The discount landscape, concretely:**
| Discount | How it works | Who qualifies |
|---|---|---|
| FlixBus student discount | ~11–25% off via student verification apps (Studentbeans/UNiDAYS) — the discount % varies by country | Students |
| National Express Young Persons Coachcard | ~1/3 off, £15/year (or £35 for 3 years) | Under a certain age, National Express only — doesn't work with other operators |
| National Express student discount (no card) | Up to 25% off full-price fares | Students, no card needed |
| megabus + TOTUM card | 10% off | Students with a TOTUM card |

**What this means for the itinerary module:** these discounts are card/verification-gated, not something the app can apply automatically — but you can surface them as advice ("if you have a student card, National Express and megabus both offer discounts — here's how") as genuinely useful content, separate from any affiliate link.

### 24.3 How UKPath should actually be different from Rome2Rio/Omio/FlixBus/Skyscanner

**You are not trying to out-build Rome2Rio's global route engine, and you shouldn't try to.** These platforms compete on breadth (every route, every operator, everywhere) and pure price comparison, aimed at a general global audience. That's not UKPath's actual gap in the market — the real gap (see [Web Guide §5](../Web/UKPath-Web-Guide.md#5-website-vs-app-split)) is that nobody serves the *Indian visitor specifically*, with cultural context, first-time guidance, and everything bundled.

**The right positioning:** UKPath sits **above** these tools as a curation and context layer, not beside them as a competitor:
- For the actual route search/booking, **deep-link or embed** Rome2Rio/Trainline/FlixBus rather than rebuilding their engines
- What you add on top is what none of them do: "you're landing at Heathrow from Delhi, here's what a first-timer should know, here's the realistic cost and time to get to Swindon, here's the student/other discount you might not know about, here's what to do if something goes wrong" — the anxious-first-arrival guidance layer from [Transport-and-Reference-Data.md §14–15](../Features/Transport-and-Reference-Data.md)
- You earn the same way Rome2Rio does (affiliate commission on the bookings you route through) without needing to build what Rome2Rio spent over a decade building

### 24.4 Does Rome2Rio pay *you* for linking to them? (Direct answer: no confirmed program)

Rome2Rio's own revenue comes from the *other* direction: when someone searches on Rome2Rio and clicks through to book, Rome2Rio earns a commission from **its own booking partners** — Skyscanner for flights, Booking.com for hotels, Rentalcars.com for cars. There is no public affiliate or referral program where Rome2Rio pays third-party sites for sending them traffic. What they do offer commercially is a **Partner API / White Label program** — a cost or a data-access deal, not a revenue source from linking out.

**What this means for a "just add the link" plan:**
- [ ] Adding a plain "want to compare more routes? Search on Rome2Rio" link is completely fine and genuinely useful to the user — but it earns UKPath nothing directly, since Rome2Rio isn't paying you for the click
- [ ] **The better version of the same idea**: rather than routing through Rome2Rio, link directly to the operators you already have affiliate relationships with (§22 above) — Trainline, Booking.com, Uber — for the specific leg of the journey you're showing
- [ ] Keep the Rome2Rio-style link as a **secondary, no-strings option** — genuinely helpful, correctly labeled as non-monetized, and not something to build any tracking or integration around

---

## 31. Payment Gateway — the Easiest One to Manage

You need a real payment processor for two things: the grocery checkout ([Grocery-and-Delivery.md §28](../Features/Grocery-and-Delivery.md#28-feature-ukpaths-own-grocery-packing--delivery-swindon-hub-plus-third-party-store-links)) and the personal-shopper model's authorize-then-settle flow ([Grocery-and-Delivery.md §30](../Features/Grocery-and-Delivery.md#30-feature-personal-shopper-courier-model-buying-groceries-on-the-customers-behalf)). Here's a direct recommendation, checked against current UK pricing.

### 31.1 Recommendation: Stripe

For "easy to manage" specifically, **Stripe is the right pick**:
- **No monthly fee, no setup fee, no cancellation fee** — you only pay per transaction, which matters at your current scale
- **Current UK fees**: 1.5% + 20p per transaction for standard UK-issued cards, 1.2% + 20p if using their "Link" one-click checkout, higher (2.5–3.5% + 20p) for EU/international cards
- **Built-in support for the personal-shopper flow**: Stripe's "manual capture" mode lets you *authorize* a card for an estimated amount, then *capture* the actual final amount later (up to 7 days later) once your courier knows the real total
- **Genuinely easy Node.js integration** — a mature, well-documented SDK (`npm install stripe`)
- **PCI compliance is handled for you** — Stripe is a Level 1 PCI DSS provider, meaning you never touch or store raw card numbers yourself

### 31.2 Where the alternatives fit instead

| Option | When it's the better pick |
|---|---|
| **PayPal** | Some users trust/prefer paying via PayPal specifically — worth offering *alongside* Stripe as a second option |
| **Wise Business** | Useful later if you start receiving payments in other currencies, not a card-payment gateway itself |
| **Square** | Better fit if you also plan in-person payments (e.g. a physical counter) — not relevant to UKPath's current online-only model |

### 31.3 What to hand the developer

- [ ] Set up a Stripe account under the registered UK business entity (needs the food-business/courier registration from [Grocery-and-Delivery.md §28.4/30](../Features/Grocery-and-Delivery.md) to be far enough along to have a business bank account to connect)
- [ ] Use **Stripe Checkout** (their pre-built hosted payment page) rather than building a custom card form
- [ ] Use **manual capture mode** specifically for the personal-shopper flow; standard automatic capture is fine for the fixed-catalogue checkout, since the price is known upfront
- [ ] Add PayPal as a second checkout option once the core Stripe flow is working — not a launch blocker, a nice-to-have

### 31.4 Paying your couriers, not just charging customers

§31 so far only covers taking money *from* the customer. The personal-shopper model also needs to pay *out* to whoever does the actual shopping and delivery — staff or gig workers. That's a different Stripe product:
- **Stripe Connect** is built exactly for this — a marketplace-style setup where money comes in from customers and a share of it flows out to couriers, with Stripe handling the split, the payout schedule, and each courier's own tax/identity verification
- [ ] Each courier gets their own "connected account" under your main Stripe account; you decide the split (e.g. service fee kept, rest paid to courier) programmatically per order
- [ ] This is meaningfully more setup than a plain checkout, so budget real time for it

### 31.5 Subscriptions (for a premium tier)

Stripe's separate **Billing** product handles recurring charges, proration, and cancellation — don't try to build recurring billing logic by hand on top of one-off Checkout; it's a different, purpose-built API (`stripe.subscriptions`) that plugs into the same account.

### 31.6 Strong Customer Authentication — see the Security Guide

UK card payments legally require Strong Customer Authentication (SCA) for most online transactions. Stripe Checkout/Elements handle this automatically — see [Security Guide §4](../../Security/UKPath-Security-Guide.md#4-payments-technical-side) for the technical control, and don't let anyone "simplify" the checkout by bypassing it.

### 31.7 A genuinely cheaper option worth adding: Pay by Bank (Open Banking)

UK **Open Banking "Pay by Bank"** payments (via **GoCardless**, the most established provider) skip the card networks (Visa/Mastercard) entirely, moving money directly bank-to-bank instead:
- **GoCardless Instant Bank Pay: 1% + £0.20 per transaction, capped at a maximum £4** — no matter how large the order. Compare that to Stripe's 1.5% + 20p with no cap: on a £150 grocery order, Stripe costs ~£2.45, GoCardless costs ~£1.70
- No chargebacks, and money typically lands in your account within seconds via UK Faster Payments
- The customer pays by logging into their own bank's app to authorise the payment — no card number typed at all

**The one honest catch:** Open Banking payments move money from a UK bank account to a UK bank account — it doesn't work with an Indian-issued card, and a first-time visitor paying for groceries *before* they've landed almost certainly doesn't have a UK bank account yet. So this is the cheaper option for **repeat customers who've since opened a UK account**, but it can't be your only payment method — international cards still need to work for the pre-arrival use case, and that means keeping Stripe (or another card processor) as the default.

**Recommended setup**: Stripe for card payments (works with Indian-issued cards, covers every customer including pre-arrival), with GoCardless's Pay by Bank offered as a cheaper alternative once you're serving repeat, UK-based customers.

---

## 32. Stripe's Business Account Prerequisite — See the Compliance Guide

Going with Stripe means going through their UK "Know Your Business" (KYB) verification before any money can move. The full requirements list (Companies House registration, business bank account, director/UBO identity verification) and the `stripe_business_kyb_verified` gate live in [Compliance Guide §4](../../Compliance/UKPath-Compliance-Guide.md#4-payments-compliance).

**The dependency chain worth knowing as a developer**: the company must be incorporated and have a business bank account *before* Stripe onboarding can complete — so a checkout feature genuinely cannot go live until that foundational business-formation step is done, regardless of how complete the code is.

---

## 33. Master Prerequisites Checklist — See the Compliance Guide

The full master checklist (every legal requirement across the whole build, mapped to its `compliance_approvals` key) lives in the [Compliance Guide's master table](../../Compliance/UKPath-Compliance-Guide.md#master-checklist-seed-data-for-the-table-above), maintained as its own document rather than a section here — see the [top-level Documentation Index](../../README.md) for the full doc map.
