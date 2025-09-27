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

## Make Quickstart
- Build and push image: `make docker-build-push` (tags with current `GIT_SHA` and `latest`)
- Force ECS to pull new image: `make deploy-force`
- Scale service: `make scale-ecs DESIRED=1`
- Start backend pipeline: `make pipeline-run`
- Full target reference: see `docs/make-commands.md`.

## Prod Quickstart
- Set AWS context: `export AWS_PROFILE=<prod-profile>` and `export AWS_REGION=us-west-2`
- Apply infra: `cd terragrunt/live/prod/app && terragrunt apply -auto-approve`
- Deploy app:
  - Option A (recommended): `make pipeline-run` or push to the tracked branch.
  - Option B (manual): `make docker-build-push && make deploy-force`
- Scale service: `make scale-ecs DESIRED=1`
- Get ALB: `terragrunt output -raw alb_dns_name`
- Full guide: see `docs/prod-runbook.md`.

## AWS CLI Setup
- Set your profile for all Makefile commands:
  - `export AWS_PROFILE=ahtr-dev`
  - `export AWS_REGION=us-west-2`
  - Verify credentials: `aws sts get-caller-identity`
- The Makefile automatically uses `AWS_PROFILE` for AWS CLI calls.

## Data Locations
- Images bucket: `terraform -chdir=infra output -raw images_bucket`
- Conventions:
  - Images: `s3://<images_bucket>/images/...`
  - Import CSVs: `s3://<images_bucket>/imports/transcarta.csv` (default)
- Helpers:
  - Upload images: `make s3-sync-images DIR=./path/to/images`
  - Upload CSV: `make upload-csv CSV=./out.csv`
  - Import default CSV: `make import-csv-default` (uses `CSV_FILE=transcarta.csv`)

## Infrastructure (Dev)
- Terraform: `cd infra && terraform init && terraform apply`
- Terragrunt (recommended for envs): `cd terragrunt/live/dev/app && terragrunt apply`
- Package Lambda POC: `make lambda-zip`

## CI/CD and Data Import
- Backend pipeline builds/pushes Docker and deploys to ECS.
- Import CSV to RDS:
  - Via ECS task: `make import-csv CSV_S3=s3://<bucket>/seed.csv DB_USER=... DB_PASSWORD=...`
  - Via CodeBuild: `make import-csv-cb CSV_S3=s3://<bucket>/seed.csv`
  - Defaults: `make import-csv-default` uses `s3://$(IMAGES_BUCKET)/imports/transcarta.csv`

## Converting Excel to Importable CSV
- If your data is in Excel with multiple sheets, use the helper:
  - Install locally: `pip install pandas openpyxl pyyaml`
  - Config-driven (recommended):
    - Edit `data/mapping.example.yaml` to match your sheet names/columns.
    - `python scripts/xlsx_to_import_csv.py --xlsx "./Data for Transcarta app.xlsx" --config data/mapping.example.yaml --out ./out.csv`
  - Auto-detect (best-effort):
    - `python scripts/xlsx_to_import_csv.py --xlsx ./data.xlsx --out ./out.csv`
  - Then upload the CSV to S3 and run an import (see above).
