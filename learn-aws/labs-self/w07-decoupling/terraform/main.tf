# ===========================================================================
# Tuần 7 — Tách rời hệ thống.  Bạn viết toàn bộ file này.
#
# Đề bài ở ../README.md. Đọc hết mục "Yêu cầu" và "Hợp đồng output" trước khi
# gõ dòng đầu tiên — verify.sh chấm đúng những gì viết ở đó, không hơn không kém.
#
# Nhắc lại hợp đồng output (khai ở outputs.tf, không phải ở đây):
#
#   kenh_don_hang     ARN của điểm phát tán
#   hang_doi_ketoan   URL hàng đợi kế toán      — nhận mọi đơn
#   hang_doi_gianlan  URL hàng đợi chống gian lận — chỉ đơn gia_tri >= 1000
#   hang_doi_cach_ly  URL nơi đơn độc nằm lại sau 3 lần thất bại
#
# Ràng buộc:
#   - prefix tên resource: self-w07-
#   - region us-east-1, đã cố định trong providers.tf
#   - mọi IAM role bạn tạo phải có permissions_boundary trỏ tới labs-self-boundary
#   - $0. Nếu bạn sắp tạo thứ gì tính tiền theo giờ thì bạn đang đi sai hướng.
#
# Thứ tự làm gợi ý: phát tán → hai hàng đợi → cho phép đẩy vào hàng đợi →
# lọc → visibility/long polling → cách ly. Apply sau mỗi bước.
#
# Kẹt quá thì mở ../HINTS.md, từng tầng một.
# ===========================================================================
