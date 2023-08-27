terraform {
  backend "s3" {
    bucket         = "tf-bap-guillaume-eu-central-1"
    dynamodb_table = "tf-bap-guillaume-eu-central-1"
    key            = "stacks/efs"
    region         = "eu-central-1"
    role_arn       = "arn:aws:iam::323997921258:role/cross_account_sharing_role"
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket   = "tf-bap-guillaume-eu-central-1"
    key      = join("/", ["env:", terraform.workspace, "stacks/vpc"])
    region   = "eu-central-1"
    role_arn = "arn:aws:iam::323997921258:role/cross_account_sharing_role"
  }
}

resource "aws_efs_file_system" "efs" {
  creation_token = "my-token"
}

resource "aws_efs_mount_target" "private_subnet_1" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = data.terraform_remote_state.vpc.outputs.DB_subnets[0]
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_efs_mount_target" "private_subnet_2" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = data.terraform_remote_state.vpc.outputs.DB_subnets[1]
  security_groups = [aws_security_group.efs_sg.id]
}

resource "aws_security_group" "efs_sg" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  name   = "allow_nfs"

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
