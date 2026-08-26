# ===========================================================================
# Tuần 9 — Những thứ KHÔNG được phép xảy ra.  Bạn viết toàn bộ file này.
#
# Đề bài ở ../README.md. Đọc hết mục "Yêu cầu" và "Hợp đồng output" trước khi
# gõ dòng đầu tiên — verify.sh chấm đúng những gì viết ở đó, không hơn không kém.
#
# Nhắc lại hợp đồng output (khai ở outputs.tf, không phải ở đây):
#
#   vai_van_hanh      ARN vai vận hành viên — mượn được, phiên <= 1 giờ, cần mã ngoài
#   ma_ngoai          chuỗi bí mật phải kèm khi mượn vai vận hành
#   vai_pha_kinh      ARN vai duy nhất đọc được bi-mat/
#   kho_du_lieu       tên kho dữ liệu
#   ranh_gioi_quyen   ARN customer managed policy đóng vai trần quyền (yêu cầu 7)
#   duong_bi_mat      tên tham số bí mật vận hành viên ĐƯỢC đọc
#   duong_bi_mat_cam  tên tham số bí mật vận hành viên KHÔNG được đọc
#
# Hợp đồng nội dung — verify.sh gọi đúng hai khoá này, bạn phải đưa lên kho:
#
#   lam-viec/thu.txt     khu làm việc — vận hành viên và admin đều đọc được
#   bi-mat/thu.txt       bảng lương  — chỉ vai phá kính đọc được
#
# Ràng buộc:
#   - prefix tên resource: self-w09-   (sai prefix -> AccessDenied nói là do
#     permission boundary, nhưng thật ra là lỗi đặt tên. Xem README.)
#   - region us-east-1, đã cố định trong providers.tf
#   - MỌI aws_iam_role bạn tạo phải có permissions_boundary trỏ tới
#     labs-self-boundary. Lấy ARN:
#         terraform -chdir=../../_boundary output -raw lab_boundary_arn
#     hoặc ghép tay: arn:aws:iam::<account-id>:policy/labs-self-boundary
#   - $0,00. IAM, STS, Policy Simulator và Parameter Store Standard đều miễn phí.
#     Nếu bạn sắp tạo KMS customer managed key ($1/tháng) hay Secrets Manager
#     ($0,40/secret/tháng) thì bạn đang đi sai hướng — xem bảng trong README.
#
# Thứ tự làm gợi ý, apply sau mỗi bước:
#   1. kho dữ liệu + hai object   -> thấy được cả hai bằng danh tính admin
#   2. vai vận hành + trust policy -> mượn được, và mượn sai thì bị từ chối
#   3. quyền của vai vận hành      -> làm được đúng việc mình, không hơn
#   4. bí mật ở Parameter Store    -> đọc được cái của mình, không đọc cái đội khác
#   5. chặn bi-mat/ ở phía kho     -> admin cũng không đọc được nữa
#   6. vai phá kính                -> đúng một cửa mở
#   7. trần quyền tự viết          -> chỉ là một policy, không attach vào đâu
#
# Bước 5 sẽ khoá chính bạn ra khỏi bi-mat/. Đó là điểm của bài. Nhưng nhớ:
# chỉ chặn s3:GetObject. Chặn rộng hơn là bạn tự khoá mình ra khỏi
# terraform destroy — bài học thật, hậu quả thật.
#
# Kẹt quá thì mở ../HINTS.md, từng tầng một.
# ===========================================================================
