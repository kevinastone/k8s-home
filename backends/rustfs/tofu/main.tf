resource "minio_s3_bucket" "postgres" {
  bucket = "postgres"
}

resource "minio_iam_user" "postgres" {
  name   = "postgres"
  secret = var.postgres
}

resource "minio_iam_policy" "postgres" {
  name   = "postgres-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = [
          "arn:aws:s3:::postgres",
          "arn:aws:s3:::postgres/*"
        ]
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "postgres" {
  user_name   = minio_iam_user.postgres.id
  policy_name = minio_iam_policy.postgres.id
}
