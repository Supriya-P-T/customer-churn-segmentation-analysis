-- Meridian Bank | Credit Card Churn Segmentation | SQL (PostgreSQL version)
-- Table loaded from credit_card_customer_churn_dataset.csv as: cards
-- (create the table with the DDL in the setup notes, then load the CSV with \copy or pgAdmin Import)
-- churned = 1 means the customer closed the card.
-- Deliberately NOT used as segment attributes (model outputs / composites,
-- would be circular): churn_probability, churn_risk_score,
-- engagement_score, customer_value_score.
CREATE TABLE cards (
  customer_id TEXT, age INTEGER, gender TEXT, marital_status TEXT,
  education_level TEXT, employment_status TEXT, income NUMERIC, city TEXT,
  credit_score INTEGER, account_age_months INTEGER, card_type TEXT,
  credit_limit NUMERIC, annual_fee INTEGER, interest_rate NUMERIC,
  num_products INTEGER, has_loan INTEGER, has_savings_account INTEGER,
  monthly_spending NUMERIC, avg_transaction_amount NUMERIC,
  monthly_transactions INTEGER, online_transactions INTEGER,
  international_transactions INTEGER, cash_withdrawals INTEGER,
  utilization_ratio NUMERIC, payment_delay_count INTEGER,
  late_payment_amount NUMERIC, app_logins_monthly INTEGER,
  website_visits_monthly INTEGER, customer_service_calls INTEGER,
  complaints_count INTEGER, support_satisfaction NUMERIC,
  reward_points INTEGER, offers_received INTEGER, offers_redeemed INTEGER,
  financial_stress_score NUMERIC, engagement_score NUMERIC,
  customer_value_score NUMERIC, churn_risk_score NUMERIC,
  churn_probability NUMERIC, churned INTEGER
);
-- Q1. Baseline: total customers, churners, portfolio churn rate.
SELECT COUNT(*) AS customers, SUM(churned) AS churned FROM cards;

-- Q2. High / low churn thresholds (1.5x and 0.6x portfolio rate) and 5% size floor.
SELECT ROUND(100.0 * AVG(churned), 2)        AS baseline_pct,
       ROUND(100.0 * AVG(churned) * 1.5, 2)  AS high_churn_threshold_pct,
       ROUND(100.0 * AVG(churned) * 0.6, 2)  AS low_churn_threshold_pct,
       COUNT(*) * 0.05                        AS min_segment_size
FROM cards;
 
