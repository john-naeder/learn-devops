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
  default = "w09"
}

# External ID là bí mật do BẠN đặt ra và chỉ chia sẻ với bên thứ ba.
# Nó chống lỗ hổng confused deputy trong kịch bản cross-account.
# Trong thực tế hãy dùng chuỗi ngẫu nhiên dài, không dùng giá trị đoán được.
variable "external_id" {
  description = "External ID bắt buộc khi assume role bên thứ ba."
  type        = string
  default     = "bi-mat-chi-hai-ben-biet-2026"
}

variable "gia_tri_secret" {
  description = "Giá trị secret mẫu lưu trong Parameter Store."
  type        = string
  default     = "mat-khau-gia-lap-khong-dung-that"
  sensitive   = true
}

# ---------------------------------------------------------------------------
# GuardDuty: 30 ngày dùng thử miễn phí, sau đó tính theo lượng sự kiện phân tích.
# Plan gốc: bật, xem finding mẫu trong một ngày, rồi TẮT.
# ---------------------------------------------------------------------------
variable "enable_guardduty" {
  description = "Bật GuardDuty. Miễn phí 30 ngày đầu, sau đó tính tiền. NHỚ TẮT."
  type        = bool
  default     = false
}
