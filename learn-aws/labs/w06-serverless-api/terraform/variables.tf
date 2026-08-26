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
  default = "w06"
}

variable "ttl_ngay" {
  description = "Ghi chú tự hết hạn sau bao nhiêu ngày. Giữ bảng lab không phình mãi."
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "MẶC ĐỊNH CỦA LAMBDA LÀ VĨNH VIỄN. 7 ngày là đủ cho lab và giữ trong 5 GB miễn phí."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "Giữ ngắn. Log dài ngày ăn hết 5 GB miễn phí mỗi tháng."
  }
}

variable "cors_allow_origins" {
  description = "Domain được phép gọi API. Production thì thay bằng domain CloudFront thật."
  type        = list(string)
  default     = ["*"]
}

# Hàng rào chi phí: giới hạn tốc độ gọi API.
# Không có nó, một vòng lặp lỗi trong script test có thể ăn sạch 1 triệu
# request miễn phí trong vài phút.
variable "throttle_rate" {
  description = "Số request mỗi giây ở trạng thái ổn định."
  type        = number
  default     = 20
}

variable "throttle_burst" {
  description = "Số request cho phép dồn trong một lúc."
  type        = number
  default     = 40
}
