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

  user_data = <<-EOF
              #!/bin/bash
              echo "App_Port=${var.server_port}" >> /usr/bin/.env
              echo "DB_Host=${aws_db_instance.my_rds_instance.address}">> /usr/bin/.env
              echo "DB_Port=${var.postgres_port}" >> /usr/bin/.env
              echo "DB_Name=${aws_db_instance.my_rds_instance.db_name}" >> /usr/bin/.env
              echo "DB_User=${aws_db_instance.my_rds_instance.username}" >> /usr/bin/.env
              echo "DB_Password=${aws_db_instance.my_rds_instance.password}" >> /usr/bin/.env
              echo "DB_SslMode=disable" > DB_SslMode >> /usr/bin/.env

              sudo mv /home/ec2-user/.env /usr/bin/.env
              sudo systemctl restart webapp.service
              EOF
}

resource "aws_db_instance" "my_rds_instance" {
  allocated_storage      = 10
  instance_class         = "db.t3.micro"
  multi_az               = false
  identifier             = "csye6225"
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_security_group.id]
  publicly_accessible    = false
  db_name                = "csye6225"
  engine                 = "postgres"
  username               = "sid"
  password               = "Longwood69"
  parameter_group_name   = aws_db_parameter_group.rds_parameter_group.name
  skip_final_snapshot    = true
}

resource "aws_db_parameter_group" "rds_parameter_group" {
  name        = "webapp-postgres-parameter-group"
  family      = "postgres16"
  description = "Example parameter group for PostgreSQL 16"
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id, aws_subnet.private[2].id]

  tags = {
    Name = "My DB Subnet Group"
  }
}

resource "aws_security_group" "application_security_group" {
  name   = "HTTP and HTTPS"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "database_security_group" {
  name   = "db_security_group"
  vpc_id = aws_vpc.main.id
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

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.application_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = var.http_port
  ip_protocol       = "tcp"
  to_port           = var.http_port
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.application_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = var.https_port
  ip_protocol       = "tcp"
  to_port           = var.https_port
}

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

resource "aws_vpc_security_group_ingress_rule" "allow_server" {
  security_group_id = aws_security_group.application_security_group.id
  cidr_ipv4         = var.cidr_block
  from_port         = var.server_port
  ip_protocol       = "tcp"
  to_port           = var.server_port
}
