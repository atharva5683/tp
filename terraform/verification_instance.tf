# Verification instance with read-only S3 access
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
  
  cat > /home/ubuntu/verify_logs.sh << 'SCRIPT'
  #!/bin/bash
  BUCKET="${var.s3_bucket_name}"
  echo "Verifying logs in S3 bucket: $BUCKET"
  echo "System logs:"
  aws s3 ls s3://$BUCKET/system/ --recursive
  echo "Application logs:"
  aws s3 ls s3://$BUCKET/app/logs/ --recursive
  
  # Try to download a file (should work with read-only access)
  echo "Attempting to download a log file:"
  aws s3 cp s3://$BUCKET/system/cloud-init.log /tmp/cloud-init.log
  
  # Try to upload a file (should fail with read-only access)
  echo "Attempting to upload a file (should fail with read-only access):"
  echo "test" > /tmp/test.txt
  aws s3 cp /tmp/test.txt s3://$BUCKET/test.txt
  SCRIPT
  
  chmod +x /home/ubuntu/verify_logs.sh
  EOF
  
  tags = {
    Name        = "${var.instance_name}-verification"
    Environment = var.environment
  }
  
  depends_on = [aws_instance.app_server]
}