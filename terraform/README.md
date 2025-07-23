# EC2 Deployment with S3 Log Archival

## Prerequisites
- AWS account (free tier)
- Terraform installed
- SSH key pair in Mumbai region

## Setup
1. Set AWS credentials:
```
$env:AWS_ACCESS_KEY_ID="your_access_key"
$env:AWS_SECRET_ACCESS_KEY="your_secret_key"
```

2. Update config file:
```
cd terraform
vi configs/dev_config.tfvars
```
- Set `key_name` to your SSH key name
- Set `s3_bucket_name` to a globally unique name

## Deploy
```
terraform init
terraform apply -var-file=configs/dev_config.tfvars
```

## Features
- Two EC2 instances:
  - App instance with write-only S3 access
  - Verification instance with read-only S3 access
- Spring Boot app running on port 80
- Private S3 bucket with 7-day lifecycle policy
- Log upload to S3 before instance shutdown
- Auto-shutdown after 60 minutes of inactivity

## Verify Deployment
1. Access the application:
```
http://<app_ip>/hello
```

2. Check logs in S3 (from verification instance):
```
ssh -i your-key.pem ubuntu@<verify_ip>
./verify_logs.sh
```

3. Manually upload logs (from app instance):
```
ssh -i your-key.pem ubuntu@<app_ip>
./upload_logs.sh
```

## Cleanup
```
terraform destroy -var-file=configs/dev_config.tfvars -auto-approve
```