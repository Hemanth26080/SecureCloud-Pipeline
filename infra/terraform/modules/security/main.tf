variable "vpc_id" {}
variable "environment" { default = "staging" }

resource "aws_security_group" "alb" {
  name   = "securecloud-alb"
  vpc_id = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-alb" }
}

resource "aws_security_group" "app" {
  name   = "securecloud-app"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "sg-app" }
}

resource "aws_security_group" "db" {
  name   = "securecloud-db"
  vpc_id = var.vpc_id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  tags = { Name = "sg-db" }
}

output "sg_alb_id" { value = aws_security_group.alb.id }
output "sg_app_id" { value = aws_security_group.app.id }
output "sg_db_id"  { value = aws_security_group.db.id }
