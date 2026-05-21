resource "minio_s3_bucket" "postgres" {
  bucket = "postgres"
}

resource "minio_iam_user" "postgres" {
  name   = "postgres"
  secret = var.postgres
}

resource "minio_s3_bucket_policy" "postgres" {
  bucket = minio_s3_bucket.postgres.bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Principal = {
          AWS = ["arn:aws:iam:::user/postgres"]
        }
        Action   = ["s3:*"]
        Resource = [
          "arn:aws:s3:::postgres",
          "arn:aws:s3:::postgres/*"
        ]
      }
    ]
  })
}
