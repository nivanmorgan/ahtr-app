variable "region" { 
    description = "AWS region" 
    type = string 
    default = "us-west-2" 
    }
variable "project" { 
    description = "Project name" 
    type = string 
    default = "ahtr" 
    }
variable "environment" { 
    description = "Environment (dev/prod)"
     type = string 
     default = "dev" 
     }

variable "db_name" { 
    description = "Database name" 
    type = string 
    }
variable "db_user" { 
    description = "Database username" 
    type = string 
    }
variable "db_password" { 
    description = "Database password" 
    type = string 
    sensitive = true 
    }

variable "vpc_id" { 
    description = "VPC id (optional)" 
    type = string 
    default = null 
    }
variable "subnet_ids" { 
    description = "Subnets (optional)" 
    type = list(string) 
    default = null 
    }

variable "cluster_name" { 
    description = "ECS cluster name (optional)" 
    type = string 
    default = null 
    }
variable "container_image" { 
    description = "Container image for ECS" 
    type = string 
    }

variable "ecs_repo_name" { 
    description = "ECR repository name" 
    type = string 
    default = "ahtr-repo" 
    }
variable "fe_ecr_repo_name" { 
    description = "Frontend ECR repo name" 
    type = string 
    default = "ahtr-ui" 
    }

variable "images_bucket_name" { 
    description = "S3 bucket for images" 
    type = string 
    }
variable "frontend_bucket_name" { 
    description = "S3 bucket for frontend" 
    type = string 
    }
variable "artifact_bucket_name" { 
    description = "S3 bucket for artifacts" 
    type = string 
    }

variable "certificate_arn" { 
    description = "ACM cert ARN (optional)" 
    type = string 
    default = null 
    }
variable "domain_name" { 
    description = "Domain for ALB (optional)" 
    type = string 
    default = null 
    }
variable "hosted_zone_id" { 
    description = "Hosted zone ID (optional)" 
    type = string 
    default = null 
    }

variable "enable_frontend_pipeline" { 
    description = "Enable FE CodePipeline" 
    type = bool 
    default = false 
    }