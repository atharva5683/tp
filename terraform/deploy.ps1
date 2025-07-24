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

# Get outputs
try {
    $publicIp = terraform output -raw app_instance_public_ip
    $appUrl = terraform output -raw application_url
    $bucket = terraform output -raw s3_bucket_name
    
    Write-Host "Deployment complete!"
    Write-Host "Application URL: $appUrl"
    Write-Host "S3 bucket for logs: $bucket"
    Write-Host "Instance will auto-stop after configured time."
} catch {
    Write-Error "Failed to get outputs"
}