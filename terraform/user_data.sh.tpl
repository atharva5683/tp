#!/bin/bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven git curl
cd /home/ubuntu
git clone https://github.com/atharva5683/tech_eazy_devops_atharva5683 app
cd app
mvn clean package
# Run the jar with the correct name from pom.xml
sudo nohup java -jar target/hellomvc-0.0.1-SNAPSHOT.jar --server.port=80 > app.log 2>&1 &

# Wait for app to start
sleep 30

# Get instance public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Verify app is running by checking /hello endpoint
echo "Testing application at http://$PUBLIC_IP/hello"
curl -v http://$PUBLIC_IP/hello