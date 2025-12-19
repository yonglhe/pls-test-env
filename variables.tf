variable "prefix_name" {
  description = "Prefix to use for resource naming"
  type        = string
  default     = "dev-pls"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "North Europe"

  validation {
    condition     = can(regex("^[a-zA-Z ]+$", var.location))
    error_message = "Location must only contain letters and spaces."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev-test"
}