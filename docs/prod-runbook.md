# Prod Runbook: Bring Up AHTR Backend (us-west-2)

Prereqs
- AWS credentials for prod with sufficient permissions
- `terragrunt`, `terraform`, `awscli`, `docker`
- Optional later: domain + ACM certificate for HTTPS (infra currently exposes HTTP via ALB)

1) Configure prod variables (verify before apply)
- File: `terragrunt/live/prod/app/terragrunt.hcl`
  - `repository_id`, `branch=main`, `code_connection_arn` point to the backend repo/branch
  - `enable_backend_pipeline = true`
  - `ecs_repo_name = "ahtr-be"` (standardized)
  - Set strong `db_password`
  - `enable_manual_approval = true` (already set; approve deploys in CodePipeline)
  - Optional later: add `certificate_arn`, `domain_name`, `hosted_zone_id` for DNS/HTTPS (ALB listener upgrade required)

2) Apply prod infra
- `cd terragrunt/live/prod/app && terragrunt apply -auto-approve`
- In AWS Console → Developer Tools → Connections, ensure the CodeStar Connection ARN is “Connected”. Re-run apply if you had to re-authorize.

3) Build and publish backend image via pipeline
- Export helpful outputs:
  - `ALB=$(terragrunt output -raw alb_dns_name)`
  - `PIPELINE=$(terragrunt output -raw backend_pipeline_name)`
  - `CLUSTER=$(terragrunt output -raw ecs_cluster_name)`
  - `SERVICE=$(terragrunt output -raw ecs_service_name)`
  - `ECR=$(terragrunt output -raw ecr_repo_url)`
- Start pipeline (or push to `main`):
  - From repo root: `PIPELINE=$PIPELINE make pipeline-run`
- After CodeBuild completes, the image is in ECR (`$ECR`), and CodePipeline deploys to ECS.

Optional: one-time bootstrap (only if you need to unblock ECS before first pipeline)
- From repo root:
  - `ECR_REPO=$ECR make ecr-login`
  - `ECR_REPO=$ECR make docker-build TAG=bootstrap`
  - `ECR_REPO=$ECR make docker-push TAG=bootstrap`
  - `CLUSTER=$CLUSTER SERVICE=$SERVICE make deploy-force`

4) Scale service
- Default desired count is 1 in prod. If needed:
  - `CLUSTER=$CLUSTER SERVICE=$SERVICE make scale-ecs DESIRED=1`

5) Import data
- Upload CSV to S3 (ensure rows contain an `s3_key` column that matches objects in your images bucket)
- Get CodeBuild import project name:
  - `CB_NAME=$(terragrunt output -raw codebuild_data_import_name)`
- Start import:
  - From repo root: `CB_NAME=$CB_NAME make import-csv-cb CSV_S3=s3://your-bucket/your.csv`

6) Verify
- Health: `curl http://$ALB/health` → `{ "database": true, "s3": true, "status": "healthy" }`
- API: see `docs/endpoints.md` for routes and examples

Notes
- Images bucket: `terragrunt output -raw images_bucket`
- CORS is enabled; set `CORS_ORIGINS` env to your FE origins for stricter behavior.
- For HTTPS + DNS, add ACM and Route53 inputs in the prod terragrunt file and extend ALB to terminate TLS (future enhancement).

## Make Cheatsheet
- Build + push backend image: `make docker-build-push`
- Force service to redeploy: `make deploy-force`
- Scale service up/down: `make scale-ecs DESIRED=1|0`
- Trigger backend pipeline: `make pipeline-run`
- Upload images: `make s3-sync-images DIR=./path`
- Upload CSV for import: `make upload-csv CSV=./out.csv`
- Run default import: `make import-csv-default`
