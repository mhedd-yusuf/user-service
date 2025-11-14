# Outputs file - Displays important information after terraform apply

# VPC ID for debugging
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

# EC2 instance public IP address
output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

# RDS database endpoint (hostname and port)
output "rds_endpoint" {
  description = "RDS MySQL database endpoint"
  value       = aws_db_instance.mysql.endpoint
}

# RDS database address (hostname only)
output "rds_address" {
  description = "RDS MySQL database address"
  value       = aws_db_instance.mysql.address
}

# Application URL
output "application_url" {
  description = "URL to access the Spring Boot application"
  value       = "http://${aws_instance.app_server.public_ip}:8080/api/users"
}

# SSH command to connect to EC2 instance
output "ssh_command" {
  description = "SSH command to connect to EC2 instance"
  value       = "ssh -i ${var.key_name}.pem ec2-user@${aws_instance.app_server.public_ip}"
}