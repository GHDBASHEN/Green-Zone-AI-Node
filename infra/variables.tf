variable "region" {
  description = "AWS Region"
  default     = "eu-north-1"
}

variable "client_name" {
  description = "Unique identifier for the client"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  default     = "10.0.0.0/16"
}