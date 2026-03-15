module "vpc" {
  source      = "./modules/vpc"
  vpc_cidr    = var.vpc_cidr
  environment = var.environment
}

module "security" {
  source  = "./modules/security"
  vpc_id  = module.vpc.vpc_id
}

module "database" {
  source            = "./modules/database"
  subnet_ids        = module.vpc.private_db_subnet_ids
  sg_db_id          = module.security.sg_db_id
  environment       = var.environment
  db_instance_class = var.db_instance_class
}
