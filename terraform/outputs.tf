output "app_instance_id" {
  value = aws_instance.app_server.id
}

output "app_instance_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "verification_instance_id" {
  value = aws_instance.verification_instance.id
}

output "verification_instance_public_ip" {
  value = aws_instance.verification_instance.public_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.logs_bucket.bucket
}

output "s3_read_role_arn" {
  value = aws_iam_role.s3_read_role.arn
}

output "s3_write_role_arn" {
  value = aws_iam_role.s3_write_role.arn
}

output "application_url" {
  value = "http://${aws_instance.app_server.public_ip}/hello"
}