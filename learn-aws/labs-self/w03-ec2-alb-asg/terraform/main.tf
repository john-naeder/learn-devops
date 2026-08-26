# ===========================================================================
# Tuần 3 — Giết một máy, không ai biết
#
# File này CỐ Ý TRỐNG. Đề bài đầy đủ ở ../README.md.
#
# ĐẶT HẸN GIỜ 4 TIẾNG NGAY BÂY GIỜ. Lab này ~$0,053/giờ, quên 1 tháng ~$39.
# ===========================================================================
#
# TÓM TẮT ĐỀ:
#
#   Trang landing cho một chiến dịch marketing chạy ba ngày.
#   Giám đốc marketing: "Tôi muốn một máy chết mà khách không nhận ra."
#   Đội bảo mật: máy chạy web không được lộ ra internet; chỉ đúng một thứ
#   được phép nhận kết nối từ bên ngoài.
#   Đội tài chính: tối đa 4 máy, và xong chiến dịch là mọi thứ biến mất.
#
#   verify.sh sẽ THẬT SỰ terminate một máy đang phục vụ rồi vừa gọi liên tục
#   vào endpoint của bạn vừa chờ. Trong 12 phút phải có máy mới thay thế, máy
#   chết phải bị gỡ khỏi vòng nhận traffic, và tỉ lệ lỗi phải dưới 15%.
#
#   Chú ý yêu cầu 6: hệ thống phải phân biệt được "máy còn sống" với "ứng dụng
#   còn phục vụ được". Mặc định của AWS không phân biệt hai thứ đó.
#
# ---------------------------------------------------------------------------
# HỢP ĐỒNG OUTPUT — tên phải khớp từng ký tự.
#
#   endpoint_url       string   URL đầy đủ CÓ scheme http://
#   asg_name           string   tên nhóm quản lý đàn máy
#   target_group_arn   string   ARN của nhóm đích
#   vpc_id             string   ID của VPC
#   chi_phi            string   ước tính USD/giờ và USD nếu quên 1 tháng
#
# ---------------------------------------------------------------------------
# QUY ƯỚC BẮT BUỘC
#
#   - Mọi tên resource bắt đầu bằng  self-w03-
#   - Region us-east-1, profile lab-builder — đã đặt sẵn trong providers.tf
#   - Tag lab/owner tự động qua default_tags, đừng gỡ
#   - MaxSize của nhóm máy KHÔNG VƯỢT QUÁ 4 (boundary chặn ở tầng API)
#   - Instance type trong danh sách rẻ: t2.micro, t3.micro, t3.small,
#     t4g.micro, t4g.small. Dùng t4g.* thì AMI phải là bản arm64.
#
#   CẢNH BÁO THẬT: nhóm máy launch instance bằng service-linked role của dịch
#   vụ Auto Scaling, KHÔNG bằng danh tính lab-builder của bạn. Nghĩa là
#   permission boundary KHÔNG nhìn thấy và KHÔNG chặn được instance type mà
#   launch template khai. Viết nhầm m5.24xlarge thì AWS launch thật và không
#   ai cản. Hàng rào còn lại chỉ là MaxSize và ngân sách $5. Đọc kỹ dòng này
#   một lần nữa trước khi gõ terraform apply.
#
# ---------------------------------------------------------------------------
# Bắt đầu viết từ dòng dưới đây.
