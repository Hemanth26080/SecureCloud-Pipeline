variable "subnet_ids"        {}
variable "sg_db_id"          {}
variable "environment"       {}
variable "db_instance_class" {}

resource "aws_db_subnet_group" "main" {
  name       = "securecloud-db-subnet-group-${var.environment}"
  subnet_ids = var.subnet_ids
  tags = { Name = "securecloud-db-subnet-group" }
}

resource "aws_db_instance" "mysql" {
  identifier        = "securecloud-mysql-${var.environment}"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.db_instance_class
  allocated_storage = 20
  db_name           = "flaskdb"

  manage_master_user_password = true
  username                    = "admin"

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_db_id]

  multi_az               = false
  publicly_accessible    = false
  storage_encrypted      = true
  backup_retention_period = 7
  skip_final_snapshot    = true

  tags = { Name = "securecloud-mysql" }
}

output "db_endpoint" { value = aws_db_instance.mysql.endpoint }
output "db_name"     { value = aws_db_instance.mysql.db_name }
