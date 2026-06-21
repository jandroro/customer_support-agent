variable "name_prefix" {
  description = "Prefix applied to every resource name (e.g. customer-support-agent-dev)"
  type        = string
}

variable "tags" {
  description = "Map of tags propagated to all resources created by this module"
  type        = map(string)
  default     = {}
}
