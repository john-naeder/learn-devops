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
  default = "w03"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t4g.micro", "t4g.small"], var.instance_type)
    error_message = "Chỉ dùng instance rẻ. t3.micro ~$0,0104/giờ."
  }
}

# ---------------------------------------------------------------------------
# BUỔI TỐN TIỀN NHẤT CẢ KHÓA. Bảng chi phí khi lab đang chạy:
#
#   ALB                     $0,0225/giờ   ← chiếm phần lớn
#   2 x t3.micro            $0,0208/giờ
#   2 x public IPv4         $0,0100/giờ
#   ------------------------------------
#   TỔNG                    ~$0,053/giờ   → lab 3 tiếng ~$0,16
#                                         → để quên 1 tháng ~$39
#
# ALB không có bậc miễn phí nào trong Free Tier mới. Nó tính tiền từ giây đầu.
# ---------------------------------------------------------------------------

variable "asg_min" {
  type    = number
  default = 1
}

variable "asg_desired" {
  description = "Số máy mong muốn. 2 để thấy load balancing luân phiên."
  type        = number
  default     = 2
}

variable "asg_max" {
  type    = number
  default = 3

  validation {
    condition     = var.asg_max <= 4
    error_message = "Giữ max <= 4. Mỗi instance thêm là ~$7,5/tháng nếu quên tắt."
  }
}

# ---------------------------------------------------------------------------
# Vì sao instance nằm ở PUBLIC subnet trong lab này (khác tuần 2)?
#
# User data cần `dnf install nginx`, tức là cần internet. Từ private subnet chỉ
# có hai đường ra: NAT Gateway (~$33/tháng) hoặc không có gì.
#
# Đây là một ĐÁNH ĐỔI CÓ CHỦ ĐÍCH, không phải cẩu thả:
#   - Production: instance ở private subnet, ALB ở public, ra internet qua NAT.
#   - Lab này:    instance ở public subnet để tránh $33/tháng.
#
# Bù lại, bảo mật vẫn được giữ đúng theo cách khác: security group của instance
# CHỈ nhận traffic từ security group của ALB, không nhận từ internet. Tức là
# máy có public IP nhưng không ai gọi thẳng vào được. Đây là mẫu "SG tham chiếu
# SG" và nó hay ra thi.
# ---------------------------------------------------------------------------
variable "instances_in_public_subnet" {
  description = "true = tiết kiệm NAT (mặc định). false = đúng chuẩn production nhưng cần NAT ~$33/tháng."
  type        = bool
  default     = true
}
