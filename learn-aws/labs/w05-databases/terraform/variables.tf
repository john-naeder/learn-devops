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
  default = "w05"
}

# ===========================================================================
# Chia đôi tuần này rất rõ ràng theo chi phí:
#
#   DynamoDB  25 GB + 25 WCU/RCU always free  →  chơi thoải mái, không giới hạn
#   RDS       ~$0,016/giờ + storage           →  bật 2 tiếng, xoá, xong
#
# Vì vậy DynamoDB là mặc định, RDS phải bật tay.
# ===========================================================================

variable "enable_rds" {
  description = "Bật RDS db.t4g.micro. ~$0,016/giờ + $0,115/GB/tháng storage. BẬT RỒI ĐẶT HẸN GIỜ 2 TIẾNG."
  type        = bool
  default     = false
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"

  validation {
    condition     = contains(["db.t4g.micro", "db.t3.micro"], var.db_instance_class)
    error_message = "Chỉ dùng micro. db.t4g.micro rẻ hơn db.t3.micro khoảng 10% nhờ Graviton."
  }
}

variable "db_allocated_storage" {
  description = "GB. 20 là mức tối thiểu RDS cho phép."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage <= 20
    error_message = "Giữ ở 20 GB. Mỗi GB thêm là $0,115/tháng và lab không cần."
  }
}

# ---------------------------------------------------------------------------
# BA THỨ BỊ CẤM TRONG TUẦN NÀY (theo đúng plan gốc), để đây làm tài liệu:
#
#   Multi-AZ        nhân đôi giá, và bạn KHÔNG học thêm được gì khi chạy thật.
#                   Standby không phục vụ đọc, không có gì để quan sát.
#   Aurora          đắt hơn nhiều, không có instance nhỏ rẻ.
#   ElastiCache     cluster nhỏ nhất cũng ~$12/tháng.
#
# Kiến thức thi về ba thứ này học bằng bảng so sánh, không cần tay chạm.
# Bảng đó nằm trong README.md của lab này.
# ---------------------------------------------------------------------------

variable "enable_multi_az" {
  description = "ĐỪNG BẬT. Nhân đôi giá RDS mà không dạy thêm điều gì quan sát được."
  type        = bool
  default     = false
}
