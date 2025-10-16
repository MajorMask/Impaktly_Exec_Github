-- Active: 1760527303238@@127.0.0.1@5432@postgres
-- NBDI Data Analyst Trainee Case Assignment 2025
-- PostgreSQL Solution
-- 
-- OBJECTIVE: Analyze educational diversity in executive management teams
-- METHOD: Calculate diversity score using formula: 1 - Σ(pi²) where pi = proportion of each education category
-- OUTPUT: education_diversity_by_company.csv with diversity metrics per company
--
-- SETUP INSTRUCTIONS:
-- 1. Download "Stockholm Large – NBDI2025.xlsx" and save as CSV named "Stockholm Large – NBDI2025.csv"
-- 2. Update the file path in line 43 below to match your system
-- 3. Ensure PostgreSQL has read/write permissions to the file locations
-- 4. Run this script in PostgreSQL (tested on version 12+)
-- 5. Export final table "education_diversity_by_company" to CSV for submission

-- KEY ASSUMPTIONS AFTER THE ANALYSIS MADE:
-- - Educational backgrounds are already in correct categories (Business, Law, Engineering, etc.)
-- - Multiple degrees separated by commas should each count toward diversity
-- - "N/A" education records are excluded from diversity calculations
-- - Diversity score based on degree counts, not executive counts (as per assignment)

-- DIVERSITY SCORE CALCULATION:
-- Formula: 1 - Σ(pi²) where pi = proportion of degrees in category i
-- 
-- Example: Company with 5 executives having 7 total degrees:
-- - 3 Business degrees: p1 = 3/7 = 0.429
-- - 2 Engineering degrees: p2 = 2/7 = 0.286  
-- - 2 Law degrees: p3 = 2/7 = 0.286
-- 
-- Diversity Score = 1 - (0.429² + 0.286² + 0.286²) = 1 - 0.348 = 0.652
-- 
-- Score interpretation:
-- - 0.0 = No diversity (all same field)
-- - 1.0 = Maximum diversity (all different fields)



-- ============================================================================
-- SECTION 1: DATA IMPORT AND INITIAL SETUP
-- ============================================================================

DROP TABLE IF EXISTS nbdi_raw;
CREATE TABLE nbdi_raw (
    company TEXT,
    board_or_executive TEXT,
    position TEXT,
    approximate_categorization TEXT,  
    special_area TEXT,                
    name TEXT,
    nationality TEXT,
    year_of_birth TEXT,
    educational_background TEXT,
    gender TEXT,
    remarks TEXT                      
);

-- UPDATE THIS PATH FOR YOUR SYSTEM:
COPY nbdi_raw FROM '/tmp/Stockholm Large – NBDI2025.csv' 
WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- Verify data import
SELECT * FROM nbdi_raw LIMIT 5;

-- ============================================================================
-- SECTION 2: DATA ANALYSIS AND OPTIMIZATION
-- ============================================================================

-- Analyze column characteristics for optimization
SELECT 
    'company' AS column_name,
    MAX(LENGTH(company)) AS max_length,
    COUNT(DISTINCT company) AS distinct_values,
    COUNT(*) - COUNT(company) AS null_count
FROM nbdi_raw;

-- Check maximum column lengths for proper sizing
SELECT 
    'company' AS column_name,
    MAX(LENGTH(company)) AS max_length
FROM nbdi_raw
UNION ALL
SELECT 'position', MAX(LENGTH(position)) FROM nbdi_raw
UNION ALL
SELECT 'name', MAX(LENGTH(name)) FROM nbdi_raw
UNION ALL
SELECT 'nationality', MAX(LENGTH(nationality)) FROM nbdi_raw
UNION ALL
SELECT 'educational_background', MAX(LENGTH(educational_background)) FROM nbdi_raw
ORDER BY max_length DESC;

-- ============================================================================
-- SECTION 3: DATA STANDARDIZATION AND CLEANING
-- ============================================================================

-- Create optimized table with proper sizing AND standardization
DROP TABLE IF EXISTS nbdi_raw_optimized;
CREATE TABLE nbdi_raw_optimized AS
SELECT 
    company::VARCHAR(36) AS company,
    -- Standardize board_or_executive during creation per assignment requirements
    CASE 
        WHEN board_or_executive = 'Board of Directors' THEN 'Board'
        WHEN board_or_executive = 'Executive Management' THEN 'Executive'
        ELSE board_or_executive
    END::VARCHAR(50) AS board_or_executive,
    position::VARCHAR(145) AS position,
    approximate_categorization::VARCHAR(50) AS approximate_categorization,
    special_area::VARCHAR(100) AS special_area,
    name::VARCHAR(30) AS name,
    nationality::VARCHAR(26) AS nationality,
    year_of_birth AS year_of_birth,  -- Keep as TEXT for data quality
    educational_background::VARCHAR(52) AS educational_background,
    gender::VARCHAR(10) AS gender,
    remarks AS remarks  -- Keep as TEXT
