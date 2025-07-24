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
    try {
        $publicIp = terraform output -raw public_ip
        Write-Host "Instance is running at IP: $publicIp"
        
        # Wait for application to start and verify it's working
        Write-Host "Waiting for application to start..."
        $appMaxAttempts = 20
        $appAttempts = 0
        $appRunning = $false
        
        do {
            $appAttempts++
            Write-Host "Checking application (attempt $appAttempts of $appMaxAttempts)..."
            
            try {
                $response = Invoke-WebRequest -Uri "http://$publicIp/hello" -TimeoutSec 10 -ErrorAction Stop
                if ($response.StatusCode -eq 200) {
                    $appRunning = $true
                    Write-Host "Application is responding!"
                    break
                }
            } catch {
                Write-Host "Application not ready yet. Waiting 15 seconds..."
                Start-Sleep -Seconds 15
            }
        } while ($appAttempts -lt $appMaxAttempts -and -not $appRunning)
        
        if ($appRunning) {
            Write-Host "Deployment successful! Application is running at: http://$publicIp/hello"
        } else {
            Write-Host "WARNING: Application may not be running correctly. Check instance logs."
            Write-Host "SSH to instance: ssh -i your-key.pem ubuntu@$publicIp"
        }
        
        Write-Host "Instance will auto-stop after configured time."
    } catch {
        Write-Error "Failed to get public IP"
    }
} else {
    Write-Error "Instance failed to reach running state"
    exit 1
}