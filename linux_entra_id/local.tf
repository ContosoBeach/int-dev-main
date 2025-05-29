locals {
  prefix = "linux${random_string.postfix.result}"
  tags = {
    SecurityControl = "Ignore"
    CostControl     = "Ignore"
  }
}
