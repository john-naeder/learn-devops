# ===========================================================================
# Tuần 6 — API không có máy chủ nào.  Bạn viết toàn bộ file này.
#
# Đề bài ở ../README.md. Đọc hết mục "Yêu cầu" (nhất là bốn yêu cầu đầu — đó là
# HỢP ĐỒNG HTTP, verify.sh gọi thật vào đúng những đường dẫn đó) và mục
# "Hàng rào của lab này" TRƯỚC khi gõ dòng đầu tiên.
#
# Nhắc lại hợp đồng output (khai ở outputs.tf, không phải ở đây):
#
#   api_url         gốc địa chỉ API, có https://, KHÔNG có dấu / ở cuối
#   api_id          id của API — verify tra trần tốc độ của stage qua nó
#   duong_dan_tao   đường dẫn tạo mã, bắt đầu bằng /
#   function_name   tên phần xử lý — verify tra cấu hình và nơi ghi log
#   role_arn        ARN danh tính của phần xử lý
#   table_name      tên bảng dữ liệu
#   chi_phi         chuỗi ghi giá/giờ và giá nếu quên một tháng
#
# ---------------------------------------------------------------------------
# BA RÀNG BUỘC LÀM GÃY `terraform apply` NẾU BỎ QUA
# ---------------------------------------------------------------------------
#
#   1. Mọi aws_iam_role BẮT BUỘC có permissions_boundary trỏ tới boundary của
#      bộ lab. Thiếu nó -> AccessDenied ngay ở resource đầu tiên, và thông điệp
#      lỗi KHÔNG nhắc gì tới code của bạn. Lấy ARN:
#
#          terraform -chdir=../../_boundary output -raw lab_boundary_arn
#
#   2. Tên tài nguyên phải có tiền tố  self-w06-  . Sai tiền tố thì hôm nay vẫn
#      tạo được, nhưng lần đầu bạn sửa trust policy sẽ ăn AccessDenied *nói là
#      do permission boundary* trong khi thật ra chỉ là lỗi đặt tên.
#
#   3. Region us-east-1, đã cố định trong providers.tf. Đừng đụng vào.
#
# ---------------------------------------------------------------------------
# THỨ TỰ LÀM GỢI Ý — apply sau mỗi bước, đừng viết một mạch rồi apply một lần
# ---------------------------------------------------------------------------
#
#   1. Kho dữ liệu. Chọn chế độ tính tiền không phát sinh phí khi rảnh
#      (yêu cầu 11). Nghĩ kỹ khoá chính trước khi tạo — đổi khoá chính nghĩa là
#      xoá bảng và tạo lại.
#
#   2. Danh tính cho phần xử lý: trust policy (ai được đóng vai role này) +
#      identity policy (role này làm được gì) + permissions_boundary.
#      Yêu cầu 7 nói rõ những gì PHẢI bị từ chối — viết policy theo danh sách
#      đó, đừng viết dynamodb:* rồi tính sau.
#
#   3. Nhóm log, khai TƯỜNG MINH với hạn giữ (yêu cầu 10). Nếu để dịch vụ tự
#      tạo nhóm log thì nó giữ log vĩnh viễn VÀ nó ở lại sau terraform destroy.
#      Tra: quy ước đặt tên nhóm log của Lambda, và depends_on.
#
#   4. Phần xử lý. Gọi tay bằng `aws lambda invoke` cho tới khi nó chạy đúng,
#      TRƯỚC khi ghép API vào — gỡ lỗi qua hai tầng cùng lúc là cách tốn thời
#      gian nhất.
#
#   5. API + route + tích hợp + quyền cho API gọi phần xử lý (đây là hướng
#      quyền thứ hai, ngược chiều với cái ở bước 2 — README nói rõ chỗ này).
#
#   6. Trần tốc độ trên stage (yêu cầu 11).
#
# ---------------------------------------------------------------------------
# CHỖ TỐN THỜI GIAN NHẤT, BÁO TRƯỚC ĐỂ BẠN KHÔNG NGẠC NHIÊN
# ---------------------------------------------------------------------------
#
# Không phải Terraform. Là yêu cầu 4: mọi input sai phải ra 400 với thân JSON
# có trường "loi", không phải 500. Một script quen tay sẽ để exception bay lên
# và thành 500. Một API thì bắt lấy, phân loại, và tự trả lời. Viết phần đọc
# input như thể mọi thứ gửi tới đều là rác — vì đó là sự thật khi API mở ra
# internet.
#
# Đóng gói mã nguồn hàm: Terraform tự nén được bằng data "archive_file"
# (provider `hashicorp/archive`, khai thêm trong versions.tf nếu bạn dùng).
# Cách khác: nén sẵn bằng tay và trỏ filename tới file .zip. Cả hai đều được —
# verify.sh không quan tâm bạn đóng gói kiểu gì.
#
# Kẹt quá thì mở ../HINTS.md, từng tầng một.
# ===========================================================================
