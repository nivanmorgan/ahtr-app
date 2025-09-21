# Default configuration
AWS_REGION          ?= us-west-2
CONTAINER_NAME      ?= ahtr

# Terraform-derived defaults (override by exporting env vars if desired)
CLUSTER             ?= $(shell terraform -chdir=infra output -raw ecs_cluster_name 2>/dev/null)
TASK_DEF            ?= $(shell terraform -chdir=infra output -raw ecs_task_definition 2>/dev/null)
SUBNETS             ?= $(shell terraform -chdir=infra output -raw subnet_ids_csv 2>/dev/null)
ECS_SG              ?= $(shell terraform -chdir=infra output -raw ecs_sg_id 2>/dev/null)
DB_HOST             ?= $(shell terraform -chdir=infra output -raw db_endpoint 2>/dev/null)
SERVICE             ?= $(shell terraform -chdir=infra output -raw ecs_service_name 2>/dev/null)
ECR_REPO            ?= $(shell terraform -chdir=infra output -raw ecr_repo_url 2>/dev/null)
REGISTRY            ?= $(shell echo $(ECR_REPO) | cut -d/ -f1)
GIT_SHA             ?= $(shell git rev-parse --short=7 HEAD 2>/dev/null)
PIPELINE            ?= $(shell terraform -chdir=infra output -raw backend_pipeline_name 2>/dev/null)
IMAGES_BUCKET       ?= $(shell terraform -chdir=infra output -raw images_bucket 2>/dev/null)

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
	@echo "  ecr-login        - docker login to ECR registry for $(AWS_REGION)"
	@echo "  docker-build     - build docker to $(ECR_REPO):$${TAG:-latest} (set TAG=...)"
	@echo "  docker-push      - push $(ECR_REPO):$${TAG:-latest} (set TAG=...)"
	@echo "  docker-build-push- build and push with TAG=$${TAG:-$(GIT_SHA)}"
	@echo "  seed-bootstrap   - build/push :bootstrap to ECR to unblock ECS"
	@echo "  deploy-force     - force ECS service redeploy"
	@echo "  scale-ecs        - update ECS desired count (set DESIRED=0/1)"
	@echo "  pipeline-run     - start backend CodePipeline execution"
	@echo "  s3-sync          - sync a local dir to images bucket (set DIR=path)"

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
	CB_NAME=$${CB_NAME:-$$(terraform -chdir=infra output -raw codebuild_data_import_name 2>/dev/null)}; \
	if [ -z "$$CB_NAME" ]; then echo "CodeBuild data import project not found. Enable in Terraform."; exit 1; fi; \
	aws codebuild start-build --region $(AWS_REGION) --project-name "$$CB_NAME" \
		--environment-variables-override name=CSV_S3,type=PLAINTEXT,value=$(CSV_S3)

.PHONY: ecr-login docker-build docker-push docker-build-push seed-bootstrap deploy-force scale-ecs

ecr-login:
	@if [ -z "$(ECR_REPO)" ]; then echo "ECR repo URL not found. Run terraform in infra/ first."; exit 1; fi
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(REGISTRY)

docker-build:
	@if [ -z "$(ECR_REPO)" ]; then echo "ECR repo URL not found. Run terraform in infra/ first."; exit 1; fi
	TAG=$${TAG:-latest}; echo "Building $(ECR_REPO):$$TAG"; \
	docker build -t $(ECR_REPO):$$TAG .

docker-push:
	@if [ -z "$(ECR_REPO)" ]; then echo "ECR repo URL not found. Run terraform in infra/ first."; exit 1; fi
	TAG=$${TAG:-latest}; echo "Pushing $(ECR_REPO):$$TAG"; \
	docker push $(ECR_REPO):$$TAG

docker-build-push: ecr-login
	TAG=$${TAG:-$(GIT_SHA)}; $(MAKE) docker-build TAG=$$TAG && $(MAKE) docker-push TAG=$$TAG && \
	docker tag $(ECR_REPO):$$TAG $(ECR_REPO):latest && docker push $(ECR_REPO):latest

seed-bootstrap: ecr-login
	$(MAKE) docker-build TAG=bootstrap && $(MAKE) docker-push TAG=bootstrap

deploy-force:
	@if [ -z "$(CLUSTER)" ] || [ -z "$(SERVICE)" ]; then echo "Missing cluster/service. Ensure terraform outputs exist or export vars."; exit 1; fi
	aws ecs update-service --region $(AWS_REGION) --cluster $(CLUSTER) --service $(SERVICE) --force-new-deployment >/dev/null && echo "Deployment forced for $(SERVICE)"

scale-ecs:
	@if [ -z "$(CLUSTER)" ] || [ -z "$(SERVICE)" ]; then echo "Missing cluster/service. Ensure terraform outputs exist or export vars."; exit 1; fi
	@if [ -z "$(DESIRED)" ]; then echo "Set DESIRED=0 or DESIRED=1"; exit 1; fi
	aws ecs update-service --region $(AWS_REGION) --cluster $(CLUSTER) --service $(SERVICE) --desired-count $(DESIRED)

pipeline-run:
	@if [ -z "$(PIPELINE)" ]; then echo "Backend pipeline not found. Ensure it's enabled and terraform outputs exist."; exit 1; fi
	aws codepipeline start-pipeline-execution --name "$(PIPELINE)" --region $(AWS_REGION)

s3-sync:
	@if [ -z "$(DIR)" ]; then echo "Set DIR=path/to/images"; exit 1; fi
	@if [ -z "$(IMAGES_BUCKET)" ]; then echo "Images bucket not found. Run terraform in infra/ first."; exit 1; fi
	aws s3 sync "$(DIR)" "s3://$(IMAGES_BUCKET)/" --region $(AWS_REGION)
