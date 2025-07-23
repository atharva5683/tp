# EC2 Deployment Automation

## Prerequisites
- AWS account (free tier)
- Terraform installed
- SSH key pair in Mumbai region

## Setup

1. Set AWS credentials:
   ```powershell
   $env:AWS_ACCESS_KEY_ID="your_access_key"
   $env:AWS_SECRET_ACCESS_KEY="your_secret_key"
   ```

2. Update SSH key name in config files:
   - Edit `configs/dev_config.tfvars` or `configs/prod_config.tfvars`
   - Change `key_name = "dev-key"` to your SSH key name
   - Optionally set `verify_app_deployment = false` to skip application verification

## Deploy

```powershell
.\deploy.ps1 -Stage dev
```
or
```bash
./deploy.sh dev
```

## Features
- Deploys Ubuntu EC2 instance in Mumbai region
- Updates system and installs:
  - Java 21 (OpenJDK 21.0.2)
  - Git
  - Maven
  - Terraform
- Clones and builds app from GitHub
- Initializes Terraform on the instance
- Builds with "mvn clean package"
- Tests the application startup
- Verifies the Spring Boot application is running and responding to HTTP requests
- Sets up port forwarding (80 → 8080)
- Auto-stops instance after configured time

## Manual Application Start
To manually start the application:
```bash
ssh -i your-key.pem ubuntu@your-instance-ip
cd /home/ubuntu/app
java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar
```

## Cleanup
```
terraform destroy -var-file="configs/dev_config.tfvars" -auto-approve
```