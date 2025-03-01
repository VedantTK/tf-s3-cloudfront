terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.89.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Random string to ensure bucket name uniqueness
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket to store the static website files
resource "aws_s3_bucket" "website_bucket" {
  bucket = "my-brain-puzzle-games-bucket-${random_string.bucket_suffix.id}"

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Project   = "BrainPuzzleGames"
    ManagedBy = "Terraform"
  }
}

# S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "website_bucket" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# S3 Bucket ACL - Set to private
resource "aws_s3_bucket_acl" "website_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.website_bucket]
  bucket     = aws_s3_bucket.website_bucket.id
  acl        = "private"
}

# S3 Bucket Public Access Block - Block public access
resource "aws_s3_bucket_public_access_block" "website_bucket_block" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "website_bucket_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# CloudFront Origin Access Control (OAC) to securely access S3
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "oac-for-brain-puzzle-games"
  description                       = "OAC for S3 bucket access"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution with HTTPS Enforcement (No Custom Domain)
resource "aws_cloudfront_distribution" "cf_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.website_bucket.id
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.website_bucket.id

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https" # Enforce HTTPS, redirect HTTP to HTTPS
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # Use CloudFront's default SSL certificate
  }

  tags = {
    Project   = "BrainPuzzleGames"
    ManagedBy = "Terraform"
  }
}

# S3 Bucket Policy to allow CloudFront OAC to access the bucket
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cf_distribution.arn
          }
        }
      }
    ]
  })

  depends_on = [aws_cloudfront_distribution.cf_distribution]
}

# Upload the index.html file to S3
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  source       = "app/index.html"
  content_type = "text/html"

  depends_on = [aws_s3_bucket.website_bucket]
}
