# EC2 Deployment with S3 Log Archival

## Prerequisites
- AWS account (free tier)
- Terraform installed
- SSH key pair in Mumbai region

## Setup
Set AWS credentials:
```
$env:AWS_ACCESS_KEY_ID="your_access_key"
$env:AWS_SECRET_ACCESS_KEY="your_secret_key"
```

Update configuration in config files:
- Edit configs/dev_config.tfvars or configs/prod_config.tfvars
- Change key_name = "dev-key" to your SSH key name
- Set s3_bucket_name to a globally unique bucket name (REQUIRED)

## Deploy
```
cd terraform
terraform init
terraform apply -var-file=configs/dev_config.tfvars
```

## Features
- Deploys two EC2 instances in Mumbai region:
  - Main application instance with write-only S3 access
  - Verification instance with read-only S3 access
- Updates system and installs:
  - Java 21 (OpenJDK 21.0.2)
  - Git
  - Maven
  - AWS CLI
- Clones and builds app from GitHub
- Runs Spring Boot application on port 80
- Creates IAM roles:
  - Read-only S3 access role (for verification instance)
  - Write-only S3 access role (for application instance)
- Creates private S3 bucket with 7-day lifecycle policy
- Uploads logs to S3 before instance shutdown:
  - System logs to s3://<bucket-name>/system/
  - Application logs to s3://<bucket-name>/app/logs/
- Auto-shutdown after configured inactivity period

## Accessing the Application
Once deployed, the application can be accessed at:
```
http://<app-instance-public-ip>/hello
```
This endpoint will display the "Hello from Spring MVC!" message.

## Verifying S3 Log Upload
SSH into the verification instance and run the verification script:
```
ssh -i your-key.pem ubuntu@<verification-instance-public-ip>
./verify_logs.sh
```
This will list all logs uploaded to S3 and demonstrate that the verification instance can read but not write to S3.

## Manual Log Upload
To manually upload logs from the application instance:
```
ssh -i your-key.pem ubuntu@<app-instance-public-ip>
./upload_logs.sh
```

## Cleanup
```
terraform destroy -var-file=configs/dev_config.tfvars -auto-approve
```