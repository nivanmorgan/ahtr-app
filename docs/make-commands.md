# Makefile Guide

Lean reference for common build, deploy, and data tasks.

- Prereqs: AWS CLI configured, Docker installed, Terraform/Terragrunt applied for the env.
- Set environment: `export AWS_PROFILE=ahtr-dev` and `export AWS_REGION=us-west-2`.
- Terraform outputs are read from `infra/` by default. If you work per‑env with Terragrunt, `cd terragrunt/live/dev/app && terragrunt apply` first.

## Core Workflows

- Build and deploy current image to ECS:
  - `make docker-build-push` (uses TAG=$GIT_SHA, also updates `:latest`)
  - `make deploy-force` (forces ECS to pull the new image)

- Bring up dev from scratch:
  - `cd terragrunt/live/dev/app && terragrunt apply -auto-approve`
  - `make seed-bootstrap` (pushes `:bootstrap` image once)
  - `make deploy-force && make scale-ecs DESIRED=1`

- Start backend pipeline (CodePipeline):
  - `make pipeline-run`

- Import data from a CSV in S3:
  - Via CodeBuild: `make import-csv-cb CSV_S3=s3://<bucket>/path.csv`
  - Default path helper: `make import-csv-default` (uses `s3://$(IMAGES_BUCKET)/imports/transcarta.csv`)

## Targets

- `help`: Prints available targets and key env vars.
- `tg-dev-apply`: Terragrunt apply for dev environment.
- `infra-init` / `infra-apply`: Terraform init/apply inside `infra/`.
- `ecr-login`: Logs Docker into your ECR registry for `$(AWS_REGION)`.
- `docker-build`: Builds image to `$(ECR_REPO):$${TAG:-latest}`. Set `TAG=...`.
- `docker-push`: Pushes `$(ECR_REPO):$${TAG:-latest}`. Set `TAG=...`.
- `docker-build-push`: Logs into ECR, builds and pushes `TAG=${GIT_SHA}`, also tags/pushes `:latest`.
- `seed-bootstrap`: Builds and pushes `:bootstrap` once to unblock initial ECS starts.
- `deploy-force`: Forces the ECS service to redeploy the current task definition/image.
- `scale-ecs`: Updates service desired count. Example: `make scale-ecs DESIRED=1`.
- `pipeline-run`: Triggers the backend CodePipeline execution.
- `s3-sync`: Sync a local directory to the images bucket root. `DIR=./path`.
- `s3-sync-images`: Sync a local directory under `s3://$(IMAGES_BUCKET)/images/`. `DIR=./path`.
- `upload-csv`: Upload a CSV to `s3://$(IMAGES_BUCKET)/imports/`. `CSV=./data.csv`.
- `import-csv-cb`: Start the CodeBuild import job. Requires `CSV_S3=s3://bucket/key.csv`.
- `import-csv-default`: Shortcut to call `import-csv-cb` for the default path.
- `import-csv`: Run a one‑off ECS task to import directly. Requires `CSV_S3`, and optional DB overrides via `DB_URL` or `DB_*`.
- `db-stats`: One‑off ECS task to print counts from key DB tables.

## Important Env Vars

- `AWS_PROFILE` / `AWS_REGION`: AWS CLI context used by targets.
- `ECR_REPO`: ECR repo URL (auto‑read from `terraform -chdir=infra output`).
- `CLUSTER`, `SERVICE`, `TASK_DEF`, `SUBNETS`, `ECS_SG`: ECS details (auto‑read from `infra` outputs).
- `IMAGES_BUCKET`: Images S3 bucket (auto‑read from outputs).
- `TAG`: Docker tag for build/push targets (defaults to `GIT_SHA` where applicable).
- `DESIRED`: Desired task count for `scale-ecs`.
- `CSV_S3`, `DIR`, `CSV`: Parameters for data upload/import helpers.

## Tips

- Use Terragrunt per‑env: `terragrunt output -raw <name>` is convenient for env‑specific values.
- If outputs aren’t available in `infra/`, set the needed variables inline, e.g.
  - `CLUSTER=... SERVICE=... make deploy-force`
  - `ECR_REPO=... make docker-build-push`

