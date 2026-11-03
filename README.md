# Customer Churn and Segmentation Analysis

## Project Overview

This project analyzes customer churn in a credit card portfolio using **PostgreSQL**. The objective is to identify customer segments with high and low churn rates, understand factors associated with customer attrition, and generate insights that can help improve customer retention.

The analysis uses SQL queries to calculate churn metrics, segment customers, compare churn rates, and identify patterns across different customer groups.

## Business Objectives

- Calculate the overall customer churn rate.
- Identify high-risk and low-risk customer segments.
- Analyze the relationship between payment delays, customer complaints, financial stress, and churn.
- Compare churn rates across different customer segments.
- Generate insights to support customer retention strategies.

## Tools and Technologies

- **Database:** PostgreSQL
- **Language:** SQL
- **Analysis:** Customer Segmentation and Churn Analysis

## Dataset Overview

The dataset contains **100,000 customer records** with information related to customer demographics, credit card usage, payment behavior, complaints, and financial stress.

The dataset is not included in this repository. Please download it separately from the source provided for this project.

## Key Performance Indicators (KPIs)

| Metric | Result |
|---|---:|
| Total Customers | 100,000 |
| Churned Customers | 19,458 |
| Overall Churn Rate | 19.46% |
| High-Churn Threshold | 29.19% or above |
| Low-Churn Threshold | 11.67% or below |
| Minimum Segment Size | 5,000 |

## Key Insights

- Customers with **2 or more payment delays** showed a churn rate of **55.8%**.
- Customers with support satisfaction scores below **2.5** had a churn rate of **45.3%**.
- Customers with financial stress scores between **40 and 59** showed a churn rate of **36.7%**.
- Customers with no payment delays, no complaints, and 2 or more products had a significantly lower churn rate of **4.7%**.
- Card variant, customer tenure, credit limit, age, and income did not materially distinguish churn in this dataset.

## SQL Concepts Used

- SELECT, WHERE, GROUP BY, ORDER BY
- Aggregate functions
- CASE statements
- Common Table Expressions (CTEs)
- Subqueries
- Customer segmentation
- Churn rate calculations
- Comparative analysis

## Project Structure

```text
customer-churn-segmentation-analysis/
│
├── README.md
├── .gitignore
│
├── sql/
│   └── Churn_segmentation_analysis.sql
│
└── reports/
    └── churn_segmentation_report.pdf
```

## How to Run the Project

1. Install PostgreSQL and open pgAdmin or your preferred SQL client.
2. Download the dataset from the original source.
3. Create the required database and import the dataset.
4. Open the SQL file from the `sql/` folder.
5. Execute the queries to perform the churn and segmentation analysis.
6. Refer to the PDF report in the `reports/` folder for the findings.

## Business Recommendations

Based on the analysis:

- Prioritize customers with repeated payment delays for retention campaigns.
- Improve customer support experiences for customers reporting low satisfaction.
- Provide targeted assistance to customers experiencing financial stress.
- Encourage healthy product engagement among customers with low churn risk.

## Limitations

- The dataset does not include explicit customer account closure reasons.
- Monthly transactions and app logins are used as activity indicators.
- The analysis identifies associations, not causal relationships.
- Customer profitability data is not available.

## Conclusion

This project demonstrates how PostgreSQL can be used to analyze customer churn, identify high-risk customer segments, and generate actionable business insights. The findings can help businesses better understand customer behavior and develop targeted retention strategies.

---

**Author:** Supriya  
**Domain:** Data Analytics  
**Technology:** PostgreSQL | SQL
