provider "aws" {
  region = "ap-south-1"
}

module "secure_network" {
  source = "./modules/network"
}

module "security_groups" {
  source = "./modules/security"
  vpc_id = module.secure_network.vpc_id
}

module "compute" {
  source           = "./modules/compute"
  # Passing the IDs from the other modules into the server
  public_subnet_id = module.secure_network.public_subnet_id
  web_sg_id        = module.security_groups.web_sg_id
}