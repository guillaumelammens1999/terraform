output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

output "DB_subnets" {
  description = "List of IDs of DB subnets"
  value       = [aws_subnet.db_subnet_1.id, aws_subnet.db_subnet_2.id]
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}