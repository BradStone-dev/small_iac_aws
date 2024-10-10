module "site_vpc" {
  source      = "./modules/site_vpc"
  debug_state = var.debug_state
  namespace   = var.namespace
  ssh_keypair = var.ssh_keypair
  ami_filter = var.ami_filter
  min_ec2_ammount = var.min_ec2_ammount
  max_ec2_ammount = var.max_ec2_ammount
  vpc       = module.network.vpc 
  sg        = module.network.sg
}


module "network" {
  source    = "./modules/network"
  namespace = var.namespace
}
