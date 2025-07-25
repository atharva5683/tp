# IAM roles and policies

# 1.a - Role with read-only access to S3
resource "aws_iam_role" "s3_read_role" {
  name = "${var.environment}-s3-read-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read_policy" {
  role       = aws_iam_role.s3_read_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "s3_read_profile" {
  name = "${var.environment}-s3-read-profile"
  role = aws_iam_role.s3_read_role.name
}

# 1.b - Role with permission to create bucket and upload files (NO read or download)
resource "aws_iam_role" "s3_write_role" {
  name = "${var.environment}-s3-write-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_write_policy" {
  name        = "${var.environment}-s3-write-policy"
  description = "Policy to create buckets and upload files to S3 without read access"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectAcl",
          "s3:ListBucket"
        ]
        Effect   = "Deny"
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_write_policy" {
  role       = aws_iam_role.s3_write_role.name
  policy_arn = aws_iam_policy.s3_write_policy.arn
}

# Create instance profile for the write role
resource "aws_iam_instance_profile" "s3_write_profile" {
  name = "${var.environment}-s3-write-profile"
  role = aws_iam_role.s3_write_role.name
}