#!/bin/bash

# This script uploads EC2 logs to S3 bucket
# It should be run before instance shutdown

# Get the bucket name from parameter, environment variable, or instance metadata
BUCKET_NAME=$1

if [ -z "$BUCKET_NAME" ]; then
  # Try to get from environment variable if not provided as parameter
  BUCKET_NAME=$S3_BUCKET_NAME
  
  if [ -z "$BUCKET_NAME" ]; then
    # Try to get from instance tags
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    if [ -n "$INSTANCE_ID" ] && [ -n "$REGION" ]; then
      # Get the bucket name from the instance tags
      BUCKET_NAME=$(aws ec2 describe-tags --region $REGION --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=s3_bucket_name" --query "Tags[0].Value" --output text)
    fi
    
    if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" == "None" ]; then
      echo "Error: S3 bucket name not found"
      exit 1
    fi
  fi
fi

# Create log directories in S3 bucket structure
mkdir -p /tmp/logs/system
mkdir -p /tmp/logs/app

# Copy system logs
cp /var/log/cloud-init-output.log /tmp/logs/system/
cp /var/log/cloud-init.log /tmp/logs/system/
cp /var/log/syslog /tmp/logs/system/

# Copy application logs
cp /home/ubuntu/app/app.log /tmp/logs/app/ 2>/dev/null
cp -r /home/ubuntu/app/logs/* /tmp/logs/app/ 2>/dev/null

# Upload logs to S3
echo "Uploading system logs to S3"
aws s3 cp /tmp/logs/system/ s3://$BUCKET_NAME/system/ --recursive

echo "Uploading application logs to S3"
aws s3 cp /tmp/logs/app/ s3://$BUCKET_NAME/ --recursive

echo "Log upload complete"