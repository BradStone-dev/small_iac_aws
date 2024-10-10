variable "namespace" {
  type = string
}

variable ami_filter {
  type = map(string)
}

variable min_ec2_ammount {
  type = number
}

variable max_ec2_ammount {
  type = number
}

variable "debug_state" {
  type = bool
}

# variable ec2_env_variable {
#   description = "Tags to set for all resources"
#   type        = map(string)
#   default     = {
#     MY_SPECIAL_DEBUG_VARIABLE     = "false",
#     MY_SPECIAL_VERSION = "not_found"
#   }
#   )
# }

variable "ssh_keypair" {
  type = string
}


variable "vpc" {
  type = any
}

variable "sg" {
  type = any
}