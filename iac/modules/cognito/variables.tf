variable "name_prefix" {
  description = "Prefix applied to every resource name; also used as the Cognito hosted-UI domain prefix (must be globally unique)"
  type        = string
}

variable "user_pool_name" {
  description = "Display name for the Cognito User Pool"
  type        = string
  default     = "CustomerSupportGatewayPool"
}

variable "machine_client_name" {
  description = "Name for the machine-to-machine Cognito app client"
  type        = string
  default     = "CustomerSupportMachineClient"
}

variable "web_client_name" {
  description = "Name for the web (SPA) Cognito app client"
  type        = string
  default     = "CustomerSupportWebClient"
}

variable "tags" {
  description = "Tags propagated to all resources"
  type        = map(string)
  default     = {}
}