FROM nbdi_raw;

-- Initial data exploration
SELECT 'Total records' AS metric, COUNT(*) AS value FROM nbdi_raw_optimized
UNION ALL
SELECT 'Total companies', COUNT(DISTINCT company) FROM nbdi_raw_optimized
UNION ALL
SELECT 'Total people', COUNT(DISTINCT name) FROM nbdi_raw_optimized;

-- Check executive records count
SELECT 
    'Executive records' AS metric,
    COUNT(*) AS value
FROM nbdi_raw_optimized
WHERE board_or_executive = 'Executive';  -- Exact match since standardized

-- ============================================================================
-- SECTION 4: EXECUTIVE DATA EXTRACTION AND PROCESSING
-- ============================================================================

-- Extract and clean executive data only (per assignment requirements)
DROP TABLE IF EXISTS executive_data CASCADE;
CREATE TABLE executive_data AS
SELECT 
    company,
    position,
    name,
    nationality,
    year_of_birth,
    -- Standardize gender per assignment requirements
    CASE 
        WHEN TRIM(gender) = 'Male' THEN 'Male'
        WHEN TRIM(gender) = 'Female' THEN 'Female'
        ELSE 'Other/Unknown'
    END AS gender,
    COALESCE(NULLIF(TRIM(educational_background), ''), 'N/A') AS education_raw
FROM nbdi_raw_optimized
WHERE board_or_executive = 'Executive';  -- Keep only executives

-- Analyze educational background patterns
SELECT 
    education_raw,
    COUNT(*) AS frequency
FROM executive_data
WHERE education_raw != 'N/A'
GROUP BY education_raw
ORDER BY frequency DESC
LIMIT 20;

-- Split comma-separated degrees into individual columns
-- This handles executives with multiple degrees (e.g., "Business, Law")
DROP TABLE IF EXISTS executive_degrees_expanded CASCADE;
CREATE TABLE executive_degrees_expanded AS
SELECT 
    company,
    name,
    education_raw,
    -- Split degrees into separate columns (handles up to 3 degrees per person)
    TRIM(SPLIT_PART(education_raw, ',', 1)) AS degree_1,
    NULLIF(TRIM(SPLIT_PART(education_raw, ',', 2)), '') AS degree_2,
    NULLIF(TRIM(SPLIT_PART(education_raw, ',', 3)), '') AS degree_3
FROM executive_data
WHERE education_raw != 'N/A';

-- Create unified degrees table - each degree gets its own row
-- This allows proper counting for diversity calculation
DROP TABLE IF EXISTS degrees_split CASCADE;
CREATE TABLE degrees_split AS
SELECT 
    company,
    name,
    degree_category
FROM (
    SELECT company, name, degree_1 AS degree_category FROM executive_degrees_expanded WHERE degree_1 IS NOT NULL
    UNION ALL
    SELECT company, name, degree_2 AS degree_category FROM executive_degrees_expanded WHERE degree_2 IS NOT NULL
    UNION ALL
    SELECT company, name, degree_3 AS degree_category FROM executive_degrees_expanded WHERE degree_3 IS NOT NULL
) AS all_degrees;

-- ============================================================================
-- SECTION 5: DIVERSITY CALCULATION AND ANALYSIS
-- ============================================================================

