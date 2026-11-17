removed {
  from = module.dragonfly.rustfs_bucket.bucket

  lifecycle {
    destroy = false
  }
}
