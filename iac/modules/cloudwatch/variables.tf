variable "name_prefix" {
  description = "Prefix applied to all resources to avoid naming collisions"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
