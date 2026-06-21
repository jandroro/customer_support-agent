output "artifacts_bucket_id" {
  description = "Name/ID of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "lambda_s3_key" {
  description = "S3 key of the Lambda function zip"
  value       = aws_s3_object.lambda_zip.key
}

output "ddgs_layer_s3_key" {
  description = "S3 key of the DDGS Lambda Layer zip"
  value       = aws_s3_object.ddgs_layer.key
}

output "kb_data_bucket_id" {
  description = "Name/ID of the Knowledge Base data S3 bucket"
  value       = aws_s3_bucket.kb_data.id
}

output "kb_data_bucket_arn" {
  description = "ARN of the Knowledge Base data S3 bucket"
  value       = aws_s3_bucket.kb_data.arn
}
