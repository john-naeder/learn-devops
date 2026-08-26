output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.cdn.domain_name}"
}

output "distribution_id" {
  value = aws_cloudfront_distribution.cdn.id
}

output "bucket_name" {
  value = aws_s3_bucket.origin.id
}

output "cache_policy_id" {
  description = "Cache policy tự viết — bỏ qua tham số utm_*."
  value       = aws_cloudfront_cache_policy.bo_qua_utm.id
}

output "hosted_zone_id" {
  description = "null nghĩa là Route 53 đang tắt — trạng thái nên có."
  value       = try(aws_route53_zone.lab[0].zone_id, null)
}

output "name_servers" {
  description = "Name server của hosted zone, nếu có bật."
  value       = try(aws_route53_zone.lab[0].name_servers, null)
}

output "chi_phi" {
  value = var.enable_route53 ? "Route 53 ĐANG BẬT: hosted zone $0,50/tháng + health check $0,50/tháng = ~$1/tháng. XOÁ TRONG 2 NGÀY." : "~$0,00 — chỉ CloudFront + S3, nằm trong hạn mức miễn phí."
}

output "thu_cache" {
  description = "Ba lệnh để tự thấy cache hoạt động."
  value       = <<-EOT
    URL=https://${aws_cloudfront_distribution.cdn.domain_name}

    # 1. Gọi hai lần, xem x-cache đổi từ Miss sang Hit
    curl -sD- -o /dev/null $URL/index.html | grep -i x-cache
    curl -sD- -o /dev/null $URL/index.html | grep -i x-cache

    # 2. Thêm utm_source — cache policy BỎ QUA nó nên vẫn là Hit
    curl -sD- -o /dev/null "$URL/index.html?utm_source=facebook" | grep -i x-cache

    # 3. /api/* không cache — luôn Miss
    curl -sD- -o /dev/null $URL/api/gio.json | grep -i x-cache
    curl -sD- -o /dev/null $URL/api/gio.json | grep -i x-cache
  EOT
}
