# ⚠️ DELIBERATELY INSECURE — this file exists to test the security pipeline.
# It should be caught by Checkov and blocked from merging. Do not deploy.

resource "aws_s3_bucket" "bad_bucket" {
  bucket = "my-deliberately-insecure-test-bucket-12345"
}

# Publicly accessible bucket (Checkov will flag this)
resource "aws_s3_bucket_public_access_block" "bad_bucket_access" {
  bucket                  = aws_s3_bucket.bad_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}