-- Q3. Bucketing view: every continuous attribute gets a band (rules in the summary doc).
CREATE OR REPLACE VIEW c AS
SELECT customer_id, churned,
  CASE WHEN age < 25 THEN '1: <25'
       WHEN age < 35 THEN '2: 25-34'
       WHEN age < 45 THEN '3: 35-44'
       WHEN age < 55 THEN '4: 45-54'
       WHEN age < 65 THEN '5: 55-64'
       ELSE                '6: 65+' END                         AS age_band,
  CASE WHEN account_age_months < 7  THEN '1: 0-6m'
       WHEN account_age_months < 13 THEN '2: 7-12m'
       WHEN account_age_months < 25 THEN '3: 13-24m'
       WHEN account_age_months < 49 THEN '4: 25-48m'
       WHEN account_age_months < 97 THEN '5: 49-96m'
       ELSE                              '6: 97m+' END          AS tenure_band,
  CASE WHEN credit_limit < 5000  THEN '1: <5k'
       WHEN credit_limit < 10000 THEN '2: 5-10k'
       WHEN credit_limit < 20000 THEN '3: 10-20k'
       WHEN credit_limit < 35000 THEN '4: 20-35k'
       ELSE                           '5: 35k+' END             AS limit_band,
  CASE WHEN utilization_ratio < 0.2 THEN '1: <20%'
       WHEN utilization_ratio < 0.4 THEN '2: 20-40%'
       WHEN utilization_ratio < 0.6 THEN '3: 40-60%'
       WHEN utilization_ratio < 0.8 THEN '4: 60-80%'
       ELSE                              '5: 80%+' END          AS util_band,
  -- no "months inactive" field exists: inactivity proxied by card usage and app logins
  CASE WHEN monthly_transactions < 11  THEN '1: 0-10 txns'
       WHEN monthly_transactions < 31  THEN '2: 11-30'
       WHEN monthly_transactions < 61  THEN '3: 31-60'
       WHEN monthly_transactions < 121 THEN '4: 61-120'
       ELSE                                 '5: 121+' END       AS txn_band,
  CASE WHEN app_logins_monthly < 8  THEN '1: <=7'
       WHEN app_logins_monthly < 11 THEN '2: 8-10'
       WHEN app_logins_monthly < 14 THEN '3: 11-13'
       WHEN app_logins_monthly < 17 THEN '4: 14-16'
       ELSE                              '5: 17+' END           AS login_band,
  CASE WHEN customer_service_calls = 0 THEN '1: 0 calls'
       WHEN customer_service_calls = 1 THEN '2: 1'
       WHEN customer_service_calls = 2 THEN '3: 2'
       WHEN customer_service_calls < 5 THEN '4: 3-4'
       ELSE                                 '5: 5+' END         AS contact_band,
  CASE WHEN complaints_count = 0 THEN '1: 0'
       WHEN complaints_count = 1 THEN '2: 1'
       WHEN complaints_count = 2 THEN '3: 2'
       ELSE                           '4: 3+' END               AS complaint_band,
  CASE WHEN payment_delay_count = 0 THEN '1: 0 delays'
       WHEN payment_delay_count = 1 THEN '2: 1 delay'
       ELSE                              '3: 2+ delays' END     AS paydelay_band,
  CASE WHEN support_satisfaction < 2.5 THEN '1: <2.5'
       WHEN support_satisfaction < 3.5 THEN '2: 2.5-3.4'
       WHEN support_satisfaction < 4.5 THEN '3: 3.5-4.4'
       ELSE                                 '4: 4.5+' END       AS satisfaction_band,
  CASE WHEN financial_stress_score < 10 THEN '1: <10'
       WHEN financial_stress_score < 20 THEN '2: 10-19'
       WHEN financial_stress_score < 30 THEN '3: 20-29'
       WHEN financial_stress_score < 40 THEN '4: 30-39'
       WHEN financial_stress_score < 60 THEN '5: 40-59'
       ELSE                                  '6: 60+' END       AS stress_band,
  CASE WHEN offers_redeemed = 0 THEN '1: 0'
       WHEN offers_redeemed = 1 THEN '2: 1'
       ELSE                          '3: 2+' END                AS redeemed_band,
  CAST(num_products AS TEXT)                                    AS products,
  card_type, gender, marital_status, education_level, employment_status,
  CASE WHEN income < 30000  THEN '1: <30k'
       WHEN income < 60000  THEN '2: 30-60k'
       WHEN income < 100000 THEN '3: 60-100k'
       ELSE                      '4: 100k+' END                 AS income_band,
  customer_service_calls, complaints_count, payment_delay_count, support_satisfaction,
  financial_stress_score, num_products, monthly_transactions, app_logins_monthly,
  utilization_ratio, credit_limit, account_age_months, age, monthly_spending, income
FROM cards;
 
