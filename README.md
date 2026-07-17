# Dubai Real Estate Market Intelligence Platform 🏙️

Understanding property market growth, investment opportunities, and area performance using Dubai Land Department transaction data.

## Business Problem
Acting as an analyst for a real estate investment company, this project answers:
- Which Dubai areas are growing?
- Where should investors focus?
- How is the market changing over time?

## Data Source
Dubai Land Department transaction records (Sales, Mortgages, Gifts), sourced via [Dubai Pulse](https://www.dubaipulse.gov.ae).

## Project Structure
├── data/                  # Raw and cleaned datasets (excluded from repo)
├── docs/                  # Documentation, cleaning summary
├── python_notebooks/      # Data cleaning notebook (pandas)
├── sql_analysis/          # PostgreSQL schema and analysis queries
├── images/                # Charts and visualizations
├── powerbi/               # Power BI dashboard files

## Data Cleaning
Raw data (1,748,953 rows × 47 columns) was cleaned to 1,748,554 rows × 33 columns:
- Removed Arabic-language duplicate columns
- Parsed and validated transaction dates
- Handled nulls (dropped near-empty columns, filled categorical fields)
- Removed invalid/non-market transactions
- Capped extreme outliers in transaction value for analysis use

Full details in `docs/cleaning_summary.md`.

## Analysis
1. **Market Growth** — YoY transaction volume, total AED value, CAGR
2. **Area Ranking Model** — weighted scoring system (growth, price growth, volume, liquidity)
3. **Property Segment Analysis** — Apartments vs Villas, luxury vs affordable, by area

## Tools
- Python (pandas) — data cleaning
- PostgreSQL — analysis queries
- Power BI — dashboard/visualization

## Status
🚧 In progress
