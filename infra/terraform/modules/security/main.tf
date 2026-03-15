variable "vpc_id" {}

# ALB security group: anyone on internet can reach port 80/443
resource "aws_security_group" "alb" {
  name   = "sg-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # Anyone can reach the load balancer
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
}

# App security group: only ALB can reach Flask on port 5000
resource "aws_security_group" "app" {
  name   = "sg-app"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]  # ONLY from the ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB security group: only the app can reach MySQL on port 3306
resource "aws_security_group" "db" {
  name   = "sg-db"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]  # ONLY from the app
  }
  # No egress needed (DB doesn't initiate connections)
}

output "sg_alb_id" { value = aws_security_group.alb.id }
output "sg_app_id" { value = aws_security_group.app.id }
output "sg_db_id"  { value = aws_security_group.db.id }
