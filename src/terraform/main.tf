resource "aws_instance" "my_ami_ec2" {
  ami                         = var.ami_id
  depends_on                  = [aws_db_instance.my_rds_instance]
  instance_type               = var.ami_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.application_security_group.id]
  associate_public_ip_address = true
  root_block_device {
    volume_size           = var.root_block_device_volume_size
    volume_type           = var.root_block_device_volume_type
    delete_on_termination = true
  }
  disable_api_termination = false
  iam_instance_profile    = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
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

              sudo systemctl restart webapp.service

              # Configure CloudWatch
              sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
              -a fetch-config \
              -m ec2 \
              -c file:/opt/cloudwatch-config.json \
              -s
              
              EOF
}

resource "aws_lb" "my_load_balancer" {
  name                       = "my-load-balancer"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.load_balancer_security_group.id]
  subnets                    = [for subnet in aws_subnet.public : subnet.id]
  enable_deletion_protection = false
}

resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_lb_target_group.arn
  }
}

resource "aws_lb_target_group" "my_lb_target_group" {
  name     = "lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "my_lb_tgt_gp_attachment" {
  target_group_arn = aws_lb_target_group.my_lb_target_group.arn
  target_id        = aws_instance.my_ami_ec2.id
  port             = 3000
}

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
  password               = var.DB_Password
  parameter_group_name   = aws_db_parameter_group.rds_parameter_group.name
  skip_final_snapshot    = var.skip_final_snapshot
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

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
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
  security_group_id = aws_security_group.application_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = var.http_port
  ip_protocol       = "tcp"
  to_port           = var.http_port
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

resource "aws_vpc_security_group_egress_rule" "lb_egress" {
  security_group_id = aws_security_group.load_balancer_security_group.id
  cidr_ipv4 = var.cidr_block
  ip_protocol = -1
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