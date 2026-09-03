locals { prefix = "${var.name}-${var.environment}" }

module "network" {
  source = "../../modules/network"
  name = local.prefix
  vpc_cidr = var.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway
}

module "security" {
  source = "../../modules/security"
  name = local.prefix
  vpc_id = module.network.vpc_id
  vpc_cidr = var.vpc_cidr
  allowed_cidr = var.allowed_cidr
}

module "storage" {
  source = "../../modules/storage"
  name = local.prefix
}

module "database" {
  source = "../../modules/database"
  name = local.prefix
  subnet_ids = module.network.private_subnet_ids
  security_group_id = module.security.rds_security_group_id
}

module "compute" {
  source = "../../modules/compute"
  name = local.prefix
  public_subnet_ids = module.network.public_subnet_ids
  private_subnet_id = module.network.private_subnet_ids[0]
  alb_security_group_id = module.security.alb_security_group_id
  app_security_group_id = module.security.app_security_group_id
  database_url_secret_arn = module.database.app_secret_arn
  image_tag = var.app_image_tag
}

module "events" {
  source = "../../modules/events"
  name = local.prefix
  private_subnet_ids = module.network.private_subnet_ids
  lambda_security_group_id = module.security.lambda_security_group_id
  evidence_bucket_name = module.storage.evidence_bucket_name
  database_url_secret_arn = module.database.app_secret_arn
}

module "observability" {
  source = "../../modules/observability"
  name = local.prefix
  alert_email = var.alert_email
  lambda_function_name = module.events.function_name
  alb_arn_suffix = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
}

resource "aws_guardduty_detector" "this" {
  count = var.enable_guardduty ? 1 : 0
  enable = true
}
