module "sqs" {
  source = "github.com/vitorfprado/terraform-aws-modules//sqs?ref=main"

  name = var.name

  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 20

  create_dlq        = true
  max_receive_count = 5

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
