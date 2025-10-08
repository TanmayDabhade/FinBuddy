
# FinBuddy — Hackathon-Only PRD (Swift-only)

*A laser-focused spec for Copilot in Xcode. No extras, no timelines—just what to build now.*

---

## 1) Objective

Ship a native iOS app that turns **user-entered expenses** into **clear, actionable spending insights** with a **single Analyze action**, running great **offline** with an **AI fallback**. It must feel like a **mobile AI agent** (proactive, contextual) and look **production-ready**.

---

## 2) Scope (Build Now)

### Must-have features

1. **Expense Capture**

   * Add expense: **amount**, **title**, **date**, optional **notes**.
   * Post-save **category chip** (editable manual override).

2. **Demo Data Import**

   * Import **bundled sample CSV/JSON**.
   * **Undo last import** (single batch rollback) to avoid duplicates.

3. **Auto-Categorization (Lightweight)**

   * **Use AI** toggle (Settings):

     * ON → try AI categorization/analysis first; single retry on invalid JSON; then fallback.
     * OFF or failure → **heuristic keyword map** (mark “uncertain” until user overrides).

4. **One-Tap Analyze**

   * Period selector: **Last 7 days** / **Last 30 days**.
   * Output (rendered as an **Insight Card** + chart):

     * **Top categories** (total + % of total).
     * **Deltas vs previous equal window** (e.g., *Food +22%*).
     * **Recurring suspects** (same merchant ≥2, similar amount).
     * **3–5 bullet insights** + **one-line summary**.
   * **Save snapshot** to immutable **History**.

5. **Dashboard**

   * Primary **Analyze** button.
   * Latest **Insight Card** (bullets + summary).
   * **Category chart** (pie or bar) with **7/30d toggle**.
   * CTAs: **+ Log Expense**, **Import Demo Data**.
   * Empty state: “Import sample data” + “Add expense”.

6. **Expenses List**

   * Group by date; **category filter chips**.
   * Row → Edit sheet; **manual category override** persists.

7. **History**

   * List saved analyses (date range, top stat, summary).
   * Detail: read-only (card + chart snapshot).

8. **Settings (Minimal)**

   * **Use AI** toggle.
   * **Import Demo Data**, **Undo last import**, **Reset App Data**.
   * Brief privacy text (no bank links; local/demo data only).

### Out-of-scope (Do not build)

* Bank/Plaid, budgets/alerts, subscription cancellation flows.
* Multi-currency/tax, exports/sharing, Siri Shortcuts, notifications.
* Auth/accounts, custom themes beyond system light/dark.

---

## 3) Navigation & Flows

**Tab bar (5):** Dashboard • Expenses • Insights • History • Settings

* **Dashboard:** Analyze (primary) → shows Insight Card + chart; CTAs.
* **Add Expense (modal):** amount → title → date → notes → Save → category chip appears (AI/heuristic prefilled; editable).
* **Insights:** pick period → Run Analysis → cards (Top Categories, Deltas, Recurring) → Save to History.
* **Expenses:** filter chips → edit row → manual override.
* **History:** select snapshot → read-only details.
* **Settings:** toggles/actions (AI, import/undo/reset) + privacy copy.

---

## 4) Design Characteristics (so Copilot doesn’t drift)

### 4.1 Visual system

* **Look:** Clean, modern, neutral; trustful and “financial.”
* **Color:** System background; chart uses system palette. Accent: system Blue.
* **Typography:** San Francisco; respect **Dynamic Type**; titles ≈ Large Title, section headers ≈ Title2, body ≈ Body.
* **Spacing:** 8-pt grid (8/16/24); generous whitespace between cards.
* **Cards:** Soft rounded corners (≥16pt), subtle shadow, clear headings and bullets.

### 4.2 Components

* **Insight Card:** Title (“This Week at a Glance”), 3–5 bullets, **summary pill** (e.g., *“↓ 7% vs last week”*).
* **Category Chip:** Filled style; editable on Expense detail.
* **Filter Chips:** Segmented-control feel; horizontal scroll if overflow.
* **Buttons:** Primary (Analyze), Secondary (Add, Import), Destructive (Reset).
* **Chart:** Pie or bar; labels show category + %; responsive to text size.

### 4.3 Interaction & motion

* **Haptics:** Light on Save, Analyze, Undo.
* **Transitions:** Standard SwiftUI transitions; no fancy animations.
* **Performance:** Lists scroll at 60fps; no blocking on main thread.

