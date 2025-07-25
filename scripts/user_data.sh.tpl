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

echo "---- Running Spring Boot App ----"
sudo nohup java -jar ${app_jar_path} > springboot.log 2>&1 &

# Store the PID of the Spring Boot app
app_pid=$!
echo "Spring Boot app started with PID: $app_pid"

# Wait for the application to start up
echo "Waiting for Spring Boot app to start up..."
sleep 30

# Check if the application is running
if ps -p $app_pid > /dev/null; then
  echo "Spring Boot application is running with PID: $app_pid"
  
  # Test if the application responds to HTTP requests
  if [ "${verify_app_deployment}" = "true" ]; then
    echo "Verifying application HTTP response..."
    max_attempts=5
    attempt=1
    success=false
    
    while [ $attempt -le $max_attempts ] && [ "$success" = "false" ]; do
      echo "Attempt $attempt of $max_attempts to verify application..."
      response_code=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:8080 || echo "failed")
      
      if [ "$response_code" = "200" ]; then
        echo "SUCCESS: Application is responding with HTTP 200 OK"
        success=true
      else
        echo "Application returned HTTP code: $response_code, waiting 10 seconds before retry..."
        sleep 10
        attempt=$((attempt+1))
      fi
    done
    
    if [ "$success" = "false" ]; then
      echo "WARNING: Application is running but not responding with HTTP 200 OK after $max_attempts attempts"
      echo "Check application logs at /home/ubuntu/app/springboot.log"
    fi
  else
    echo "Application verification skipped as per configuration"
  fi
else
  echo "ERROR: Spring Boot application failed to start!"
  echo "Check application logs at /home/ubuntu/app/springboot.log"
fi

# Set up port forwarding from 80 to 8080
echo "Setting up port forwarding from ${target_port} to 8080..."
sudo iptables -t nat -A PREROUTING -p tcp --dport ${target_port} -j REDIRECT --to-port 8080
sudo iptables -t nat -A OUTPUT -p tcp --dport ${target_port} -j REDIRECT --to-port 8080

# Make iptables rules persistent
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save