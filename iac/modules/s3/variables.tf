variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "lambda_zip_path" {
  description = "Absolute path to the Lambda function zip archive"
  type        = string
}

variable "ddgs_layer_zip_path" {
  description = "Absolute path to the pre-built DDGS Lambda Layer zip archive"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
