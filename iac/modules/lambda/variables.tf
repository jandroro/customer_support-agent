variable "name_prefix" {
  description = "Prefix applied to every resource name"
  type        = string
}

variable "lambda_source_path" {
  description = "Absolute path to the directory containing Lambda Python source files"
  type        = string
}

variable "ddgs_layer_zip_path" {
  description = "Absolute path to the pre-built DDGS Lambda Layer zip"
  type        = string
}

variable "artifacts_bucket_id" {
  description = "Name of the S3 bucket that holds the Lambda zip (from modules/s3)"
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key of the Lambda function zip (from modules/s3)"
  type        = string
}

variable "warranty_table_arn" {
  description = "ARN of the warranty DynamoDB table (from modules/dynamodb)"
  type        = string
}

variable "customer_profile_table_arn" {
  description = "ARN of the customer-profile DynamoDB table (from modules/dynamodb)"
  type        = string
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
