# resource "aws_instance" "my_ami_ec2" {
#   ami                         = var.ami_id
#   depends_on                  = [aws_db_instance.my_rds_instance]
#   instance_type               = var.ami_instance_type
#   subnet_id                   = aws_subnet.public[0].id
#   vpc_security_group_ids      = [aws_security_group.application_security_group.id]
#   associate_public_ip_address = true
#   root_block_device {
#     volume_size           = var.root_block_device_volume_size
#     volume_type           = var.root_block_device_volume_type
#     delete_on_termination = true
#   }
#   disable_api_termination = false
#   iam_instance_profile    = aws_iam_instance_profile.ec2_instance_profile.name

#   user_data = <<-EOF
#               #!/bin/bash
#               echo "App_Port=${var.server_port}" >> /usr/bin/.env
#               echo "DB_Host=${aws_db_instance.my_rds_instance.address}">> /usr/bin/.env
#               echo "DB_Port=${var.postgres_port}" >> /usr/bin/.env
#               echo "DB_Name=${aws_db_instance.my_rds_instance.db_name}" >> /usr/bin/.env
#               echo "DB_User=${aws_db_instance.my_rds_instance.username}" >> /usr/bin/.env
#               echo "DB_Password=${aws_db_instance.my_rds_instance.password}" >> /usr/bin/.env
#               echo "DB_SslMode=disable" >> /usr/bin/.env
#               echo "AWS_Region=${var.aws_region}" >> /usr/bin/.env
#               echo "S3_Bucket_Name=${aws_s3_bucket.my_s3_bucket.bucket}" >> /usr/bin/.env

#               sudo systemctl restart webapp.service

#               # Configure CloudWatch
#               sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#               -a fetch-config \
#               -m ec2 \
#               -c file:/opt/cloudwatch-config.json \
#               -s

#               EOF
# }

resource "aws_launch_template" "ec2_launch_template" {
  name          = var.launch_temp_name_prefix
  image_id      = var.ami_id
  instance_type = var.ami_instance_type
  key_name      = aws_key_pair.ssh_key_pair.key_name

  disable_api_termination = false
  depends_on              = [aws_db_instance.my_rds_instance]
  # subnet_id                   = aws_subnet.public[0].id

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = var.launch_temp_device_name
    ebs {
      volume_size           = var.root_block_device_volume_size
      volume_type           = var.root_block_device_volume_type
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_kms_key.arn
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.application_security_group.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "App_Port=${var.server_port}" >> /usr/bin/.env
              echo "DB_Host=${aws_db_instance.my_rds_instance.address}">> /usr/bin/.env
              echo "DB_Port=${var.postgres_port}" >> /usr/bin/.env
              echo "DB_Name=${aws_db_instance.my_rds_instance.db_name}" >> /usr/bin/.env
              echo "DB_User=${aws_db_instance.my_rds_instance.username}" >> /usr/bin/.env
              echo "DB_Password=${aws_db_instance.my_rds_instance.password}" >> /usr/bin/.env
              echo "DB_SslMode=disable" >> /usr/bin/.env
              echo "AWS_Region=${var.aws_region}" >> /usr/bin/.env
              echo "S3_Bucket_Name=${aws_s3_bucket.my_s3_bucket.bucket}" >> /usr/bin/.env
              echo "Sns_Topic_Arn=${aws_sns_topic.email_validation_topic.arn}" >> /usr/bin/.env

              sudo systemctl restart webapp.service

              # Configure CloudWatch
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
              -a fetch-config \
              -m ec2 \
              -c file:/opt/cloudwatch-config.json \
              -s
              
              EOF
  )
}

resource "aws_autoscaling_group" "my_autoscalar" {
  name                      = "csye6225_asg"
  desired_capacity          = var.autoscaling_desiredCapacity
  max_size                  = var.autoscaling_maxSize
  min_size                  = var.autoscaling_minSize
  health_check_grace_period = var.health_check_grace_period
  default_cooldown          = var.autoscaling_cooldown
  target_group_arns         = [aws_lb_target_group.my_lb_target_group.arn]
  vpc_zone_identifier       = [aws_subnet.public[0].id, aws_subnet.public[1].id, aws_subnet.public[2].id]

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
  }
}

resource "aws_lambda_function" "my_lambda_func" {
  filename      = var.lambda_filename_path
  function_name = var.lambda_function_name
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime

  environment {
    variables = {
      App_Port         = var.server_port
      DB_Host          = aws_db_instance.my_rds_instance.address
      DB_Port          = 5432
      DB_User          = var.DB_User
      DB_Password      = var.DB_Password
      DB_Name          = var.DB_Name
      DB_SslMode       = "disable"
      SENDGRID_API_KEY = var.sendgrid_api_key
      API_ENDPOINT     = var.route_53_name
    }
  }
}

