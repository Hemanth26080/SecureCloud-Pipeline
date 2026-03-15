output "vpc_id" {
  value = module.vpc.vpc_id
}

output "db_endpoint" {
  value     = module.database.db_endpoint
  sensitive = true
}
