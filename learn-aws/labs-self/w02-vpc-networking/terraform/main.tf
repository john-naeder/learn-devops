# ===========================================================================
# Tuần 2 — Máy không có cửa
#
# File này CỐ Ý TRỐNG. Đề bài đầy đủ ở ../README.md.
# ===========================================================================
#
# TÓM TẮT ĐỀ:
#
#   Một job xử lý ảnh chạy trên một máy chủ Linux nội bộ.
#   Đội bảo mật: không cửa nào mở ra internet — không port 22 từ ngoài,
#   không bastion, không IP công khai, không khoá SSH.
#   Vận hành: bạn vẫn phải chạy được lệnh trên máy đó lúc 2 giờ sáng.
#   Đội dev: máy vẫn phải tải được gói phần mềm từ repo chính thức của distro.
#   Tài chính: đường ra internet không được đắt hơn chính cái máy ($7,5/tháng).
#   Và: KHÔNG NAT GATEWAY. Đó là một phần của đề bài, không phải trở ngại.
#
#   Ba yêu cầu "máy nói chuyện được với bên ngoài" đi qua BA đích đến khác
#   nhau, với ba mức giá chênh nhau hàng chục lần. Nhận ra điều đó là toàn bộ
#   nội dung của lab này.
#
# ---------------------------------------------------------------------------
# HỢP ĐỒNG OUTPUT — tên phải khớp từng ký tự.
#
#   vpc_id              string   ID của VPC
#   public_subnet_ids   string   danh sách subnet công khai, PHÂN TÁCH BẰNG DẤU PHẨY
#   private_subnet_ids  string   danh sách subnet riêng tư, phân tách bằng dấu phẩy
#   instance_id         string   ID máy chủ ở tầng riêng tư
#   bucket_name         string   tên kho object mà máy phải đọc được
#   flow_log_group      string   tên CloudWatch log group nhận Flow Logs
#   chi_phi             string   ước tính USD/giờ và USD nếu quên 1 tháng
#
#   `terraform output -raw` không đọc được list. Dùng join(",", ...) cho hai
#   output danh sách.
#
# ---------------------------------------------------------------------------
# QUY ƯỚC BẮT BUỘC
#
#   - Mọi tên resource bắt đầu bằng  self-w02-
#   - Region us-east-1, profile lab-builder — đã đặt sẵn trong providers.tf
#   - Tag lab/owner tự động qua default_tags, đừng gỡ
#   - Instance type phải nằm trong danh sách boundary cho phép
#     (t2.micro, t3.micro, t3.small, t4g.micro, t4g.small)
#   - Log group PHẢI khai báo thời hạn lưu. Mặc định của CloudWatch là VĨNH VIỄN.
#
# ---------------------------------------------------------------------------
# Bắt đầu viết từ dòng dưới đây.
