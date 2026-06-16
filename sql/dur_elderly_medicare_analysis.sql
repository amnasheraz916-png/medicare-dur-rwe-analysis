-- -- ==========================================================
-- PROJECT:
-- Drug Utilization Review (DUR) in Elderly Patients
-- Medicare Part D Real-World Evidence (RWE) Analysis
--
-- Dataset:
-- CMS Medicare Part D Prescriber Public Use File
--
-- Objective:
-- Evaluate high-risk medication use among elderly
-- beneficiaries (≥65 years) using Beers Criteria
-- and STOPP/START-informed prescribing principles.
--
-- Author: Amna Sheraz
-- ==========================================================
---
-- ==========================================================
-- STEP 1: Create Elderly Drug Utilization Table
-- ==========================================================

CREATE TABLE elderly_drug_use AS
SELECT
    Prscrbr_NPI AS provider_id,
    Prscrbr_Type AS provider_specialty,
    LOWER(TRIM(Gnrc_Name)) AS generic_name,

    CAST(GE65_Tot_Clms AS INTEGER)
        AS elderly_claims,

    CAST(GE65_Tot_Drug_Cst AS REAL)
        AS elderly_drug_cost,

    CAST(GE65_Tot_Benes AS INTEGER)
        AS elderly_beneficiaries

FROM cms_partd_raw

WHERE
    Gnrc_Name IS NOT NULL
    AND GE65_Tot_Clms IS NOT NULL
    AND CAST(GE65_Tot_Clms AS INTEGER) > 0;

---

-- ==========================================================
-- STEP 2: Extract High-Risk Elderly Medications
-- ==========================================================

CREATE TABLE elderly_highrisk_subset AS

SELECT
    e.provider_id,
    e.provider_specialty,
    e.generic_name,
    e.elderly_claims,
    e.elderly_drug_cost,
    e.elderly_beneficiaries

FROM elderly_drug_use e

INNER JOIN drug_risk_reference_final d
ON e.generic_name =
LOWER(TRIM(d.generic_name));

----
-- ==========================================================
-- STEP 3: Create DUR Analysis Table
-- ==========================================================

CREATE TABLE elderly_dur_analysis AS

SELECT
    e.provider_id,
    e.provider_specialty,
    e.generic_name,
    e.elderly_claims,
    e.elderly_drug_cost,
    e.elderly_beneficiaries,

    d.drug_class,
    d.risk_level,
    d.high_risk_reason,
    d.likely_outcome,
    d.deprescribing_recommendation,
    d.primary_risk_category,
    d.secondary_risk_category

FROM elderly_highrisk_subset e

LEFT JOIN drug_risk_reference_final d
ON e.generic_name =
LOWER(TRIM(d.generic_name));
----
-- ==========================================================
-- RESULT 1: High-Risk Medication Burden
-- ==========================================================

-- Purpose:
-- Quantify prescribing burden of high-risk medications
-- among elderly Medicare beneficiaries.

SELECT
    risk_level,

    COUNT(DISTINCT generic_name)
        AS number_of_drugs,

    SUM(elderly_claims)
        AS total_claims,

    ROUND(SUM(elderly_drug_cost),2)
        AS total_cost,

    SUM(elderly_beneficiaries)
        AS elderly_patients

FROM elderly_dur_analysis

GROUP BY risk_level
ORDER BY total_claims DESC;
----
-- ==========================================================
-- RESULT 1 INTERPRETATION
-- ==========================================================

-- Findings:
-- Moderate-high risk drugs accounted for the highest
-- prescribing volume and healthcare spending.

-- Interpretation:
-- These medications may contribute substantially to
-- preventable adverse drug events in elderly patients
-- and represent deprescribing opportunities.
----
-- ==========================================================
-- RESULT 2: Drug Class Burden Analysis
-- ==========================================================

-- Purpose:
-- Identify high-risk medication classes contributing
-- most to elderly prescribing burden.

SELECT
    drug_class,

    COUNT(DISTINCT generic_name)
        AS number_of_drugs,

    SUM(elderly_claims)
        AS total_claims,

    ROUND(SUM(elderly_drug_cost),2)
        AS total_cost,

    SUM(elderly_beneficiaries)
        AS total_patients

