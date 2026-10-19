resource "random_id" "suffix" {
  byte_length = 4
}
resource "aws_s3_bucket" "artifact" {
  bucket = "${local.name}-releases-${random_id.suffix.hex}"
}
resource "aws_s3_bucket" "static" {
  bucket = "${local.name}-static-${random_id.suffix.hex}"
}
locals {
  buckets = {
    artifact = aws_s3_bucket.artifact.id, static = aws_s3_bucket.static.id
  }
}
resource "aws_s3_bucket_public_access_block" "all" {

  for_each                = local.buckets
  bucket                  = each.value
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

}
resource "aws_s3_bucket_server_side_encryption_configuration" "all" {

  for_each = local.buckets
  bucket   = each.value
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }

}
resource "aws_s3_bucket_versioning" "all" {

  for_each = local.buckets
  bucket   = each.value
  versioning_configuration {
    status = "Enabled"
  }

}
data "archive_file" "app" {
  type        = "zip"
  output_path = "${path.module}/app-release.zip"
  # Explicit allowlist prevents local secrets/caches entering the release ZIP.
  dynamic "source" {
    for_each = toset(["app.py", "init_db.py", "requirements.txt", "templates/index.html", "static/style.css"])
    content {
      content  = file("${path.module}/../app/${source.value}")
      filename = source.value
    }
  }
}

resource "aws_s3_object" "artifact" {

  bucket      = aws_s3_bucket.artifact.id
  key         = "releases/${data.archive_file.app.output_sha256}.zip"
  source      = data.archive_file.app.output_path
  source_hash = data.archive_file.app.output_sha256

}
resource "aws_s3_object" "static" {

  for_each      = fileset("${path.module}/../app/static", "**")
  bucket        = aws_s3_bucket.static.id
  key           = "${local.static_hash}/${each.value}"
  source        = "${path.module}/../app/static/${each.value}"
  source_hash   = filesha256("${path.module}/../app/static/${each.value}")
  content_type  = endswith(each.value, ".css") ? "text/css" : "application/octet-stream"
  cache_control = "public, max-age=31536000, immutable"

}
resource "aws_s3_bucket_policy" "artifact" {

  bucket = aws_s3_bucket.artifact.id
  policy = jsonencode({
    Version = "2012-10-17", Statement = [{
      Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.artifact.arn, "${aws_s3_bucket.artifact.arn}/*"], Condition = {
        Bool = {
          "aws:SecureTransport" = "false"
        }
      }
    }]
  })

}
