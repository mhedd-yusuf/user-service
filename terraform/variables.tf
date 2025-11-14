# Variables file - Allows customization without modifying main.tf

# AWS Region where resources will be created
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# AMI ID for EC2 instance (Amazon Linux 2023)
# You need to get the latest AMI ID for your region
variable "ami_id" {
  description = "AMI ID for EC2 instance (Amazon Linux 2023)"
  type        = string
  default     = "ami-0c7217cdde317cfec"  # Amazon Linux 2023 in us-east-1
}

# EC2 Instance size
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"  # Free tier eligible
}

# SSH Key pair name (must be created in AWS first)
variable "key_name" {
  description = "SSH key pair name for EC2 access"
  type        = string
  # You must create this key pair in AWS Console before running terraform
}

# RDS Database Instance size
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"  # Free tier eligible
}

# Database name
variable "db_name" {
  description = "Name of the MySQL database"
  type        = string
  default     = "userdb"
}

# Database master username
variable "db_username" {
  description = "Master username for MySQL database"
  type        = string
  default     = "admin"
}

# Database master password
# IMPORTANT: In production, use AWS Secrets Manager or environment variables
variable "db_password" {
  description = "Master password for MySQL database"
  type        = string
  sensitive   = true  # Prevents password from showing in logs
}