variable "aws_region" {
  description = "AWS region for the serverless application."
  type        = string
  default     = "ap-south-2"
}

variable "application_name" {
  description = "Application name used for AWS resources."
  type        = string
  default     = "NSP-4-S2-S25App"
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 15
}

variable "lambda_memory_mb" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 365
}

variable "huggingface_api_token" {
  description = "Optional Hugging Face API token. Leave empty to use the public fallback API."
  type        = string
  default     = ""
  sensitive   = true
}

variable "huggingface_model_id" {
  description = "Optional Hugging Face model ID used by the router API."
  type        = string
  default     = "meta-llama/Llama-3.2-1B-Instruct"
}

variable "lambda_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN used to encrypt Lambda environment variables."
  type        = string
  default     = ""
}
