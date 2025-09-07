region                  = "us-west-2"
environment             = "dev"    

# Backend (ahtr-app) CodePipeline
repository_id           = "nivanmorgan/ahtr-app"
branch                  = "main"
code_connection_arn     = "arn:aws:codeconnections:us-west-2:428847003703:connection/3316d1d6-da19-4bd6-a7a3-b1823ec05b08"

# Frontend (ahtr-ui) CodePipeline
frontend_repository_id       = "nivanmorgan/ahtr-ui"
frontend_branch              = "main"
frontend_code_connection_arn = "arn:aws:codeconnections:us-west-2:428847003703:connection/3316d1d6-da19-4bd6-a7a3-b1823ec05b08"

# Names must be globally unique
artifact_bucket_name    = "ahtr-dev-artifacts-gp-bucket"
images_bucket_name      = "ahtr-dev-images-gp-bucket"
frontend_bucket_name    = "ahtr-dev-frontend-gp-bucket"

# Database (use temporary creds for dev; rotate later)
db_name     = "ahtr"
db_user     = "ahtr_user"
db_password = "2VXn0bhGdcnseM2JQB50"

# Optional HTTPS + DNS (comment out if not used)
# certificate_arn = "arn:aws:acm:us-west-2:<ACCOUNT_ID>:certificate/<CERT_ID>"
# domain_name     = "api.dev.example.com"
# hosted_zone_id  = "ZXXXXXXXXXXXXX"

# Optional: specify non-default VPC/subnets
vpc_id     = "vpc-0b20bd3efed7d6b83"
subnet_ids = ["subnet-00f70b8da96121bcb", "subnet-055a293f918608598", "subnet-08f684a9012611f93", "subnet-0fcc1383801e586a8"]

#ECR
backend_container_image=428847003703.dkr.ecr.us-west-2.amazonaws.com/ahtr-be
frontend_container_image=428847003703.dkr.ecr.us-west-2.amazonaws.com/ahtr-fe