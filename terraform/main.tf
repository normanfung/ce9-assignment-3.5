locals {
  prefix = "norman-ce9"
}

provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket = "sctp-ce9-tfstate"
    key    = "norman-ce9-module3-lesson5-infra.tfstate" # Replace the value of key to <your suggested name>.tfstat   
    region = "us-east-1"
  }
}

data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/20"
  tags = {
    Name = "${local.prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.prefix}-rtb-public"
  }
}

resource "aws_route" "default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_ssm_parameter" "app_config" {
  name      = "/${local.prefix}/config"
  type      = "String"
  value     = var.ssm_string
  overwrite = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.prefix}/db_password"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "db_password_version" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.secret_string
}


