data "aws_availability_zones" "available" {}

module "vpc" {
  source                           = "terraform-aws-modules/vpc/aws"
  version                          = "2.64.0"
  name                             = "${var.namespace}-vpc"
  cidr                             = "10.0.0.0/16"
  azs                              = data.aws_availability_zones.available.names
  private_subnets                  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets                   = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  
  enable_nat_gateway               = true
  single_nat_gateway               = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_security_group" "lb_sg" {
    name = "webserver load balancer"
    vpc_id = module.vpc.vpc_id

    ingress {
    description      = "Allow incoming HTTP traffic on port 80"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }

    egress  {
    description      = "Allow traffic from webservers"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    }
 }

resource "aws_security_group" "websvr_sg" {
    name = "simple_web_server"
    description = "Rules for simple golang webservers"
    vpc_id = module.vpc.vpc_id

    ingress {
    description      = "Allow incoming HTTP traffic on port 8080"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
    }

    ingress {
    description      = "Allow incoming SSH traffic"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    }

    egress  {
    description      = "Allow all outcomming traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    }
 }

