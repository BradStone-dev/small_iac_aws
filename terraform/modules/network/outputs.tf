output "vpc" {
  value = module.vpc
}

output "sg" {
  value = {
    lb     = aws_security_group.lb_sg.id
    websvr = aws_security_group.websvr_sg.id
  }
}
