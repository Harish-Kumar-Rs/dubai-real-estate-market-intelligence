 Dubai Real Estate Market Intelligence Platform

A Business Analyst portfolio project analyzing 1.75M+ property transactions from the Dubai Land Department to surface investor-relevant patterns in growth, value, and area characteristics — built with a deliberate focus on statistical rigor over surface-level polish.

**Stack:** PostgreSQL · Power BI · Python (pandas, geopy, googlemaps, scipy, scikit-learn)

---

 Why This Project

Most public "Dubai real estate dashboard" projects stop at descriptive KPIs — totals, averages, trend lines. This project goes further: every claim on the dashboard that could be tested, was tested. Where a hypothesis didn't hold up (landmark proximity driving growth, property type driving growth), that null result is reported as-is rather than reframed into something that sounds more impressive. Where a raw statistic was misleading (outlier-inflated means, mix-shift-distorted area growth), the misleading version was diagnosed and corrected before it reached the dashboard.

The goal isn't to prove a thesis. It's to demonstrate the analytical discipline of not fooling yourself — or the reader — with your own numbers.

---

 Data & Scope

- **Source:** Dubai Land Department transaction records, `real_estate_data` PostgreSQL database, `transactions` table (1,748,554 rows)
- **Analysis window:** 1998–2025. Pre-1998 rows excluded (sparse, unreliable legacy data). 2026 excluded (partial year, would distort any year-over-year comparison).
- **Transaction filter:** `trans_group = 'Sales'` only, applied everywhere. Mortgages and Gifts are structurally different transaction types and are excluded to avoid conflating them with market-price sales.
- **Value field convention:** `actual_worth_capped` is used for anything sensitive to skew — averages, growth rates, per-area comparisons. Raw `actual_worth` is only used for simple SUM-based facts (e.g., "which year had the highest total transaction value"), where ranking order was verified to be identical either way.

 A note on CAGR

An early version of this project computed CAGR (2021–2025) as a headline growth metric. It was dropped entirely. The 2021–25 period was shaped by COVID-era capital flight, the Golden Visa program, and war-driven migration into the UAE — a shock-driven boom, not organic market growth. Presenting a CAGR calculated over that window as a "typical" growth rate would have been misleading, so the metric was removed rather than caveated.

---

Architecture: Static vs. Dynamic KPIs

KPIs that don't change with user interaction (e.g., total historical transaction value, peak value year) are computed once in **SQL views** and pulled directly into Power BI. KPIs that respond to slicers (e.g., year-over-year growth for a selected year) are computed in **DAX** at query time. This separation was deliberate — it keeps static facts fast and simple, and keeps interactive logic isolated and testable, rather than mixing the two and creating an inconsistent mental model of "where does this number come from."

Every `WHERE` filter used across the project was checked to confirm it was actually excluding rows — not just present for defensive-coding's sake.

---

 Page 1: Overview

- Static KPI row: Net Transaction Value, Total Sales Transactions, Avg Transaction Value, Peak Value Year, Areas Covered
- Dynamic KPI row (year slicer): Selected/Previous Year Value & Count, YoY Growth % with conditional formatting
- Trend line, 1998–2025
- Property Type composition (value vs. count) — this comparison revealed a rank-swap between Land and Villa depending on whether you look at total value or transaction count, which is itself a useful reminder that "biggest" depends on which metric you're asking about

---

 Page 2: Area Analysis — Landmark Correlation

**Question:** Does proximity to a mall or metro station predict an area's growth?

**Method:**
1. Geocoded 186 areas and 44 malls/metro stations (Nominatim first pass, Google Geocoding API to close remaining gaps — 100% final coverage)
2. Computed haversine distance from each area to its nearest mall and nearest metro station
3. Built an area-level growth metric: % change in average `actual_worth_capped` between a 2018–20 window and a 2023–25 window, computed **separately per property type** (Unit/Villa/Land — Building excluded for data sparsity), for areas with ≥5 transactions in both windows

Why property-type-separated growth matters:** An early blended version of this metric showed apparent −80% to −90% "crashes" in some areas. These were not real declines — they were an artifact of property-type mix-shift (e.g., an area that was Land-heavy in 2018–20 becoming Unit-heavy by 2023–25, diluting the blended average with a structurally cheaper property type). Controlling for property type before computing growth was essential to get a real signal instead of a measurement artifact.

Result:** Pearson correlation between distance and growth, tested per property type and overall — **no statistically significant correlation found anywhere.**

