# ---------------------------------------------------------------------------
# Biến của hàng rào.
#
# Nguyên tắc: mọi biến ở đây đều làm hàng rào CHẶT hơn khi giữ mặc định.
# Sửa biến để nới hàng rào là một hành động có ý thức, phải gõ tay, và
# phải chạy lại `terraform apply` bằng profile admin. Đó là cố ý.
# ---------------------------------------------------------------------------

variable "admin_profile" {
  description = <<-EOT
    Profile admin dùng để dựng hàng rào. KHÔNG phải profile bạn làm lab.
    Đây là profile duy nhất được phép sửa boundary, nên chỉ dùng nó ở thư mục này.
  EOT
  type        = string
  default     = "learn"
}

variable "region" {
  description = "Region để tạo tài nguyên của chính module này. Budget và IAM là global nhưng provider vẫn cần một region."
  type        = string
  default     = "us-east-1"
}

variable "allowed_regions" {
  description = <<-EOT
    Danh sách region mà boundary cho phép gọi API. Mặc định đúng MỘT region.

    Tài nguyên bị bỏ quên ở một region bạn không bao giờ mở lại là cách phổ
    biến nhất để đốt sạch credit — nên đây là hàng rào quan trọng nhất trong file.
    Thêm region thứ hai chỉ khi bạn thật sự cần, và xoá đi ngay sau đó.
  EOT
  type        = list(string)
  default     = ["us-east-1"]

  validation {
    condition     = length(var.allowed_regions) <= 2
    error_message = "Tối đa 2 region. Cần hơn 2 nghĩa là bài lab đang thiết kế sai, không phải hàng rào sai."
  }
}

variable "boundary_name" {
  description = "Tên IAM policy dùng làm permission boundary. guard.sh và README dựa vào tên này."
  type        = string
  default     = "labs-self-boundary"
}

variable "role_name" {
  description = "Tên IAM role người học sẽ assume. Trùng với tên profile `lab-builder` trong ~/.aws/config."
  type        = string
  default     = "lab-builder"
}

variable "trusted_principal_arns" {
  description = <<-EOT
    Ai được phép assume role `lab-builder`.

    Để rỗng thì module tự suy ra từ danh tính đang chạy `terraform apply`
    (data.aws_caller_identity). Nếu bạn apply bằng IAM Identity Center / SSO,
    ARN suy ra sẽ sai đường dẫn — lúc đó khai báo tay ARN của IAM role hoặc
    IAM user tại đây.
  EOT
  type        = list(string)
  default     = []
}

variable "max_session_duration" {
  description = "Thời gian sống tối đa của một phiên assume role, tính bằng giây. 4 giờ đủ cho một buổi lab và ngắn hơn access key vĩnh viễn rất nhiều."
  type        = number
  default     = 14400

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "AWS chỉ chấp nhận từ 3600 đến 43200 giây."
  }
}

# --- Danh sách trắng những thứ đắt tiền ------------------------------------

variable "allowed_instance_types" {
  description = "Instance type được phép `ec2:RunInstances`. Mọi loại khác bị Deny thẳng ở tầng API."
  type        = list(string)
  default     = ["t2.micro", "t3.micro", "t3.small", "t4g.micro", "t4g.small"]
}

variable "allowed_db_classes" {
  description = "Class được phép cho RDS. db.t3.micro ~$0,018/giờ, db.t4g.micro ~$0,016/giờ."
  type        = list(string)
  default     = ["db.t3.micro", "db.t4g.micro"]
}

variable "max_asg_size" {
  description = <<-EOT
    Trần `MaxSize` của Auto Scaling Group.

    Boundary KHÔNG chặn được instance type mà ASG launch (xem README, mục
    "Boundary không bảo vệ được gì"), nên thứ chặn được là số lượng. Tuần 3
    dùng max = 3, nên 4 là vừa đủ rộng.
  EOT
  type        = number
  default     = 4
}

# --- Ngân sách --------------------------------------------------------------

variable "notify_email" {
  description = "Email nhận cảnh báo ngân sách. KHÔNG có mặc định — bắt buộc khai báo, vì một ngân sách không ai đọc thì không phải ngân sách."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.notify_email))
    error_message = "notify_email phải là một địa chỉ email hợp lệ."
  }
}

variable "budget_name" {
  description = "Tên budget. guard.sh tra đúng tên này để xác nhận ngân sách còn sống."
  type        = string
  default     = "labs-self-budget"
}

variable "budget_limit_usd" {
  description = "Trần chi tiêu hàng tháng, USD. Cả 12 tuần làm đúng quy trình tốn dưới $2, nên $5 là ngưỡng báo động chứ không phải hạn mức."
  type        = string
  default     = "5"
}

variable "budget_thresholds" {
  description = "Các mốc % chi tiêu thực tế sẽ gửi mail cảnh báo."
  type        = list(number)
  default     = [50, 80, 100]
}
