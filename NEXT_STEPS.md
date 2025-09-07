# Next Steps Log

This living document tracks operational steps, decisions, and dates. Append new entries at the top with the most recent first.

## 2025-09-07
- Provisioned dev infrastructure scaffolding in `us-west-2` using Terraform/Terragrunt (ECS + ALB + RDS + ECR + S3 + CloudFront).
- Added CI/CD via CodePipeline/CodeBuild for backend; frontend pipeline disabled by default.
- Implemented Rekognition Lambda POC for S3 image tagging.
- Wired Secrets Manager for DB password; ECS consumes via container secret; CodeBuild data-import reads via secret.
- Added data-import paths: ECS one-off task and CodeBuild job (`make import-csv` / `make import-csv-cb`).
- API stabilized; added bbox filter; tests and CSV import script (S3-supported).

Planned next:
- Optional: Admin portal (Cognito-protected) to browse/edit metadata and trigger imports.
- Prod environment via Terragrunt (`environment=prod`), ACM HTTPS + Route53 alias.
- More API tests (bbox/radius, error cases) and sample CSV in `data/`.

