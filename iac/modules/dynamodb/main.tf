# ------------------------------------------------------------------------------
# DynamoDB table — warranty records
# Partition key: serial_number | GSI: customer-index (customer_id)
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "warranty" {
  name         = "${var.name_prefix}-warranty"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "serial_number"

  attribute {
    name = "serial_number"
    type = "S"
  }

  attribute {
    name = "customer_id"
    type = "S"
  }

  global_secondary_index {
    name            = "customer-index"
    hash_key        = "customer_id"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Application = "CustomerSupport"
    CostCenter  = "CustomerSupport"
  })
}

# ------------------------------------------------------------------------------
# DynamoDB table — customer profiles
# Partition key: customer_id | GSI: email-index, phone-index
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "customer_profile" {
  name         = "${var.name_prefix}-customer-profile"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customer_id"

  attribute {
    name = "customer_id"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "phone"
    type = "S"
  }

  global_secondary_index {
    name            = "email-index"
    hash_key        = "email"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "phone-index"
    hash_key        = "phone"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Application = "CustomerSupport"
    CostCenter  = "CustomerSupport"
  })
}

# ------------------------------------------------------------------------------
# Seed data — customer profiles (replaces CFN PopulateDataFunction)
# ------------------------------------------------------------------------------
locals {
  customers = {
    CUST001 = jsonencode({
      customer_id               = { S = "CUST001" }
      first_name                = { S = "John" }
      last_name                 = { S = "Smith" }
      email                     = { S = "john.smith@email.com" }
      phone                     = { S = "+1-555-0101" }
      address                   = { M = { street = { S = "123 Main Street" }, city = { S = "New York" }, state = { S = "NY" }, zip_code = { S = "10001" }, country = { S = "USA" } } }
      date_of_birth             = { S = "1985-03-15" }
      registration_date         = { S = "2022-11-20" }
      tier                      = { S = "Premium" }
      communication_preferences = { M = { email = { BOOL = true }, sms = { BOOL = true }, phone = { BOOL = false } } }
      support_cases_count       = { N = "2" }
      total_purchases           = { N = "3" }
      lifetime_value            = { N = "2850" }
      notes                     = { S = "VIP customer, prefers email communication" }
    })
    CUST002 = jsonencode({
      customer_id               = { S = "CUST002" }
      first_name                = { S = "Sarah" }
      last_name                 = { S = "Johnson" }
      email                     = { S = "sarah.johnson@email.com" }
      phone                     = { S = "+1-555-0102" }
      address                   = { M = { street = { S = "456 Oak Avenue" }, city = { S = "Los Angeles" }, state = { S = "CA" }, zip_code = { S = "90210" }, country = { S = "USA" } } }
      date_of_birth             = { S = "1990-07-22" }
      registration_date         = { S = "2023-03-15" }
      tier                      = { S = "Standard" }
      communication_preferences = { M = { email = { BOOL = true }, sms = { BOOL = false }, phone = { BOOL = true } } }
      support_cases_count       = { N = "1" }
      total_purchases           = { N = "1" }
      lifetime_value            = { N = "1299.99" }
      notes                     = { S = "Tech-savvy customer, quick to resolve issues" }
    })
    CUST003 = jsonencode({
      customer_id               = { S = "CUST003" }
      first_name                = { S = "Mike" }
      last_name                 = { S = "Davis" }
      email                     = { S = "mike.davis@email.com" }
      phone                     = { S = "+1-555-0103" }
      address                   = { M = { street = { S = "789 Pine Street" }, city = { S = "Chicago" }, state = { S = "IL" }, zip_code = { S = "60601" }, country = { S = "USA" } } }
      date_of_birth             = { S = "1988-12-03" }
      registration_date         = { S = "2023-08-10" }
      tier                      = { S = "Gold" }
      communication_preferences = { M = { email = { BOOL = true }, sms = { BOOL = true }, phone = { BOOL = true } } }
      support_cases_count       = { N = "0" }
      total_purchases           = { N = "2" }
      lifetime_value            = { N = "549.98" }
      notes                     = { S = "Audio enthusiast, interested in premium products" }
    })
    CUST004 = jsonencode({
      customer_id               = { S = "CUST004" }
      first_name                = { S = "Emily" }
      last_name                 = { S = "Brown" }
      email                     = { S = "emily.brown@email.com" }
      phone                     = { S = "+1-555-0104" }
      address                   = { M = { street = { S = "321 Elm Drive" }, city = { S = "Houston" }, state = { S = "TX" }, zip_code = { S = "77001" }, country = { S = "USA" } } }
      date_of_birth             = { S = "1992-04-18" }
      registration_date         = { S = "2022-09-05" }
      tier                      = { S = "Standard" }
      communication_preferences = { M = { email = { BOOL = true }, sms = { BOOL = false }, phone = { BOOL = false } } }
      support_cases_count       = { N = "3" }
      total_purchases           = { N = "1" }
      lifetime_value            = { N = "399.99" }
      notes                     = { S = "Fitness enthusiast, uses wearables frequently" }
    })
    CUST005 = jsonencode({
      customer_id               = { S = "CUST005" }
      first_name                = { S = "Robert" }
      last_name                 = { S = "Wilson" }
      email                     = { S = "robert.wilson@email.com" }
      phone                     = { S = "+1-555-0105" }
      address                   = { M = { street = { S = "654 Maple Lane" }, city = { S = "Phoenix" }, state = { S = "AZ" }, zip_code = { S = "85001" }, country = { S = "USA" } } }
      date_of_birth             = { S = "1983-09-11" }
      registration_date         = { S = "2023-10-12" }
      tier                      = { S = "Premium" }
      communication_preferences = { M = { email = { BOOL = false }, sms = { BOOL = true }, phone = { BOOL = true } } }
      support_cases_count       = { N = "1" }
      total_purchases           = { N = "1" }
      lifetime_value            = { N = "699.99" }
      notes                     = { S = "Gaming enthusiast, prefers phone support" }
    })
  }

  warranties = {
    ABC12345678 = jsonencode({
      serial_number     = { S = "ABC12345678" }
      customer_id       = { S = "CUST001" }
      product_name      = { S = "SmartPhone Pro Max 128GB" }
      purchase_date     = { S = "2023-01-15" }
      warranty_end_date = { S = "2025-01-15" }
      warranty_type     = { S = "Extended Warranty" }
      coverage_details  = { S = "Full coverage including accidental damage, water damage, and manufacturer defects" }
      purchase_price    = { N = "1299.99" }
      store_location    = { S = "New York - 5th Avenue" }
    })
    DEF98765432 = jsonencode({
      serial_number     = { S = "DEF98765432" }
      customer_id       = { S = "CUST002" }
      product_name      = { S = "Laptop Ultra 15.6\"" }
      purchase_date     = { S = "2023-06-20" }
      warranty_end_date = { S = "2024-06-20" }
      warranty_type     = { S = "Standard Warranty" }
      coverage_details  = { S = "Hardware defects and manufacturing issues covered. Software support included" }
      purchase_price    = { N = "1299.99" }
      store_location    = { S = "Los Angeles - Beverly Hills" }
    })
    GHI11111111 = jsonencode({
      serial_number     = { S = "GHI11111111" }
      customer_id       = { S = "CUST003" }
      product_name      = { S = "Wireless Headphones Elite" }
      purchase_date     = { S = "2024-02-10" }
      warranty_end_date = { S = "2026-02-10" }
      warranty_type     = { S = "Premium Warranty" }
      coverage_details  = { S = "Comprehensive coverage including battery replacement, driver issues, and cosmetic damage" }
      purchase_price    = { N = "299.99" }
      store_location    = { S = "Chicago - Michigan Avenue" }
    })
    JKL22222222 = jsonencode({
      serial_number     = { S = "JKL22222222" }
      customer_id       = { S = "CUST004" }
      product_name      = { S = "Smart Watch Series X" }
      purchase_date     = { S = "2022-12-05" }
      warranty_end_date = { S = "2023-12-05" }
      warranty_type     = { S = "Standard Warranty" }
      coverage_details  = { S = "Hardware and software defects covered. Water resistance guaranteed" }
      purchase_price    = { N = "399.99" }
      store_location    = { S = "Houston - Galleria" }
    })
    MNO33333333 = jsonencode({
      serial_number     = { S = "MNO33333333" }
      customer_id       = { S = "CUST005" }
      product_name      = { S = "Gaming Console Pro" }
      purchase_date     = { S = "2023-11-25" }
      warranty_end_date = { S = "2024-11-25" }
      warranty_type     = { S = "Gaming Warranty" }
      coverage_details  = { S = "Controller issues, overheating protection, and hard drive replacement covered" }
      purchase_price    = { N = "699.99" }
      store_location    = { S = "Phoenix - Scottsdale" }
    })
    PQR44444444 = jsonencode({
      serial_number     = { S = "PQR44444444" }
      customer_id       = { S = "CUST001" }
      product_name      = { S = "Tablet Air 10.9\"" }
      purchase_date     = { S = "2024-03-12" }
      warranty_end_date = { S = "2025-03-12" }
      warranty_type     = { S = "Standard Warranty" }
      coverage_details  = { S = "Screen defects, battery issues, and charging port problems covered" }
      purchase_price    = { N = "599.99" }
      store_location    = { S = "New York - 5th Avenue" }
    })
    STU55555555 = jsonencode({
      serial_number     = { S = "STU55555555" }
      customer_id       = { S = "CUST001" }
      product_name      = { S = "Smart TV 65\" OLED" }
      purchase_date     = { S = "2023-08-30" }
      warranty_end_date = { S = "2025-08-30" }
      warranty_type     = { S = "Extended Warranty" }
      coverage_details  = { S = "Panel replacement, smart features, sound system, and remote control covered" }
      purchase_price    = { N = "1999.99" }
      store_location    = { S = "New York - 5th Avenue" }
    })
    VWX66666666 = jsonencode({
      serial_number     = { S = "VWX66666666" }
      customer_id       = { S = "CUST003" }
      product_name      = { S = "Bluetooth Speaker Pro" }
      purchase_date     = { S = "2024-01-08" }
      warranty_end_date = { S = "2026-01-08" }
      warranty_type     = { S = "Audio Warranty" }
      coverage_details  = { S = "Driver replacement, battery issues, and waterproofing covered" }
      purchase_price    = { N = "249.99" }
      store_location    = { S = "Chicago - Michigan Avenue" }
    })
  }
}

resource "aws_dynamodb_table_item" "customers" {
  for_each   = local.customers
  table_name = aws_dynamodb_table.customer_profile.name
  hash_key   = aws_dynamodb_table.customer_profile.hash_key
  item       = each.value
}

resource "aws_dynamodb_table_item" "warranties" {
  for_each   = local.warranties
  table_name = aws_dynamodb_table.warranty.name
  hash_key   = aws_dynamodb_table.warranty.hash_key
  item       = each.value
}

# ------------------------------------------------------------------------------
# SSM Parameters — table names consumed by the Lambda function at runtime
# ------------------------------------------------------------------------------
resource "aws_ssm_parameter" "warranty_table_name" {
  name        = "/app/customersupport/dynamodb/warranty_table_name"
  type        = "String"
  value       = aws_dynamodb_table.warranty.name
  description = "DynamoDB table name for warranty information"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}

resource "aws_ssm_parameter" "customer_profile_table_name" {
  name        = "/app/customersupport/dynamodb/customer_profile_table_name"
  type        = "String"
  value       = aws_dynamodb_table.customer_profile.name
  description = "DynamoDB table name for customer profiles"
  tags        = merge(var.tags, { Application = "CustomerSupport" })
}
