data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Globally unique bucket name: matches prereq.sh naming convention
  artifacts_bucket_name = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  kb_data_bucket_name   = "${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}-kb-data-bucket"
}

# ------------------------------------------------------------------------------
# Artifacts bucket — stores Lambda function zip and DDGS layer zip
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "artifacts" {
  bucket = local.artifacts_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload Lambda function zip
resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "lambda.zip"
  source = var.lambda_zip_path
  etag   = filemd5(var.lambda_zip_path)
}

# Upload DDGS Lambda Layer zip (pre-built, shipped with the source).
#
# Uses source_hash (a Terraform-only change-detection value), not etag.
# This file is ~8MB, just over the AWS SDK's multipart-upload threshold, so
# any upload of it (including this resource's own) produces a multipart S3
# ETag (format "<hash>-<parts>"), which never equals filemd5()'s plain MD5 —
# causing permanent drift on every plan if etag is used for comparison.
resource "aws_s3_object" "ddgs_layer" {
  bucket      = aws_s3_bucket.artifacts.id
  key         = "ddgs-layer.zip"
  source      = var.ddgs_layer_zip_path
  source_hash = filemd5(var.ddgs_layer_zip_path)
}

# ------------------------------------------------------------------------------
# Knowledge Base data bucket — holds technical documentation for Bedrock KB
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "kb_data" {
  bucket = local.kb_data_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "kb_data" {
  bucket = aws_s3_bucket.kb_data.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "kb_data" {
  bucket                  = aws_s3_bucket.kb_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "kb_data" {
  bucket = aws_s3_bucket.kb_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
