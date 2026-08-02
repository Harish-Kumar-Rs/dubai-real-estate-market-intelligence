# Dubai Real Estate Market Intelligence Platform

A Business Analytics portfolio project analyzing **1.75 million+ Dubai property transactions** from the Dubai Land Department to uncover investor-focused insights using SQL, Python, statistical testing, and interactive Power BI dashboards.

> Rather than stopping at descriptive KPIs, this project validates every analytical claim using appropriate statistical methods and reports both significant and non-significant findings.

---

## Dashboard Preview

> powerbi/dashboard_screenshots/Screenshot 2026-08-02 174515.png
>powerbi/dashboard_screenshots/Screenshot 2026-08-02 174556.png
>powerbi/dashboard_screenshots/Screenshot 2026-08-02 174617.png
>powerbi/dashboard_screenshots/Screenshot 2026-08-02 174641.png

---

## Project Overview

This project explores Dubai's residential property market between **1998 and 2025**, focusing exclusively on **sales transactions** to identify meaningful market trends, investment patterns, and area characteristics.

The dashboard combines SQL data engineering, Python-based statistical analysis, and Power BI visualization to answer business questions such as:

* Which areas have experienced the strongest long-term growth?
* Does proximity to malls or metro stations influence property appreciation?
* Do different property types exhibit significantly different growth?
* Can Dubai communities be grouped into meaningful investment profiles?

---

## Key Features

### Executive Dashboard

* Historical market KPIs
* Dynamic Year-over-Year analysis
* Market trend visualization
* Property type distribution

### Landmark Correlation Analysis

* Distance analysis to malls and metro stations
* Pearson correlation testing
* Growth comparison by property type

### Statistical Property Type Analysis

* Shapiro-Wilk normality testing
* Levene's variance testing
* Kruskal-Wallis hypothesis testing
* Investor profile comparison

### Investment Segmentation

* K-Means clustering
* Area classification into four investor profiles
* Geographic cluster visualization
* Comparative cluster scoring

---

## Dataset

| Item            | Details                      |
| --------------- | ----------------------------- |
| Source          | Dubai Land Department        |
| Records         | 1,748,554 Sales Transactions |
| Analysis Period | 1998–2025                    |
| Areas Covered   | 243
| Database        | PostgreSQL                   |

---

## Technology Stack

| Category        | Tools                                       |
| --------------- | ----------------------------------------------- |
| Database        | PostgreSQL                                  |
| Analytics       | Python (pandas, scipy, scikit-learn, geopy) |
| Visualization   | Power BI                                    |
| Query Language  | SQL                                         |
| Data Processing | Power Query, DAX                            |

---

## Key Findings

* Landmark proximity showed **no statistically significant relationship** with long-term property growth.
* Growth rates were **not significantly different** across Units, Villas, and Land after applying appropriate statistical testing.
* Four distinct investment profiles were identified using **K-Means clustering**, separating premium growth markets from declining and high-volatility areas.
* The project prioritizes statistical validity by testing assumptions before selecting analytical methods and reporting null findings rather than forcing positive conclusions.

---

## Repository Structure

├── powerbi/
│   └── Realestate_Dashboard.pbix
├── python_notebooks/
│   └── Corelattion_Analysis.ipynb
├── sql_analysis/
│   └── Analysis/
│       └── views_1.sql
├── docs/
│   └── Methodology.md
├── .gitattributes
├── .gitignore
└── README.md
```

---

## Design Philosophy

This project emphasizes **analytical integrity over visual polish**.

Every statistical conclusion is supported by appropriate testing, assumptions are validated before analysis, and negative or null findings are presented transparently rather than omitted.

---

## Future Enhancements

* Area Investment Score (0–100)
* Additional predictive modelling
* Enhanced investor recommendation framework
* Dashboard UX improvements

---

## Documentation

For readers interested in the complete analytical methodology  including statistical assumptions, hypothesis testing, feature engineering, clustering methodology, data validation, limitations, and development decisions see:

**📄 dubai-real-estate-market-intelligence
/docs**

---

## Author

**Harish Kumar**

Business Analytics | Data Analytics | SQL | Python | Power BI

LinkedIn:(https://www.linkedin.com/in/harish-kumar-analyst/)

---

**If you found this project interesting, consider giving it a ⭐.**
