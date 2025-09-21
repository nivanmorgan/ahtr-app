# 🎈 App template

AHTR interactive map !

### How to run it on your own machine

1. Install the requirements
   ```
   $ pip install -r requirements.txt
   ```
## Quick Links
- Dev process log: see `NEXT_STEPS.md` for dated actions and decisions.
- Contributor guide: see `AGENTS.md` for structure, style, and commands.
- API endpoints: see `docs/endpoints.md` for routes and examples.
- Dev runbook: see `docs/dev-runbook.md` to bring the app up in AWS.
- Prod runbook: see `docs/prod-runbook.md` to bring the prod stack up.

## Local Development
- Install deps: `pip install -r requirements.txt`
- Run API: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload`
- Tests: `pytest -q`

## Infrastructure (Dev)
- Terraform: `cd infra && terraform init && terraform apply`
- Terragrunt (recommended for envs): `cd terragrunt/live/dev/app && terragrunt apply`
- Package Lambda POC: `make lambda-zip`

## CI/CD and Data Import
- Backend pipeline builds/pushes Docker and deploys to ECS.
- Import CSV to RDS:
  - Via ECS task: `make import-csv CSV_S3=s3://<bucket>/seed.csv DB_USER=... DB_PASSWORD=...`
  - Via CodeBuild: `make import-csv-cb CSV_S3=s3://<bucket>/seed.csv`

## Converting Excel to Importable CSV
- If your data is in Excel with multiple sheets, use the helper:
  - Install locally: `pip install pandas openpyxl pyyaml`
  - Config-driven (recommended):
    - Edit `data/mapping.example.yaml` to match your sheet names/columns.
    - `python scripts/xlsx_to_import_csv.py --xlsx "./Data for Transcarta app.xlsx" --config data/mapping.example.yaml --out ./out.csv`
  - Auto-detect (best-effort):
    - `python scripts/xlsx_to_import_csv.py --xlsx ./data.xlsx --out ./out.csv`
  - Then upload the CSV to S3 and run an import (see above).
