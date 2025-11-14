# User Service - Spring Boot CRUD Application

A simple Spring Boot microservice for managing users, deployed on AWS EC2 with RDS MySQL database.

## Prerequisites

- AWS Account
- AWS CLI configured with credentials
- Terraform installed
- Java 17 and Maven installed
- SSH key pair created in AWS Console

## AWS Setup

### 1. Create IAM User
1. Go to AWS Console → IAM → Users
2. Create user: `terraform-user`
3. Attach policies:
    - `AmazonEC2FullAccess`
    - `AmazonRDSFullAccess`
    - `AmazonVPCFullAccess`
4. Create access keys and save them

### 2. Configure AWS CLI
```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Enter region: eu-west-2 (or your preferred region)
```

### 3. Create SSH Key Pair
1. Go to AWS Console → EC2 → Key Pairs
2. Create key pair: `user-service-key`
3. Download the `.pem` file
4. Set permissions: `chmod 400 user-service-key.pem`

## Deployment Steps

### Step 1: Configure Terraform

Edit `terraform/terraform.tfvars`:
```hcl
aws_region        = "eu-west-2"
ami_id            = "ami-07eb36e50da2fcccd"  # Amazon Linux 2023 for eu-west-2
instance_type     = "t3.micro"
key_name          = "user-service-key"
db_instance_class = "db.t3.micro"
db_name           = "userdb"
db_username       = "admin"
db_password       = "YourSecurePassword123!"
```

### Step 2: Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy (takes ~20 minutes)
terraform apply
# Type 'yes' when prompted

# Save the outputs (EC2 IP and RDS endpoint)
terraform output
```

### Step 3: Build Spring Boot Application

```bash
cd user-service

# Build JAR file
mvn clean package

# JAR created at: target/user-service-0.0.1-SNAPSHOT.jar
```

### Step 4: Deploy Application to EC2

```bash
# Upload JAR to EC2 (replace <EC2_IP> with your EC2 public IP)
scp -i user-service-key.pem target/user-service-0.0.1-SNAPSHOT.jar ec2-user@<EC2_IP>:/tmp/

# SSH to EC2
ssh -i user-service-key.pem ec2-user@<EC2_IP>

# Move JAR to application directory
sudo mv /tmp/user-service-0.0.1-SNAPSHOT.jar /opt/user-service/user-service.jar

# Start the service
sudo systemctl start user-service

# Check status
sudo systemctl status user-service

# View logs
sudo journalctl -u user-service -f
```

## Testing the API

### Get All Users
```bash
curl http://<EC2_IP>:8080/api/users
```

### Create a User
```bash
curl -X POST http://<EC2_IP>:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'
```

### Get User by ID
```bash
curl http://<EC2_IP>:8080/api/users/1
```

### Update User
```bash
curl -X PUT http://<EC2_IP>:8080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Jane Doe","email":"jane@example.com"}'
```

### Delete User
```bash
curl -X DELETE http://<EC2_IP>:8080/api/users/1
```

## Verify Data in Database

### Connect to RDS from EC2

```bash
# SSH to EC2
ssh -i user-service-key.pem ec2-user@<EC2_IP>

# Install MySQL client
sudo yum install -y mariadb105

# Connect to database (use password from terraform.tfvars)
mysql -h <RDS_ENDPOINT> -u admin -p userdb
```

### Query Data

```sql
-- Show all tables
SHOW TABLES;

-- View all users
SELECT * FROM users;

-- Count users
SELECT COUNT(*) FROM users;

-- Exit
EXIT;
```

## Project Structure

```
user-service/
├── src/
│   └── main/
│       ├── java/com/example/userservice/
│       │   ├── UserServiceApplication.java
│       │   ├── controller/UserController.java
│       │   ├── model/User.java
│       │   └── repository/UserRepository.java
│       └── resources/
│           └── application.properties
├── pom.xml
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── terraform.tfvars
    └── user-data.sh
```

## Useful Commands

### Application Management
```bash
# Start service
sudo systemctl start user-service

# Stop service
sudo systemctl stop user-service

# Restart service
sudo systemctl restart user-service

# View logs
sudo journalctl -u user-service -f

# Check status
sudo systemctl status user-service
```

### Infrastructure Management
```bash
# View outputs
terraform output

# Destroy everything
terraform destroy
```

## Troubleshooting

### Application won't start
```bash
# Check logs
sudo journalctl -u user-service -n 100 --no-pager

# Verify Java is installed
java -version

# Check if JAR exists
ls -la /opt/user-service/
```

### Can't connect to database
```bash
# Test DNS resolution
nslookup <RDS_ENDPOINT>

# Test connectivity
nc -zv <RDS_ENDPOINT> 3306

# Check environment variables
cat /etc/systemd/system/user-service.service | grep DB_
```

### Can't SSH to EC2
```bash
# Fix key permissions
chmod 400 user-service-key.pem

# Verify EC2 is running
aws ec2 describe-instances --region eu-west-2
```

## Architecture

- **VPC**: Isolated network (10.0.0.0/16)
- **Public Subnet**: EC2 instance with public IP
- **Private Subnets**: RDS MySQL (not internet accessible)
- **Security Groups**: EC2 can access RDS, RDS blocks external access
- **Spring Boot**: Runs on EC2, connects to RDS via private network

## Cost Estimate

Using AWS Free Tier:
- EC2 t3.micro: Free (750 hours/month)
- RDS db.t3.micro: Free (750 hours/month)
- Storage: ~$2-3/month
- **Total**: ~$2-3/month (after free tier)

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
# Type 'yes' when prompted
```

This removes all AWS resources and stops billing.


**Note:** This application is generated by Claude to demonstrate the use of Terraform to create simple resources like EC2 and MySql RDS