### 4.4 Accessibility & copy

* **A11y:** VoiceOver labels on actions, chips, chart; hit targets ≥44pt; contrast compliant.
* **Microcopy (examples):**

  * Empty state: “No expenses yet. Import sample data or add one to begin.”
  * Fallback banner: “AI unavailable—using on-device analysis.”
  * CSV error: “We couldn’t import 3 rows. The rest were added.”
  * Reset confirm: “This permanently deletes expenses and analyses.”

---

## 5) Data Model (minimal, SwiftData/Core Data-ready)

**Expense** → `id, title, amount(Decimal), date, merchant?, category?, source(manual|csvImport), notes?, createdAt`
**Analysis** → `id, createdAt, periodStart, periodEnd, topCategories([Category: Decimal]), deltas([Category: Double]), recurringMerchants([String]), insights([String]), summary(String)`
**Enums** → `Category: food, transport, shopping, bills, entertainment, health, education, other` | `Source: manual, csvImport`
**Notes:** arrays/maps persisted as JSON blobs (Codable); index by `date`; currency via `NumberFormatter.currency`.

---

## 6) AI Contract (strict)

* **Toggle:** **Use AI** ON → try AI; on invalid JSON/timeout → **single retry** → then local fallback. OFF → always local.
* **System instruction:** “You are a concise financial assistant. Return **valid JSON only** matching the schema. No prose.”
* **User payload:** `period(start,end ISO), currency, transactions[{title, amount, date, merchant?, category?}]`
* **Expected JSON (exact keys):**

  ```json
  {
    "topCategories": [{"category":"food","total":123.45}],
    "deltas": [{"category":"food","deltaPct":22.3}],
    "recurringMerchants": ["Spotify","iCloud"],
    "insights": [
      "Food is your top category at 34% of spend.",
      "Subscriptions total $21.98 from Spotify and iCloud."
    ],
    "summary": "Up 7% vs last week. Biggest mover: Food (+22%)."
  }
  ```
* **On parse error:** retry once with “Return valid JSON that matches the schema exactly. No extra keys.” Then fallback.
* **Cache:** store last successful Analysis per period to load Dashboard instantly.

---

## 7) Core Behaviors & Edge Cases

* **Offline-first:** Analyze works offline (local analyzer).
* **Manual override wins:** do not overwrite user category changes.
* **Duplicate imports:** track last batch; **Undo last import** removes only that batch.
* **Charts:** handle single-category or tiny slices elegantly (aggregate tiny into “Other” if needed).
* **Error surfaces:** non-blocking banners for AI fallback/CSV issues; actionable messages.

---

## 8) Build Order (Task list for Copilot in Xcode)

1. **Project Skeleton** — SwiftUI app, tabs, SwiftData/Core Data entities (Expense, Analysis), repository protocols.
2. **Demo Import** — bundled CSV/JSON → map to Expense; store batch id; **Undo last import** action.
3. **Add/Edit Expense** — modal form with validation; show/edit category chip post-save.
4. **Expenses List & Filters** — grouped list, filter chips, edit sheet with manual override.
5. **LocalAnalyzer** — period aggregate, deltas vs previous, recurring suspects, insight strings; returns struct matching AI schema.
6. **Insights Screen** — period selector; **Run Analysis**; show cards; **Save to History**.
7. **Dashboard** — latest Insight Card + chart; **Analyze** (primary); CTAs; empty state.
8. **AIAnalysisService** — request/parse to strict schema; single retry; fallback + banner; cache latest Analysis.
9. **History** — list snapshots; detail read-only view (card + chart).
10. **Settings** — **Use AI** toggle; **Import Demo Data**, **Undo last import**, **Reset App Data**; privacy text.

---

## 9) Acceptance Checklist (must pass)

* Import bundled demo → Dashboard shows Insight Card + chart; **Analyze** works.
* Add an expense → re-Analyze → deltas update logically.
* **Use AI ON:** valid AI path; forcing failure shows fallback banner and still returns insights.
* **Use AI OFF:** always uses local analyzer with sensible output.
* **Undo last import** removes only most recent batch; **Reset App Data** clears all safely.
* Filters, edits, and manual category overrides persist.
* No crashes across import, analyze, add/edit, undo, reset, offline.
* Currency/date formatting correct; Dark Mode & Dynamic Type clean; VoiceOver reads key elements.