-- Q4. Single-attribute analysis: churn rate, churn share, x-baseline and class for every band.
WITH base AS (SELECT COUNT(*) n, SUM(churned) ch, 1.0*SUM(churned)/COUNT(*) r FROM cards),
long_form AS (
  SELECT 'age' attr, age_band bucket, churned FROM c UNION ALL
  SELECT 'tenure',            tenure_band,       churned FROM c UNION ALL
  SELECT 'credit_limit',      limit_band,        churned FROM c UNION ALL
  SELECT 'utilisation',       util_band,         churned FROM c UNION ALL
  SELECT 'txns_per_month',    txn_band,          churned FROM c UNION ALL
  SELECT 'app_logins',        login_band,        churned FROM c UNION ALL
  SELECT 'service_calls',     contact_band,      churned FROM c UNION ALL
  SELECT 'complaints',        complaint_band,    churned FROM c UNION ALL
  SELECT 'payment_delays',    paydelay_band,     churned FROM c UNION ALL
  SELECT 'satisfaction',      satisfaction_band, churned FROM c UNION ALL
  SELECT 'financial_stress',  stress_band,       churned FROM c UNION ALL
  SELECT 'offers_redeemed',   redeemed_band,     churned FROM c UNION ALL
  SELECT 'num_products',      products,          churned FROM c UNION ALL
  SELECT 'card_type',         card_type,         churned FROM c UNION ALL
  SELECT 'income',            income_band,       churned FROM c UNION ALL
  SELECT 'gender',            gender,            churned FROM c UNION ALL
  SELECT 'marital_status',    marital_status,    churned FROM c UNION ALL
  SELECT 'education',         education_level,   churned FROM c UNION ALL
  SELECT 'employment',        employment_status, churned FROM c)
SELECT attr, bucket,
       COUNT(*)                                         AS customers,
       ROUND(100.0*COUNT(*)/b.n, 1)                     AS pct_of_base,
       SUM(churned)                                     AS churners,
       ROUND(100.0*AVG(churned), 1)                     AS churn_rate_pct,
       ROUND(100.0*SUM(churned)/b.ch, 1)                AS churn_share_pct,
       ROUND(AVG(churned)/b.r, 2)                       AS x_baseline,
       CASE WHEN AVG(churned) >= 1.5*b.r THEN 'HIGH'
            WHEN AVG(churned) <= 0.6*b.r THEN 'LOW'
            ELSE 'average' END                          AS class,
       CASE WHEN COUNT(*) >= 0.05*b.n THEN 'ok' ELSE 'too small' END AS size_check
FROM long_form, base b
GROUP BY attr, bucket, b.n, b.ch, b.r
ORDER BY attr, bucket;
 
-- Q5. Shortlist: single-attribute buckets that are HIGH or LOW and >= 5% of base.
WITH base AS (SELECT COUNT(*) n, SUM(churned) ch, 1.0*SUM(churned)/COUNT(*) r FROM cards),
long_form AS (
  SELECT 'service_calls' attr, contact_band bucket, churned FROM c UNION ALL
  SELECT 'complaints', complaint_band, churned FROM c UNION ALL
  SELECT 'payment_delays', paydelay_band, churned FROM c UNION ALL
  SELECT 'satisfaction', satisfaction_band, churned FROM c UNION ALL
  SELECT 'financial_stress', stress_band, churned FROM c UNION ALL
  SELECT 'num_products', products, churned FROM c UNION ALL
  SELECT 'utilisation', util_band, churned FROM c UNION ALL
  SELECT 'app_logins', login_band, churned FROM c)
SELECT CASE WHEN AVG(churned) >= 1.5*b.r THEN 'HIGH' ELSE 'LOW' END AS class,
       attr, bucket, COUNT(*) customers,
       ROUND(100.0*AVG(churned),1) churn_rate_pct,
       ROUND(100.0*SUM(churned)/b.ch,1) churn_share_pct,
       ROUND(AVG(churned)/b.r,2) x_baseline
FROM long_form, base b
GROUP BY attr, bucket, b.n, b.ch, b.r
HAVING COUNT(*) >= 0.05*b.n
   AND (AVG(churned) >= 1.5*b.r OR AVG(churned) <= 0.6*b.r)
ORDER BY class, churn_rate_pct DESC;
 
