output "alb_dns_name" {
  value       = aws_lb.app_alb.dns_name
  description = "Public DNS of the ALB"
}

output "cloudfront_domain" {
  value       = var.enable_frontend_cdn ? aws_cloudfront_distribution.frontend[0].domain_name : null
  description = "CloudFront distribution domain for the frontend"
}

output "ecr_repo_url" {
  value       = aws_ecr_repository.ahtr.repository_url
  description = "ECR repository URL"
}

output "images_bucket" {
  value       = aws_s3_bucket.images.bucket
  description = "S3 bucket for images"
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.ahtr.name
  description = "ECS cluster name"
}

output "ecs_service_name" {
  value       = aws_ecs_service.ahtr.name
  description = "ECS service name"
}

output "ecs_task_definition" {
  value       = aws_ecs_task_definition.ahtr.family
  description = "ECS task definition family"
}

output "db_endpoint" {
  value       = aws_db_instance.ahtr_postgres.address
  description = "RDS endpoint hostname"
}

output "ecs_sg_id" {
  value       = aws_security_group.ecs_sg.id
  description = "Security group ID for ECS tasks"
}

output "subnet_ids" {
  value       = local.subnet_ids
  description = "List of subnet IDs used for ECS/RDS"
}

output "subnet_ids_csv" {
  value       = join(",", local.subnet_ids)
  description = "Comma-separated subnet IDs"
}
