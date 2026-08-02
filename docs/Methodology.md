# Methodology

This document covers the full analytical methodology behind the Dubai Real Estate Market Intelligence Platform: data scope, statistical assumptions and testing, feature engineering, clustering methodology, bugs caught and fixed during development, and known limitations. The main [README](../README.md) covers the high-level summary — this document is for readers who want the reasoning behind every number on the dashboard.

## Table of Contents

1. [Data Scope & Conventions](#data-scope--conventions)
2. [Architecture: Static vs. Dynamic KPIs](#architecture-static-vs-dynamic-kpis)
3. [Page 2: Area Analysis — Landmark Correlation](#page-2-area-analysis--landmark-correlation)
4. [Statistical Study: Growth by Property Type](#statistical-study-growth-by-property-type)
5. [Page 4: Area Investment Segmentation (K-Means Clustering)](#page-4-area-investment-segmentation-k-means-clustering)
6. [Design Principles Followed Throughout](#design-principles-followed-throughout)
7. [Known Limitations & Caveats](#known-limitations--caveats)

---

## Data Scope & Conventions

**Source:** Dubai Land Department transaction records, `real_estate_data` PostgreSQL database, `transactions` table (1,748,554 rows).

**Analysis window:** 1998–2025. Pre-1998 rows excluded (sparse, unreliable legacy data). 2026 excluded (partial year, would distort any year-over-year comparison). The area clustering study specifically uses the full 2000–2025 window rather than a fixed comparison window — see the clustering section below.

**Transaction filter:** `trans_group = 'Sales'` only, applied everywhere. Mortgages and Gifts are structurally different transaction types and are excluded to avoid conflating them with market-price sales.

**Value field convention:** `actual_worth_capped` is used for anything sensitive to skew — averages, growth rates, per-area comparisons. Raw `actual_worth` is only used for simple SUM-based facts (e.g., "which year had the highest total transaction value"), where ranking order was verified to be identical either way.

**On CAGR:** an early version of this project computed CAGR (2021–2025) as a headline growth metric. It was dropped entirely. The 2021–25 period was shaped by COVID-era capital flight, the Golden Visa program, and war-driven migration into the UAE — a shock-driven boom, not organic market growth. Presenting a CAGR calculated over that window as a "typical" growth rate would have been misleading, so the metric was removed rather than caveated.

---

## Architecture: Static vs. Dynamic KPIs

KPIs that don't change with user interaction (e.g., total historical transaction value, peak value year) are computed once in SQL views and pulled directly into Power BI. KPIs that respond to slicers (e.g., year-over-year growth for a selected year) are computed in DAX at query time. This separation was deliberate — it keeps static facts fast and simple, and keeps interactive logic isolated and testable, rather than mixing the two and creating an inconsistent mental model of "where does this number come from."

Every `WHERE` filter used across the project was checked to confirm it was actually excluding rows — not just present for defensive-coding's sake.

---

## Page 2: Area Analysis — Landmark Correlation

**Question:** Does proximity to a mall or metro station predict an area's growth?

**Method:**

- Geocoded 186 areas and 44 malls/metro stations (Nominatim first pass, Google Geocoding API to close remaining gaps — 100% final coverage).
- Computed haversine distance from each area to its nearest mall and nearest metro station.
- Built an area-level growth metric: % change in average `actual_worth_capped` between a 2018–20 window and a 2023–25 window, computed separately per property type (Unit/Villa/Land — Building excluded for data sparsity), for areas with ≥5 transactions in both windows.

**Why property-type-separated growth matters:** an early blended version of this metric showed apparent −80% to −90% "crashes" in some areas. These were not real declines — they were an artifact of property-type mix-shift (e.g., an area that was Land-heavy in 2018–20 becoming Unit-heavy by 2023–25, diluting the blended average with a structurally cheaper property type). Controlling for property type before computing growth was essential to get a real signal instead of a measurement artifact.

**Result:** Pearson correlation between distance and growth, tested per property type and overall — no statistically significant correlation found anywhere.

| Comparison | r | p-value |
|---|---|---|
| Overall vs. Mall distance | −0.083 | 0.235 |
| Overall vs. Metro distance | −0.042 | 0.554 |
| Unit vs. Mall distance (closest to significance) | — | 0.097 |

**Interpretation:** landmark proximity does not meaningfully predict growth in this dataset, over this timeframe. This is reported as a genuine null finding, not reframed as a weak positive.

**Explored and explicitly parked** (Phase 2 candidates, not pursued): business license data, population data, income data, metro ridership data. Flagged as legitimate enrichment ideas but excluded to avoid scope creep on this phase of the project.

**Limitations** (also stated on the dashboard itself): this analysis measures growth, not price level; uses straight-line distance rather than actual travel distance/time; and depends on a ≥5-transaction threshold per window that inherently favors more active areas.

---

## Statistical Study: Growth by Property Type

**Hypothesis (H₀):** growth rate does not significantly differ by property type (Unit / Villa / Land).

**Method — and why this specific method:**

- Shapiro-Wilk test run per group to check normality. All three groups failed (p < 0.01 in every case) — the data is not normally distributed.
- Levene's test for homogeneity of variance: F = 7.385, p = 0.0008 — variances are significantly unequal across groups.
- Because both assumptions required for a standard one-way ANOVA were violated, Kruskal-Wallis (the non-parametric alternative) was used instead — a one-way ANOVA would not have been statistically valid here.

**Result:** H = 0.716, p = 0.699, effect size ε² = 0.0035 — not significant, and the effect size is negligible. Growth rates do not meaningfully differ by property type.

**The outlier story:** raw group means look different at first glance — Land averaged 81.3% growth vs. ~55–56% for Unit and Villa. But this is outlier-driven: the medians are far closer together (Land 55.3%, Unit 46.0%, Villa 46.8%). A handful of high-outlier Land transactions pull the mean up without reflecting the typical transaction. Reporting only the mean here would have overstated Land's real growth character.

**Investor framing:** since there's no statistically meaningful growth difference by type, the honest investment question isn't "which type grows more" — it's risk, liquidity, and ticket size:

| Type | n | Avg Deal Size | Character |
|---|---|---|---|
| Unit | 59 | 2.37M AED | Most liquid, lowest entry point, tightest spread |
| Villa | 71 | 6.94M AED | Mid-tier ticket size, similar risk profile to Unit |
| Land | 75 | 13.79M AED | Highest ticket size and variance; upside concentrated in a small number of outlier deals rather than the typical transaction |

**Limitation:** sample sizes (n = 59–75 areas per type) support directional comparison but are too small for precise estimates — within-type differences should be read as suggestive, not definitive.

---

## Page 4: Area Investment Segmentation (K-Means Clustering)

**Question:** can Dubai areas be grouped into a small number of statistically distinct, plain-language investor profiles based on how they've actually behaved historically — rather than relying on a windowed before/after comparison?

Unlike the landmark-correlation study (which compares a 2018–20 window to a 2023–25 window), this analysis uses each area's **full 2000–2025 transaction history**, since the goal here is to characterize an area's overall market behavior, not measure change between two points in time.

### Feature engineering

After checking the correlation matrix and dropping `total_value` — mathematically redundant with `txn_count × avg_deal_size`, r = 0.898 — the final feature set was:

- `txn_count` — transaction volume
- `avg_deal_size` — average transaction value
- `growth_b_slope` — linear regression slope of yearly average value over time, chosen over a fixed-window endpoint comparison since ~47% of areas had no data in a fixed 2000–02 / 2023–25 window pair
- `volatility_cv` — coefficient of variation of yearly average value

**Reliability filter:** areas required ≥10 years of *reliable* transaction history (years with <10 transactions were dropped as thin before the ≥10-year check was applied). Final qualifying set: **103 of 238 candidate areas**.

**Scaling:** `StandardScaler` applied to all four features, confirmed mean ≈ 0 / std ≈ 1 post-scaling.

**k selection:** the elbow method showed a clear inflection at k = 4. Silhouette score technically preferred k = 2 (0.52), with k = 4 a close second (~0.43). k = 4 was chosen deliberately over the statistically "best" k = 2, because k = 2 wouldn't support the goal of producing distinct, plain-language investor personas — a tradeoff stated here rather than hidden behind the silhouette number.
![Elbow Method - Optimal K](images/charts/optimalk.png)

![Silhouette Score](images/charts/silhouette%20score.png)

### Bugs caught and fixed

Two bugs were caught and fixed during pipeline development — both changed real output, not just code style:

1. **Filter-order bug:** the pipeline originally checked "≥10 years of history" *before* removing thin-transaction years (<10 txns/year), letting unreliable years count toward the history-length requirement. Re-sequencing the filter (drop thin years first, then require ≥10 remaining reliable years) changed the qualifying area count from an initially miscounted 165/238 down to the correct 103/238.
2. **Al Merkadh distortion:** pre-fix, this area showed an implausible −2.39M/year growth slope, traced to two artificially high-value years (2013: 4 transactions, 2014: 1 transaction) skewing the regression. Post-fix, the slope corrected to −955K/year — verified against raw yearly data as a genuine structural transition (a handful of expensive early deals, followed by thousands of cheaper later ones), not a data artifact.

### Cluster results

Four clusters, manually inspected area-by-area (not just by their averages) to confirm each grouping made sense:

| Cluster | Name | n areas | Avg growth (AED/yr) | Avg deal size | Volatility (CV) |
|---|---|---|---|---|---|
| 0 | Established Mid-Market Areas | 64 | +52.8K | 3.13M | 0.50 |
| 1 | Premium Growth Areas | 22 | +319.5K | 11.2M | 0.50 |
| 2 | High-Turnover, Declining-Value Areas | 4 | −166.2K | 1.8M | 0.92 |
| 3 | High-Volatility Declining Areas | 13 | −568.4K | 1.9M | 1.48 |

- **Cluster 1** — low volume, highest deal size, strongest growth. Confirmed via manual inspection: Island 2, Jumeirah Second, Al Nahda Second, Um Suqaim, Al Manara — established premium/villa areas.
- **Cluster 0** — moderate on every dimension. Confirmed as a genuine broad middle market, not a leftover bucket — spans Jabal Ali, Nad Al Shiba, Jumeirah First at the higher end down to Madinat Hind 4, Wadi Al Safa 2 at the lower end.
- **Cluster 2 (n = 4) — flagged for caution throughout the dashboard.** Extreme transaction volume, moderate-low value, negative growth, high volatility. Confirmed as Marsa Dubai (Dubai Marina), Business Bay, Al Barsha South Fourth, Al Thanyah Fifth — dense, iconic, high-turnover hotspots. With only 4 areas, this cluster's statistics are treated as directional, not a stable category.
- **Cluster 3** — highest volume, lowest value, most negative growth, highest volatility. Includes both Al Merkadh (confirming the structural-transition pattern found during feature-engineering debugging) and Burj Khalifa alongside peripheral areas like Al Warsan First. This cluster groups areas by **shared statistical pattern — not by neighborhood character or a shared underlying cause** — a distinction stated explicitly on the dashboard rather than glossed over.

### Cross-cluster comparison scoring

Each cluster is also scored 0–100 on five dimensions (Growth, Deal Size, Liquidity, Stability, Volume) using `MinMaxScaler`, shown as a clustered bar chart on the dashboard.

- Scores are **relative, not absolute** — because scaling is fit across only the 4 cluster-level values, the lowest-scoring cluster on any metric always scores 0, even if its real gap to the next cluster is small. Stated directly on the dashboard next to the chart.
- **Volume and Liquidity are deliberately distinct metrics.** An earlier version of this scoring used `n_areas` (cluster size) as a stand-in for "Volume," which conflated a clustering artifact with an actual market characteristic. This was corrected: Volume is now based on total transaction activity (`avg_txn_count × n_areas`), while Liquidity remains per-area average transaction count.

### Area map

The 103 clustered areas were joined to previously geocoded coordinates (from the landmark-correlation work) and plotted geographically, colored by cluster — giving a spatial view of where each investor profile is physically concentrated across the city, alongside the statistical view. The join was verified: all 103 clustered areas found an exact coordinate match, with no duplicate coordinate rows.

**Limitation:** clustering covers 103 of 238 candidate areas — areas without ≥10 years of reliable transaction history were excluded rather than analyzed on insufficient data.

---

## Design Principles Followed Throughout

- **Statistical rigor is checked, not assumed.** Every test's assumptions (normality, variance homogeneity) were checked first, and the non-parametric alternative was used whenever assumptions failed — with the reasoning documented, not hidden.
- **Effect size is reported alongside p-value.** A significant p-value with a negligible effect size is not treated as a meaningful finding.
- **Null and negative findings are reported as such.** The landmark-correlation study and the property-type-growth study both came back non-significant. Both are shown on the dashboard exactly as found.
- **Mockups are layout references only, never data sources.** AI-generated visual mockups were used during design to get panel structure and layout right — but every number that ended up on the live dashboard was cross-checked against the actual Postgres output before publishing. This wasn't a one-off precaution: an early mockup was caught showing a fabricated Levene's test result, and later mockups during the clustering phase were caught fabricating area counts, growth figures, and even placing a real area (Dubai Marina) into the wrong cluster with an invented growth number. Every one of these was cross-checked and corrected before reaching the dashboard.
- **Real numbers live in Postgres, not hardcoded.** All test statistics, growth figures, and investor-profile numbers are pulled from dedicated result tables (`area_landmark_stats_summary`, `property_type_test_results`, `property_type_investor_profile`, `area_cluster_assignments`, `cluster_profile_summary`, `cluster_radar_scores`, `area_cluster_map_data`) rather than typed directly into the report.

---

## Known Limitations & Caveats

- **Cluster 2 (High-Turnover, Declining-Value Areas) is based on only 4 areas.** Its statistics are real and verified, but should be treated as directional rather than a statistically stable category.
- **Cluster comparison scores are relative (MinMax-scaled across 4 clusters), not absolute.** A score of 0 on a given metric means "lowest of these 4 clusters," not "zero performance."
- **Cluster 3 groups areas by statistical pattern, not shared cause or character.** It includes both iconic high-value areas (Burj Khalifa) and peripheral areas (Al Warsan First) — the shared thread is volume/volatility/decline pattern, not neighborhood type.
- **Clustering covers 103 of 238 candidate areas** — areas without ≥10 years of reliable (non-thin) transaction history were excluded rather than analyzed on insufficient data.
- **Landmark-correlation growth uses straight-line distance**, not travel time or actual route distance, and depends on a ≥5-transaction-per-window threshold that favors more active areas.
- **Property-type sample sizes (n = 59–75 areas per type)** support directional comparison but are too small for precise estimates.
- **CAGR is intentionally not reported** anywhere in this project, since the 2021–25 boom period would distort any compound-growth framing into something misleadingly smooth.