-- Q6. The brief's four open questions, tested directly as combined segments.
WITH base AS (SELECT COUNT(*) n, SUM(churned) ch, 1.0*SUM(churned)/COUNT(*) r FROM cards),
seg AS (
  SELECT 'Q-a High limit (20k+) AND low card use (<=30 txns)' s, churned FROM c WHERE credit_limit>=20000 AND monthly_transactions<=30 UNION ALL
  SELECT 'Q-a High limit (20k+) AND low app logins (<=10)',     churned FROM c WHERE credit_limit>=20000 AND app_logins_monthly<=10 UNION ALL
  SELECT 'Q-b Fee-paying variant (Silver/Gold/Platinum)',       churned FROM c WHERE card_type<>'Standard' UNION ALL
  SELECT 'Q-b No-fee variant (Standard)',                       churned FROM c WHERE card_type='Standard' UNION ALL
  SELECT 'Q-c Contacts: 3+ service calls',                      churned FROM c WHERE customer_service_calls>=3 UNION ALL
  SELECT 'Q-c Silent: 0 service calls',                         churned FROM c WHERE customer_service_calls=0 UNION ALL
  SELECT 'Q-d Tenure <=12m',                                    churned FROM c WHERE account_age_months<13 UNION ALL
  SELECT 'Q-d Tenure 97m+',                                     churned FROM c WHERE account_age_months>=97 UNION ALL
  SELECT 'Q-d Fee variant AND tenure <=12m',                    churned FROM c WHERE card_type<>'Standard' AND account_age_months<13 UNION ALL
  SELECT 'Q-d Fee variant AND tenure 97m+',                     churned FROM c WHERE card_type<>'Standard' AND account_age_months>=97)
SELECT s AS segment, COUNT(*) customers, ROUND(100.0*COUNT(*)/b.n,1) pct_of_base,
       ROUND(100.0*AVG(churned),1) churn_rate_pct,
       ROUND(100.0*SUM(churned)/b.ch,1) churn_share_pct,
       ROUND(AVG(churned)/b.r,2) x_baseline
FROM seg, base b GROUP BY s, b.n, b.ch, b.r ORDER BY s;
 
-- Q7. Two-attribute combined segments (>=5% of base, HIGH or LOW), across the key drivers.
WITH base AS (SELECT COUNT(*) n, SUM(churned) ch, 1.0*SUM(churned)/COUNT(*) r FROM cards),
combo AS (
  SELECT 'products x satisfaction' pair, CONCAT(products,' prod | sat ',satisfaction_band) seg, churned FROM c UNION ALL
  SELECT 'products x stress',       CONCAT(products,' prod | stress ',stress_band), churned FROM c UNION ALL
  SELECT 'products x pay delays',   CONCAT(products,' prod | ',paydelay_band), churned FROM c UNION ALL
  SELECT 'products x complaints',   CONCAT(products,' prod | complaints ',complaint_band), churned FROM c UNION ALL
  SELECT 'products x contacts',     CONCAT(products,' prod | calls ',contact_band), churned FROM c UNION ALL
  SELECT 'pay delays x complaints', CONCAT(paydelay_band,' | complaints ',complaint_band), churned FROM c UNION ALL
  SELECT 'pay delays x contacts',   CONCAT(paydelay_band,' | calls ',contact_band), churned FROM c UNION ALL
  SELECT 'stress x complaints',     CONCAT('stress ',stress_band,' | complaints ',complaint_band), churned FROM c UNION ALL
  SELECT 'stress x satisfaction',   CONCAT('stress ',stress_band,' | sat ',satisfaction_band), churned FROM c UNION ALL
  SELECT 'satisfaction x utilisation',CONCAT('sat ',satisfaction_band,' | util ',util_band), churned FROM c UNION ALL
  SELECT 'stress x offers redeemed',CONCAT('stress ',stress_band,' | redeemed ',redeemed_band), churned FROM c)
