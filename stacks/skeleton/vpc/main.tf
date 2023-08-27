terraform {
  backend "s3" {
    bucket         = "tf-bap-guillaume-eu-central-1"
    dynamodb_table = "tf-bap-guillaume-eu-central-1"
    key            = "stacks/vpc"
    region         = "eu-central-1"
    role_arn       = "arn:aws:iam::323997921258:role/cross_account_sharing_role"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.100.10.0/24"
  enable_dns_hostnames = "true"
  enable_dns_support = "true"
  tags = {
    Name ="vpc-bap-terraform"
  }
}

# Subnets for private resources
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.100.10.64/27"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "Private Subnet 1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.100.10.96/27"
  availability_zone = "eu-central-1b"
  tags = {
    Name = "Private Subnet 2"
  }
}

# Subnets for public resources
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.100.10.0/27"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.100.10.32/27"
  availability_zone = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet 2"
  }
}

# Subnets for DB
resource "aws_subnet" "db_subnet_1" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.100.10.128/27"
  availability_zone = "eu-central-1a"
  tags = {
    Name = "DB Subnet 1"
  }
}

resource "aws_subnet" "db_subnet_2" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.100.10.160/27"
  availability_zone = "eu-central-1b"
  tags = {
    Name = "DB Subnet 2"
  }
}

# NAT gateways
resource "aws_eip" "nat_eip_1" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway_1" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.public_subnet_1.id
   tags = {
    Name = "ngw-bap-1-tf"
  }
}

resource "aws_eip" "nat_eip_2" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gateway_2" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.public_subnet_2.id
   tags = {
    Name = "ngw-bap-2-tf"
  }
}

# Route tables
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
  }

  tags = {
    Name = "Private Route Table TF"
  }
}

resource "aws_route_table_association" "private_subnet_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table TF"
  }
}

resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table" "db_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway_2.id
  }

  tags = {
    Name = "DB Route Table TF"
  }
}

resource "aws_route_table_association" "db_subnet_1" {
  subnet_id      = aws_subnet.db_subnet_1.id
  route_table_id = aws_route_table.db_route_table.id
}

resource "aws_route_table_association" "db_subnet_2" {
  subnet_id      = aws_subnet.db_subnet_2.id
  route_table_id = aws_route_table.db_route_table.id
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "igw-bap-tf"
  }
}
