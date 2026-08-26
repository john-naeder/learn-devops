output "cloudfront_url" {
  description = "Mở cái này trong trình duyệt."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "distribution_id" {
  description = "Dùng cho invalidation."
  value       = aws_cloudfront_distribution.site.id
}

output "bucket_name" {
  value = aws_s3_bucket.site.id
}

output "bucket_url" {
  description = "Gọi thẳng vào đây PHẢI nhận 403 — đó là bằng chứng OAC hoạt động."
  value       = "https://${aws_s3_bucket.site.bucket_regional_domain_name}/index.html"
}

output "replica_bucket" {
  description = "Bucket region phụ. null nghĩa là CRR đang tắt — trạng thái nên có."
  value       = try(aws_s3_bucket.replica[0].id, null)
}

output "replica_region" {
  value = var.replica_region
}
