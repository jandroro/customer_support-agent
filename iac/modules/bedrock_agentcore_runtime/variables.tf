variable "name_prefix" {
  description = "Prefix applied to all resources to avoid naming collisions"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}

variable "container_image_uri" {
  description = "URI of the container image in ECR (e.g. <account>.dkr.ecr.<region>.amazonaws.com/<repo>:tag)"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository, used to scope ECR pull permissions on the IAM role"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables to inject into the AgentCore runtime container"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "allowed_client_id" {
  description = "Cognito app client ID authorized to obtain JWTs accepted by the runtime (MCPServerPoolClient)"
  type        = string
}

variable "discovery_url" {
  description = "OIDC discovery URL of the Cognito User Pool issuing the JWTs (MCPServerPool)"
  type        = string
}
