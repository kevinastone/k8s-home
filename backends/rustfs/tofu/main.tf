module "postgres" {
  source = "./modules/s3-user-bucket"
  name   = "postgres"
  secret = var.postgres
}

module "dragonfly" {
  source = "./modules/s3-user-bucket"
  name   = "dragonfly"
  secret = var.dragonfly
}

module "zot" {
  source = "./modules/s3-user-bucket"
  name   = "zot"
  secret = var.zot
}

import {
  to = module.postgres.rustfs_bucket.bucket
  id = "postgres"
}

import {
  to = module.postgres.rustfs_policy.policy
  id = "postgres"
}

import {
  to = module.postgres.rustfs_user.user
  id = "postgres"
}

import {
  to = module.dragonfly.rustfs_bucket.bucket
  id = "dragonfly"
}

import {
  to = module.dragonfly.rustfs_policy.policy
  id = "dragonfly"
}

import {
  to = module.dragonfly.rustfs_user.user
  id = "dragonfly"
}
