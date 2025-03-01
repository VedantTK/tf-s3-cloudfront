variable "aws_access_key_id" {
  description = "AWS Access Key ID for authentication"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for authentication"
  type        = string
  sensitive   = true
}

variable "Project" {
  description = "The project name for resource tagging"
  type        = string
  default     = "BrainPuzzleGames"
}

variable "ManagedBy" {
  description = "The tool managing the resources"
  type        = string
  default     = "Terraform"
}
