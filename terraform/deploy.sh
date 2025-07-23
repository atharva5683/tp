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

# Get the instance ID from terraform output
instance_id=$(terraform output -raw app_instance_id 2>/dev/null)
if [ -z "$instance_id" ]; then
    echo "Error: Failed to get instance ID. Make sure the instance was created properly."
    exit 1
fi

echo "Waiting for instance $instance_id to reach running state..."
max_attempts=30
attempts=0
instance_running=false

while [ $attempts -lt $max_attempts ] && [ "$instance_running" = false ]; do
    attempts=$((attempts+1))
    echo "Checking instance status (attempt $attempts of $max_attempts)..."
    
    status=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[0].Instances[0].State.Name" --output text 2>/dev/null)
    
    if [ "$status" = "running" ]; then
        instance_running=true
        echo "Instance is now running!"
        break
    else
        echo "Instance status: $status. Waiting 10 seconds..."
        sleep 10
    fi
done

if [ "$instance_running" = true ]; then
    # Instance is running, deployment is already complete
    app_ip=$(terraform output -raw app_instance_public_ip)
    verify_ip=$(terraform output -raw verification_instance_public_ip)
    app_url=$(terraform output -raw application_url)
    bucket=$(terraform output -raw s3_bucket_name)
    
    echo "Deployment complete!"
    echo "Application instance is running at IP: $app_ip"
    echo "Verification instance is running at IP: $verify_ip"
    echo "Application URL: $app_url"
    echo "S3 bucket for logs: $bucket"
    echo "Instance will auto-stop after configured time."
else
    echo "Error: Instance failed to reach running state. Deployment aborted."
    echo "You may need to manually clean up resources with: terraform destroy -var-file='configs/$1_config.tfvars' -auto-approve"
    exit 1
fi