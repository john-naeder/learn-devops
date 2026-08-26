# ===========================================================================
# Tuần 4 — Kho đóng, cửa hàng mở
#
# File này CỐ Ý TRỐNG. Đề bài đầy đủ ở ../README.md.
#
# Lab này gần như $0/giờ. Cái đắt của nó không phải tiền — là RÁC:
# bucket bật versioning không xoá được bằng cách xoá file thường.
# Đọc mục "Dọn dẹp" của README TRƯỚC khi apply, không phải sau.
# ===========================================================================
#
# TÓM TẮT ĐỀ:
#
#   Trang tài liệu kỹ thuật, người đọc ở khắp thế giới, than chậm.
#
#   Đội bảo mật: KHÔNG kho lưu trữ nào của công ty được truy cập trực tiếp
#   từ internet. Không ngoại lệ, kể cả với nội dung công khai — vì một kho
#   mở là một kho liệt kê được, và cấu trúc thư mục cũng là thông tin.
#
#   Đội tài liệu: ghi đè nhầm thì phải tự khôi phục được bản trước.
#
#   Đội tài chính: bản nháp cũ phải tự dọn, đừng để ai nhớ.
#
#   Nghĩa là: người dùng ẩn danh ở Brazil phải tải được trang, còn cùng
#   người đó gọi thẳng vào nơi lưu trữ thì phải nhận 403. Chọn cơ chế nào
#   để đạt được hai điều đó cùng lúc là việc của bạn.
#
#   verify.sh có BỐN check phủ định: gọi thẳng vào kho, gọi ẩn danh vào
#   gốc kho, gọi bằng http:// không mã hoá, và kho không được tự phục vụ
#   web. Cả bốn phải bị chặn thật, không phải "chắc là bị chặn".
#
# ---------------------------------------------------------------------------
# HỢP ĐỒNG OUTPUT — tên phải khớp từng ký tự, không thừa không thiếu.
#
#   cdn_url                 string  gốc địa chỉ công khai, có https://,
#                                   KHÔNG có dấu / ở cuối
#   duong_dan_trang_chu     string  đường dẫn trang chủ, BẮT ĐẦU bằng /
#                                   ví dụ /index.html
#   bucket_name             string  tên kho lưu trữ
#   bucket_regional_domain  string  tên miền REST của kho,
#                                   <ten>.s3.us-east-1.amazonaws.com
#   chuoi_moc               string  chuỗi mốc phải xuất hiện trong trang chủ
#                                   ví dụ MOC-W04-7f3a9c
#   chi_phi                 string  ước tính USD/giờ và USD nếu quên 1 tháng
#
# Trang chủ phải DÀI HƠN 1 KB. Dịch vụ CDN không nén file nhỏ hơn 1 KB, và
# bạn sẽ mất một tiếng debug nhầm chỗ nếu trang chủ chỉ có 20 chữ.
#
# ---------------------------------------------------------------------------
# QUY ƯỚC BẮT BUỘC
#
#   - Mọi tên resource bắt đầu bằng  self-w04-
#     Tên bucket phải duy nhất TOÀN CẦU: ghép thêm account id vào cuối.
#     Dùng data.aws_caller_identity.toi.account_id đã cho sẵn trong providers.tf
#   - Region us-east-1, profile lab-builder — đã đặt sẵn trong providers.tf
#   - Tag lab/owner tự động qua default_tags, đừng gỡ
#   - KHÔNG bật replication (nhân đôi lưu trữ, và tạo đồ ở region thứ hai)
#   - KHÔNG tạo customer managed KMS key ($1/tháng mỗi key, lab không cần)
#   - KHÔNG bật access log của CDN vào S3 (ghi liên tục, không có trần)
#   - KHÔNG mua tên miền, không tạo hosted zone
#
#   Nếu bạn thấy mình đang gõ một dòng để TẮT một khoá chặn public: dừng lại.
#   Bài này giải bằng cách cấp cho cửa hàng một danh tính để vào kho, không
#   phải bằng cách mở toang cửa kho.
#
# ---------------------------------------------------------------------------
# Bắt đầu viết từ dòng dưới đây.
