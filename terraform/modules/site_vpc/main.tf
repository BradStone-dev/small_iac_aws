locals {
  debug_variable = var.debug_state ? "true" : "false"
}

data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/cloud_config.yaml", { debug_variable = local.debug_variable })
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }
  owners = [var.ami_filter.owner]
}

resource "aws_launch_template" "webserver" {
  name_prefix   = var.namespace
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"  # should be chousen dynamucly 
  user_data     = data.cloudinit_config.config.rendered
  key_name      = var.ssh_keypair
  vpc_security_group_ids = [var.sg.websvr]
}


resource "aws_autoscaling_group" "webserver" {
  name                = "${var.namespace}-asg"
  min_size            = var.min_ec2_ammount
  max_size            = var.max_ec2_ammount
  vpc_zone_identifier = var.vpc.private_subnets
  target_group_arns   = module.alb.target_group_arns
  launch_template {
    id      = aws_launch_template.webserver.id
    version = aws_launch_template.webserver.latest_version
  }
  tag {
    key = "runner"
    value = "docker"
    propagate_at_launch = true
  }
}

module "alb" {
  source             = "terraform-aws-modules/alb/aws"
  version            = "~> 5.0"
  name               = var.namespace
  load_balancer_type = "application"
  vpc_id             = var.vpc.vpc_id
  subnets            = var.vpc.public_subnets
  security_groups    = [var.sg.lb]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    { name_prefix      = "web"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "instance"
    }
  ]
}