SELECT pair, seg AS segment, COUNT(*) customers,
       ROUND(100.0*AVG(churned),1) churn_rate_pct,
       ROUND(100.0*SUM(churned)/b.ch,1) churn_share_pct,
       ROUND(AVG(churned)/b.r,2) x_baseline,
       CASE WHEN AVG(churned) >= 1.5*b.r THEN 'HIGH' ELSE 'LOW' END class
FROM combo, base b
GROUP BY pair, seg, b.n, b.ch, b.r
HAVING COUNT(*) >= 0.05*b.n
   AND (AVG(churned) >= 1.5*b.r OR AVG(churned) <= 0.6*b.r)
ORDER BY class, churn_rate_pct DESC
LIMIT 40;
 
-- Q8. Three-attribute combined segments (explicit, reproducible rules).
WITH base AS (SELECT COUNT(*) n, SUM(churned) ch, 1.0*SUM(churned)/COUNT(*) r FROM cards),
seg AS (
  SELECT 'H1 1 product + sat <2.5 + (any stress)' s, churned FROM c WHERE num_products=1 AND support_satisfaction<2.5 UNION ALL
  SELECT 'H2 1 product + stress>=40',               churned FROM c WHERE num_products=1 AND financial_stress_score>=40 UNION ALL
  SELECT 'H3 pay delays>=1 + 1 product',            churned FROM c WHERE payment_delay_count>=1 AND num_products=1 UNION ALL
  SELECT 'H4 pay delays>=1 + calls>=3',             churned FROM c WHERE payment_delay_count>=1 AND customer_service_calls>=3 UNION ALL
  SELECT 'H5 sat<3.5 + stress>=30 + 1 product',     churned FROM c WHERE support_satisfaction<3.5 AND financial_stress_score>=30 AND num_products=1 UNION ALL
  SELECT 'H6 calls>=3 + complaints>=2',             churned FROM c WHERE customer_service_calls>=3 AND complaints_count>=2 UNION ALL
  SELECT 'L1 pay delays=0 + complaints=0 + 2+ products', churned FROM c WHERE payment_delay_count=0 AND complaints_count=0 AND num_products>=2 UNION ALL
  SELECT 'L2 stress<20 + 2+ products',              churned FROM c WHERE financial_stress_score<20 AND num_products>=2 UNION ALL
  SELECT 'L3 stress<20 + sat>=3.5',                 churned FROM c WHERE financial_stress_score<20 AND support_satisfaction>=3.5 UNION ALL
  SELECT 'L4 calls=0 + pay delays=0 + 2+ products + complaints=0', churned FROM c WHERE customer_service_calls=0 AND payment_delay_count=0 AND num_products>=2 AND complaints_count=0 UNION ALL
  SELECT 'L5 stress<30 + 3+ products',              churned FROM c WHERE financial_stress_score<30 AND num_products>=3)
SELECT s AS segment, COUNT(*) customers, ROUND(100.0*COUNT(*)/b.n,1) pct_of_base,
       SUM(churned) churners,
       ROUND(100.0*AVG(churned),1) churn_rate_pct,
       ROUND(100.0*SUM(churned)/b.ch,1) churn_share_pct,
       ROUND(AVG(churned)/b.r,2) x_baseline
FROM seg, base b GROUP BY s, b.n, b.ch, b.r ORDER BY s;
 
-- Q9. High (H3) vs Low (L1) profile on every attribute; flag relative diff >= 20%.
--     HIGH = payment_delay_count>=1 AND num_products=1
--     LOW  = payment_delay_count=0  AND complaints_count=0 AND num_products>=2
WITH g AS (
  SELECT CASE WHEN payment_delay_count>=1 AND num_products=1 THEN 'HIGH'
              WHEN payment_delay_count=0 AND complaints_count=0 AND num_products>=2 THEN 'LOW' END AS grp, cards.*
  FROM cards),
