# ===========================================================================
# Tuần 1 — Ai được làm gì
#
# File này CỐ Ý TRỐNG. Bạn viết toàn bộ hạ tầng từ đây.
# Đề bài đầy đủ ở ../README.md — đọc nó trước, đừng đoán từ comment này.
# ===========================================================================
#
# TÓM TẮT ĐỀ (bản đầy đủ ở README.md, mục "Yêu cầu"):
#
#   Một kho lưu trữ dùng chung, hai khu vực: báo cáo và lương.
#   Ba bên cần đụng vào:
#     - chị Lan (phân tích): chỉ đọc khu báo cáo
#     - job tổng hợp chạy trên máy chủ AWS: chỉ ghi thêm vào khu báo cáo,
#       và không được tồn tại credential dài hạn nào cho nó
#     - công ty kiểm toán ở account AWS khác: mượn danh tính, phải xuất trình
#       một chuỗi bí mật đã thoả thuận trước
#   Không ai đọc được khu lương.
#   Kho tự từ chối mọi request không mã hoá đường truyền — việc chặn nằm ở
#   phía kho, không trông chờ từng danh tính tự giữ kỷ luật.
#   Không danh tính nào tự nới quyền cho chính mình được.
#
# ---------------------------------------------------------------------------
# HỢP ĐỒNG OUTPUT — verify.sh chỉ nhìn thấy hạ tầng của bạn qua đây.
# Tên phải khớp từng ký tự. Thiếu một cái là không chấm được.
#
#   bucket_name           string   tên kho
#   bucket_arn            string   ARN kho
#   prefix_bao_cao        string   tiền tố khu báo cáo, CÓ dấu / ở cuối
#   prefix_luong          string   tiền tố khu lương, CÓ dấu / ở cuối
#   analyst_arn           string   ARN danh tính chị Lan
#   app_role_arn          string   ARN danh tính job tổng hợp (phải là role)
#   partner_role_arn      string   ARN danh tính cho kiểm toán
#   partner_external_id   string   chuỗi bí mật để mượn danh tính đó
#   chi_phi               string   tự ước tính; lab này phải ra $0
#
# Bạn có thể để output ở file này hoặc tách ra outputs.tf — tuỳ bạn.
#
# ---------------------------------------------------------------------------
# QUY ƯỚC BẮT BUỘC
#
#   - Mọi tên resource bắt đầu bằng  self-w01-
#     (permission boundary có điều kiện dựa trên tiền tố này)
#   - Region us-east-1, profile lab-builder — đã đặt sẵn trong providers.tf
#   - Tag lab/owner đã tự động qua default_tags, đừng gỡ
#   - Tên bucket phải duy nhất TOÀN CẦU. Ghép account ID vào cho chắc:
#     data.aws_caller_identity.toi.account_id đã có sẵn trong providers.tf
#
# ---------------------------------------------------------------------------
# Bắt đầu viết từ dòng dưới đây.
