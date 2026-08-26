# ===========================================================================
# Tuần 5 — Đọc đúng thứ mình cần
#
# File này CỐ Ý TRỐNG. Đề bài đầy đủ ở ../README.md.
#
# Lab rẻ nhất cả bộ (~$0/giờ). Toàn bộ điểm số nằm ở một quyết định thiết kế
# bạn đưa ra trong 20 phút đầu. Đừng gõ trước khi vẽ xong khoá ra giấy.
# ===========================================================================
#
# TÓM TẮT ĐỀ:
#
#   Một cửa hàng trực tuyến. Ba màn hình đang dùng chung một kho dữ liệu đơn
#   hàng:
#
#     - Trang tài khoản: các đơn CỦA MỘT KHÁCH, mới nhất trước, có lọc
#       "từ ngày X trở đi"
#     - Bảng treo tường của đội vận hành: MỌI đơn đang ở MỘT TRẠNG THÁI, của
#       mọi khách, làm mới 30 giây một lần
#     - Nút "theo dõi đơn": ghi một bản ghi tạm, chỉ có nghĩa vài giờ, phải tự
#       biến mất mà không ai chạy job dọn
#
#   Điều kiện cứng, và đây là toàn bộ bài:
#
#     TRẢ LỜI MỘT CÂU HỎI NGHIỆP VỤ KHÔNG ĐƯỢC ĐỌC NHIỀU BẢN GHI HƠN SỐ BẢN
#     GHI THỰC SỰ TRẢ VỀ.
#
#   verify.sh không đọc file .tf của bạn và cũng không cần biết bạn đặt tên
#   thuộc tính là gì. Nó hỏi thẳng AWS xem bảng có khoá nào, tên gì, kiểu gì,
#   rồi TỰ DỰNG câu truy vấn và in ra hai con số cạnh nhau: đọc bao nhiêu,
#   trả về bao nhiêu. Lệch một bản ghi cũng đỏ.
#
#   Bốn check phủ định:
#     - hỏi mà thiếu khoá phân hoạch  -> kho dữ liệu phải TỪ CHỐI
#     - cách "đọc cả bảng rồi lọc"    -> đúng cùng kết quả, nhưng đọc gấp N lần
#     - thuộc tính hết hạn sai kiểu / sai đơn vị / mốc quá khứ -> đỏ
#     - khoá phân hoạch dồn vào ít giá trị -> đỏ
#
# ---------------------------------------------------------------------------
# HỢP ĐỒNG OUTPUT — tên phải khớp từng ký tự.
#
#   table_name              string  tên bảng
#   gsi_name                string  tên chỉ mục phụ trả lời câu hỏi 2
#   khach_mau               string  giá trị khoá phân hoạch của một khách
#                                   CÓ SẴN dữ liệu trong bảng
#   so_don_cua_khach_mau    number  số đơn của khách đó (>= 8)
#   trang_thai_mau          string  giá trị trạng thái cho câu hỏi 2
#   so_don_trang_thai_mau   number  số đơn đang ở trạng thái đó
#   chi_phi                 string  ước tính USD/giờ và USD nếu quên 1 tháng
#
# Bảng phải có sẵn ÍT NHẤT 80 đơn, của ÍT NHẤT 10 khách khác nhau. Nạp dữ liệu
# bằng cách nào là việc của bạn — nhưng đừng gõ tay 80 lần.
#
# ---------------------------------------------------------------------------
# QUY ƯỚC BẮT BUỘC
#
#   - Mọi tên resource bắt đầu bằng  self-w05-
#   - Region us-east-1, profile lab-builder — đã đặt sẵn trong providers.tf
#   - Tag lab/owner tự động qua default_tags, đừng gỡ
#   - Chế độ tính tiền: theo request, HOẶC provisioned với tổng RCU <= 25 và
#     tổng WCU <= 25 tính CẢ chỉ mục phụ. Ngoài hai lựa chọn đó là ra tiền.
#   - KHÔNG tạo RDS, KHÔNG tạo cluster (boundary chặn hoàn toàn), KHÔNG
#     ElastiCache, KHÔNG Kinesis stream.
#
#   CHÚ Ý MỘT CHỖ DỄ NHẦM: "DynamoDB Streams" và "Kinesis Data Streams" là hai
#   thứ khác nhau. Cái đầu miễn phí và bật bằng một dòng cấu hình trên chính
#   bảng, không tạo stream nào cả. Cái sau tính tiền theo shard và bị boundary
#   chặn. Nếu bạn thấy mình sắp gọi kinesis:CreateStream thì đang đi nhầm đường.
#
# ---------------------------------------------------------------------------
# Bắt đầu viết từ dòng dưới đây.
