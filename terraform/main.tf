# Terraform configuration to deploy Spring Boot app on EC2 with RDS MySQL

# Define the AWS provider and region where resources will be created
provider "aws" {
  region = var.aws_region
}

# Create a VPC (Virtual Private Cloud) - This is your isolated network in AWS
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"  # IP address range for the VPC
  enable_dns_hostnames = true            # Enable DNS hostnames for instances
  enable_dns_support   = true            # Enable DNS resolution

  tags = {
    Name = "user-service-vpc"
  }
}

# Explicitly set DNS support with DHCP options
resource "aws_vpc_dhcp_options" "main" {
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name = "user-service-dhcp-options"
  }
}

# Associate DHCP options with VPC
resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.main.id
}

# Create an Internet Gateway - This allows resources in the VPC to access the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id  # Attach to our VPC

  tags = {
    Name = "user-service-igw"
  }
}

# Create a PUBLIC subnet - This is where the EC2 instance will live
# Public subnet has internet access through the Internet Gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"  # IP range within the VPC
  availability_zone       = "${var.aws_region}a"  # Specific data center location
  map_public_ip_on_launch = true  # Automatically assign public IPs to instances

  tags = {
    Name = "user-service-public-subnet"
  }
}

# Create a PRIVATE subnet 1 - RDS requires at least 2 subnets in different availability zones
resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "user-service-private-subnet-1"
  }
}

# Create a PRIVATE subnet 2 - Second subnet in different availability zone for RDS
resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}b"  # Different zone for high availability

  tags = {
    Name = "user-service-private-subnet-2"
  }
}

# Create a Route Table for the public subnet
# This defines how traffic is routed from the subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route all internet traffic (0.0.0.0/0) through the Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "user-service-public-rt"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2 Instance
# This acts as a virtual firewall controlling inbound and outbound traffic
resource "aws_security_group" "ec2_sg" {
  name        = "user-service-ec2-sg"
  description = "Security group for EC2 instance running Spring Boot"
  vpc_id      = aws_vpc.main.id

  # Allow inbound HTTP traffic on port 8080 (Spring Boot default port)
  ingress {
    description = "HTTP from anywhere"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from any IP (for demo purposes)
  }

  # Allow inbound SSH traffic on port 22 for remote access
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # In production, restrict this to your IP
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "user-service-ec2-sg"
  }
}

# Security Group for RDS MySQL Database
resource "aws_security_group" "rds_sg" {
  name        = "user-service-rds-sg"
  description = "Security group for RDS MySQL database"
  vpc_id      = aws_vpc.main.id

  # Allow inbound MySQL traffic on port 3306 ONLY from EC2 instances
  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]  # Only allow EC2 security group
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "user-service-rds-sg"
  }
}

# DB Subnet Group - Groups multiple subnets for RDS high availability
resource "aws_db_subnet_group" "main" {
  name       = "user-service-db-subnet-group"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "user-service-db-subnet-group"
  }
}

# RDS MySQL Database Instance
resource "aws_db_instance" "mysql" {
  identifier           = "user-service-db"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.db_instance_class  # Size of the database instance
  allocated_storage    = 20  # Storage in GB
  storage_type         = "gp2"  # General Purpose SSD

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot       = true  # Don't create snapshot when deleting (for testing)
  publicly_accessible       = false  # Database is not accessible from internet
  multi_az                  = false  # Single availability zone (cheaper for testing)
  backup_retention_period   = 0  # 0 days = no automated backups (free tier compatible)

  tags = {
    Name = "user-service-mysql-db"
  }
}

# EC2 Instance to run Spring Boot application
resource "aws_instance" "app_server" {
  ami           = var.ami_id  # Amazon Machine Image ID (operating system)
  instance_type = var.instance_type  # Size of the EC2 instance

  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true  # Assign a public IP

  key_name = var.key_name  # SSH key pair for accessing the instance

  # User data script - This runs when the instance first starts
  # It installs Java, MySQL client, and sets up environment variables
  user_data = templatefile("${path.module}/user-data.sh", {
    db_host     = aws_db_instance.mysql.address
    db_name     = var.db_name
    db_username = var.db_username
    db_password = var.db_password
  })

  tags = {
    Name = "user-service-app-server"
  }

  # Ensure RDS is created before EC2 instance
  depends_on = [aws_db_instance.mysql, aws_vpc_dhcp_options_association.main]
}