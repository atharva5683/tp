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
instance_id=$(terraform output -raw instance_id 2>/dev/null)
if [ -z "$instance_id" ]; then
    echo "Error: Failed to get instance ID"
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
    public_ip=$(terraform output -raw public_ip)
    echo "Instance is running at IP: $public_ip"
    
    # Wait for application to start and verify it's working
    echo "Waiting for application to start..."
    app_max_attempts=20
    app_attempts=0
    app_running=false
    
    while [ $app_attempts -lt $app_max_attempts ] && [ "$app_running" = false ]; do
        app_attempts=$((app_attempts+1))
        echo "Checking application (attempt $app_attempts of $app_max_attempts)..."
        
        if curl -f -s "http://$public_ip/hello" > /dev/null 2>&1; then
            app_running=true
            echo "Application is responding!"
            break
        else
            echo "Application not ready yet. Waiting 15 seconds..."
            sleep 15
        fi
    done
    
    if [ "$app_running" = true ]; then
        echo "Deployment successful! Application is running at: http://$public_ip/hello"
    else
        echo "WARNING: Application may not be running correctly. Check instance logs."
        echo "SSH to instance: ssh -i your-key.pem ubuntu@$public_ip"
    fi
    
    echo "Instance will auto-stop after configured time."
else
    echo "Error: Instance failed to reach running state"
    exit 1
fi