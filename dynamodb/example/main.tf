module "dynamodb" {
  source = "github.com/vitorfprado/terraform-aws-modules//dynamodb?ref=main"

  name      = var.name
  hash_key  = "customer_id"
  range_key = "order_id"

  attributes = [
    { name = "customer_id", type = "S" },
    { name = "order_id", type = "S" },
    { name = "status", type = "S" },
  ]

  global_secondary_indexes = [
    {
      name            = "by-status"
      hash_key        = "status"
      range_key       = "order_id"
      projection_type = "ALL"
    },
  ]

  ttl_enabled        = true
  ttl_attribute_name = "expires_at"

  point_in_time_recovery_enabled = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
