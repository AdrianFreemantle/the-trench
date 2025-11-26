variable "environment" {
  type        = string
  description = "Deployment environment suffix, for example dev, test, prod"
}

variable "owner" {
  type        = string
  description = "Owner tag value for Azure resources"
  default     = "adrian"
}

variable "cost_center" {
  type        = string
  description = "Cost center tag value for Azure resources"
  default     = "aks-lab"
}
