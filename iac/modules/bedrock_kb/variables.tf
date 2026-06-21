variable "kb_data_bucket_id" {
  description = "Name/ID of the S3 bucket holding KB documentation files (from modules/s3)"
  type        = string
}

variable "kb_data_bucket_arn" {
  description = "ARN of the S3 bucket holding KB documentation files (from modules/s3)"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
