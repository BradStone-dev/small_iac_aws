variable "namespace" {
  description = "The project namespace to use for unique resource naming"
  type        = string
}

variable "ssh_keypair" {
  description = "SSH keypair to use for EC2 instance"
  default     = null
  type        = string
}

variable "region" {
  description = "AWS region"
  default     = "eu-north-1"
  type        = string
}

variable ami_filter{
  description = "Filter amazon image for ec2 instance creation"
  type = map(string)
  }

variable min_ec2_ammount{
  description = "How many ec2 we want at the start"
  type = number
    validation {
    condition     = var.min_ec2_ammount > 0
    error_message = "We need at least one ec2"
  }
}

variable max_ec2_ammount{
  description = "Max ec2 instances for autoscale group"
  type = number
}

variable "debug_state" {
  description = "Enable debug info on web servers"
  type = bool
  default = false
}