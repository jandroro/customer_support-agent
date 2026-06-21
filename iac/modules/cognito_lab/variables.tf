variable "name_prefix" {
  description = "Prefix applied to resource tags (the pool/client names are fixed for notebook compatibility)"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
