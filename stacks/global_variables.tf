provider "aws" {
  region = local.default_static_tags.region
  default_tags {
    tags = local.default_static_tags

  }
}

provider "aws" {
  region = "eu-west-1"
  alias  = "sentinel"
  default_tags {
    tags = local.default_static_tags
  }
}

terraform {
  required_version = "~> 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4"
    }
    powerdns = {
      source  = "pan-net/powerdns"
      version = "1.5.0"
    }
    netbox = {
      source  = "e-breuninger/netbox"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.1"
    }
  }
}

locals {
  default_static_tags = {
    customer        = "guillaume"
    project         = "bap-gui"
    region          = "eu-central-1"
    stack           = var.stack
    terraform       = "1.3"
    workspace       = terraform.workspace
    serviceLevel    = terraform.workspace == "acceptance" ? "NC" : "MC"
    environmentType = upper(terraform.workspace)
    CREATE_ALERT    = true
    locksmith_name  = "bapgui"
  }
}

data "aws_caller_identity" "current" {}