FROM elderly_dur_analysis

GROUP BY drug_class

ORDER BY total_claims DESC;
----
-- ==========================================================
-- RESULT 2 INTERPRETATION
-- ==========================================================

-- Key Findings:
-- Opioid analgesics represented the largest prescribing
-- burden among high-risk medications.

-- DOAC anticoagulants generated the highest healthcare expenditure
-- despite lower prescribing volume, reflecting high medication costs.
-- Benzodiazepines and sedative agents remained highly
-- utilized despite known risks of falls, cognitive
-- impairment, and dependency.

-- Clinical Interpretation:
-- Drug classes with high utilization and spending may
-- represent priority targets for deprescribing programs
-- and medication review interventions in elderly patients.
----
-- ==========================================================
-- RESULT 3: TOP HIGH-RISK DRUGS
-- ==========================================================

-- Purpose:
-- Identify the most frequently prescribed high-risk
-- medications among elderly Medicare beneficiaries.

SELECT
    generic_name,
    drug_class,
    risk_level,

    SUM(elderly_claims)
        AS total_claims,

    ROUND(SUM(elderly_drug_cost),2)
        AS total_cost,

    SUM(elderly_beneficiaries)
        AS total_patients

FROM elderly_dur_analysis

GROUP BY
    generic_name,
    drug_class,
    risk_level

ORDER BY total_claims DESC
LIMIT 20;
----
-- ==========================================================
-- RESULT 3 INTERPRETATION
-- ==========================================================

-- Key Findings:
-- Gabapentin represented the highest prescribing burden
-- among high-risk medications with 21.5 million claims,
-- indicating substantial utilization of neuropathic pain
-- agents despite fall and CNS depression concerns.

-- Apixaban generated the highest healthcare expenditure
-- (>11.5 billion USD), highlighting anticoagulants as a
-- major pharmacoeconomic burden in elderly patients.

-- Opioid analgesics, including hydrocodone/acetaminophen,
-- tramadol, and oxycodone-containing products, accounted
-- for a substantial prescribing burden, suggesting
-- opportunities for opioid stewardship and deprescribing.

-- Benzodiazepines (alprazolam, clonazepam, lorazepam)
-- and sedative hypnotics (zolpidem) remained frequently
-- prescribed despite known risks of falls, cognitive
-- impairment, sedation, and dependency in elderly adults.

-- NSAIDs such as meloxicam, diclofenac, and celecoxib
-- demonstrated continued high utilization despite risks
-- of gastrointestinal bleeding, cardiovascular events,
-- and renal impairment.

-- Clinical Interpretation:
-- Frequently prescribed high-risk medications represent
-- priority targets for pharmacist-led medication review,
-- deprescribing interventions, and prevention of
-- avoidable adverse drug events in elderly patients.
----
-- ==========================================================
-- RESULT 4: Cost Burden of High-Risk Medications
-- ==========================================================

/*
Purpose:
Evaluate financial burden associated with
high-risk medications in elderly patients.

Metric:
Cost-per-claim =
Total elderly drug cost / Total elderly claims

Clinical Relevance:
Identifies medications associated with
high healthcare expenditure and potential
targets for medication review, deprescribing,
or formulary optimization.
*/

SELECT
    generic_name,
    drug_class,

    ROUND(SUM(elderly_drug_cost),2)
        AS total_cost,

    SUM(elderly_claims)
        AS total_claims,

    ROUND(
        SUM(elderly_drug_cost) * 1.0
        / SUM(elderly_claims),
    2)
        AS cost_per_claim

FROM elderly_dur_analysis

GROUP BY
    generic_name,
    drug_class

ORDER BY total_cost DESC
LIMIT 20;

-- ==========================================================
-- RESULT 4 INTERPRETATION
-- ==========================================================

