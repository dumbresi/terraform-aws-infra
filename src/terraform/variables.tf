variable "aws_region" {
  type = string
}

variable "aws_profile" {
  type = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnets_cidrs" {
  description = "CIDR for public subnets"
  type        = list(string)
}

variable "private_subnets_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI id of the image file"
  type        = string
}

variable "ami_instance_type" {
  type = string
}

variable "http_port" {
  type = string
}

variable "https_port" {
  type = string
}

variable "server_port" {
  type = string
}