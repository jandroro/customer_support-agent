data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id         = data.aws_caller_identity.current.account_id
  region             = data.aws_region.current.region
  vector_bucket_name = "${local.account_id}-${local.region}-kb-vector-bucket"
  index_name         = "${local.account_id}-${local.region}-kb-vector-index"
  kb_name            = "${local.account_id}-${local.region}-kb"
  datasource_name    = "${local.account_id}-${local.region}-kb-datasource"
}

# ------------------------------------------------------------------------------
# IAM role — Bedrock service accesses S3 docs and the vector store
# ------------------------------------------------------------------------------
resource "aws_iam_role" "bedrock_service" {
  name = "${local.account_id}-${local.region}-kb-bedrock-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "bedrock_service" {
  name = "bedrock-kb-access-policy"
  role = aws_iam_role.bedrock_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.kb_data_bucket_arn, "${var.kb_data_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Effect = "Allow"
        Action = [
          "s3vectors:ListIndexes",
          "s3vectors:ListVectorBuckets",
          "s3vectors:ListVectors",
          "s3vectors:GetVectorBucket",
          "s3vectors:GetVectors",
          "s3vectors:GetIndex",
          "s3vectors:PutVectorBucketPolicy",
          "s3vectors:PutVectors",
          "s3vectors:CreateVectorBucket",
          "s3vectors:CreateIndex",
          "s3vectors:QueryVectors",
          "s3vectors:GetVectorBucketPolicy",
        ]
        Resource = "*"
      },
    ]
  })
}

# ------------------------------------------------------------------------------
# S3 Vector Bucket — backing store for Bedrock Knowledge Base embeddings
# ------------------------------------------------------------------------------
resource "aws_s3vectors_vector_bucket" "kb" {
  vector_bucket_name = local.vector_bucket_name

  encryption_configuration {
    sse_type = "AES256"
  }
}

# ------------------------------------------------------------------------------
# Vector Index — 1024-dimension cosine index (matches Titan Embed Text v2)
# ------------------------------------------------------------------------------
resource "aws_s3vectors_index" "kb" {
  vector_bucket_name = aws_s3vectors_vector_bucket.kb.vector_bucket_name
  index_name         = local.index_name
  dimension          = 1024
  distance_metric    = "cosine"
  data_type          = "float32"
}

# ------------------------------------------------------------------------------
# Knowledge Base documentation — upload 6 text files to the KB data bucket
# ------------------------------------------------------------------------------
resource "aws_s3_object" "kb_docs" {
  for_each = fileset("${path.module}/kb_docs", "*.txt")

  bucket       = var.kb_data_bucket_id
  key          = each.value
  source       = "${path.module}/kb_docs/${each.value}"
  content_type = "text/plain"
  etag         = filemd5("${path.module}/kb_docs/${each.value}")
}

# ------------------------------------------------------------------------------
# Bedrock Knowledge Base — VECTOR type, backed by S3 Vectors
# ------------------------------------------------------------------------------
resource "aws_bedrockagent_knowledge_base" "main" {
  name     = local.kb_name
  role_arn = aws_iam_role.bedrock_service.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${local.region}::foundation-model/amazon.titan-embed-text-v2:0"

      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = 1024
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.kb.index_arn
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy.bedrock_service,
    aws_s3vectors_index.kb,
  ]
}

# ------------------------------------------------------------------------------
# Data Source — S3 bucket with fixed-size chunking (200 tokens, 10% overlap)
# ------------------------------------------------------------------------------
resource "aws_bedrockagent_data_source" "main" {
  name                 = local.datasource_name
  knowledge_base_id    = aws_bedrockagent_knowledge_base.main.id
  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.kb_data_bucket_arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 200
        overlap_percentage = 10
      }
    }
  }

  depends_on = [aws_s3_object.kb_docs]
}

# ------------------------------------------------------------------------------
# SSM Parameters — Knowledge Base IDs consumed by the agent at runtime
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "knowledge_base_id" {
  name        = "/${local.account_id}-${local.region}/kb/knowledge-base-id"
  type        = "String"
  value       = aws_bedrockagent_knowledge_base.main.id
  description = "Electronics Support Knowledge Base ID"
  tags        = var.tags
}

resource "aws_ssm_parameter" "data_source_id" {
  name        = "/${local.account_id}-${local.region}/kb/data-source-id"
  type        = "String"
  value       = aws_bedrockagent_data_source.main.data_source_id
  description = "Electronics Support Data Source ID"
  tags        = var.tags
}
