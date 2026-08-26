variable "region" {
  description = "Region. Giữ nguyên us-east-1 cho cả 12 tuần — đổi region là công thức để quên tài nguyên."
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile."
  type        = string
  default     = "learn"
}

variable "prefix" {
  description = "Tiền tố tên resource."
  type        = string
  default     = "w01"
}

variable "enable_access_analyzer" {
  description = "Bật IAM Access Analyzer. MIỄN PHÍ. Nó soi mọi policy và báo resource nào đang mở ra ngoài account."
  type        = bool
  default     = true
}
