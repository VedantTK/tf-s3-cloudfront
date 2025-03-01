output "s3_bucket_name" {
  value       = aws_s3_bucket.website_bucket.id
  description = "The name of the S3 bucket hosting the website"
}

output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.cf_distribution.domain_name}"
  description = "The CloudFront distribution URL to access the website"
}