resource "aws_sns_topic" "email_validation_topic" {
  name              = "user-email-validate"
  kms_master_key_id = var.sns_kms_master_key_id
}

resource "aws_sns_topic_subscription" "email_validate_lambda_target" {
  topic_arn = aws_sns_topic.email_validation_topic.arn
  protocol  = var.sns_protocol
  endpoint  = aws_lambda_function.my_lambda_func.arn
}

resource "aws_lambda_permission" "sns_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda_func.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.email_validation_topic.arn
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "lambda_secrets_manager_access_policy" {
  name = "SecretsManagerAccessForLambda"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "SecretsManagerAccess",
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "${aws_secretsmanager_secret.my_secret_manager.arn}"
      },
      {
        "Sid" : "AllowKMSDecrypt",
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt"
        ],
        "Resource" : "${aws_kms_key.secret_manager_key.arn}"
      }
    ]
  })
}

resource "aws_sns_topic_policy" "sns_policy" {
  arn    = aws_sns_topic.email_validation_topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission",
    ]


    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.email_validation_topic.arn,
    ]

    sid = "__default_statement_ID"
  }
}

resource "aws_iam_policy_attachment" "lambda_vpc_access" {
  name       = "lambda_vpc_access_policy_attachment"
  roles      = [aws_iam_role.iam_for_lambda.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_security_group" "lambda_security_group" {
  name        = "lambda_to_rds_sg"
  description = "Security group for Lambda function to access RDS"
  vpc_id      = aws_vpc.main.id
}
resource "aws_vpc_security_group_ingress_rule" "lambda_ingress" {
  security_group_id = aws_security_group.lambda_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = 0
  ip_protocol       = "TCP"
  to_port           = 0
}
resource "aws_vpc_security_group_ingress_rule" "allow_postgres_lambda" {
  security_group_id            = aws_security_group.database_security_group.id
  referenced_security_group_id = aws_security_group.lambda_security_group.id
  # cidr_ipv4         = var.cidr_block
  from_port   = var.postgres_port
  ip_protocol = "TCP"
  to_port     = var.postgres_port
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_lamda" {
  security_group_id = aws_security_group.lambda_security_group.id
  cidr_ipv4         = var.cidr_block
  ip_protocol       = -1
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = var.autoscaling_policy_scale_out_adjustment
  adjustment_type        = var.autoscaling_policy_adjustment_type
  cooldown               = var.autoscaling_cooldown
  autoscaling_group_name = aws_autoscaling_group.my_autoscalar.name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  scaling_adjustment     = var.autoscaling_policy_scale_in_adjustment
  adjustment_type        = var.autoscaling_policy_adjustment_type
  cooldown               = var.autoscaling_cooldown
  autoscaling_group_name = aws_autoscaling_group.my_autoscalar.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-high"
  comparison_operator = var.cpu_high_alarm_comparison_operator
  evaluation_periods  = var.cloudwatch_metric_evaluation_periods
  metric_name         = var.cloudwatch_metric_alarm_name
  namespace           = var.cloudwatch_metric_alarm_namespace
  period              = var.cpu_high_alarm_period
  statistic           = var.cloudwatch_metric_alarm_statistic
  threshold           = var.cpu_high_threshold
  alarm_description   = "Scale out if CPU > 10%"
  actions_enabled     = var.cloudwatch_metric_actions_enabled
  treat_missing_data  = var.cloudwatch_metric_treat_missing_data

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.my_autoscalar.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-low"
  comparison_operator = var.cpu_low_alarm_comparision_operatpr
  evaluation_periods  = var.cloudwatch_metric_evaluation_periods
  metric_name         = var.cloudwatch_metric_alarm_name
  namespace           = var.cloudwatch_metric_alarm_namespace
  period              = var.cpu_low_alarm_period
  statistic           = var.cloudwatch_metric_alarm_statistic
  threshold           = var.cpu_low_threshold
  alarm_description   = "Scale in if CPU < 7%"
  actions_enabled     = var.cloudwatch_metric_actions_enabled
  treat_missing_data  = var.cloudwatch_metric_treat_missing_data

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.my_autoscalar.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}


resource "aws_autoscaling_attachment" "aws_attahment" {
  autoscaling_group_name = aws_autoscaling_group.my_autoscalar.id
  lb_target_group_arn    = aws_lb_target_group.my_lb_target_group.arn
}

resource "aws_lb" "my_load_balancer" {
  name                       = "my-load-balancer"
  internal                   = false
  load_balancer_type         = var.load_balancer_type
  security_groups            = [aws_security_group.load_balancer_security_group.id]
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  enable_deletion_protection = false
}

resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = var.http_port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_lb_target_group.arn
  }
}