p AS (
  SELECT grp, COUNT(*) n,
    AVG(age) age, AVG(account_age_months) tenure_m, AVG(credit_limit) credit_limit, AVG(income) income,
    AVG(credit_score) credit_score, AVG(utilization_ratio) utilisation, AVG(monthly_spending) monthly_spend,
    AVG(monthly_transactions) monthly_txns, AVG(app_logins_monthly) app_logins, AVG(website_visits_monthly) web_visits,
    AVG(customer_service_calls) service_calls, AVG(complaints_count) complaints,
    AVG(payment_delay_count) payment_delays, AVG(late_payment_amount) late_pay_amt,
    AVG(support_satisfaction) satisfaction, AVG(financial_stress_score) fin_stress,
    AVG(num_products) products, AVG(annual_fee) annual_fee, AVG(interest_rate) interest_rate,
    AVG(offers_received) offers_recd, AVG(offers_redeemed) offers_redeemed,
    AVG(has_loan) has_loan, AVG(has_savings_account) has_savings, AVG(reward_points) reward_pts,
    AVG(cash_withdrawals) cash_wd, AVG(international_transactions) intl_txns,
    AVG(churned) churn_rate
  FROM g WHERE grp IS NOT NULL GROUP BY grp)
SELECT m.metric,
       ROUND(h.v::numeric,3) AS high_seg, ROUND(l.v::numeric,3) AS low_seg,
       ROUND((100.0*ABS(h.v-l.v)/NULLIF(LEAST(ABS(h.v),ABS(l.v)),0))::numeric,1) AS rel_diff_pct,
       CASE WHEN LEAST(ABS(h.v),ABS(l.v)) = 0 AND GREATEST(ABS(h.v),ABS(l.v)) > 0 THEN 'MATERIAL (one side is 0)'
            WHEN ABS(h.v-l.v) >= 0.2*LEAST(ABS(h.v),ABS(l.v)) THEN 'MATERIAL'
            ELSE 'observation' END AS flag
FROM (SELECT 'n' metric UNION ALL SELECT 'age' UNION ALL SELECT 'tenure_m' UNION ALL SELECT 'credit_limit' UNION ALL SELECT 'income' UNION ALL
      SELECT 'credit_score' UNION ALL SELECT 'utilisation' UNION ALL SELECT 'monthly_spend' UNION ALL SELECT 'monthly_txns' UNION ALL
      SELECT 'app_logins' UNION ALL SELECT 'web_visits' UNION ALL SELECT 'service_calls' UNION ALL SELECT 'complaints' UNION ALL
      SELECT 'payment_delays' UNION ALL SELECT 'late_pay_amt' UNION ALL SELECT 'satisfaction' UNION ALL SELECT 'fin_stress' UNION ALL
      SELECT 'products' UNION ALL SELECT 'annual_fee' UNION ALL SELECT 'interest_rate' UNION ALL SELECT 'offers_recd' UNION ALL
      SELECT 'offers_redeemed' UNION ALL SELECT 'has_loan' UNION ALL SELECT 'has_savings' UNION ALL SELECT 'reward_pts' UNION ALL
      SELECT 'cash_wd' UNION ALL SELECT 'intl_txns' UNION ALL SELECT 'churn_rate') m
