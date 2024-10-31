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

variable "root_block_device_volume_size" {
  type    = string
  default = "25"
}

variable "root_block_device_volume_type" {
  type    = string
  default = "gp2"
}

variable "postgres_port" {
  type    = string
  default = "5432"
}

variable "rds_allocated_storage" {
  type    = string
  default = "10"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_multi_az" {
  type    = string
  default = false
}

variable "rds_identifier" {
  type    = string
  default = "csye6225"
}

variable "rds_publicly_accessible" {
  type    = string
  default = false
}

variable "DB_Name" {
  type    = string
  default = "csye6225"
}

variable "rds_engine" {
  type    = string
  default = "postgres"
}

variable "DB_User" {
  type    = string
  default = "csye6225"
}

variable "DB_Password" {
  type = string
}

variable "skip_final_snapshot" {
  type    = string
  default = true
}

variable "rds_force_ssl" {
  type    = string
  default = "0"
}

variable "log_connections" {
  type    = string
  default = 1
}

variable "route53_zone_id" {
  type    = string
  default = "Z016850939BMD3U05VFFL"
}

variable "route_53_name" {
  type    = string
  default = "dev.siddumbre.me"
}

variable "route_53_type" {
  type    = string
  default = "A"
}

variable "route_53_ttl" {
  type    = string
  default = 60
}
