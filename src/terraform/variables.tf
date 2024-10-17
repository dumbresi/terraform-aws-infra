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
  type    = string
  default = "80"
}

variable "https_port" {
  type    = string
  default = "443"
}

variable "ssh_port" {
  type    = string
  default = "22"
}

variable "server_port" {
  type    = string
  default = "3000"
}

variable "cidr_block" {
  type    = string
  default = "0.0.0.0/0"
}

variable "root_block_device_volume_size"{
  type = string
  default ="25"
}

variable "root_block_device_volume_type"{
  type = string
  default= "gp2"
}