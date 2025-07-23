# EC2 instance for verification with read-only role

resource "aws_instance" "verification_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.s3_read_profile.name
  
  user_data = <<-EOF
  #!/bin/bash
  sudo apt-get update
  sudo apt-get install -y awscli
  
  # Create verification script
  cat > /home/ubuntu/verify_logs.sh << 'SCRIPT'
  #!/bin/bash
  echo "Verifying logs in S3 bucket: ${var.s3_bucket_name}"
  echo "System logs:"
  aws s3 ls s3://${var.s3_bucket_name}/system/ --recursive
  echo "Application logs:"
  aws s3 ls s3://${var.s3_bucket_name}/app/logs/ --recursive
  
  # Try to download a file (should work with read-only access)
  echo "Attempting to download a log file:"
  aws s3 cp s3://${var.s3_bucket_name}/system/cloud-init.log /tmp/cloud-init.log
  
  # Try to upload a file (should fail with read-only access)
  echo "Attempting to upload a file (should fail with read-only access):"
  echo "test" > /tmp/test.txt
  aws s3 cp /tmp/test.txt s3://${var.s3_bucket_name}/test.txt
  SCRIPT
  
  chmod +x /home/ubuntu/verify_logs.sh
  EOF
  
  tags = {
    Name        = "${var.instance_name}-verification"
    Environment = var.environment
  }
  
  depends_on = [aws_instance.app_server]
}