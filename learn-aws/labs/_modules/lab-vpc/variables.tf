variable "name" {
  description = "Tiền tố tên cho mọi resource, ví dụ \"w02\"."
  type        = string
}

variable "cidr" {
  description = "CIDR của VPC. /16 cho thoải mái, không tốn gì thêm."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Số Availability Zone. 2 là đủ để học Multi-AZ và cũng là mức rẻ nhất."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count phải từ 1 đến 3. Nhiều AZ hơn chỉ làm lab chậm và đắt hơn."
  }
}

# ---------------------------------------------------------------------------
# NAT Gateway — mặc định TẮT, và đây là quyết định thiết kế có chủ đích.
#
# NAT Gateway giá ~$0,045/giờ + $0,045/GB = khoảng $33/tháng. Nó đắt gấp hơn
# bốn lần cái EC2 t3.micro mà nó phục vụ. Trong toàn bộ 12 tuần bạn KHÔNG cần nó:
#   - Muốn instance private nói chuyện với S3/DynamoDB → Gateway Endpoint, MIỄN PHÍ.
#   - Muốn SSH vào instance private → SSM Session Manager, MIỄN PHÍ.
#   - Muốn cài package từ internet → nướng sẵn vào AMI, hoặc dùng SSM Distributor.
#
# Đề thi SAA hỏi đúng chỗ này: "private subnet cần gọi S3 với chi phí thấp nhất"
# → đáp án là Gateway Endpoint, không phải NAT Gateway.
# ---------------------------------------------------------------------------
variable "enable_nat" {
  description = "Bật NAT Gateway. ~$33/tháng. Gần như luôn luôn nên để false."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Nếu buộc phải bật NAT, dùng chung 1 cái cho mọi AZ thay vì mỗi AZ một cái (rẻ hơn, đánh đổi tính sẵn sàng — chính là bài toán cost vs resilience trong đề thi)."
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "S3 Gateway Endpoint. MIỄN PHÍ. Luôn bật."
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "DynamoDB Gateway Endpoint. MIỄN PHÍ."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "VPC Flow Logs vào CloudWatch. Bản thân flow log miễn phí, chi phí nằm ở lượng log ghi vào CloudWatch (5 GB/tháng miễn phí)."
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Retention của log group flow logs. Để ngắn kẻo ăn hết 5 GB miễn phí."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tag bổ sung. Tag Project=learn đã được provider gắn tự động qua default_tags."
  type        = map(string)
  default     = {}
}
