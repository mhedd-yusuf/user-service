#!/bin/bash
# User data script for EC2 instance initialization

# Update package list
sudo yum update -y

# Install Java 17 (required for Spring Boot 3.x)
sudo yum install -y java-17-amazon-corretto-headless

# Install MySQL client for testing database connectivity
sudo yum install -y mysql

# Create directory for the application
sudo mkdir -p /opt/user-service

# Set environment variables for database connection
cat << 'ENVFILE' | sudo tee -a /etc/environment
export DB_HOST=${db_host}
export DB_NAME=${db_name}
export DB_USER=${db_username}
export DB_PASSWORD=${db_password}
ENVFILE

# Create systemd service file to run Spring Boot as a service
cat << 'SERVICEFILE' | sudo tee /etc/systemd/system/user-service.service
[Unit]
Description=User Service Spring Boot Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/user-service
ExecStart=/usr/bin/java -jar /opt/user-service/user-service.jar
Restart=always
Environment="DB_HOST=${db_host}"
Environment="DB_NAME=${db_name}"
Environment="DB_USER=${db_username}"
Environment="DB_PASSWORD=${db_password}"

[Install]
WantedBy=multi-user.target
SERVICEFILE

# Enable the service (don't start yet - waiting for JAR upload)
sudo systemctl daemon-reload
sudo systemctl enable user-service

# Add RDS endpoint to /etc/hosts as backup DNS resolution
# Get the IP address of RDS and add to hosts file
RDS_IP=$(getent ahosts ${db_host} | awk '{print $1; exit}')
if [ ! -z "$RDS_IP" ]; then
    echo "$RDS_IP ${db_host}" | sudo tee -a /etc/hosts
fi