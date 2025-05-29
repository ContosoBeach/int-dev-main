variable "subscription_id" {
  description = "The ID of the Azure subscription where the resources will be created."
  type        = string
  default     = "3ab3f568-ab27-413c-be5a-7a1cc89a8104"
}

variable "region" {
  description = "The Azure region where the resources will be created."
  type        = string
  default     = "eastus2"
}

variable "admin_user_principal_name" {
  description = "The user principal name of the admin user to be assigned to the virtual machine."
  type        = string
  default     = "judechen@microsoft.com"
}
