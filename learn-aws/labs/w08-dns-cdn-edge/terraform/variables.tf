variable "region" {
  type    = string
  default = "us-east-1"
}

variable "profile" {
  type    = string
  default = "learn"
}

variable "prefix" {
  type    = string
  default = "w08"
}

# ---------------------------------------------------------------------------
# Route 53 MẶC ĐỊNH TẮT vì nó là phần tốn tiền duy nhất của tuần này:
#   hosted zone   $0,50/tháng
#   health check  $0,50/tháng mỗi cái
#
# Bật để nhìn thấy weighted và failover routing bằng mắt, rồi XOÁ trong 2 ngày
# → chi phí thực tế khoảng $0,05.
#
# Nếu muốn tiết kiệm tuyệt đối: để false và học routing policy bằng bảng trong
# README. Đây là kiến thức NHỚ, không cần tay chạm mới thi được.
# ---------------------------------------------------------------------------
variable "enable_route53" {
  description = "Tạo hosted zone + health check. ~$1/tháng. XOÁ SAU 2 NGÀY."
  type        = bool
  default     = false
}

variable "ten_mien" {
  description = "Tên miền cho hosted zone. KHÔNG cần sở hữu thật — bạn vẫn xem được cấu hình routing policy, chỉ là DNS công cộng không trỏ về đây."
  type        = string
  default     = "lab-hoc-aws.example"
}

variable "chan_quoc_gia" {
  description = "Mã quốc gia bị chặn ở edge (ví dụ [\"CN\", \"RU\"]). Rỗng = không chặn."
  type        = list(string)
  default     = []
}
