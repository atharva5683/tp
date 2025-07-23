variable "environment" {
  type    = string
  default = "dev"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "target_port" {
  type    = number
  default = 80
}

variable "instance_name" {
  type    = string
  default = "techeasy_devops"
}

variable "java_version" {
  type    = string
  default = "21"
}

variable "github_repo" {
  type    = string
  default = "https://github.com/atharva5683/tech_eazy_devops_atharva5683"
}

variable "app_jar_path" {
  type    = string
  default = "target/hellomvc-0.0.1-SNAPSHOT.jar"
}

variable "auto_shutdown_minutes" {
  type    = number
  default = 60
}

variable "verify_app_deployment" {
  description = "Whether to verify if the Spring Boot application is running after deployment"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for storing logs"
  type        = string
  validation {
    condition     = length(var.s3_bucket_name) > 0
    error_message = "S3 bucket name must be provided."
  }
}
