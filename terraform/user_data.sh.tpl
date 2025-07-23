#!/bin/bash

# Update system
sudo apt-get update -y

# Install Java 21
sudo apt-get install -y openjdk-21-jdk

# Verify Java version
java -version

# Install Git and Maven
sudo apt-get install -y git maven

# Clone the repository
cd /home/ubuntu
git clone https://github.com/atharva5683/tech_eazy_devops_atharva5683 app
cd app

# Build with Maven
mvn clean package

# Run the application on port 80
sudo nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar --server.port=80 > /home/ubuntu/app.log 2>&1 &

# Test if app is reachable via port 80
sleep 30
curl -v http://localhost:80
