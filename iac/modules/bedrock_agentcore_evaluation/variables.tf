variable "name_prefix" {
  description = "Prefix applied to all resources to avoid naming collisions"
  type        = string
}

variable "runtime_id" {
  description = "ID of the AgentCore Runtime being evaluated (agent_runtime_id), used to derive the DEFAULT endpoint's vended log group name"
  type        = string
}

variable "otel_service_name" {
  description = "OTEL service.name reported by the container (OTEL_SERVICE_NAME in docker/Dockerfile) — used to filter traces, NOT the Terraform agent_runtime_name"
  type        = string
  default     = "customer_support_agent"
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
