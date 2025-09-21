# AHTR Backend API Endpoints (Dev/Prod)

Base URL
- Dev ALB: obtain via `terragrunt output -raw alb_dns_name` in `terragrunt/live/dev/app`
- Prod ALB: obtain via `terragrunt output -raw alb_dns_name` in `terragrunt/live/prod/app`
- All endpoints are HTTP on port 80 via ALB. Add HTTPS + domain when ACM/Route53 is configured.

Auth/CORS
- CORS: Enabled. Configure allowed origins via env `CORS_ORIGINS` (comma-separated). Defaults to `*` in dev.
- No auth in dev. Add auth in front of ALB or in app if needed.

Endpoints
- GET `/` : Service banner
  - 200: `{ "message": "AHTR Map Service Operational" }`
- GET `/health` : Health check for DB and S3
  - 200: `{ "database": true|false, "s3": true|false, "status": "healthy"|"unhealthy" }`
- GET `/api/images` : List image views with optional filters
  - Query: `limit` (1..100, default 10), `offset` (>=0), `image_id` (UUID), `view` (e.g. `front`, `back`)
  - 200: `[ { "id": "<uuid>", "image_id": "<uuid>", "view": "front", "url": "https://..." | null } ]`
  - `url` is a short‑lived S3 pre‑signed URL when S3 key is available.
- GET `/api/image?image_key=<s3-key>` : Redirect to a pre‑signed S3 URL for a specific object
  - 302 redirect to S3 pre‑signed URL or 404 if not found.

Notes for FE
- Use `/api/images` to paginate through available image views; follow the `url` for direct display.
- Handle `url=null` gracefully (no S3 key known).
- If calling from the browser, set the site origin in `CORS_ORIGINS` for stricter CORS in non‑dev.

Examples
- `curl http://<ALB>/`
- `curl http://<ALB>/health`
- `curl "http://<ALB>/api/images?limit=20&view=front"`
- `curl -i "http://<ALB>/api/image?image_key=folder/file.jpg"`
