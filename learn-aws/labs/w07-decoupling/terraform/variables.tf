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
  default = "w07"
}

# Công tắc gây lỗi có chủ đích, để quan sát cơ chế thử lại và DLQ.
#   terraform apply -var gay_loi_don_hang=true    → message sẽ rơi vào DLQ
#   terraform apply -var gay_loi_don_hang=false   → xử lý bình thường
variable "gay_loi_don_hang" {
  description = "Bắt Lambda đơn hàng ném exception cho mọi message. Dùng để xem DLQ hoạt động."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# EventBridge schedule MẶC ĐỊNH TẮT.
#
# Plan gốc nhắc riêng ở tuần 7: "đã tắt EventBridge schedule — để chạy mãi sẽ
# sinh log vô ích". Một rule mỗi 5 phút = 8640 lần gọi mỗi tháng. Không đủ để
# hết hạn mức, nhưng đủ để làm bẩn CloudWatch và che mất tín hiệu thật.
#
# Bật khi làm bài, rồi TẮT:
#   terraform apply -var bat_lich=true
#   terraform apply -var bat_lich=false
# ---------------------------------------------------------------------------
variable "bat_lich" {
  description = "Bật EventBridge rule chạy định kỳ. NHỚ TẮT khi làm xong."
  type        = bool
  default     = false
}

variable "lich_chay" {
  description = "Biểu thức lịch. rate(...) đơn giản hơn cron(...) và ít sai hơn."
  type        = string
  default     = "rate(5 minutes)"
}
