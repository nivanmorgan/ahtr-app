# Default configuration
AWS_REGION          ?= us-west-2
CONTAINER_NAME      ?= ahtr

# Terraform-derived defaults (override by exporting env vars if desired)
CLUSTER             ?= $(shell terraform -chdir=infra output -raw ecs_cluster_name 2>/dev/null)
TASK_DEF            ?= $(shell terraform -chdir=infra output -raw ecs_task_definition 2>/dev/null)
SUBNETS             ?= $(shell terraform -chdir=infra output -raw subnet_ids_csv 2>/dev/null)
ECS_SG              ?= $(shell terraform -chdir=infra output -raw ecs_sg_id 2>/dev/null)
DB_HOST             ?= $(shell terraform -chdir=infra output -raw db_endpoint 2>/dev/null)

# DB details (override as needed)
DB_NAME             ?= ahtr
DB_USER             ?= ahtr_user
DB_PASSWORD         ?= change_me
DB_URL              ?= postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):5432/$(DB_NAME)

# Import source (required for import)
CSV_S3              ?= 

.PHONY: help infra-init infra-apply tg-dev-apply lambda-zip import-csv

help:
	@echo "Targets:"
	@echo "  infra-init       - terraform init in infra/"
	@echo "  infra-apply      - terraform apply in infra/"
	@echo "  tg-dev-apply     - terragrunt apply for dev (if terragrunt installed)"
	@echo "  lambda-zip       - package Rekognition lambda zip"
	@echo "  import-csv       - run one-off ECS task to import CSV from S3"
	@echo "      Variables (env): CSV_S3, DB_URL (or DB_*), CLUSTER, TASK_DEF, SUBNETS, ECS_SG"
	@echo "  import-csv-cb    - start CodeBuild data-import with CSV_S3 override"

infra-init:
	terraform -chdir=infra init

infra-apply:
	terraform -chdir=infra apply

tg-dev-apply:
	cd terragrunt/live/dev/app && terragrunt apply

lambda-zip:
	cd lambda && zip -j rekognition_labeler.zip rekognition_labeler.py

import-csv:
	@if [ -z "$(CSV_S3)" ]; then echo "Set CSV_S3=s3://bucket/key.csv"; exit 1; fi
	@if [ -z "$(CLUSTER)" ] || [ -z "$(TASK_DEF)" ] || [ -z "$(SUBNETS)" ] || [ -z "$(ECS_SG)" ]; then \
		echo "Missing cluster/task/subnets/sg. Ensure terraform outputs exist or export vars."; exit 1; fi
	@TMP=$$(mktemp); \
	cat > $$TMP <<EOF
{
  "containerOverrides": [
    {
      "name": "$(CONTAINER_NAME)",
      "command": [
        "python","scripts/import_csv.py","--csv","$(CSV_S3)","--db","$(DB_URL)"
      ]
    }
  ]
}
EOF
	aws ecs run-task \
		--region $(AWS_REGION) \
		--cluster $(CLUSTER) \
		--launch-type FARGATE \
		--task-definition $(TASK_DEF) \
		--network-configuration awsvpcConfiguration="subnets=[$(SUBNETS)],securityGroups=[$(ECS_SG)],assignPublicIp=ENABLED" \
		--overrides file://$$TMP ; \
	rc=$$?; rm -f $$TMP; exit $$rc

import-csv-cb:
	@if [ -z "$(CSV_S3)" ]; then echo "Set CSV_S3=s3://bucket/key.csv"; exit 1; fi
	CB_NAME=$$(terraform -chdir=infra output -raw codebuild_data_import_name 2>/dev/null); \
	if [ -z "$$CB_NAME" ]; then echo "CodeBuild data import project not found. Enable in Terraform."; exit 1; fi; \
	aws codebuild start-build --region $(AWS_REGION) --project-name "$$CB_NAME" \
		--environment-variables-override name=CSV_S3,type=PLAINTEXT,value=$(CSV_S3)