/*
Key Findings:

1. Apixaban generated the highest total
cost burden ($11.57 billion) among elderly
patients, despite lower utilization than
gabapentin, reflecting high treatment cost
($829 per claim).

2. Rivaroxaban demonstrated similarly high
financial burden ($3.24 billion) with
very high cost-per-claim ($906.17).

3. Insulin therapies (glargine, degludec,
lispro, and aspart) represented substantial
economic burden, reflecting chronic disease
management costs among elderly populations.

4. Gabapentin showed extremely high
utilization (21.5 million claims) with
low cost-per-claim ($14.57), yet contributed
significantly to cumulative expenditure.

5. Opioid analgesics including hydrocodone/
acetaminophen and oxycodone products
demonstrated major utilization burden with
considerable spending implications.

6. Budesonide/glycopyrrolate/formoterol
showed disproportionately high cost-per-claim
($781.76), suggesting potential opportunity
for prescribing optimization or formulary
review.
*/
-- ==========================================================
-- RESULT 5A: Provider Specialty Risk Analysis
-- ==========================================================

/*
Purpose:
Identify provider specialties associated
with the highest burden of high-risk
medication prescribing in elderly patients.

Clinical Relevance:
Identifies specialties where prescribing
interventions, medication review, and
deprescribing programs may reduce
medication-related harm among older adults.
*/

SELECT
    provider_specialty,

    COUNT(DISTINCT generic_name)
        AS high_risk_drug_count,

    SUM(elderly_claims)
        AS total_highrisk_claims,

    ROUND(
        SUM(elderly_drug_cost),2
    ) AS total_cost,

    SUM(elderly_beneficiaries)
        AS elderly_patients

FROM elderly_dur_analysis

GROUP BY provider_specialty

ORDER BY total_highrisk_claims DESC
LIMIT 20;

-- ==========================================================
-- RESULT 5A INTERPRETATION
-- ==========================================================

/*
Key Findings:

1. Family Practice represented the highest
burden of high-risk prescribing among elderly
patients (31.9 million claims), likely due
to management of multiple chronic conditions
in primary care settings.

2. Internal Medicine demonstrated similarly
high prescribing burden (28.8 million claims)
with the highest cumulative expenditure
($3.98 billion), indicating major involvement
in elderly medication management.

3. Nurse Practitioners contributed
substantially to high-risk prescribing
(24.1 million claims), reflecting their
expanding role in chronic disease care.

4. Cardiology showed disproportionately
high medication cost burden ($3.72 billion)
despite lower claim volume, likely driven by
high-cost anticoagulants such as apixaban
and rivaroxaban.

5. Psychiatry demonstrated elevated
prescribing burden of high-risk medications,
potentially reflecting benzodiazepine and
antipsychotic utilization in elderly patients.

6. Pain-related specialties including
Pain Management, Interventional Pain
Management, and Physical Medicine &
Rehabilitation showed substantial exposure
to high-risk medications, likely driven
by opioid utilization.

7. Geriatric Medicine demonstrated lower
overall prescribing volume compared with
primary care specialties, but remained
highly involved in elderly medication
management.
*/
-- ==========================================================
-- RESULT 5B: Specialty × Risk Category Heatmap
-- ==========================================================
/*
Purpose:
Identify provider specialties associated
with major preventable medication risks
in elderly patients.

Clinical Relevance:
Highlights which medical specialties
may benefit most from targeted
medication safety interventions.
*/

SELECT
    provider_specialty,
    primary_risk_category,

    SUM(elderly_claims)
        AS total_claims,

    ROUND(
        SUM(elderly_drug_cost),2
    ) AS total_cost,

    SUM(elderly_beneficiaries)
        AS elderly_patients

FROM elderly_dur_analysis

WHERE provider_specialty IN (

    'Family Practice',
    'Internal Medicine',
    'Nurse Practitioner',
    'Physician Assistant',
    'Psychiatry',
    'Cardiology',
    'Pain Management',
    'Neurology',
    'Endocrinology',
    'Geriatric Medicine',
    'Orthopedic Surgery',
    'Physical Medicine and Rehabilitation'

)

GROUP BY
    provider_specialty,
    primary_risk_category

ORDER BY total_claims DESC;
*/
-- ==========================================================
-- RESULT 5B INTERPRETATION
-- Provider Specialty × Risk Category Heatmap
-- ==========================================================