resource "aws_lb_target_group" "my_lb_target_group" {
  name     = "lb-target-group"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = var.server_port
    healthy_threshold   = 5
    unhealthy_threshold = 10
  }
}

# resource "aws_lb_target_group_attachment" "my_lb_tgt_gp_attachment" {
#   target_group_arn = aws_lb_target_group.my_lb_target_group.arn
#   target_id        = aws_instance.my_ami_ec2.id
#   port             = 3000
# }

resource "aws_db_instance" "my_rds_instance" {
  allocated_storage      = var.rds_allocated_storage
  instance_class         = var.rds_instance_class
  multi_az               = var.rds_multi_az
  identifier             = var.rds_identifier
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_security_group.id]
  publicly_accessible    = var.rds_publicly_accessible
  db_name                = var.DB_Name
  engine                 = var.rds_engine
  username               = var.DB_User
  password               = random_password.password.result
  parameter_group_name   = aws_db_parameter_group.rds_parameter_group.name
  skip_final_snapshot    = var.skip_final_snapshot
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds_kms_key.arn
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket        = "sid-bucket-${random_uuid.bucket_uuid.result}"
  force_destroy = true


}

resource "aws_s3_bucket_server_side_encryption_configuration" "my_s3_bucket_encryption" {
  bucket = aws_s3_bucket.my_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.my_s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "_bucket_lifecycle" {
  bucket = aws_s3_bucket.my_s3_bucket.id

  rule {
    id     = "transition-to-IA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "cloudwatch_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_access_policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2_secret_manager_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_secretManager_access_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-s3-access-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3-access-policy"
  description = "Policy to allow EC2 instances access to the specific S3 bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.my_s3_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.my_s3_bucket.bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_access_policy" {
  name        = "CloudWatchAccessPolicy"
  description = "Policy to allow CloudWatch access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_secretManager_access_policy" {
  name        = "SecretsManagerAcessPolicy"
  description = "Policy to allow CloudWatch access"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "SecretsManagerAccess",
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "${aws_secretsmanager_secret.my_secret_manager.arn}"
      },
      {
        "Sid" : "AllowKMSDecrypt",
        "Effect" : "Allow",
        "Action" : [
          "kms:Decrypt"
        ],
        "Resource" : "${aws_kms_key.secret_manager_key.arn}"
      }
    ]
  })
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(var.public_subnets_cidrs, count.index)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnets_cidrs, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = var.cidr_block
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidrs)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidrs)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_db_parameter_group" "rds_parameter_group" {
  name        = "webapp-postgres-parameter-group"
  family      = "postgres16"
  description = "Example parameter group for PostgreSQL 16"
  parameter {
    name  = "rds.force_ssl"
    value = var.rds_force_ssl
  }

  parameter {
    name  = "log_connections"
    value = var.log_connections
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id, aws_subnet.private[2].id]

  tags = {
    Name = "My DB Subnet Group"
  }
}

