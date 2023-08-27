terraform {
  backend "s3" {
    bucket         = "tf-bap-guillaume-eu-central-1"
    dynamodb_table = "tf-bap-guillaume-eu-central-1"
    key            = "stacks/rds"
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


resource "aws_db_subnet_group" "database" {
  name       = "database sg terraform"
  subnet_ids = data.terraform_remote_state.vpc.outputs.DB_subnets

  tags = {
    Name = "Database subnet group"
  }
}
# Expensive Database 
resource "aws_db_instance" "default" {
  identifier                = "database-bap-terraform"
  allocated_storage         = 400
  storage_type              = "gp2"
  engine                    = "mysql"
  engine_version            = "8.0.32"
  instance_class            = "db.m5.large"
  # name                      = "databaseterraform"
  username                  = "admin"
  password                  = "adminadmin"
  parameter_group_name      = "default.mysql8.0"
  multi_az                  = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "foo"
  publicly_accessible       = false

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.sg.id]

  tags = {
    Name = "DB instance"
  }
}



# For this example, I am considering a basic security group that allows all outbound and inbound traffic. 
# You should restrict the inbound and outbound traffic according to your application requirements in a production environment.

resource "aws_security_group" "sg" {
  name   = "DatabaseSG_TF"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = []
  }
}