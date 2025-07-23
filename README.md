# EC2 Deployment Automation

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
- Set s3_bucket_name = "your-unique-bucket-name" for log storage

## Deploy
```
.\deploy.ps1 -Stage dev
```
or
```
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
- Sets up port forwarding (80 → 8080)
- Auto-stops instance after configured time
- Automatically uploads logs to S3 bucket before shutdown

## Manual Application Start
To manually start the application:
```
ssh -i your-key.pem ubuntu@your-instance-ip
cd /home/ubuntu/app
java -jar target/hellomvc-0.0.1-SNAPSHOT.jar
```

## Log Management
Logs are automatically uploaded to the configured S3 bucket before instance shutdown. To manually upload logs to S3:

```
ssh -i your-key.pem ubuntu@your-instance-ip
./upload_logs.sh
```

To verify logs in S3 bucket:
1. Connect to an instance with read-only IAM role for S3:
```
ssh -i your-key.pem ubuntu@your-readonly-instance-ip
```

2. Run the following commands to list logs:
```
aws s3 ls s3://your-bucket-name/system/ --recursive
aws s3 ls s3://your-bucket-name/ --recursive
```

Note: The application EC2 instance has an IAM role with write-only permissions to the S3 bucket, so verification should be done from a separate instance with read permissions.

## Cleanup
```
terraform destroy -var-file="configs/dev_config.tfvars" -auto-approve
```