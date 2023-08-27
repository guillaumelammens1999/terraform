variable "region" {
  default = "eu-central-1"
}

variable "stack" {
  default = "ec2"
}

variable "domain_name" {
  default = "bappende.link"
}

variable "key_name" {
  description = "The EC2 key pair name"
  type        = string
  default     = "guiaug2"
}