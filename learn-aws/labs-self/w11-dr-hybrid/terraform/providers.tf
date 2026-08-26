# CHO SẴN — không sửa file này, với đúng MỘT ngoại lệ: khối provider phụ ở
# cuối file, được phép bỏ comment sau khi bạn đã mở rào. Đọc kỹ ở đó.
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
      lab   = "w11"
      owner = "labs-self"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider phụ — ĐANG Ở DẠNG COMMENT, CÓ CHỦ ĐÍCH.
#
# Đề bài không bắt bạn dùng khối này. Cả lab chạy được trọn vẹn trong một
# Region, và README nói rõ vì sao đó là bài học chứ không phải hạn chế: cơ chế
# sao chép cùng Region và khác Region dùng chung cấu hình, chung IAM role,
# chung cách xử lý delete marker. Thứ duy nhất khác là kho đích nằm ở đâu.
#
# Nếu bạn vẫn muốn chạm vào hai Region thật, làm ĐÚNG THỨ TỰ này:
#
#   1. MỞ RÀO TRƯỚC, bằng profile admin (learn), KHÔNG phải lab-builder:
#        cd ../../_boundary
#        terraform apply -var 'notify_email=...' \
#                        -var 'allowed_regions=["us-east-1","us-west-2"]'
#   2. Rồi mới bỏ comment khối dưới đây và `terraform apply` lab này.
#   3. Xong việc: dọn Region thứ hai (../../../scripts/find-orphans.sh --all),
#      comment lại khối này, rồi ĐÓNG RÀO — vẫn bằng profile learn.
#
# Vì sao nó phải nằm ở dạng comment chứ không phải dạng sống: Terraform cấu
# hình MỌI provider trước khi chạm tới resource đầu tiên. Một provider trỏ tới
# Region đang bị `DenyOutsideAllowedRegions` chặn sẽ làm `terraform apply` gãy
# ngay ở bước đó — trước khi tới bất cứ resource nào của bạn, và với một thông
# điệp không nhắc gì tới Region. Bỏ comment SAU khi rào đã mở, không phải trước.
#
# provider "aws" {
#   alias   = "phu"
#   region  = "us-west-2"
#   profile = "lab-builder"
#
#   default_tags {
#     tags = {
#       lab   = "w11"
#       owner = "labs-self"
#     }
#   }
# }
