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
  default = "w02"
}

variable "instance_type" {
  description = "Loại EC2. Đã khoá danh sách để không lỡ tay chọn con đắt."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t4g.micro", "t4g.small"], var.instance_type)
    error_message = "Chỉ dùng instance rẻ trong lab. t3.micro ~$0,0104/giờ. Xem bảng bẫy tiền trong aws-saa-plan.md."
  }
}

# ===========================================================================
# ĐÂY LÀ BIẾN TỐN TIỀN DUY NHẤT CỦA LAB NÀY — ĐỌC KỸ TRƯỚC KHI APPLY
#
# Bài toán: bạn muốn một EC2 nằm trong private subnet (không public IP, không
# đường ra internet) mà vẫn SSH vào được bằng SSM Session Manager.
#
# SSM Agent trên máy cần nói chuyện với BA endpoint dịch vụ: ssm, ssmmessages,
# ec2messages. Từ private subnet không có đường ra, chỉ có hai cách:
#
#   A. NAT Gateway            ~$0,045/giờ  = ~$33/tháng   ← đắt gấp 4 lần cái EC2
#   B. 3 Interface Endpoint   ~$0,03/giờ   = ~$65/tháng   ← rẻ hơn theo GIỜ
#
# Lab 3 tiếng: cách A tốn ~$0,14, cách B tốn ~$0,09. Chọn B.
# Để quên 1 tháng: cách A tốn $33, cách B tốn $65. Cả hai đều là thảm hoạ.
#
# → BÀI HỌC THẬT: Interface Endpoint rẻ hơn NAT khi tính theo giờ và an toàn hơn
#   (traffic không ra internet), nhưng bạn trả tiền cho TỪNG endpoint TỪNG AZ.
#   Còn Gateway Endpoint (S3, DynamoDB) thì MIỄN PHÍ tuyệt đối. Đề thi SAA hỏi
#   đúng sự phân biệt này.
#
# → Endpoint dưới đây cố ý chỉ đặt ở MỘT AZ để giảm nửa chi phí. Trong production
#   bạn sẽ đặt mọi AZ để chịu lỗi — chính là đánh đổi cost vs resilience.
#
# CHẠY XONG PHẢI `terraform destroy`. Không có ngoại lệ.
# ===========================================================================
variable "enable_ssm_endpoints" {
  description = "Interface Endpoint cho SSM (~$0,03/giờ tổng). Cần để vào được máy trong private subnet. TẮT khi không lab."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "VPC Flow Logs. Cần cho bài tìm gói tin bị NACL chặn."
  type        = bool
  default     = true
}

variable "blocked_port" {
  description = "Port bị NACL chặn để tạo bản ghi REJECT trong flow logs."
  type        = number
  default     = 8080
}
