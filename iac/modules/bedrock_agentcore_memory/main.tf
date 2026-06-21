# ──────────────────────────────────────────────────────────────────────────────
# Bedrock AgentCore Memory — long-term + short-term memory store for the
# customer-support agent. Mirrors the resource created via the Python SDK
# (MemoryManager.create_memory_and_wait) in lab_helpers/lab2_memory.py.
# ──────────────────────────────────────────────────────────────────────────────

locals {
  memory_name = "CustomerSupportMemory"
}

resource "aws_bedrockagentcore_memory" "main" {
  name                  = local.memory_name
  description           = "Customer support agent memory"
  event_expiry_duration = 90

  tags = var.tags
}

# ------------------------------------------------------------------------------
# Strategy — captures customer preferences and behavior
# ------------------------------------------------------------------------------
resource "aws_bedrockagentcore_memory_strategy" "user_preference" {
  memory_id   = aws_bedrockagentcore_memory.main.id
  name        = "CustomerPreferences"
  description = "Captures customer preferences and behavior"
  type        = "USER_PREFERENCE"
  namespaces  = ["support/customer/{actorId}/preferences/"]
}

# ------------------------------------------------------------------------------
# Strategy — stores facts extracted from conversations
# ------------------------------------------------------------------------------
resource "aws_bedrockagentcore_memory_strategy" "semantic" {
  memory_id   = aws_bedrockagentcore_memory.main.id
  name        = "CustomerSupportSemantic"
  description = "Stores facts from conversations"
  type        = "SEMANTIC"
  namespaces  = ["support/customer/{actorId}/semantic/"]
}

# ------------------------------------------------------------------------------
# Observability (enable_observability=True) — CloudWatch Logs delivery pipeline
# streaming both APPLICATION_LOGS (to a log group) and TRACES (to X-Ray).
# Mirrors ObservabilityDeliveryManager.enable_for_memory() from the
# bedrock_agentcore_starter_toolkit.
# ------------------------------------------------------------------------------

# Logs — vended log group + delivery source/destination/delivery
resource "aws_cloudwatch_log_group" "memory_logs" {
  name              = "/aws/vendedlogs/bedrock-agentcore/memory/APPLICATION_LOGS/${aws_bedrockagentcore_memory.main.id}"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_source" "memory_logs" {
  name         = "${aws_bedrockagentcore_memory.main.id}-logs-source"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagentcore_memory.main.arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "memory_logs" {
  name                      = "${aws_bedrockagentcore_memory.main.id}-logs-destination"
  delivery_destination_type = "CWL"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.memory_logs.arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "memory_logs" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.memory_logs.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.memory_logs.arn

  tags = var.tags
}

# Traces — delivery source/destination/delivery to X-Ray
resource "aws_cloudwatch_log_delivery_source" "memory_traces" {
  name         = "${aws_bedrockagentcore_memory.main.id}-traces-source"
  log_type     = "TRACES"
  resource_arn = aws_bedrockagentcore_memory.main.arn

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery_destination" "memory_traces" {
  name                      = "${aws_bedrockagentcore_memory.main.id}-traces-destination"
  delivery_destination_type = "XRAY"

  tags = var.tags
}

resource "aws_cloudwatch_log_delivery" "memory_traces" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.memory_traces.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.memory_traces.arn

  tags = var.tags
}

# ------------------------------------------------------------------------------
# SSM Parameter — memory ID consumed by the agent at runtime
# (matches lab_helpers.utils.put_ssm_parameter("/app/customersupport/agentcore/memory_id", ...))
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "memory_id" {
  name        = "/app/customersupport/agentcore/memory_id"
  type        = "String"
  value       = aws_bedrockagentcore_memory.main.id
  description = "Bedrock AgentCore Memory ID for the customer support agent"
  overwrite   = true
  tags        = var.tags
}
