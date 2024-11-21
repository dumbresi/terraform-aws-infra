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

variable "public_key" {
  type = string
}

variable "autoscaling_minSize" {
  type    = string
  default = 1
}

variable "autoscaling_maxSize" {
  type    = string
  default = 3
}

variable "autoscaling_desiredCapacity" {
  type    = string
  default = 2
}

variable "health_check_grace_period" {
  type    = string
  default = 300
}

variable "autoscaling_cooldown" {
  type    = string
  default = 60
}

variable "autoscaling_policy_adjustment_type" {
  type    = string
  default = "ChangeInCapacity"
}

variable "autoscaling_group_name" {
  type    = string
  default = "csye6225_asg"
}

variable "cpu_high_alarm_comparison_operator" {
  type = string
}

variable "cloudwatch_metric_alarm_name" {
  type = string
}

variable "cpu_low_alarm_comparision_operatpr" {
  type = string
}

variable "cpu_low_threshold" {
  type    = string
  default = 7
}

variable "cpu_high_threshold" {
  type    = string
  default = 10
}

variable "cloudwatch_metric_treat_missing_data" {
  type = string
}

variable "cloudwatch_metric_evaluation_periods" {
  type    = string
  default = 1
}

variable "autoscaling_policy_scale_out_adjustment" {
  type = string
}

variable "autoscaling_policy_scale_in_adjustment" {
  type = string
}

variable "cloudwatch_metric_actions_enabled" {
  type = bool
}

variable "cloudwatch_metric_alarm_namespace" {
  type = string
}

variable "cloudwatch_metric_alarm_statistic" {
  type = string
}

variable "health_check_path" {
  type = string
}

variable "launch_temp_device_name" {
  type = string
}

variable "launch_temp_name_prefix" {
  type = string
}

variable "load_balancer_type" {
  type    = string
  default = "application"
}

variable "cpu_high_alarm_period" {
  type = string
}

variable "cpu_low_alarm_period" {
  type = string
}

variable "sendgrid_api_key" {
  type = string
}

variable "lambda_filename_path" {
  type    = string
  default = "../../myFunction.zip"
}

variable "lambda_function_name" {
  type    = string
  default = "my_lambbdaEmailfunction"
}

variable "lambda_handler" {
  type    = string
  default = "bootstrap"
}

variable "lambda_runtime" {
  type    = string
  default = "provided.al2"
}

variable "sns_kms_master_key_id" {
  type    = string
  default = "alias/aws/sns"
}

variable "sns_protocol" {
  type    = string
  default = "lambda"
}


