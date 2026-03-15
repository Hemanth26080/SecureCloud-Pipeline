variable "subnet_ids" {}
variable "sg_db_id"   {}

resource "aws_db_subnet_group" "main" {
  name       = "securecloud-db-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "mysql" {
  identifier        = "securecloud-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"      # Free tier eligible
  allocated_storage = 20
  db_name           = "flaskdb"

  # Credentials from Secrets Manager (you set these after creation)
  manage_master_user_password = true     # AWS auto-rotates the password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.sg_db_id]

  multi_az               = false         # Set true in prod for high availability
  publicly_accessible    = false         # NEVER expose DB to internet
  storage_encrypted      = true          # Encrypt data at rest
  backup_retention_period = 7            # Keep 7 days of backups
  deletion_protection    = true          # Prevent accidental delete

  skip_final_snapshot = false
  final_snapshot_identifier = "securecloud-final-snapshot"
}

output "db_endpoint" { value = aws_db_instance.mysql.endpoint }