resource "aws_security_group" "application_security_group" {
  name   = "application_security_group"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "load_balancer_security_group" {
  name   = "lb_security_group"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "database_security_group" {
  name   = "db_security_group"
  vpc_id = aws_vpc.main.id
}

resource "aws_route53_record" "my_record" {
  zone_id = var.route53_zone_id
  name    = var.route_53_name
  type    = var.route_53_type
  # ttl     = var.route_53_ttl
  # records = [aws_instance.my_ami_ec2.public_ip]
  alias {
    name                   = aws_lb.my_load_balancer.dns_name
    zone_id                = aws_lb.my_load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_postgres" {
  security_group_id            = aws_security_group.database_security_group.id
  referenced_security_group_id = aws_security_group.application_security_group.id
  from_port                    = var.postgres_port
  ip_protocol                  = "tcp"
  to_port                      = var.postgres_port
}

resource "aws_vpc_security_group_egress_rule" "allow_traffic_from_db" {
  security_group_id = aws_security_group.database_security_group.id
  cidr_ipv4         = var.cidr_block
  ip_protocol       = -1
}

resource "aws_vpc_security_group_ingress_rule" "allow_load_balancer_traffic" {
  security_group_id            = aws_security_group.application_security_group.id
  referenced_security_group_id = aws_security_group.load_balancer_security_group.id
  from_port                    = var.http_port
  ip_protocol                  = "tcp"
  to_port                      = var.http_port
}

resource "aws_security_group_rule" "allow_ipv6_to_lb" {
  type              = "ingress"
  from_port         = 80 # Adjust for your specific ports
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = []
  ipv6_cidr_blocks  = ["::/0"] # Allow all IPv6 addresses
  security_group_id = aws_security_group.load_balancer_security_group.id
}

# resource "aws_vpc_security_group_ingress_rule" "allow_http" {
#   security_group_id = aws_security_group.application_security_group.id
#   cidr_ipv4         = var.cidr_block
#   from_port         = var.http_port
#   ip_protocol       = "tcp"
#   to_port           = var.http_port
# }

resource "aws_vpc_security_group_ingress_rule" "lb_allow_http" {
  security_group_id = aws_security_group.load_balancer_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = var.http_port
  ip_protocol       = "tcp"
  to_port           = var.http_port
}

resource "aws_vpc_security_group_egress_rule" "lb_egress_ipv4" {
  security_group_id = aws_security_group.load_balancer_security_group.id
  cidr_ipv4         = var.cidr_block
  ip_protocol       = -1
}

resource "aws_vpc_security_group_egress_rule" "lb_egress_ipv6" {
  security_group_id = aws_security_group.load_balancer_security_group.id
  cidr_ipv6         = "::/0"
  ip_protocol       = -1
}
# resource "aws_vpc_security_group_ingress_rule" "allow_https" {
#   security_group_id = aws_security_group.application_security_group.id
#   cidr_ipv4         = var.cidr_block
#   from_port         = var.https_port
#   ip_protocol       = "tcp"
#   to_port           = var.https_port
# }

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.application_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.application_security_group.id
  cidr_ipv4         = var.cidr_block
  ip_protocol       = -1
}

resource "aws_vpc_security_group_ingress_rule" "allow_server_port" {
  security_group_id = aws_security_group.application_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = var.server_port
  ip_protocol       = "tcp"
  to_port           = var.server_port
}

resource "random_uuid" "bucket_uuid" {}

resource "aws_key_pair" "ssh_key_pair" {
  key_name   = "dev-key"
  public_key = var.public_key
}

resource "aws_kms_key" "ec2_kms_key" {
  description             = "KMS key for ec2"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_key" "rds_kms_key" {
  description             = "KMS key for RDS"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_key" "s3_kms_key" {
  description             = "KMS key for s3"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_key" "secret_manager_key" {
  description             = "KMS key for secret manager"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_secretsmanager_secret" "my_secret_manager" {
  name       = "MySecretManager"
  kms_key_id = aws_kms_key.secret_manager_key.id
}

resource "aws_secretsmanager_secret_version" "example" {
  secret_id = aws_secretsmanager_secret.my_secret_manager.id
  secret_string = jsonencode({
    DB_Password      = random_password.password.result
    SENDGRID_API_KEY = var.sendgrid_api_key
  })
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_kms_key_policy" "ec2_policy" {
  key_id = aws_kms_key.ec2_kms_key.id
  policy = jsonencode({
    "Id" : "key-consolepolicy-3",
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow access for Key Administrators",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:RotateKeyOnDemand"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow use of the key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        },
        "Action" : [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        "Resource" : "*",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
  })

}

resource "aws_kms_key_policy" "kms_rds_policy" {
  key_id = aws_kms_key.rds_kms_key.id
  policy = jsonencode({
    "Id" : "key-consolepolicy-3",
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "${aws_kms_key.rds_kms_key.arn}"
      },
      {
        "Sid" : "Allow access for Key Administrators",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:RotateKeyOnDemand"
        ],
        "Resource" : "${aws_kms_key.rds_kms_key.arn}"
      },
      {
        "Sid" : "Allow use of the key",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        "Resource" : "${aws_kms_key.rds_kms_key.arn}"
      },
      {
        "Sid" : "Allow attachment of persistent resources",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        },
        "Action" : [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ],
        "Resource" : "${aws_kms_key.rds_kms_key.arn}",
        "Condition" : {
          "Bool" : {
            "kms:GrantIsForAWSResource" : "true"
          }
        }
      }
    ]
  })
}

resource "aws_kms_key_policy" "kms_s3_policy" {
  key_id = aws_kms_key.s3_kms_key.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "${aws_kms_key.s3_kms_key.arn}"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "${aws_kms_key.s3_kms_key.arn}"
      }
    ]
  })
}

resource "aws_kms_key_policy" "kms_secrets_manager_policy" {
  key_id = aws_kms_key.secret_manager_key.arn
  policy = jsonencode({
    "Id" : "key-consolepolicy-3",
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "Allow Use of Key for ec2",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.ec2_role.name}"
        },
        "Action" : [
          "kms:Decrypt",
          "kms:DescribeKey"
        ],
        "Resource" : "${aws_kms_key.secret_manager_key.arn}"
      },
      {
        "Sid" : "Allow Use of Key for lambda",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.iam_for_lambda.name}"
        },
        "Action" : [
          "kms:Decrypt"
        ],
        "Resource" : "${aws_kms_key.secret_manager_key.arn}"
      }
    ]
  })
}



data "aws_caller_identity" "current" {}