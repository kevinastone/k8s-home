# Explicitly import existing RustFS buckets, IAM users, and policies
# into the new minio provider resources.

import {
  to = module.postgres.minio_s3_bucket.bucket
  id = "postgres"
}

import {
  to = module.postgres.minio_iam_user.user
  id = "postgres"
}

import {
  to = module.postgres.minio_iam_policy.policy
  id = "postgres"
}

import {
  to = module.dragonfly.minio_s3_bucket.bucket
  id = "dragonfly"
}

import {
  to = module.dragonfly.minio_iam_user.user
  id = "dragonfly"
}

import {
  to = module.dragonfly.minio_iam_policy.policy
  id = "dragonfly"
}
