# S3 bucket with 7-day lifecycle rule
resource "aws_s3_bucket" "logs_bucket" {
  bucket = var.s3_bucket_name
  tags = {
    Name        = var.s3_bucket_name
    Environment = var.environment
  }
}

# Make bucket private
resource "aws_s3_bucket_public_access_block" "logs_bucket_block" {
  bucket = aws_s3_bucket.logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Delete logs after 7 days
resource "aws_s3_bucket_lifecycle_configuration" "logs_lifecycle" {
  bucket = aws_s3_bucket.logs_bucket.id
  rule {
    id     = "delete-after-7-days"
    status = "Enabled"
    expiration { days = 7 }
    filter { prefix = "" }
  }
}