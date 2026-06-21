variable "aws_profile" {
  description = "AWS CLI named profile to use for authentication"
  type        = string
}

variable "aws_region" {
  description = "AWS region where all resources will be deployed"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name that prefixes every resource to avoid naming collisions"
  type        = string
  default     = "customer-support-agent"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "project_name must be 3-32 lowercase alphanumeric characters or hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "model_id" {
  description = "Model ID used for the Agents"
  type        = string
}
