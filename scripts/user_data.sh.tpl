#!/bin/bash

# Log all output for debugging
exec > /var/log/user-data.log 2>&1

# Install required packages
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven git curl awscli

# Clone and build application
cd /home/ubuntu
git clone https://github.com/atharva5683/tech_eazy_devops_atharva5683 app
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

# Upload logs to S3
echo "Uploading system logs to S3"
aws s3 cp /tmp/logs/system/ s3://$BUCKET_NAME/system/ --recursive

echo "Uploading application logs to S3"
aws s3 cp /tmp/logs/app/ s3://$BUCKET_NAME/ --recursive

echo "Log upload complete"
EOF

chmod +x /home/ubuntu/upload_logs.sh

# Run the jar with the correct name from pom.xml
sudo nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar --server.port=80 > app.log 2>&1 &

# Wait for app to start
sleep 30

# Get instance public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Verify app is running by checking /hello endpoint
echo "Testing application at http://$PUBLIC_IP/hello"
curl -v http://$PUBLIC_IP/hello

# Set up shutdown hook to upload logs before termination
echo "#!/bin/bash
/home/ubuntu/upload_logs.sh" | sudo tee /etc/rc0.d/K01upload_logs
sudo chmod +x /etc/rc0.d/K01upload_logs

# Set up auto-shutdown after inactivity
cat > /home/ubuntu/auto_shutdown.sh << 'EOF'
#!/bin/bash
INACTIVITY_THRESHOLD=${auto_shutdown_minutes}
LAST_ACTIVITY=$(stat -c %Y /home/ubuntu/app/.git/FETCH_HEAD)
CURRENT_TIME=$(date +%s)

if [ $(($CURRENT_TIME - $LAST_ACTIVITY)) -gt $(($INACTIVITY_THRESHOLD * 60)) ]; then
  echo "No activity detected for $INACTIVITY_THRESHOLD minutes. Uploading logs and shutting down..."
  /home/ubuntu/upload_logs.sh
  sudo shutdown -h now
fi
EOF

chmod +x /home/ubuntu/auto_shutdown.sh

# Add cron job to check for inactivity every 5 minutes
echo "*/5 * * * * /home/ubuntu/auto_shutdown.sh" | crontab -