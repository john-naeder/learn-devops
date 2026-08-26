# ===========================================================================
# Tuần 12 — Máy chấm cho chính bạn.  Bạn viết toàn bộ file này.
#
# Đề bài ở ../README.md. Lab này có BA hợp đồng, không phải một — đọc hết cả ba
# trước khi gõ dòng đầu tiên, vì verify.sh chấm đúng những gì viết ở đó:
#
#   "Hợp đồng dữ liệu"       schema của item trong kho ôn tập
#   "Hợp đồng của giám khảo" payload vào / JSON ra của hàm chấm
#   "Hợp đồng output"        tên output Terraform bắt buộc
#
# Nhắc lại hợp đồng output (khai ở outputs.tf, không phải ở đây):
#
#   bang_on_tap     tên kho ôn tập
#   chi_muc_mien    tên đường vào thứ hai, khoá phân vùng là mien
#   ham_giam_khao   tên hàm giám khảo verify.sh gọi
#   chi_phi         số, USD/giờ bạn KHAI. verify đối chiếu lời khai với thực tế
#
# Ràng buộc:
#   - prefix tên resource: self-w12-   (sai prefix -> AccessDenied nói là do
#     permissions boundary, nhưng thật ra là lỗi đặt tên. Xem README.)
#   - region us-east-1, đã cố định trong providers.tf
#   - danh tính giám khảo chạy dưới BẮT BUỘC có permissions_boundary trỏ tới
#     labs-self-boundary:
#         terraform -chdir=../../_boundary output -raw lab_boundary_arn
#   - $0,00/giờ TUYỆT ĐỐI. Kho ôn tập phải ở chế độ tính tiền THEO LƯỢT DÙNG.
#     Hàng rào KHÔNG chặn được bạn chọn nhầm chế độ đặt trước dung lượng —
#     đó là lỗ của tầng 1 mà lab này dạy bạn nhìn thấy, và verify.sh là tầng
#     bắt nó. Xem README mục "Một lỗ của hàng rào".
#
# Thứ tự làm gợi ý, apply sau mỗi bước — đừng viết cả 30 item rồi mới apply
# lần đầu, vì sai schema ở item thứ nhất là sai ở cả ba mươi:
#
#   1. kho ôn tập + đường vào thứ hai, chưa có item nào
#      -> aws dynamodb describe-table, xem sơ đồ khoá có đúng như README không
#   2. ĐÚNG HAI bảng so sánh
#      -> truy vấn bằng tay, đọc lại kiểu dữ liệu của từng thuộc tính
#   3. giám khảo + danh tính của nó, mới chỉ chế độ kiem_ke
#      -> chế độ dễ nhất, và nó chứng minh hàm ĐỌC ĐƯỢC kho
#   4. hai câu hỏi, rồi chế độ cham
#   5. chế độ de_thi
#   6. RỒI MỚI ngồi viết nốt 8 bảng và 18 câu còn lại
#
# Bước 6 chiếm khoảng ba trong năm giờ của buổi lab, và đó là ba giờ ôn thi
# thật sự. Năm bước đầu chỉ là dựng cái khuôn để đựng nó. Đừng đảo thứ tự:
# viết 20 câu hỏi rồi mới phát hiện schema sai là cách mất một buổi tối.
#
# Ba chỗ dễ mất thời gian nhất, theo thứ tự:
#
#   - Kiểu dữ liệu khi nạp item. Kho này lưu JSON có gắn nhãn kiểu, và chuỗi
#     rỗng thì không nạp được. Sai một nhãn là ValidationException không nói rõ
#     item nào — nạp hai item trước rồi kiểm, đừng nạp ba mươi.
#
#   - Truy vấn phải CHỌN LỌC, không được quét rồi lọc. verify.sh so sánh
#     ScannedCount của hai đường lấy ra CÙNG một kết quả; đường của bạn phải rẻ
#     hơn đường quét. Đây là lý do khoá sắp xếp có tiền tố bang# và cauhoi#.
#
#   - Quyền của giám khảo. Nó đọc kho qua HAI ARN khác nhau: ARN của kho, và
#     ARN của đường vào thứ hai. Cấp thiếu cái thứ hai là lỗi phổ biến nhất,
#     và thông điệp lỗi không nói ra điều đó.
#
#   - Đóng gói mã của giám khảo. Bạn có hai đường: nén sẵn một tệp zip rồi trỏ
#     vào nó, hoặc để Terraform tự nén lúc apply. Đường thứ hai cần một provider
#     nữa, và Terraform tự tải nó về — versions.tf cho sẵn KHÔNG cần sửa.
#
# Đừng cấp cho giám khảo quyền ghi. verify.sh có một check phủ định cho việc
# này: một máy chấm sửa được ngân hàng đề là một máy chấm sửa được điểm của
# chính nó, và đó là câu hỏi Domain 1 chứ không phải một chi tiết nhỏ.
#
# Và một việc ngoài Terraform, làm TRƯỚC khi destroy: xuất kho ôn tập ra một
# tệp JSON rồi giữ lại. Hạ tầng của lab này vứt đi được; nội dung bạn viết vào
# nó thì không. Lệnh cụ thể ở ../README.md mục "Dọn dẹp".
#
# Kẹt quá thì mở ../HINTS.md, từng tầng một.
# ===========================================================================
