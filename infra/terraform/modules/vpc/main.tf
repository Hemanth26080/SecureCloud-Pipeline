variable "vpc_cidr"    { default = "10.0.0.0/16" }
variable "environment" { default = "staging" }

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "securecloud-${var.environment}" }
}

# Public subnet — ALB lives here (faces the internet)
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-3a"
  tags = { Name = "public-a-${var.environment}" }
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "eu-west-3b"
  tags = { Name = "public-b-${var.environment}" }
}

# Private subnet — Flask app lives here (no direct internet access)
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "eu-west-3a"
  tags = { Name = "private-app-a-${var.environment}" }
}

# Private subnet — Database lives here
resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "eu-west-3a"
  tags = { Name = "private-db-a-${var.environment}" }
}

resource "aws_subnet" "private_db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "eu-west-3b"
  tags = { Name = "private-db-b-${var.environment}" }
}

# Internet Gateway — door to the internet for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "igw-${var.environment}" }
}

# NAT Gateway — lets private subnets reach internet (for updates), but blocks inbound
resource "aws_eip" "nat" { domain = "vpc" }

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags = { Name = "nat-${var.environment}" }
}

output "vpc_id"              { value = aws_vpc.main.id }
output "public_subnet_ids"   { value = [aws_subnet.public_a.id, aws_subnet.public_b.id] }
output "private_app_subnet_ids" { value = [aws_subnet.private_app_a.id] }
output "private_db_subnet_ids"  { value = [aws_subnet.private_db_a.id, aws_subnet.private_db_b.id] }
