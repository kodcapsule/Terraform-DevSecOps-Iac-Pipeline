variable "environment" {
  type        = string
  default     = "dev"
  description = "This is an environment "

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of 'dev', 'staging', or 'prod'."
  }
}


variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 0))
    error_message = "The VPC CIDR block must be a valid CIDR notation."
  }
}

variable "public_subnet_cidr" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidr) == 2
    error_message = "Exactly two CIDR blocks must be provided for public subnets."
  }
}

variable "private_subnet_cidr" {
  type    = list(string)
  default = ["10.0.16.0/20", "10.0.32.0/20"]

  validation {
    condition     = length(var.private_subnet_cidr) == 2
    error_message = "Exactly two CIDR blocks must be provided for private subnets."
  }
}