locals {
  primary_region   = "eastus"
  secondary_region = "westus"
  prefix           = "redisent${random_string.postfix.result}"
  tags = {
    SecurityControl = "Ignore"
    CostControl     = "Ignore"
  }
}
