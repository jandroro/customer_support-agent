output "warranty_table_name" {
  description = "Name of the warranty DynamoDB table"
  value       = aws_dynamodb_table.warranty.name
}

output "warranty_table_arn" {
  description = "ARN of the warranty DynamoDB table"
  value       = aws_dynamodb_table.warranty.arn
}

output "customer_profile_table_name" {
  description = "Name of the customer-profile DynamoDB table"
  value       = aws_dynamodb_table.customer_profile.name
}

output "customer_profile_table_arn" {
  description = "ARN of the customer-profile DynamoDB table"
  value       = aws_dynamodb_table.customer_profile.arn
}

output "customer_profile_table_index_arns" {
  description = "ARNs of the customer-profile table GSI indexes"
  value = [
    "${aws_dynamodb_table.customer_profile.arn}/index/*",
  ]
}