-- Calculate educational diversity metrics by company
-- Uses diversity formula: 1 - Σ(pi²) where pi = proportion of each degree category
DROP TABLE IF EXISTS education_diversity_by_company CASCADE;
CREATE TABLE education_diversity_by_company AS
WITH company_stats AS (
    -- Calculate basic company statistics
    SELECT 
        company,
        COUNT(DISTINCT name) AS num_executives,
        COUNT(*) AS total_degrees  -- Total degree instances (not people)
    FROM degrees_split
    GROUP BY company
),
category_counts AS (
    -- Count degrees by category for each company
    SELECT 
        company,
        degree_category,
        COUNT(*) AS category_count
    FROM degrees_split
    GROUP BY company, degree_category
),
diversity_calc AS (
    SELECT 
        cs.company,
        cs.num_executives,
        COUNT(DISTINCT cc.degree_category) AS unique_categories,
        -- Find most common education field
        (SELECT degree_category 
         FROM category_counts cc2
         WHERE cc2.company = cs.company 
         ORDER BY category_count DESC, degree_category 
         LIMIT 1) AS most_common_field,
        -- Calculate share of most common field
        ROUND(
            CAST(MAX(cc.category_count) AS NUMERIC) / cs.total_degrees, 
            3
        ) AS most_common_share,
        -- Calculate diversity score using assignment formula: 1 - Σ(pi²)
        ROUND(
            1.0 - SUM(
                POWER(
                    CAST(cc.category_count AS NUMERIC) / cs.total_degrees, 
                    2
                )
            ),
            3
        ) AS diversity_score
    FROM company_stats cs
    JOIN category_counts cc ON cs.company = cc.company
    GROUP BY cs.company, cs.num_executives, cs.total_degrees
)
SELECT 
    company AS "Company",
    num_executives AS "Number of Executives",
    unique_categories AS "Unique Education Categories",
    most_common_field AS "Most Common Education Field", 
    most_common_share AS "Share of Most Common Field",
    diversity_score AS "Diversity Score"
FROM diversity_calc
ORDER BY company;

-- ============================================================================
-- SECTION 6: RESULTS EXPORT AND SUMMARY STATISTICS
-- ============================================================================

-- Export handled by GitHub Actions using client-side copy
-- COPY education_diversity_by_company TO '/tmp/education_diversity_by_company.csv' 
-- WITH (FORMAT CSV, HEADER TRUE);


-- GitHub Actions will handle export using client-side \copy
SELECT 'Export will be handled by GitHub Actions' AS export_status;

-- Display complete results

SELECT * FROM education_diversity_by_company;

-- Summary Statistics
SELECT '=== ANALYSIS COMPLETE ===' AS status;

SELECT 
    'Total companies analyzed: ' || COUNT(*)::TEXT AS summary 
FROM education_diversity_by_company;

SELECT 
    'Total executives: ' || SUM("Number of Executives")::TEXT AS summary 
FROM education_diversity_by_company;

SELECT 
    'Companies with high diversity (>0.7): ' || COUNT(*)::TEXT AS summary 
FROM education_diversity_by_company 
WHERE "Diversity Score" > 0.7;

SELECT 
    'Companies with low diversity (<0.3): ' || COUNT(*)::TEXT AS summary 
FROM education_diversity_by_company 
WHERE "Diversity Score" < 0.3;

-- Diversity Score Statistics
SELECT '=== DIVERSITY SCORE STATISTICS ===' AS stats_header;
SELECT 
    ROUND(MIN("Diversity Score"), 3) AS min_score,
    ROUND(AVG("Diversity Score"), 3) AS avg_score,
    ROUND(MAX("Diversity Score"), 3) AS max_score,
    ROUND(STDDEV("Diversity Score"), 3) AS stddev_score
FROM education_diversity_by_company;

-- Top and Bottom Performers
SELECT '=== TOP 5 MOST DIVERSE COMPANIES ===' AS top_diverse;
SELECT 
    "Company",
    "Number of Executives",
    "Unique Education Categories",
    "Diversity Score"
FROM education_diversity_by_company
ORDER BY "Diversity Score" DESC
LIMIT 5;

SELECT '=== TOP 5 LEAST DIVERSE COMPANIES ===' AS least_diverse;
SELECT 
    "Company",
    "Number of Executives",
    "Unique Education Categories",
    "Most Common Education Field",
    "Diversity Score"
FROM education_diversity_by_company
ORDER BY "Diversity Score" ASC
LIMIT 5;

-- Final Status

SELECT 
    'Analysis completed successfully. CSV export handled by GitHub Actions.' AS final_message;
    
-- EXPECTED OUTPUT:
-- 1. education_diversity_by_company.csv with columns:
--    - Company: Company name
--    - Number of Executives: Count of executive team members  
--    - Unique Education Categories: Number of different degree types
--    - Most Common Education Field: Dominant degree category
--    - Share of Most Common Field: Proportion of most common degree (0-1)
--    - Diversity Score: Calculated diversity metric (0-1)
--
-- 2. Console output with summary statistics and analysis results


-- ============================================================================
-- COMMAND TO RUN SCRIPT AND CAPTURE OUTPUT:
-- psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "\pset border 2" -c "\pset format wrapped" -c "\timing on" -f Solution.sql > analysis_results.txt 2>&1
-- ============================================================================
-- END OF SCRIPT