JOIN (SELECT 'n' metric, n v FROM p WHERE grp='HIGH' UNION ALL SELECT 'age',age FROM p WHERE grp='HIGH' UNION ALL SELECT 'tenure_m',tenure_m FROM p WHERE grp='HIGH' UNION ALL SELECT 'credit_limit',credit_limit FROM p WHERE grp='HIGH' UNION ALL SELECT 'income',income FROM p WHERE grp='HIGH' UNION ALL SELECT 'credit_score',credit_score FROM p WHERE grp='HIGH' UNION ALL SELECT 'utilisation',utilisation FROM p WHERE grp='HIGH' UNION ALL SELECT 'monthly_spend',monthly_spend FROM p WHERE grp='HIGH' UNION ALL SELECT 'monthly_txns',monthly_txns FROM p WHERE grp='HIGH' UNION ALL SELECT 'app_logins',app_logins FROM p WHERE grp='HIGH' UNION ALL SELECT 'web_visits',web_visits FROM p WHERE grp='HIGH' UNION ALL SELECT 'service_calls',service_calls FROM p WHERE grp='HIGH' UNION ALL SELECT 'complaints',complaints FROM p WHERE grp='HIGH' UNION ALL SELECT 'payment_delays',payment_delays FROM p WHERE grp='HIGH' UNION ALL SELECT 'late_pay_amt',late_pay_amt FROM p WHERE grp='HIGH' UNION ALL SELECT 'satisfaction',satisfaction FROM p WHERE grp='HIGH' UNION ALL SELECT 'fin_stress',fin_stress FROM p WHERE grp='HIGH' UNION ALL SELECT 'products',products FROM p WHERE grp='HIGH' UNION ALL SELECT 'annual_fee',annual_fee FROM p WHERE grp='HIGH' UNION ALL SELECT 'interest_rate',interest_rate FROM p WHERE grp='HIGH' UNION ALL SELECT 'offers_recd',offers_recd FROM p WHERE grp='HIGH' UNION ALL SELECT 'offers_redeemed',offers_redeemed FROM p WHERE grp='HIGH' UNION ALL SELECT 'has_loan',has_loan FROM p WHERE grp='HIGH' UNION ALL SELECT 'has_savings',has_savings FROM p WHERE grp='HIGH' UNION ALL SELECT 'reward_pts',reward_pts FROM p WHERE grp='HIGH' UNION ALL SELECT 'cash_wd',cash_wd FROM p WHERE grp='HIGH' UNION ALL SELECT 'intl_txns',intl_txns FROM p WHERE grp='HIGH' UNION ALL SELECT 'churn_rate',churn_rate FROM p WHERE grp='HIGH') h ON h.metric=m.metric
JOIN (SELECT 'n' metric, n v FROM p WHERE grp='LOW' UNION ALL SELECT 'age',age FROM p WHERE grp='LOW' UNION ALL SELECT 'tenure_m',tenure_m FROM p WHERE grp='LOW' UNION ALL SELECT 'credit_limit',credit_limit FROM p WHERE grp='LOW' UNION ALL SELECT 'income',income FROM p WHERE grp='LOW' UNION ALL SELECT 'credit_score',credit_score FROM p WHERE grp='LOW' UNION ALL SELECT 'utilisation',utilisation FROM p WHERE grp='LOW' UNION ALL SELECT 'monthly_spend',monthly_spend FROM p WHERE grp='LOW' UNION ALL SELECT 'monthly_txns',monthly_txns FROM p WHERE grp='LOW' UNION ALL SELECT 'app_logins',app_logins FROM p WHERE grp='LOW' UNION ALL SELECT 'web_visits',web_visits FROM p WHERE grp='LOW' UNION ALL SELECT 'service_calls',service_calls FROM p WHERE grp='LOW' UNION ALL SELECT 'complaints',complaints FROM p WHERE grp='LOW' UNION ALL SELECT 'payment_delays',payment_delays FROM p WHERE grp='LOW' UNION ALL SELECT 'late_pay_amt',late_pay_amt FROM p WHERE grp='LOW' UNION ALL SELECT 'satisfaction',satisfaction FROM p WHERE grp='LOW' UNION ALL SELECT 'fin_stress',fin_stress FROM p WHERE grp='LOW' UNION ALL SELECT 'products',products FROM p WHERE grp='LOW' UNION ALL SELECT 'annual_fee',annual_fee FROM p WHERE grp='LOW' UNION ALL SELECT 'interest_rate',interest_rate FROM p WHERE grp='LOW' UNION ALL SELECT 'offers_recd',offers_recd FROM p WHERE grp='LOW' UNION ALL SELECT 'offers_redeemed',offers_redeemed FROM p WHERE grp='LOW' UNION ALL SELECT 'has_loan',has_loan FROM p WHERE grp='LOW' UNION ALL SELECT 'has_savings',has_savings FROM p WHERE grp='LOW' UNION ALL SELECT 'reward_pts',reward_pts FROM p WHERE grp='LOW' UNION ALL SELECT 'cash_wd',cash_wd FROM p WHERE grp='LOW' UNION ALL SELECT 'intl_txns',intl_txns FROM p WHERE grp='LOW' UNION ALL SELECT 'churn_rate',churn_rate FROM p WHERE grp='LOW') l ON l.metric=m.metric;
 
