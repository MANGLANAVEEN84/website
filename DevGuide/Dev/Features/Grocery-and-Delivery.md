# UKPath — Traveler-First Navigation & Grocery Delivery Features

### Sections 26–30 of the Developer Guide

See the [Dev docs index](../README.md) for how this fits with the other module docs.

---

## 26. A Simple, Traveler-First Architecture (Plain English, No Jargon)

The modules in [Module-Build-Notes.md §4](../Module-Build-Notes.md#4-module-by-module-build-notes) ("Module A, Module B...") are how a *developer* thinks about the app. A traveler doesn't think in modules — they think in a timeline of worries. The cleanest fix is to rename and regroup the entire navigation around **what's on the traveler's mind at each moment**, not around your internal feature list.

### 26.1 The traveler's actual mental timeline

Put yourself in their shoes, landing at Heathrow for the first time:
1. **"Did I bring the right things? What don't I need to carry?"** — before landing
2. **"I've landed — what do I do right now?"** — the first hour
3. **"How do I get to where I'm staying?"** — the next few hours
4. **"How do I live day to day here?"** — food, money, phone, once settled
5. **"What if something goes wrong?"** — the thing they hope they never need, but need to find in seconds if they do

### 26.2 Renaming the navigation around that timeline, not your module list

| Old (developer-facing) | New (traveler-facing, plain English) | What lives here |
|---|---|---|
| Module A — Onboarding | *(just the sign-in screen, not a nav item)* | Login/guest mode |
| Module F — Itinerary Planning | **Before You Land** | Packing advice, pre-order groceries (§27 below), what to expect at your airport (see [Transport-and-Reference-Data.md §14](Transport-and-Reference-Data.md#14-india--uk-flight-routes-reference-data-for-the-itinerary-module)) |
| Module C — Local Travel | **Getting to Your Stay** | Airport → destination routes, fare estimates (see [Transport-and-Reference-Data.md §15, §21](Transport-and-Reference-Data.md)) |
| Module B, D, E — Food, SIM, Money | **Living Here** | Food & grocery, SIM setup, money/card guidance |
| Module G — Writing Help | **Need Help Writing Something?** | Email/complaint templates |
| Module H — Emergency | **If Something's Wrong** | Always one tap away, never buried |
| Chat widget | **Chat With Us** | Visible everywhere, not hidden in a menu |

**The test for every screen name going forward:** would a first-time visitor, reading it out loud, immediately know what's behind it without thinking? "If Something's Wrong" passes that test. "Module H — Emergency & Safety Services" does not.

### 26.3 What this means for the home screen

Instead of a flat grid of equal-sized category tiles, structure the home screen around the timeline itself:
- A single, prominent card at the top that changes based on *where the user is in their trip* — "Landing in 2 days? Order your groceries now" before arrival, "Just landed? Here's your route to Swindon" right after, "Need something right now?" once settled
- The category tiles (food, travel, SIM, money, etc.) sit below as the everyday toolbox, not competing with the one thing that's actually relevant *right now*
- Emergency stays as its own fixed, always-visible element (not a tile that scrolls away)

---

## 27. Feature: Order Groceries Ahead of Landing (Corrected for How Delivery Actually Works)

Delivery pricing **depends entirely on the retailer** — some do weight-tier pricing, others price by order value only. Shubham Foods UK's actual published rates:

**Shubham Foods UK — real, current UK mainland rates:**
| Weight | Order value | Delivery cost |
|---|---|---|
| Up to 25kg (1 box) | £50+ | **£0** (free) |
| Up to 25kg (1 box) | Below £50 | **£5.99** |
| Under 2kg (small parcel, economy) | Any | £4.99 |
| Under 2kg (small parcel, express) | Any | £6.99 |
| 25–50kg (2 boxes) | Any | £11.98 |
| 50–75kg (3 boxes) | Any | £17.97 |
| 75–100kg (4 boxes) | Any | £23.96 |

**Note: Scotland has separate, higher rates** (starting at £15.99 for 0–25kg) — worth building this as a region-aware field, not a single UK-wide number.

So for a typical example — **up to 10kg fits entirely within their "up to 25kg" band**, meaning the delivery cost is just **£5.99 if the basket is under £50, or free if it's £50+** — it doesn't scale up between 0 and 25kg, it's a flat rate for that whole band. That's the honest, useful number to show a user: not a per-kg calculation (which would imply false precision), but "here's the real flat rate for the weight band your order falls into."

**Other retailers work differently** — Red Rickshaw and PickEasy publish a value-based free-delivery threshold (£50 and £40 respectively) without a public weight-tier breakdown, and Lakshmi Stores quotes up to 5 working days standard delivery. Delivery speed genuinely varies by retailer, so this should be pulled per-retailer, not assumed uniform — exactly the kind of retailer-by-retailer variation the [daily-refresh pipeline](Transport-and-Reference-Data.md#17-daily-data-refresh-pipeline-keeping-static-data-current) should track — a `delivery_policy` field per partner rather than one hardcoded number for "Indian grocery delivery."

### 27.1 The feature, built correctly

1. User enters their **arrival date** and **UK destination address** (§26's "Before You Land" screen)
2. App shows a curated, small list of common items (rice, dal, spices, snacks, ghee) rather than replicating a full retailer catalogue — this is a *starter kit* experience, not a full grocery app
3. App shows the **real delivery cost for the weight band and the real delivery speed, per retailer** — never a single averaged number across retailers
4. Because delivery speed varies this much by retailer, the app's "order by this date" suggestion should be **retailer-specific**, not one fixed rule — a next-day retailer selected 1 day out is fine; a 5-day retailer selected 1 day out should visibly warn the user it likely won't arrive in time
5. User is deep-linked out to complete the actual purchase on the retailer's own site (this is an affiliate-link opportunity — see [Payments-and-Monetisation.md](Payments-and-Monetisation.md) — check if an affiliate program actually exists before assuming one does)

### 27.2 The one real-world catch worth flagging before you build this

**Hotels don't always accept deliveries addressed to a guest who hasn't checked in yet**, and even when they do, some charge a holding fee or won't take responsibility for it.
- [ ] Add a simple note on this screen: "Check with your hotel that they'll accept a delivery before you check in — most will, but it's worth a quick call first"
- [ ] Default the suggested delivery date to **the day of arrival or the day after**, not before
- [ ] For guests staying with family/friends rather than a hotel, this whole caveat disappears — worth asking which applies before showing the delivery-date suggestion

---

## 28. Feature: UKPath's Own Grocery Packing & Delivery (Swindon Hub), Plus Third-Party Store Links

Instead of only linking out to third-party retailers, **UKPath itself becomes the seller** — packing groceries from a Swindon base and shipping nationwide, with the third-party retailer links from §27 staying available as an alternative.

### 28.1 UK delivery pricing isn't really distance-based

UK domestic couriers (Royal Mail, DPD, Evri, Parcelforce) price mainland deliveries almost entirely by **weight and speed**, not by distance — sending a 10kg box from Swindon to Bristol costs about the same as sending it to Edinburgh, because mainland UK is treated as one flat pricing zone by every major courier. Distance only matters at the edges: **the Scottish Highlands & Islands, and Northern Ireland, carry a real surcharge** from every courier.

**So the "rough fare from Swindon" is best built as:**
- A flat, weight-tiered rate for UK mainland (up to 5kg, 5–10kg, 10–25kg bands, one price per band regardless of destination)
- A separate, higher rate band for the Scottish Highlands/Islands and Northern Ireland (postcode-detected, not distance-calculated)
- This is simpler to build than a true distance calculator, and more accurate to how couriers actually charge you

### 28.2 The ordering flow

1. **Predefined item catalogue** — a curated list you stock and pack yourself (start small: rice, dal, spices, snacks, ghee)
2. User builds a basket from this list; running weight total shown as they add items
3. **Delivery fare** looked up from the weight-band table (§28.1) plus a remote-postcode surcharge flag, calculated the moment the user enters their delivery postcode
4. Checkout — payment (see [Payments-and-Monetisation.md](Payments-and-Monetisation.md)), delivery address, requested delivery/arrival date
5. **Alongside this flow, the third-party store options from §27 still show as an alternative** — "or order from these other UK stores directly" — with their phone number and minimum order value visible for comparison

### 28.3 Schema for the item catalogue and fare bands

```sql
-- Your own stocked items (distinct from third-party `listings`)
grocery_items
  id UUID PRIMARY KEY
  name VARCHAR
  category VARCHAR         -- 'rice', 'spices', 'snacks', etc.
  price DECIMAL
  weight_grams INT
  in_stock BOOLEAN

-- Weight-banded delivery fares from your Swindon hub
delivery_fare_bands
  id UUID PRIMARY KEY
  min_weight_grams INT
  max_weight_grams INT
  mainland_uk_fare DECIMAL
  highlands_islands_ni_fare DECIMAL

-- Third-party store directory (extends the `listings` table from Architecture-and-API.md §2)
-- add these columns specifically for this comparison view:
ALTER TABLE listings ADD COLUMN phone_number VARCHAR;
ALTER TABLE listings ADD COLUMN minimum_order_value DECIMAL;
ALTER TABLE listings ADD COLUMN typical_delivery_speed VARCHAR;  -- 'next-day', 'up to 5 days', etc.
```

### 28.4 Legal obligations this feature triggers — see the Compliance Guide

Once UKPath packs and ships food itself, it becomes a food business with real legal obligations (council registration, allergen labelling, courier account, food hygiene certification) that don't apply to the rest of this guide's consult-only/directory/affiliate modules. Full detail: [Compliance Guide §3](../../Compliance/UKPath-Compliance-Guide.md#3-food-business-compliance-sections-2830-of-the-developer-guide).

---

## 29. Code-Enforced Compliance Gate — Architecture Summary

Legal sign-off must be a **hard gate in the code itself**, not just a checklist that can quietly get skipped under launch pressure. The full `compliance_approvals` schema, seed list, and code pattern live in the [Compliance Guide](../../Compliance/UKPath-Compliance-Guide.md#code-enforced-compliance-gate) — this is the one piece of "legal" content that's also an architecture decision, so it's worth knowing it exists from the developer side too:

- A `compliance_approvals` table holds one row per legal requirement, defaulted to `is_approved: false`
- Every checkout/payment endpoint checks the relevant keys **server-side** before proceeding — via the `compliance` module's exported `isApproved()` function (see [Scaling-and-Modular-Architecture.md §34](../Scaling-and-Modular-Architecture.md#34-building-this-as-a-truly-modular-system-plug-in-not-tangled)), never a UI-only warning
- Only a person with real authority flips a row to `true` — never a developer, and never hardcoded

---

## 30. Feature: Personal-Shopper Courier Model (Buying Groceries on the Customer's Behalf)

This is a different, and genuinely simpler-to-license, model than §28's "UKPath stocks and ships its own groceries" — worth building as a clearly separate flow, not a variant of the same one.

### 30.1 How this is different from §28

Instead of UKPath holding its own stock, a UKPath courier (staff or a gig worker) **physically goes to an existing Indian grocery store, buys the items the customer requested, and delivers them.** This is the same underlying model as Deliveroo/Uber Eats/Instacart — you're not the retailer of the goods, you're the purchasing-and-delivery agent, and it sidesteps §28.4's food-business-registration requirement entirely, since you're not manufacturing, packing, or selling food as a retailer — the grocery store remains the seller of record.

### 30.2 Payment handling — an important distinction from the Money module's "no money handling" rule

This is worth being precise about, since [Module-Build-Notes.md's Module E](../Module-Build-Notes.md#4-module-by-module-build-notes) established "no money handling" as a legal boundary (to stay outside FCA e-money regulation). **This is a different kind of money handling, and it's the common, already-legal kind**: taking payment for a purchase-and-delivery service (exactly what Deliveroo/Uber Eats/Instacart already do) is not the same as issuing or managing e-money/prepaid balances. That said, get this specific point confirmed as part of the [Compliance Guide's](../../Compliance/UKPath-Compliance-Guide.md) legal sign-off — the exact structure (do you take payment before or after buying, do you mark up prices, etc.) affects the details.

**A practical flow that keeps this clean:**
1. Customer selects items from a list (can be the same predefined-item UI as §28.2) and a target store
2. App shows an **estimated total** (item prices + a clearly stated service/delivery fee) and takes an **authorization** for that estimated amount, not a final charge
3. Courier buys the actual items, keeps the receipt
4. Final charge is settled against the real receipt total plus the service fee — refund the difference if items were unavailable/substituted, charge the difference (with the customer's prior consent to a reasonable range) if it came in higher
5. [ ] **Substitution policy needs to be explicit and shown to the customer up front** — what happens if an item's out of stock — this is the single most common source of complaints in this business model, worth designing deliberately rather than leaving implicit

### 30.3 Schema addition

```sql
shopper_orders
  id UUID PRIMARY KEY
  user_id UUID REFERENCES users(id)
  store_listing_id UUID REFERENCES listings(id)
  requested_items JSONB          -- what the customer asked for
  estimated_total DECIMAL
  actual_total DECIMAL           -- filled in after the courier shops
  service_fee DECIMAL
  substitution_notes TEXT
  status ENUM('requested','shopping','out_for_delivery','delivered','cancelled')
  courier_id UUID                -- references a `couriers` table (staff or gig workers)
```

### 30.4 This adds a new compliance flag, not a replacement for §28's

This model is generally simpler to license than §28's (no food-business registration needed), but its payment structure still needs its own sign-off before its checkout endpoint goes live — see [Compliance Guide §3](../../Compliance/UKPath-Compliance-Guide.md#3-food-business-compliance-sections-2830-of-the-developer-guide) for the `personal_shopper_payment_model_reviewed` requirement.
