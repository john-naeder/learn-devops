# ===========================================================================
# Tuần 11 — Chọn một chiến lược DR, rồi chứng minh bạn đã dựng đúng cái mình
# chọn.  Bạn viết toàn bộ file này.
#
# Đề bài ở ../README.md. Đọc hết mục "Yêu cầu", "Hợp đồng output" và "Hàng rào
# của lab này" trước khi gõ dòng đầu tiên.
#
# Lab này chấm HAI vế, và vế thứ nhất chấm trước: bạn KHAI gì, rồi bạn DỰNG gì.
# Khai một đằng dựng một nẻo là trượt, dù hạ tầng có hoàn hảo tới đâu.
#
# ---------------------------------------------------------------------------
# Nhắc lại hợp đồng output — verify.sh gọi đúng 11 tên này, không hơn không kém
# (khai ở outputs.tf cho gọn, không nhất thiết ở file này):
#
#   LUÔN bắt buộc
#     chien_luoc_dr        backup_restore | pilot_light | warm_standby | multi_site
#     rto_phut             số nguyên phút bạn CAM KẾT
#     rpo_phut             số nguyên phút bạn CAM KẾT
#     kho_chinh            kho object chính
#     kho_du_phong         kho object chứa bản sao thứ hai
#     duong_dan_runbook    key của tệp runbook — phải có ở CẢ HAI kho
#     bang_giao_dich       kho dữ liệu giao dịch
#     chi_phi              chuỗi in ra trước khi bạn gõ yes
#
#   Chỉ bắt buộc khi bạn khai pilot_light TRỞ LÊN
#     ten_canh_bao_su_co   tín hiệu sự cố — verify ĐỌC, ÉP ĐỔI, rồi TRẢ LẠI
#     nhom_den_moi         nhóm năng lực tính toán đang tắt (yêu cầu 7)
#
#   Tuỳ chọn — bỏ trống KHÔNG bị trừ điểm
#     ma_tin_hieu_dns      id tín hiệu sức khoẻ ở tầng DNS, nếu bạn có dựng.
#                          Nó tốn $0,50/tháng và đề bài không bắt bạn mua.
#
# Khai backup_restore mà vẫn khai hai output có điều kiện thì không sao —
# verify chỉ đơn giản không đọc tới chúng.
#
# ---------------------------------------------------------------------------
# Ràng buộc:
#   - prefix tên tài nguyên: self-w11-   (sai prefix -> AccessDenied NÓI LÀ do
#     permission boundary, nhưng thật ra chỉ là lỗi đặt tên. Xem README.)
#   - region us-east-1, đã cố định trong providers.tf. Cả hai kho nằm cùng một
#     Region — đó là bài học, không phải hạn chế; README nói rõ vì sao, và nói
#     cả đường mở rào sang Region thứ hai nếu bạn muốn trả giá cho nó.
#   - MỌI aws_iam_role bạn tạo BẮT BUỘC có permissions_boundary:
#         terraform -chdir=../../_boundary output -raw lab_boundary_arn
#     Lab này cần ít nhất một role: cơ chế sao chép giữa hai kho đóng vai nó để
#     đọc kho nguồn và ghi kho đích. Đó là chỗ bạn va vào hàng rào.
#   - $0,00/giờ. verify.sh có hai check PHỦ ĐỊNH, và một trong hai quét theo tag
#     lab=w11 tìm mọi thứ tính tiền theo giờ: máy chủ, CSDL quản lý, cân bằng
#     tải, NAT, Elastic IP, Transit Gateway, VPN. Không cái nào được có mặt.
#
# ---------------------------------------------------------------------------
# Thứ tự làm gợi ý, apply sau mỗi bước:
#
#   1. QUYẾT ĐỊNH TRƯỚC, GÕ SAU. Ba giá trị chien_luoc_dr / rto_phut / rpo_phut
#      phải cùng nằm trong dải của nhau (bảng bốn chiến lược ở
#      ../../../docs/notebook/13-khoi-phuc-tham-hoa.md mục 3) TRƯỚC khi bạn tạo
#      tài nguyên đầu tiên — chúng quyết định bạn phải dựng những gì, và đó là
#      quyết định đắt nhất của lab. Hai trong bốn chiến lược tự loại mình khỏi
#      bối cảnh vì MỘT câu duy nhất trong mục Bối cảnh. Tìm ra câu đó trước.
#
#   2. Hai kho object. Cả hai đều cần lịch sử phiên bản (yêu cầu 2 và 3), cả
#      hai đều bị check phủ định soi (yêu cầu 9) — kho backup là một bản sao
#      ĐẦY ĐỦ của dữ liệu sản xuất, siết nó y như kho chính.
#
#   3. Cơ chế đưa bản sao từ kho chính sang kho dự phòng, TỰ ĐỘNG. verify đặt
#      một tệp MỚI vào kho chính rồi ngồi chờ 5 phút. "Tự động" nghĩa là không
#      ai bấm gì và không có lịch chạy nào.
#
#   4. Kho dữ liệu giao dịch + cơ chế khôi phục về một thời điểm bất kỳ. Chờ
#      vài phút rồi TỰ KIỂM mốc khôi phục gần nhất cách hiện tại bao xa, so với
#      rpo_phut bạn định khai. verify đọc mốc thật và tự trừ; nó không tin lời.
#
#   5. Runbook: viết, tải lên kho chính, rồi kiểm tra nó đã sang được kho dự
#      phòng chưa. Nội dung bị chấm — xem bước 6.
#
#   6. Nếu bạn khai pilot_light trở lên: tín hiệu sự cố (máy đọc được, đổi
#      trạng thái được, coi im lặng là dấu hiệu xấu, có nơi gửi thông điệp) và
#      nhóm năng lực tính toán đã khai báo nhưng đang ở 0.
#
# ---------------------------------------------------------------------------
# Bốn chỗ tốn thời gian nhất, biết trước để không hoảng:
#   - Bước 3 và 4 cần THỜI GIAN THẬT trôi qua. Bản sao và mốc khôi phục đều
#     không có ngay sau apply.
#   - Cơ chế sao chép chỉ áp cho object tạo SAU khi rule ra đời. Runbook bạn
#     tải lên trước khi bật rule sẽ nằm lại kho chính một mình, mãi mãi.
#   - Nội dung runbook bị chấm theo CHUỖI: đúng giá trị chien_luoc_dr, cả hai
#     con số RTO/RPO, và các bước đánh số TĂNG DẦN.
#   - Tín hiệu sự cố kẹt ở "không đủ dữ liệu" trông y hệt tín hiệu khoẻ trên
#     dashboard. verify phân biệt được, mắt người thì không.
#
# Hai check phủ định dễ bị chính bạn phá:
#   - Không thành phần nào được tính tiền theo giờ, kể cả thứ đang tắt mà vẫn
#     giữ tài nguyên (Elastic IP không gắn vào đâu là ví dụ kinh điển).
#   - CẢ HAI kho phải từ chối người không có credential. Kho backup bị quên
#     siết là khởi đầu của rất nhiều vụ lộ dữ liệu.
#
# Kẹt quá thì mở ../HINTS.md, từng tầng một.
# ===========================================================================
