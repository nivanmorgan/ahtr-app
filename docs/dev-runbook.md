# Dev Runbook: Bring Up AHTR Backend

Prereqs
- AWS CLI configured and profile set
  - `export AWS_PROFILE=ahtr-dev`
  - `export AWS_REGION=us-west-2`
  - Verify: `aws sts get-caller-identity`
- `terragrunt`, `terraform`, `awscli`, `docker` installed

1) Apply dev infra (ECR, ECS, RDS, S3, CodePipeline/CodeBuild)
- `cd terragrunt/live/dev/app && terragrunt apply -auto-approve`
- Ensure CodeStar Connection is “Connected” for the ARN in the terragrunt file.

2) Seed a bootstrap image to ECR (unblocks ECS before pipeline builds)
- From repo root:
  - `make ecr-login`
  - `make seed-bootstrap`

3) Force ECS redeploy and scale up
- `make deploy-force`
- `make scale-ecs DESIRED=1`

4) (Optional) Kick off the backend pipeline
- `make pipeline-run` (or push to the tracked branch; see terragrunt inputs)
- After success, ECS service will roll to the new image automatically.

5) Import data
- Upload your CSV to S3 (any bucket; recommended to use the images bucket from outputs)
- Start the import job:
  - `make import-csv-cb CSV_S3=s3://your-bucket/your.csv`

6) Verify ALB and endpoints
- Get the ALB DNS: `terragrunt output -raw alb_dns_name`
- `curl http://<ALB>/health` should show `{ "database": true, "s3": true, "status": "healthy" }`
- See `docs/endpoints.md` for API and examples.

## Make Cheatsheet
- Build + push backend image: `make docker-build-push`
- Force service to redeploy: `make deploy-force`
- Scale service up/down: `make scale-ecs DESIRED=1|0`
- Trigger backend pipeline: `make pipeline-run`
- Upload images: `make s3-sync-images DIR=./path`
- Upload CSV for import: `make upload-csv CSV=./out.csv`
- Run default import: `make import-csv-default`
- More: see `docs/make-commands.md` for all targets and variables.

## Data Locations (Dev)
- Images bucket: `terragrunt output -raw images_bucket` (example: `ahtr-dev-images-gp-bucket`)
- Conventions:
  - Images: `s3://<images_bucket>/images/...`
  - Import CSVs: `s3://<images_bucket>/imports/transcarta.csv` (default)
- Helpers:
  - Upload images under prefix: `make s3-sync-images DIR=./path/to/images`
  - Upload a CSV: `make upload-csv CSV=./out.csv`
  - Run import with default path: `make import-csv-default` (uses `CSV_FILE=transcarta.csv` by default)
  - Override the CSV file name: `CSV_FILE=mydata.csv make import-csv-default`

Notes
- CORS is enabled; set `CORS_ORIGINS` env for stricter non‑dev origins.
- To pause service: `make scale-ecs DESIRED=0`.
