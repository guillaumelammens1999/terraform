# Sentia variables

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "stack" {
  type    = string
  default = "vpc"
}

variable "servicelevel" {
  type    = string
  default = "NO"
}

# ## VPC vars

# variable "cidr_block" {
#   type    = string
#   default = ""
# }

# variable "azs" {
#   description = "The names of the azs in which you want to deploy"
#   type        = list(string)
#   default     = ["eu-central-1a", "eu-central-1b"]
# }

# variable "private_subnets" {
#   type    = list(string)
#   default = []
# }
# variable "public_subnets" {
#   type    = list(string)
#   default = []
# }

# variable "DB_subnets" {
#   type    = list(string)
#   default = []
# }

# variable "enable_nat_gateway" {
#   default = true
#   type    = bool
# }

# variable "single_nat_gateway" {
#   default = false
#   type    = bool
# }

# variable "public_subnet_tags" {
#   type        = map(string)
#   default     = { 
#     "kubernetes.io/role/elb" = ""
#     }
# }