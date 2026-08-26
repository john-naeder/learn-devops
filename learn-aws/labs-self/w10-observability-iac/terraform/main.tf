# ===========================================================================
# Tuần 10 — Cảnh báo phải kêu.  Bạn viết toàn bộ file này.
#
# Đề bài ở ../README.md. Đọc hết mục "Yêu cầu", "Hợp đồng đầu vào của dịch vụ"
# và "Hợp đồng output" trước khi gõ dòng đầu tiên — verify.sh chấm đúng những gì
# viết ở đó, không hơn không kém.
#
# Nhắc lại hợp đồng output (khai ở outputs.tf, không phải ở đây):
#
#   ten_ham            tên hàm verify.sh gọi để gây lỗi
#   nhom_nhat_ky       tên nhóm nhật ký
#   so_do_khong_gian   namespace của số đo lỗi
#   so_do_ten          tên số đo lỗi
#   ten_canh_bao       tên cảnh báo
#   hop_thu_truc       URL hộp thư mà verify ĐỌC để chứng minh cảnh báo tới nơi
#   ten_truy_van       tên truy vấn đã lưu
#   kho_state          tên kho chứa state Terraform
#   duong_dan_state    key của object state trong kho đó
#   bang_khoa_state    tên bảng dùng làm khoá chống ghi đồng thời
#
# Ràng buộc:
#   - prefix tên resource: self-w10-   (sai prefix -> AccessDenied nói là do
#     permission boundary, nhưng thật ra là lỗi đặt tên. Xem README.)
#   - region us-east-1, đã cố định trong providers.tf
#   - role thực thi của hàm BẮT BUỘC có permissions_boundary trỏ tới
#     labs-self-boundary:
#         terraform -chdir=../../_boundary output -raw lab_boundary_arn
#   - $0. Không tài nguyên nào tính tiền theo giờ — verify.sh có một check quét
#     đúng điều đó. Và nhớ: số đo tuỳ chỉnh CHỈ miễn phí tới 10 cái, alarm tới
#     10 cái. Đừng sinh số đo theo từng mã yêu cầu.
#
# Hai pha, vì state phải nằm ở nơi chưa tồn tại lúc bạn bắt đầu:
#
#   pha 1   terraform init && terraform apply     (state còn ở local)
#   pha 2   thêm khối backend "s3" -> terraform init -migrate-state
#
# Thứ tự làm gợi ý, apply sau mỗi bước:
#   1. hàm + role thực thi + nhóm nhật ký có hạn giữ
#      -> gọi tay bằng aws lambda invoke, xem log hiện ra
#   2. số đo sinh từ nhật ký  -> gọi vài lần, xem số đo có điểm dữ liệu chưa
#   3. kênh thông báo + hộp thư trực + cho phép kênh đẩy vào hộp thư
#   4. cảnh báo trỏ tới kênh thông báo
#   5. truy vấn lưu sẵn
#   6. kho state + bảng khoá, rồi mới dời state lên (pha 2)
#
# Bước 2 là bước tốn thời gian nhất và cũng dễ sai nhất: mẫu lọc phải bắt ĐÚNG
# dòng lỗi và bỏ qua dòng bình thường, nhưng vẫn phải phát ra số 0 cho dòng bình
# thường. Hai việc đó nghe mâu thuẫn cho tới khi bạn tìm ra thuộc tính đúng.
#
# Kẹt quá thì mở ../HINTS.md, từng tầng một.
# ===========================================================================
