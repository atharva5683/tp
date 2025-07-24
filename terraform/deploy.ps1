param ([string]$Stage)

if ($Stage -ne "dev" -and $Stage -ne "prod") {
    Write-Error "Stage must be either 'dev' or 'prod'"
    exit 1
}

if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY) {
    Write-Error "Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
    exit 1
}

# Initialize Terraform
Write-Host "Initializing Terraform..."
terraform init

# Apply the full Terraform configuration
Write-Host "Creating infrastructure..."
try {
    terraform apply -var-file="configs/${Stage}_config.tfvars" -auto-approve
} catch {
    Write-Error "Failed to create infrastructure. Aborting deployment."
    exit 1
}

# Get the instance ID from terraform output
try {
    $instanceId = terraform output -raw instance_id
} catch {
    Write-Error "Failed to get instance ID. Make sure the instance was created properly."
    exit 1
}

Write-Host "Waiting for instance $instanceId to reach running state..."
$maxAttempts = 30
$attempts = 0
$instanceRunning = $false

do {
    $attempts++
    Write-Host "Checking instance status (attempt $attempts of $maxAttempts)..."
    
    try {
        $status = aws ec2 describe-instances --instance-ids $instanceId --query "Reservations[0].Instances[0].State.Name" --output text
        
        if ($status -eq "running") {
            $instanceRunning = $true
            Write-Host "Instance is now running!"
            break
        } else {
            Write-Host "Instance status: $status. Waiting 10 seconds..."
            Start-Sleep -Seconds 10
        }
    } catch {
        Write-Host "Error checking instance status. Waiting 10 seconds..."
        Start-Sleep -Seconds 10
    }
} while ($attempts -lt $maxAttempts -and -not $instanceRunning)

if ($instanceRunning) {
    # Instance is running, deployment is already complete
    try {
        $publicIp = terraform output -raw public_ip
        Write-Host "Deployment complete! Instance is running at IP: $publicIp"
        Write-Host "Instance will auto-stop after configured time."
    } catch {
        Write-Error "Failed to get public IP, but instance is running."
    }
} else {
    Write-Error "Instance failed to reach running state. Deployment aborted."
    Write-Host "You may need to manually clean up resources with: terraform destroy -var-file='configs/${Stage}_config.tfvars' -auto-approve"
    exit 1
}