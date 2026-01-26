# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

AHTR is an interactive map application backend service built with FastAPI and deployed on AWS. The system serves image metadata and generates pre-signed S3 URLs for map visualization. The infrastructure is managed with Terraform/Terragrunt and deployed via AWS ECS Fargate with CodePipeline for CI/CD.

### Core Technologies
- **Backend**: FastAPI, SQLAlchemy, Uvicorn/Gunicorn
- **Database**: PostgreSQL (AWS RDS) with Alembic migrations
- **Storage**: S3 for images and artifacts
- **Infrastructure**: Terraform + Terragrunt, AWS ECS, ALB, CodePipeline/CodeBuild
- **Container**: Docker (Python 3.11-slim base)

### Architecture

**Application Layer**:
- `app/main.py`: FastAPI application with CORS, health checks, and Prometheus metrics
- `app/models.py`: SQLAlchemy models (Artist, Image, ImageView)
- `app/image_router.py`: API endpoints for image listing and pre-signed URL generation
- `app/admin_router.py`: Database statistics endpoint (dev/troubleshooting)
- `app/queries.py`: Database query helpers
- `app/db.py`: Database connection and session management

**Data Model**:
- `Artist` → `Image` (one-to-many): Artists can have multiple images
- `Image` → `ImageView` (one-to-many): Images can have multiple views (front, back, etc.)
- Images reference S3 objects via `s3_key` field

**Infrastructure**:
- `infra/`: Core Terraform modules (ECS, RDS, ALB, ECR, S3, CodePipeline)
- `terragrunt/live/dev/app/`: Dev environment configuration
- `terragrunt/live/prod/app/`: Prod environment configuration
- Environments are isolated with separate state and resources

**Data Import Pipeline**:
- Excel → CSV conversion: `scripts/xlsx_to_import_csv.py`
- CSV → Database: `scripts/import_csv.py`
- Import jobs run as ECS tasks or CodeBuild projects
- Supports S3-based CSV sources

## Common Commands

### Development Commands

**Local Development**:
```bash
# Install dependencies
pip install -r requirements.txt

# Run API locally (with auto-reload)
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Run tests (if pytest is configured)
pytest -q

# Run tests with verbose output
pytest -v

# Run specific test file
pytest tests/test_specific.py -v
```

**Database Migrations** (Alembic):
```bash
# Create new migration
alembic revision --autogenerate -m "description of changes"

# Apply migrations
alembic upgrade head

# Rollback one migration
alembic downgrade -1

# View migration history
alembic history

# Note: Alembic uses POSTGRES_URL env var or falls back to DB_* vars
```

**Data Import (Local)**:
```bash
# Convert Excel to importable CSV
python scripts/xlsx_to_import_csv.py \
  --xlsx "./Data for Transcarta app.xlsx" \
  --config data/mapping.example.yaml \
  --out ./out.csv

# Import CSV to local database
python scripts/import_csv.py --csv ./out.csv --db postgresql://user:pass@localhost:5432/ahtr
```

### Docker Operations

```bash
# Login to ECR
make ecr-login

# Build Docker image (tags with latest)
make docker-build

# Build with specific tag
TAG=v1.0.0 make docker-build

# Push image to ECR
make docker-push

# Build, tag with git SHA, and push (also updates :latest)
make docker-build-push

# Bootstrap image for initial ECS deployment
make seed-bootstrap
```

### AWS Deployment

**Prerequisites**:
```bash
# Set AWS context
export AWS_PROFILE=ahtr-dev
export AWS_REGION=us-west-2

# Verify credentials
aws sts get-caller-identity
```

**Infrastructure Management**:
```bash
# Dev environment - Apply infrastructure
cd terragrunt/live/dev/app && terragrunt apply -auto-approve

# Prod environment - Apply infrastructure
cd terragrunt/live/prod/app && terragrunt apply -auto-approve

# Get infrastructure outputs
terragrunt output -raw alb_dns_name
terragrunt output -raw ecr_repo_url
terragrunt output -raw images_bucket
```

**ECS Service Management**:
```bash
# Force ECS service to pull new image
make deploy-force

# Scale service up
make scale-ecs DESIRED=1

# Scale service down (to save costs)
make scale-ecs DESIRED=0

# Trigger CodePipeline build and deploy
make pipeline-run
```

**Data Management**:
```bash
# Upload images to S3
make s3-sync-images DIR=./path/to/images

# Upload CSV for import
make upload-csv CSV=./out.csv

# Import CSV via CodeBuild (default path)
make import-csv-default

# Import CSV via CodeBuild (custom path)
make import-csv-cb CSV_S3=s3://bucket-name/path/file.csv

# Import CSV via ECS task (direct)
make import-csv CSV_S3=s3://bucket-name/path/file.csv DB_URL=postgresql://...

# Check database stats
make db-stats
```

## API Endpoints

Base URL format: `http://<ALB_DNS>/`

**Core Endpoints**:
- `GET /` - Service banner
- `GET /health` - Health check (tests DB and S3 connectivity)
- `GET /api/images?limit=10&offset=0&view=front&image_id=<uuid>` - List image views with pre-signed URLs
- `GET /api/image?image_key=<s3-key>` - Redirect to pre-signed S3 URL
- `GET /api/db-stats?limit=5` - Database statistics (dev only)

**Environment Variables**:
- `POSTGRES_URL` or `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` - Database connection
- `S3_BUCKET_NAME` - Images bucket name
- `CORS_ORIGINS` - Comma-separated allowed origins (defaults to `*`)

## Project Structure

