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