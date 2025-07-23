#!/bin/bash

# This script uploads EC2 logs to S3 bucket
# It should be run before instance shutdown

# Get the bucket name from parameter
BUCKET_NAME=$1

if [ -z "$BUCKET_NAME" ]; then
  echo "Error: S3 bucket name not provided"
  exit 1
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
echo "Uploading logs to S3 bucket: $BUCKET_NAME"
aws s3 cp /tmp/logs/system/ s3://$BUCKET_NAME/system/ --recursive
aws s3 cp /tmp/logs/app/ s3://$BUCKET_NAME/app/logs/ --recursive

echo "Log upload complete"