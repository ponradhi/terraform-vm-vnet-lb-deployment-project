variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive = true
}
variable "client_id" {
  description = "Azure client ID"
  type        = string
  sensitive = true
}
variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
  sensitive = true
}
variable "client_secret" {
  description = "Azure client secret"
  type        = string
  sensitive = true
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
  default     = "rg-terraform-demo"
}

variable "admin_ip_cidr" {
  type = string
}

variable "vm_size" {
  type    = string
  default = "Standard_D2als_v6"
}

variable "vm_admin_username" {
  type    = string
  default = "azureuser"
}

variable "vm_admin_password" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.vm_admin_password) >= 12
    error_message = "Password must have at least 12 characters."
  }
}
