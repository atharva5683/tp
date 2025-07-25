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

  user_data = templatefile("${path.module}/../scripts/user_data.sh.tpl", {
    java_version          = var.java_version
    github_repo           = var.github_repo
    app_jar_path          = var.app_jar_path
    target_port           = var.target_port
    auto_shutdown_minutes = var.auto_shutdown_minutes
    verify_app_deployment = var.verify_app_deployment
  })

  tags = {
    Name        = var.instance_name
    Environment = var.environment
  }
}