```
ahtr-app/
├── app/                    # FastAPI application
│   ├── main.py            # Application entry, CORS, health checks
│   ├── models.py          # SQLAlchemy models
│   ├── db.py              # Database connection
│   ├── image_router.py    # Image API endpoints
│   ├── admin_router.py    # Admin/stats endpoints
│   └── queries.py         # Database query helpers
├── infra/                 # Terraform infrastructure modules
│   ├── main.tf            # Provider configuration
│   ├── compute.tf         # ECS cluster, task definition, service
│   ├── rds.tf             # PostgreSQL database
│   ├── alb.tf             # Application Load Balancer
│   ├── ecr.tf             # Container registries
│   ├── s3.tf              # S3 buckets
│   ├── backend_pipeline.tf # CodePipeline for backend
│   ├── data_import.tf     # CodeBuild for CSV imports
│   └── outputs.tf         # Terraform outputs
├── terragrunt/            # Environment-specific configurations
│   └── live/
│       ├── dev/app/       # Dev environment
│       └── prod/app/      # Prod environment
├── scripts/               # Data import and conversion scripts
│   ├── import_csv.py      # CSV to database importer
│   ├── xlsx_to_import_csv.py # Excel to CSV converter
│   └── convert_transcarta_xlsx.py # Legacy converter
├── alembic/               # Database migrations
│   ├── env.py             # Alembic environment
│   └── versions/          # Migration files
├── docs/                  # Documentation
│   ├── dev-runbook.md     # Development deployment guide
│   ├── prod-runbook.md    # Production deployment guide
│   ├── endpoints.md       # API documentation
│   └── make-commands.md   # Makefile reference
├── Makefile               # Deployment and operations automation
├── Dockerfile             # Container definition
├── requirements.txt       # Python dependencies
└── alembic.ini           # Alembic configuration
```

## Makefile Reference

The Makefile automates common operations. Key variables:

**Auto-detected from Terraform outputs**:
- `CLUSTER`, `SERVICE`, `TASK_DEF` - ECS resources
- `ECR_REPO`, `REGISTRY` - Container registry
- `DB_HOST` - RDS endpoint
- `IMAGES_BUCKET` - S3 images bucket
- `PIPELINE` - CodePipeline name

**User-configurable**:
- `AWS_PROFILE` - AWS credentials profile
- `AWS_REGION` - AWS region (default: us-west-2)
- `TAG` - Docker image tag
- `DESIRED` - ECS desired task count
- `CSV_S3` - S3 path for CSV import
- `DIR` - Local directory for S3 sync
- `CSV` - Local CSV file path

**Common Targets**:
- `help` - Display all available targets
- `docker-build-push` - Build and push Docker image
- `deploy-force` - Force ECS service redeployment
- `scale-ecs` - Update service desired count
- `pipeline-run` - Trigger CodePipeline
- `import-csv-cb` - Import CSV via CodeBuild
- `import-csv-default` - Import default CSV path
- `s3-sync-images` - Upload images to S3

## Database Schema

**Tables**:
- `artists`: id (UUID), name, bio
- `images`: id (UUID), s3_key (unique), title, artist_id (FK)
- `image_views`: id (UUID), image_id (FK), view (e.g., "front", "back")

**Key Relationships**:
- Artist → Image: One-to-many via `artist_id`
- Image → ImageView: One-to-many via `image_id`

**Indexes**:
- `artists.name` - Indexed for fast artist lookup
- `images.s3_key` - Unique index for S3 key lookups

## Development Workflow

**Starting a new feature**:
1. Create feature branch: `git checkout -b feature/description`
2. Make code changes in `app/`
3. If database changes: `alembic revision --autogenerate -m "description"`
4. Test locally: `uvicorn app.main:app --reload`
5. Commit and push: `git push -u origin feature/description`

**Deploying to dev**:
1. Merge to `develop` branch
2. CodePipeline automatically builds and deploys
3. Or manually: `make docker-build-push && make deploy-force`

**Deploying to prod**:
1. Merge to `main` branch
2. CodePipeline triggers (with manual approval step)
3. Approve in AWS Console → CodePipeline
4. ECS service automatically updates

## Important Notes

**Environment Setup**:
- Always set `AWS_PROFILE` and `AWS_REGION` before running Make commands
- Terraform outputs must exist before Makefile commands work
- Run `terragrunt apply` first to generate infrastructure outputs

**Database Connections**:
- Local: Use `POSTGRES_URL` or individual `DB_*` environment variables
- AWS: ECS tasks receive DB credentials via environment variables set in task definition
- Alembic migrations use same connection logic as app

**S3 Bucket Conventions**:
- Images: `s3://<images_bucket>/images/...`
- Import CSVs: `s3://<images_bucket>/imports/...`
- Artifacts: Separate bucket for CodePipeline/CodeBuild

**Cost Management**:
- Scale ECS to 0 when not in use: `make scale-ecs DESIRED=0`
- RDS runs continuously unless manually stopped
- Dev environment auto-detects your IP for DB access (via terragrunt)

**CodeStar Connection**:
- Must be in "Connected" state in AWS Console
- Required for CodePipeline to access GitHub repository
- Re-run `terragrunt apply` after connecting

**Data Import CSV Format**:
Expected columns: `s3_key`, `title`, `artist`, `views`, `latitude`, `longitude`
- `s3_key` is required and must match actual S3 object keys
- `views` can be comma or semicolon-separated (e.g., "front,back")
- Empty fields are acceptable except for `s3_key`

**CORS Configuration**:
- Default: `*` (all origins allowed)
- Production: Set `CORS_ORIGINS` env var to comma-separated list of allowed origins

**Pre-signed URLs**:
- Generated with 5-minute expiration (300 seconds)
- Frontend should refresh URLs before expiration
- URLs are not cached; generated on each API request
