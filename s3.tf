resource "aws_s3_bucket" "bucket" {
  force_destroy = "true"
}

resource "aws_s3_bucket_cors_configuration" "cors_rule" {
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_methods = ["POST"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "clean_staging" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id = "rule-1"
    filter {
      prefix = "staging/"
    }
    expiration {
      days = 1
    }
    status = "Enabled"
  }
}
