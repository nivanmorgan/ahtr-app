variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "db_user" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC id for the database"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnets for the DB subnet group"
  type        = list(string)
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "ahtr-cluster"
}

variable "container_image" {
  description = "Container image for the ECS service"
  type        = string
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "ahtr-repo"
}