/*
Key Findings:

1. Family Practice demonstrated the largest
overall burden of preventable medication-related
risk among elderly patients, particularly
Falls/CNS Depression (15.3 million claims),
Bleeding risk (4.3 million claims), and
Respiratory Depression (4.0 million claims).
This likely reflects the complexity of
polypharmacy and chronic disease management
in primary care settings.

2. Internal Medicine showed a similarly high
risk burden across multiple adverse outcome
categories, particularly Falls/CNS Depression
(13.4 million claims), Bleeding
(4.9 million claims), and Hypoglycemia
(3.5 million claims), reinforcing its
central role in elderly medication management.

3. Nurse Practitioners contributed
substantially to high-risk prescribing burden,
particularly Falls/CNS Depression
(11.9 million claims), Respiratory Depression
(3.8 million claims), and Bleeding
(3.1 million claims), reflecting their
expanding role in chronic disease care and
elderly medication management.

4. Cardiology demonstrated a disproportionately
high bleeding-related burden
(3.8 million claims; >$3.7 billion cost),
primarily driven by anticoagulant use,
highlighting the importance of careful
bleeding-risk assessment and medication review
in elderly cardiovascular populations.

5. Psychiatry demonstrated a strong
Falls/CNS Depression burden
(approximately 4 million claims),
likely driven by benzodiazepine and
antipsychotic prescribing, emphasizing the
importance of deprescribing strategies and
cognitive safety interventions in older adults.

6. Pain-related specialties, including
Pain Management and Physical Medicine &
Rehabilitation, demonstrated elevated
Respiratory Depression burden, reflecting
opioid utilization and associated overdose,
sedation, and hospitalization risks.

7. Endocrinology showed a dominant
Hypoglycemia burden (1.58 million claims),
likely reflecting insulin and sulfonylurea
therapy in elderly diabetic populations,
supporting individualized glycemic targets
and medication optimization.

8. Geriatric Medicine demonstrated
relatively lower prescribing volume but
distributed involvement across multiple
risk domains, highlighting the specialty’s
focus on medication optimization and
comprehensive elderly care.


Clinical Interpretation:

The heatmap findings suggest that medication
safety interventions in elderly populations
should be specialty-targeted. Primary care
(Family Practice and Internal Medicine),
Cardiology, Psychiatry, Pain-related
specialties, and Endocrinology represent
priority areas for pharmacist-led medication
review, deprescribing interventions, and
risk-benefit reassessment to reduce
preventable adverse drug events among
older adults.
*/
-- ==========================================================
-- RESULT 6: Preventable Adverse Outcomes
-- ==========================================================

/*
Purpose:
Identify major preventable adverse outcomes
associated with high-risk medications
among elderly patients.

Clinical Relevance:
Highlights medication-related harms that
may potentially be reduced through safer
prescribing, medication review, and
deprescribing interventions.
*/

SELECT
    primary_risk_category,

    COUNT(DISTINCT generic_name)
        AS implicated_drugs,

    SUM(elderly_claims)
        AS total_claims,

    ROUND(
        SUM(elderly_drug_cost),2
    ) AS total_cost,

    SUM(elderly_beneficiaries)
        AS affected_patients

FROM elderly_dur_analysis

GROUP BY primary_risk_category

ORDER BY total_claims DESC;

-- ==========================================================
-- RESULT 6 INTERPRETATION
-- ==========================================================

/*
Key Findings:

1. Falls/CNS-related adverse outcomes represented
the largest preventable medication-related burden
among elderly patients, involving 13 high-risk drugs 
and more than 59.2 million claims.

2. Bleeding-related outcomes generated
the highest healthcare expenditure
($14.84 billion), primarily driven by
high-cost anticoagulants such as
apixaban and rivaroxaban.

3. Respiratory depression accounted
for over 20.5 million claims, reflecting
substantial opioid and CNS depressant
utilization among elderly populations.

4. Hypoglycemia-related outcomes
affected more than 12.1 million claims,
highlighting risks associated with
insulin and sulfonylurea use.

5. Renal injury remained an important
preventable adverse event, largely linked
to NSAID exposure and medication-related
kidney toxicity in older adults.

6. Anticholinergic burden affected
approximately 4.3 million claims,
raising concerns regarding delirium,
confusion, urinary retention, and
functional decline in elderly patients.

7. Gastrointestinal toxicity,
including peptic ulcer disease and
GI bleeding, remained a clinically
important adverse outcome associated
with NSAID exposure.
*/
----
-- ==========================================================
-- RESULT 7: Deprescribing Opportunity Analysis
-- ==========================================================

