# NBDI Educational Diversity Analysis 2026

## Overview
This repository contains the solution for the Nordic Business Diversity Index (NBDI) 2026 Data Analyst Trainee Case Assignment.

## Files
- `Solution.sql` - Main PostgreSQL script for local execution
- `Solution_GitHub.sql` - Modified version for GitHub Actions
- `data/Stockholm Large – NBDI2025.csv` - Input data file
- `.github/workflows/nbdi-analysis.yml` - GitHub Actions workflow

## Running the Analysis

### Local Execution
```bash

psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "\pset border 2" -c "\pset format wrapped" -c "\timing on" -f Solution.sql > analysis_results.txt 2>&1
