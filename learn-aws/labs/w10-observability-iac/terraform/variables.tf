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
  default = "w10"
}

# ---------------------------------------------------------------------------
# ĐẶT EMAIL THẬT CỦA BẠN. Cả điểm của lab là NHẬN ĐƯỢC MỘT EMAIL CẢNH BÁO THẬT.
#
#   terraform apply -var email_canh_bao=ban@example.com
#
# Sau khi apply, kiểm tra hộp thư và BẤM LINK XÁC NHẬN. Chưa xác nhận thì
# subscription ở trạng thái PendingConfirmation và alarm kêu vào hư không.
# ---------------------------------------------------------------------------
variable "email_canh_bao" {
  description = "Email nhận cảnh báo. Để rỗng thì không tạo subscription."
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30], var.log_retention_days)
    error_message = "Giữ ngắn để nằm trong 5 GB log miễn phí mỗi tháng."
  }
}

variable "nguong_p99_ms" {
  description = "Ngưỡng cảnh báo cho p99 Duration. Đặt thấp để lab dễ kích hoạt."
  type        = number
  default     = 2000
}

# Tạo hạ tầng cho remote state (bucket + bảng khoá).
# Tách riêng vì đây là bài toán "con gà quả trứng": Terraform không tự tạo
# được backend cho chính nó.
variable "tao_backend" {
  description = "Tạo S3 bucket + DynamoDB lock table cho remote state."
  type        = bool
  default     = false
}
