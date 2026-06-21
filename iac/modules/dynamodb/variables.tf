variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
