cat > fixed_upload.sh << 'EOF'
#!/bin/bash

# Hardcode the bucket name
BUCKET_NAME="techeazy-logs-bucket-atharva"

echo "Starting log upload to S3 bucket: $BUCKET_NAME"

# Create log directories in S3 bucket structure
mkdir -p /tmp/logs/system
mkdir -p /tmp/logs/app/logs

# Copy system logs
cp /var/log/cloud-init-output.log /tmp/logs/system/ 2>/dev/null
cp /var/log/cloud-init.log /tmp/logs/system/ 2>/dev/null
cp /var/log/syslog /tmp/logs/system/ 2>/dev/null

# Copy application logs
cp /home/ubuntu/app/app.log /tmp/logs/app/logs/ 2>/dev/null

# Upload logs to S3
echo "Uploading system logs to S3"
aws s3 cp /tmp/logs/system/ s3://$BUCKET_NAME/system/ --recursive

echo "Uploading application logs to S3"
aws s3 cp /tmp/logs/app/ s3://$BUCKET_NAME/ --recursive

echo "Log upload complete"
EOF

chmod +x fixed_upload.sh
sudo ./fixed_upload.sh
