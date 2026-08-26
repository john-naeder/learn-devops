# CHO SẴN — không sửa file này.
#
# Vì sao nó được cho sẵn: đây là hạ tầng của lab, không phải lời giải của bài.
#
#   profile = "lab-builder"  → danh tính có permission boundary gắn sẵn (xem
#                              ../../_boundary/). Không dùng profile "learn".
#   region  = "us-east-1"    → cố định cho cả bộ labs-self.
#   default_tags             → mọi resource tự mang hai tag dưới đây. Đó là thứ
#                              ../_lib/cleanup.sh và ../../scripts/find-orphans.sh
#                              dựa vào để tìm đồ bỏ quên. ĐỪNG GỠ.
provider "aws" {
  region  = "us-east-1"
  profile = "lab-builder"

  default_tags {
    tags = {
      lab   = "w07"
      owner = "labs-self"
    }
  }
}
