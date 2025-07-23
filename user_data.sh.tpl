#!/bin/bash
sudo apt-get update
sudo apt-get install -y openjdk-21-jdk maven git
cd /home/ubuntu
git clone https://github.com/atharva5683/tech_eazy_devops_atharva5683 app
cd app
mvn clean package
sudo java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar --server.port=80
