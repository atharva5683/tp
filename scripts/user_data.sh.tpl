#!/bin/bash

# Log all output for debugging
exec > /var/log/user-data.log 2>&1

# Install required packages
sudo apt-get update
sudo apt-get install -y openjdk-${java_version}-jdk maven git curl awscli

# Clone and build application
cd /home/ubuntu
git clone ${github_repo} app
cd app
mvn clean package

# Create logs directory
mkdir -p /home/ubuntu/app/logs

# Create log upload script
cat > /home/ubuntu/upload_logs.sh << 'EOF'
#!/bin/bash

# Get the bucket name from Terraform variable
BUCKET_NAME="${s3_bucket_name}"

echo "Starting log upload to S3 bucket: $BUCKET_NAME"

# Create log directories in S3 bucket structure
mkdir -p /tmp/logs/system
mkdir -p /tmp/logs/app/logs

# Copy system logs
cp /var/log/cloud-init-output.log /tmp/logs/system/
cp /var/log/cloud-init.log /tmp/logs/system/
cp /var/log/syslog /tmp/logs/system/

# Copy application logs
cp /home/ubuntu/app/app.log /tmp/logs/app/logs/
cp -r /home/ubuntu/app/logs/* /tmp/logs/app/logs/ 2>/dev/null

# Check AWS credentials and IAM role
echo "Checking AWS credentials and IAM role..."
aws sts get-caller-identity || echo "No AWS credentials found"

# Check if instance profile is attached
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
ROLE_NAME=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ || echo "No IAM role found")
echo "Instance ID: $INSTANCE_ID"
echo "IAM Role: $ROLE_NAME"

# Upload logs to S3
echo "Uploading system logs to S3 bucket: $BUCKET_NAME"
aws s3 cp /tmp/logs/system/ s3://$BUCKET_NAME/system/ --recursive
UPLOAD_STATUS_SYSTEM=$?

echo "Uploading application logs to S3 bucket: $BUCKET_NAME"
aws s3 cp /tmp/logs/app/ s3://$BUCKET_NAME/ --recursive
UPLOAD_STATUS_APP=$?

if [ $UPLOAD_STATUS_SYSTEM -eq 0 ] && [ $UPLOAD_STATUS_APP -eq 0 ]; then
  echo "Log upload completed successfully"
else
  echo "Log upload encountered issues."
  echo "System logs upload status: $UPLOAD_STATUS_SYSTEM"
  echo "Application logs upload status: $UPLOAD_STATUS_APP"
  
  # Try with explicit credentials from instance metadata
  if [ -n "$ROLE_NAME" ]; then
    echo "Trying with explicit credentials from instance metadata..."
    CREDS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)
    export AWS_ACCESS_KEY_ID=$(echo $CREDS | grep -o '"AccessKeyId" : "[^"]*"' | cut -d '"' -f 4)
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | grep -o '"SecretAccessKey" : "[^"]*"' | cut -d '"' -f 4)
    export AWS_SESSION_TOKEN=$(echo $CREDS | grep -o '"Token" : "[^"]*"' | cut -d '"' -f 4)
    
    echo "Retrying upload with explicit credentials..."
    aws s3 cp /tmp/logs/system/ s3://$BUCKET_NAME/system/ --recursive
    aws s3 cp /tmp/logs/app/ s3://$BUCKET_NAME/ --recursive
  fi
fi
EOF

chmod +x /home/ubuntu/upload_logs.sh

# Run the jar with the correct name from pom.xml
sudo nohup java -jar ${app_jar_path} --server.port=${target_port} > app.log 2>&1 &

# Wait for app to start
sleep 30

# Get instance public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Verify app is running by checking /hello endpoint
echo "Testing application at http://$PUBLIC_IP/hello"
curl -v http://$PUBLIC_IP/hello

# Create a direct shutdown script that will definitely run
sudo mkdir -p /lib/systemd/system-shutdown

# Create the improved shutdown script with the bucket name directly embedded
cat > /tmp/upload-logs-shutdown << EOF
#!/bin/bash
# This script runs during shutdown process to upload logs to S3

# Make sure we have enough time to complete the upload
sleep 2

# Create a separate log file that will survive the shutdown process
LOG_FILE=/tmp/shutdown-upload.log
touch \$LOG_FILE
chmod 666 \$LOG_FILE

# Log all actions with timestamps
exec > \$LOG_FILE 2>&1
echo "[\$(date)] Starting log upload during shutdown..."

# Hardcode the bucket name from Terraform variable
BUCKET_NAME="${s3_bucket_name}"

# If bucket name not found, try environment variable
if [ -z "\$BUCKET_NAME" ] || [ "\$BUCKET_NAME" == "None" ]; then
  # Try to get from environment variable
  if [ -f /etc/environment ]; then
    source /etc/environment
  fi
  BUCKET_NAME=\$S3_BUCKET_NAME
  
  # If still not found, try to get from instance tags
  if [ -z "\$BUCKET_NAME" ] || [ "\$BUCKET_NAME" == "None" ]; then
    INSTANCE_ID=\$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=\$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    BUCKET_NAME=\$(aws ec2 describe-tags --region \$REGION --filters "Name=resource-id,Values=\$INSTANCE_ID" "Name=key,Values=s3_bucket_name" --query "Tags[0].Value" --output text)
  fi
fi

echo "[\$(date)] Using S3 bucket: \$BUCKET_NAME"

# Create log directories in S3 bucket structure
mkdir -p /tmp/logs/system
mkdir -p /tmp/logs/app

# Copy system logs
echo "[\$(date)] Copying system logs..."
cp /var/log/cloud-init-output.log /tmp/logs/system/ 2>/dev/null
cp /var/log/cloud-init.log /tmp/logs/system/ 2>/dev/null
cp /var/log/syslog /tmp/logs/system/ 2>/dev/null
cp /var/log/user-data.log /tmp/logs/system/ 2>/dev/null
cp \$LOG_FILE /tmp/logs/system/ 2>/dev/null

# Copy application logs
echo "[\$(date)] Copying application logs..."
cp /home/ubuntu/app/app.log /tmp/logs/app/ 2>/dev/null
cp -r /home/ubuntu/app/logs/* /tmp/logs/app/ 2>/dev/null

# Check AWS credentials
echo "[\$(date)] Checking AWS credentials..."
aws sts get-caller-identity
AWS_STATUS=\$?

# If AWS credentials not available, try to get them from instance metadata
if [ \$AWS_STATUS -ne 0 ]; then
  echo "[\$(date)] Getting credentials from instance metadata..."
  ROLE_NAME=\$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ || echo "")
  
  if [ -n "\$ROLE_NAME" ]; then
    CREDS=\$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/\$ROLE_NAME)
    export AWS_ACCESS_KEY_ID=\$(echo \$CREDS | grep -o '"AccessKeyId" : "[^"]*"' | cut -d '"' -f 4)
    export AWS_SECRET_ACCESS_KEY=\$(echo \$CREDS | grep -o '"SecretAccessKey" : "[^"]*"' | cut -d '"' -f 4)
    export AWS_SESSION_TOKEN=\$(echo \$CREDS | grep -o '"Token" : "[^"]*"' | cut -d '"' -f 4)
    
    echo "[\$(date)] Got temporary credentials from instance metadata"
  fi
fi

# Upload logs to S3 with maximum retries
echo "[\$(date)] Uploading system logs to S3..."
for i in {1..3}; do
  aws s3 cp /tmp/logs/system/ s3://\$BUCKET_NAME/system/ --recursive
  UPLOAD_STATUS_SYSTEM=\$?
  
  if [ \$UPLOAD_STATUS_SYSTEM -eq 0 ]; then
    echo "[\$(date)] System logs upload successful"
    break
  else
    echo "[\$(date)] System logs upload failed (attempt \$i), retrying..."
    sleep 2
  fi
done

echo "[\$(date)] Uploading application logs to S3..."
for i in {1..3}; do
  aws s3 cp /tmp/logs/app/ s3://\$BUCKET_NAME/ --recursive
  UPLOAD_STATUS_APP=\$?
  
  if [ \$UPLOAD_STATUS_APP -eq 0 ]; then
    echo "[\$(date)] Application logs upload successful"
    break
  else
    echo "[\$(date)] Application logs upload failed (attempt \$i), retrying..."
    sleep 2
  fi
done

# Final status
if [ \$UPLOAD_STATUS_SYSTEM -eq 0 ] && [ \$UPLOAD_STATUS_APP -eq 0 ]; then
  echo "[\$(date)] All logs uploaded successfully"
else
  echo "[\$(date)] Some logs failed to upload"
  echo "[\$(date)] System logs status: \$UPLOAD_STATUS_SYSTEM"
  echo "[\$(date)] Application logs status: \$UPLOAD_STATUS_APP"
fi

# Copy the final log to S3 directly
echo "[\$(date)] Uploading shutdown log itself..."
aws s3 cp \$LOG_FILE s3://\$BUCKET_NAME/system/shutdown-upload.log

echo "[\$(date)] Shutdown log upload process complete"

# Force sync to ensure all data is written
sync
EOF

sudo mv /tmp/upload-logs-shutdown /lib/systemd/system-shutdown/
sudo chmod +x /lib/systemd/system-shutdown/upload-logs-shutdown

# Store S3 bucket name in environment file for shutdown script
echo "S3_BUCKET_NAME=${s3_bucket_name}" | sudo tee -a /etc/environment

# Create a systemd service for shutdown
cat > /tmp/upload-logs.service << 'EOF'
[Unit]
Description=Upload logs to S3 before shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/lib/systemd/system-shutdown/upload-logs-shutdown
TimeoutStartSec=180
RemainAfterExit=yes

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

sudo mv /tmp/upload-logs.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable upload-logs.service

# Create a second backup mechanism using /etc/rc0.d/
cat > /tmp/S01upload-logs << 'EOF'
#!/bin/bash
# This script runs during shutdown via rc0.d

# Run the shutdown script directly
/lib/systemd/system-shutdown/upload-logs-shutdown

# Wait for upload to complete
sleep 10
EOF

sudo mv /tmp/S01upload-logs /etc/rc0.d/
sudo chmod +x /etc/rc0.d/S01upload-logs

# Set up auto-shutdown after inactivity
cat > /home/ubuntu/auto_shutdown.sh << 'EOF'
#!/bin/bash
INACTIVITY_THRESHOLD=${auto_shutdown_minutes}
LAST_ACTIVITY=$(stat -c %Y /home/ubuntu/app/.git/FETCH_HEAD)
CURRENT_TIME=$(date +%s)

if [ $(($CURRENT_TIME - $LAST_ACTIVITY)) -gt $(($INACTIVITY_THRESHOLD * 60)) ]; then
  echo "No activity detected for $INACTIVITY_THRESHOLD minutes. Uploading logs and shutting down..."
  /home/ubuntu/upload_logs.sh
  # Wait for upload to complete
  sleep 30
  sudo shutdown -h now
fi
EOF

chmod +x /home/ubuntu/auto_shutdown.sh

# Add cron job to check for inactivity every 5 minutes
echo "*/5 * * * * /home/ubuntu/auto_shutdown.sh" | crontab -
