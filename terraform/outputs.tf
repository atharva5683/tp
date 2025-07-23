output "app_ip" {
  value = aws_instance.app_server.public_ip
}

output "verify_ip" {
  value = aws_instance.verification_instance.public_ip
}

output "s3_bucket" {
  value = aws_s3_bucket.logs_bucket.bucket
}

output "app_url" {
  value = "http://${aws_instance.app_server.public_ip}/hello"
}