-- Q10. DEEP DIVE 1 (HIGH): payment_delay>=1 AND 1 product -> split by satisfaction -> contacts -> utilisation.
--      Level 0 = segment, Level 1 = satisfaction band, Level 2 = + call band, Level 3 = + utilisation band.
WITH base AS (SELECT COUNT(*) n, SUM(churned) ch FROM cards),
s AS (SELECT *, CASE WHEN support_satisfaction<2.5 THEN 'sat <2.5'
                     WHEN support_satisfaction<3.5 THEN 'sat 2.5-3.4' ELSE 'sat 3.5+' END sat,
                 CASE WHEN customer_service_calls>=3 THEN 'calls 3+' ELSE 'calls 0-2' END calls,
                 CASE WHEN utilization_ratio>=0.4 THEN 'util 40%+' ELSE 'util <40%' END util
      FROM cards WHERE payment_delay_count>=1 AND num_products=1)
SELECT 0 lvl, 'ALL: pay delays>=1 + 1 product' path, COUNT(*) n, SUM(churned) churners, ROUND(100.0*AVG(churned),1) rate, ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) share FROM s
UNION ALL SELECT 1, sat, COUNT(*), SUM(churned), ROUND(100.0*AVG(churned),1), ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) FROM s GROUP BY sat
UNION ALL SELECT 2, CONCAT(sat,' > ',calls), COUNT(*), SUM(churned), ROUND(100.0*AVG(churned),1), ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) FROM s GROUP BY sat, calls
UNION ALL SELECT 3, CONCAT(sat,' > ',calls,' > ',util), COUNT(*), SUM(churned), ROUND(100.0*AVG(churned),1), ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) FROM s GROUP BY sat, calls, util
ORDER BY 1, 2;
 
-- Q11. DEEP DIVE 2 (LOW): payment_delay=0 AND complaints=0 AND 2+ products -> products -> stress -> satisfaction.
WITH base AS (SELECT COUNT(*) n, SUM(churned) ch FROM cards),
s AS (SELECT *, CASE WHEN num_products>=3 THEN '3-4 products' ELSE '2 products' END prod,
                 CASE WHEN financial_stress_score<20 THEN 'stress <20'
                      WHEN financial_stress_score<30 THEN 'stress 20-29' ELSE 'stress 30+' END stress,
                 CASE WHEN support_satisfaction<3.5 THEN 'sat <3.5' ELSE 'sat 3.5+' END sat
      FROM cards WHERE payment_delay_count=0 AND complaints_count=0 AND num_products>=2)
SELECT 0 lvl, 'ALL: no delays + no complaints + 2+ products' path, COUNT(*) n, SUM(churned) churners, ROUND(100.0*AVG(churned),1) rate, ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) share FROM s
UNION ALL SELECT 1, prod, COUNT(*), SUM(churned), ROUND(100.0*AVG(churned),1), ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) FROM s GROUP BY prod
UNION ALL SELECT 2, CONCAT(prod,' > ',stress), COUNT(*), SUM(churned), ROUND(100.0*AVG(churned),1), ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) FROM s GROUP BY prod, stress
UNION ALL SELECT 3, CONCAT(prod,' > ',stress,' > ',sat), COUNT(*), SUM(churned), ROUND(100.0*AVG(churned),1), ROUND(100.0*SUM(churned)/(SELECT ch FROM base),1) FROM s GROUP BY prod, stress, sat
ORDER BY 1, 2;