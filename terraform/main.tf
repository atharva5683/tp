provider "aws" {
  region = "ap-south-1"  # Mumbai region
}

resource "aws_security_group" "app_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for ${var.environment} application"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.target_port
    to_port     = var.target_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  user_data              = <<-EOF
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install -y openjdk-21-jdk maven git
  cd /home/ubuntu
  git clone https://github.com/atharva5683/tech_eazy_devops_atharva5683 app
  cd app
  mvn clean package
  sudo java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar --server.port=80
  EOF
  
  # Force new resource creation
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
