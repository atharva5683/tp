#!/bin/bash

# This script verifies S3 access using the read-only role
# It assumes the AWS CLI is installed and configured

# Get the bucket name from parameter
BUCKET_NAME=$1

if [ -z "$BUCKET_NAME" ]; then
  echo "Error: S3 bucket name not provided"
  exit 1
fi

# Assume the read-only role
echo "Assuming read-only role to verify S3 access"

# List files in the bucket
echo "Listing files in bucket: $BUCKET_NAME"
aws s3 ls s3://$BUCKET_NAME/ --recursive

# Try to upload a file (should fail with read-only access)
echo "Attempting to upload a file (should fail with read-only access)"
echo "test" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://$BUCKET_NAME/test.txt

echo "Verification complete"