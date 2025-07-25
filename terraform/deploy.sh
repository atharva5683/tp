#!/bin/bash

if [ $# -ne 1 ] || { [ "$1" != "dev" ] && [ "$1" != "prod" ]; }; then
    echo "Usage: $0 <dev|prod>"
    exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "Error: Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
    exit 1
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Apply the full Terraform configuration
echo "Creating infrastructure..."
if ! terraform apply -var-file="configs/$1_config.tfvars" -auto-approve; then
    echo "Error: Failed to create infrastructure. Aborting deployment."
    exit 1
fi

# Get outputs
public_ip=$(terraform output -raw app_instance_public_ip)
app_url=$(terraform output -raw application_url)
bucket=$(terraform output -raw s3_bucket_name)

echo "Deployment complete!"
echo "Application URL: $app_url"
echo "S3 bucket for logs: $bucket"
echo "Instance will auto-stop after configured time."