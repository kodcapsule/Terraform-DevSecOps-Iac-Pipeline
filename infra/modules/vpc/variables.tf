variable "environment" {
  type = string
  default = "dev"
  description = "This is an environment "
}


variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidr" {
  type = list(string)
  default = ["10.0.16.0/20", "10.0.32.0/20"]
}