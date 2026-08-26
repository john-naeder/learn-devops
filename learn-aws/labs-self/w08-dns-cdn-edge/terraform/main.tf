# ===========================================================================
# Tuần 8 — Tầng biên.  Bạn viết toàn bộ file này.
#
# Đề bài ở ../README.md.
#
# Hợp đồng output (khai ở outputs.tf):
#
#   dia_chi_bien   tên miền của điểm biên, KHÔNG kèm https:// và không có / cuối
#   kho_luu_tru    tên kho lưu trữ gốc
#   ten_mien       TUỲ CHỌN — chỉ khai nếu bạn làm yêu cầu 5
#   vung_dns       TUỲ CHỌN — đi kèm ten_mien
#
# Hợp đồng nội dung: ba đường dẫn sau phải trả về 200 qua tầng biên.
#
#   /tinh/thu.txt        query string KHÔNG tách bản cache
#   /nguoidung/thu.txt   query string CÓ tách bản cache
#   /api/thu.txt         không bao giờ phục vụ từ bản đã lưu
#
# Ràng buộc:
#   - prefix tên resource: self-w08-
#   - kho lưu trữ phải private hoàn toàn; đường duy nhất vào là qua biên
#   - $0. Thứ duy nhất trong lab này tính tiền theo tháng là hosted zone
#     ($0,50) — và nó tuỳ chọn.
#
# Cảnh báo thời gian: mỗi lần apply/destroy distribution mất 8–15 phút.
# Viết cho đủ rồi hãy apply. Đừng apply từng dòng một.
# ===========================================================================
