#!/bin/bash

# Install required packages
sudo apt-get update
sudo apt-get install -y openjdk-${java_version}-jdk maven git awscli

# Clone and build application
cd /home/ubuntu
git clone ${github_repo} app
cd app
mvn clean package

# Create log upload script
cat > /home/ubuntu/upload_logs.sh << EOF
#!/bin/bash
BUCKET_NAME="${var.s3_bucket_name}"

# Create log directories
mkdir -p /tmp/logs/system /tmp/logs/app/logs

# Copy logs
cp /var/log/cloud-init*.log /tmp/logs/system/ 2>/dev/null
cp /home/ubuntu/app/app.log /tmp/logs/app/logs/ 2>/dev/null

# Upload logs to S3
aws s3 cp /tmp/logs/system/ s3://$BUCKET_NAME/system/ --recursive
aws s3 cp /tmp/logs/app/ s3://$BUCKET_NAME/ --recursive
EOF

chmod +x /home/ubuntu/upload_logs.sh

# Run the application
sudo nohup java -jar ${app_jar_path} --server.port=${target_port} > app.log 2>&1 &

# Set up shutdown hook to upload logs
echo "#!/bin/bash
/home/ubuntu/upload_logs.sh" | sudo tee /etc/rc0.d/K01upload_logs
sudo chmod +x /etc/rc0.d/K01upload_logs

# Set up auto-shutdown after inactivity
cat > /home/ubuntu/auto_shutdown.sh << EOF
#!/bin/bash
if [ \$(( \$(date +%s) - \$(stat -c %Y /home/ubuntu/app/.git/FETCH_HEAD) )) -gt $((${auto_shutdown_minutes} * 60)) ]; then
  /home/ubuntu/upload_logs.sh
  sudo shutdown -h now
fi
EOF

chmod +x /home/ubuntu/auto_shutdown.sh
echo "*/5 * * * * /home/ubuntu/auto_shutdown.sh" | crontab -