/*
Purpose:
Identify high-risk medications contributing the greatest
preventable medication burden in elderly populations and
evaluate opportunities for deprescribing interventions to
improve medication safety, reduce adverse outcomes,
and optimize healthcare spending.
*/

SELECT
    generic_name,
    drug_class,
    risk_level,
    deprescribing_recommendation,

    SUM(elderly_claims)
        AS total_claims,

    ROUND(SUM(elderly_drug_cost), 2)
        AS total_cost,

    SUM(elderly_beneficiaries)
        AS elderly_patients

FROM elderly_dur_analysis

GROUP BY
    generic_name,
    drug_class,
    risk_level,
    deprescribing_recommendation

ORDER BY total_claims DESC
LIMIT 20;


-- ==========================================================
-- INTERPRETATION: RESULT 7
-- ==========================================================

/*
Key Findings:

1. Gabapentin represented the largest utilization burden
(21.5 million claims) among high-risk medications in
elderly patients. Although the medication demonstrated
relatively low cost-per-claim, its extensive utilization
suggests the need for routine reassessment of indication,
renal dose adjustment, and avoidance of unnecessary
co-prescribing with central nervous system (CNS)
depressants.

2. Direct oral anticoagulants (DOACs), particularly
apixaban and rivaroxaban, generated the highest economic
burden ($11.57 billion and $3.24 billion, respectively).
These findings emphasize the importance of periodic
reassessment of renal function, bleeding risk, dose
appropriateness, and treatment duration to reduce
preventable hemorrhagic complications.

3. Opioid analgesics, including
hydrocodone/acetaminophen, tramadol, and oxycodone
formulations, accounted for substantial prescribing
burden in elderly patients. Their association with falls,
respiratory depression, overdose risk, and hospitalization
suggests opportunities for deprescribing through gradual
tapering, reassessment of pain indication, and
prioritization of safer analgesic alternatives.

4. Benzodiazepines, particularly alprazolam,
clonazepam, and lorazepam, remained widely utilized
despite their known association with falls, fractures,
sedation, cognitive impairment, and dependence in older
adults. Gradual tapering and non-pharmacologic
interventions may substantially reduce potentially preventable 
medication-related harm.

5. NSAIDs, including meloxicam, diclofenac sodium,
and celecoxib, demonstrated significant utilization burden
and risk of gastrointestinal bleeding, acute kidney injury,
hypertension, and cardiovascular complications.
Findings support limiting prolonged NSAID exposure and
using the lowest effective dose for the shortest duration.

6. Hypoglycemia-inducing therapies, including
insulin glargine and glipizide, demonstrated substantial
utilization and economic burden, reinforcing the need
for individualized glycemic targets and deprescribing
strategies aimed at reducing severe hypoglycemia risk
in elderly populations.

7. Anticholinergic medications, particularly
oxybutynin chloride, highlighted concerns regarding
cognitive impairment, delirium, urinary retention,
and falls, suggesting that safer therapeutic alternatives
should be considered where clinically appropriate.


Clinical Interpretation:

The findings indicate that a significant proportion of
medication-related harm in elderly populations may be
preventable through targeted deprescribing interventions.
High-utilization and high-cost medications, particularly
opioids, benzodiazepines, anticoagulants, NSAIDs,
insulin therapies, and anticholinergic agents, should be
prioritized for medication review programs, risk-benefit
reassessment, dose optimization, and safer therapeutic
substitution.


Project-Level Conclusion:

This Drug Utilization Review (DUR) demonstrated
substantial high-risk medication exposure among elderly
Medicare beneficiaries, revealing important opportunities
to reduce preventable adverse outcomes through
evidence-based deprescribing and medication optimization
strategies. The findings support the implementation of
targeted prescribing interventions to improve patient
safety while potentially reducing healthcare costs.
*/
