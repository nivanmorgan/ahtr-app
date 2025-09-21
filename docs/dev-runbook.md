# Dev Runbook: Bring Up AHTR Backend

Prereqs
- AWS credentials configured (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION=us-west-2`)
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

Notes
- CORS is enabled; set `CORS_ORIGINS` env for stricter non‑dev origins.
- To pause service: `make scale-ecs DESIRED=0`.
