variable "region" {
  type    = string
  default = "us-east-1"
}

variable "replica_region" {
  description = "Region phụ cho Cross-Region Replication. Chỉ dùng khi enable_crr = true."
  type        = string
  default     = "us-west-2"
}

variable "profile" {
  type    = string
  default = "learn"
}

variable "prefix" {
  type    = string
  default = "w04"
}

# ---------------------------------------------------------------------------
# Lab này gần như MIỄN PHÍ:
#   CloudFront   1 TB data out + 10 triệu request/tháng   → always free
#   S3 Standard  $0,023/GB/tháng, site vài chục KB        → ~$0,000001
#   Request      $0,005/1000 PUT, $0,0004/1000 GET        → không đáng kể
#
# Hai thứ CÓ THỂ tốn tiền:
#   - Invalidation: 1000 path đầu mỗi tháng miễn phí, sau đó $0,005/path.
#     Đừng invalidate "/*" trong vòng lặp.
#   - CRR: nhân đôi dung lượng lưu + phí data transfer giữa region.
#     Với vài chục KB thì vẫn ~$0, nhưng bucket bỏ quên thì tính tiền mãi.
# ---------------------------------------------------------------------------

variable "enable_crr" {
  description = "Bật Cross-Region Replication. Bật để làm bài, xong TẮT NGAY và destroy."
  type        = bool
  default     = false
}

variable "enable_ip_restriction" {
  description = "Thêm bucket policy chỉ cho phép một IP. Bài tập tuần 4."
  type        = bool
  default     = false
}

variable "allowed_ip" {
  description = "IP được phép khi enable_ip_restriction = true. Lấy bằng: curl -s ifconfig.me"
  type        = string
  default     = "0.0.0.0/32"
}

variable "glacier_after_days" {
  description = "Số ngày trước khi chuyển object sang Glacier Instant Retrieval."
  type        = number
  default     = 30
}

variable "expire_noncurrent_after_days" {
  description = "Số ngày giữ version cũ trước khi xoá hẳn."
  type        = number
  default     = 7
}