| Comparison | r | p-value |
|---|---|---|
| Overall vs. Mall distance | −0.083 | 0.235 |
| Overall vs. Metro distance | −0.042 | 0.554 |
| Unit vs. Mall distance (closest to significance) | — | 0.097 |

**Interpretation:** Landmark proximity does not meaningfully predict growth in this dataset, over this timeframe. This is reported as a genuine null finding, not reframed as a weak positive.

**Explored and explicitly parked (Phase 2 candidates, not pursued):** business license data, population data, income data, metro ridership data. Flagged as legitimate enrichment ideas but excluded to avoid scope creep on this phase of the project.

**Limitations (stated on the dashboard itself):** this analysis measures growth, not price level; uses straight-line distance rather than actual travel distance/time; and depends on a ≥5-transaction threshold per window that inherently favors more active areas.

---

 Statistical Study: Does Growth Differ by Property Type?

Hypothesis (H₀):** Growth rate does not significantly differ by property type (Unit / Villa / Land).

**Method — and why this specific method:**
1. **Shapiro-Wilk test** run per group to check normality. All three groups failed (p < 0.01 in every case) — the data is not normally distributed.
2. **Levene's test** for homogeneity of variance: F = 7.385, p = 0.0008 — variances are significantly unequal across groups.
3. Because both assumptions required for a standard one-way ANOVA were violated, **Kruskal-Wallis** (the non-parametric alternative) was used instead — a one-way ANOVA would not have been statistically valid here.

Result:** H = 0.716, p = 0.699, effect size ε² = 0.0035 — **not significant, and the effect size is negligible.** Growth rates do not meaningfully differ by property type.

The outlier story:** Raw group means look different at first glance — Land averaged 81.3% growth vs. ~55–56% for Unit and Villa. But this is outlier-driven: the medians are far closer together (Land 55.3%, Unit 46.0%, Villa 46.8%). A handful of high-outlier Land transactions pull the mean up without reflecting the typical transaction. Reporting only the mean here would have overstated Land's real growth character.

Investor framing:** since there's no statistically meaningful growth difference by type, the honest investment question isn't "which type grows more" — it's risk, liquidity, and ticket size:

| Type | n | Avg Deal Size | Character |
|---|---|---|---|
| Unit | 59 | 2.37M AED | Most liquid, lowest entry point, tightest spread |
| Villa | 71 | 6.94M AED | Mid-tier ticket size, similar risk profile to Unit |
| Land | 75 | 13.79M AED | Highest ticket size and variance; upside concentrated in a small number of outlier deals rather than the typical transaction |

**Limitation:** sample sizes (n = 59–75 areas per type) support directional comparison but are too small for precise estimates — within-type differences should be read as suggestive, not definitive.

---

## Design Principles Followed Throughout

- **Statistical rigor is checked, not assumed.** Every test's assumptions (normality, variance homogeneity) were checked first, and the non-parametric alternative was used whenever assumptions failed — with the reasoning documented, not hidden.
- **Effect size is reported alongside p-value.** A significant p-value with a negligible effect size is not treated as a meaningful finding.
- **Null and negative findings are reported as such.** The landmark-correlation study and the property-type-growth study both came back non-significant. Both are shown on the dashboard exactly as found.
- **Mockups are layout references only, never data sources.** AI-generated visual mockups were used during design to get panel structure and layout right — but every number that ended up on the live dashboard was cross-checked against the actual Postgres output before publishing, after an early mockup was caught showing a fabricated Levene's test result that contradicted the real one.
- **Real numbers live in Postgres, not hardcoded.** All test statistics, growth figures, and investor-profile numbers are pulled from dedicated result tables (`area_landmark_stats_summary`, `property_type_test_results`, `property_type_investor_profile`) rather than typed directly into the report.

---

## What's Next

- **Area Investment Score (0–100)** — a composite score combining growth (40%), value (30%), liquidity (10%), and volume (20%), normalized 0–100. Design questions still open: whether the growth component should blend or pick a single property type per area; whether value should be average or total; and how to define liquidity distinctly from volume, since both currently want to use transaction count as their base.
- **Area Clustering for Investors** — k-means clustering (scikit-learn) across ~190+ areas using full 1998–2025 history (not the 2018–20 vs. 2023–25 windowed comparison used elsewhere), with a feature set covering total value, transaction count, average deal size, full-history growth, and volatility. Each resulting cluster will get a plain-language investor description rather than a generic "Cluster 1/2/3" label. Not yet started — feature set and cluster count (k) still to be decided.

---

## Repository

[github.com/Harish-Kumar-Rs/dubai-real-estate-market-intelligence](https://github.com/Harish-Kumar-Rs/dubai-real-estate-market-intelligence)