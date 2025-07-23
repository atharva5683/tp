#!/bin/bash

# Update and upgrade system
sudo apt-get update -y
sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y git maven openjdk-21-jdk

# Verify Java version
java -version

# Clone repository
cd /home/ubuntu
git clone https://github.com/atharva5683/tech_eazy_devops_atharva5683 app
cd app

# Build the project
mvn clean package

# Run the application with sudo to bind to port 80
sudo nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar --server.port=80 > app.log 2>&1 &
