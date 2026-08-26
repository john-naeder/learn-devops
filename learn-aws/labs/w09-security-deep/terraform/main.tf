# ===========================================================================
# TUẦN 9 — Bảo mật chuyên sâu (Domain 1 = 30% đề thi, miền nặng nhất)
#
# Lab này dựng bốn cơ chế mà đề thi hỏi liên tục, và bạn CHỨNG MINH ĐƯỢC
# từng cái bằng Policy Simulator hoặc bằng cách gọi thật:
#
#   1. AssumeRole + external ID          — cross-account đúng cách
#   2. Permission boundary               — trần quyền, chặn được cả admin
#   3. SSM Parameter Store SecureString  — thay Secrets Manager, MIỄN PHÍ
#   4. Explicit Deny thắng tất cả        — chứng minh bằng thực nghiệm
#
# Toàn bộ MIỄN PHÍ. GuardDuty và KMS mặc định tắt vì tốn tiền.
# ===========================================================================

data "aws_partition" "current" {}

locals {
  account = data.aws_caller_identity.current.account_id
}

# ============================================ 1. AssumeRole + external ID
#
# Kịch bản thật: bạn thuê một công ty giám sát bên ngoài. Họ cần đọc log
# trong account của bạn. Cách ĐÚNG là cho họ assume một role, không phải
# tạo IAM user và đưa access key.
#
# EXTERNAL ID giải bài toán "confused deputy":
#
#   Không có external ID: công ty giám sát đó cũng phục vụ khách hàng khác.
#   Nếu một khách hàng khác đoán được ARN role của bạn, họ có thể lừa công ty
#   giám sát assume vào role của BẠN thay vì role của họ.
#
#   Có external ID: một bí mật do BẠN đặt ra, chỉ bạn và họ biết. Không có nó
#   thì assume thất bại, kể cả khi biết ARN.
#
# Đề thi mô tả tình huống này gần như nguyên văn khi hỏi về cross-account.

resource "aws_iam_role" "ben_thu_ba" {
  name        = "${var.prefix}-ben-thu-ba"
  description = "Role cho ben thu ba assume vao, co external ID"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        # Trong đời thật đây là account ID của công ty kia.
        # Lab mô phỏng bằng chính account của bạn.
        AWS = "arn:${data.aws_partition.current.partition}:iam::${local.account}:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.external_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ben_thu_ba" {
  name = "chi-doc-log"
  role = aws_iam_role.ben_thu_ba.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:DescribeLogGroups", "logs:FilterLogEvents"]
      Resource = "*"
    }]
  })
}

# ==================================================== 2. Permission boundary
#
# Permission boundary KHÔNG cấp quyền. Nó đặt TRẦN cho quyền tối đa.
#
# Quyền thực tế = GIAO của (identity policy) và (permission boundary).
#
# Ví dụ trong lab này: role dưới đây được gắn AdministratorAccess — quyền
# cao nhất tồn tại. Nhưng boundary chỉ cho phép S3 và CloudWatch Logs.
# Kết quả: role đó KHÔNG tạo được IAM user, KHÔNG khởi động được EC2.
#
# Dùng ở đâu trong thực tế: cho phép developer tự tạo role cho ứng dụng của họ,
# mà không sợ họ tự cấp cho mình quyền admin. Đây là câu hỏi thi hay gặp về
# "làm sao uỷ quyền tạo IAM mà vẫn an toàn".

resource "aws_iam_policy" "boundary" {
  name        = "${var.prefix}-boundary"
  description = "Tran quyen: chi S3 va CloudWatch Logs, khong gi khac"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "TranQuyenToiDa"
      Effect   = "Allow"
      Action   = ["s3:*", "logs:*"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role" "bi_gioi_han" {
  name        = "${var.prefix}-admin-bi-gioi-han"
  description = "Co AdministratorAccess nhung bi boundary chan lai"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${local.account}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  # ĐÂY là dòng làm nên tất cả.
  permissions_boundary = aws_iam_policy.boundary.arn
}

# Cấp quyền CAO NHẤT có thể. Boundary vẫn chặn.
resource "aws_iam_role_policy_attachment" "bi_gioi_han_admin" {
  role       = aws_iam_role.bi_gioi_han.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

# ============================================ 3. Explicit Deny thắng tất cả
#
# Role này có AdministratorAccess VÀ một policy Deny hẹp.
# Deny luôn thắng, bất kể Allow rộng đến đâu.
#
# Ứng dụng thực tế: chặn một vài hành động nguy hiểm (xoá CloudTrail, tắt
# GuardDuty, xoá backup) cho MỌI người kể cả admin. Trong Organizations thì
# việc này làm bằng SCP.

resource "aws_iam_role" "admin_co_deny" {
  name        = "${var.prefix}-admin-co-deny"
  description = "AdministratorAccess nhung bi Deny mot so hanh dong nguy hiem"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${local.account}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "admin_co_deny" {
  role       = aws_iam_role.admin_co_deny.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy" "cam_pha_hoai" {
  name = "cam-pha-hoai"
  role = aws_iam_role.admin_co_deny.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "KhongAiDuocXoaDauVet"
      Effect = "Deny"
      Action = [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "guardduty:DeleteDetector",
        "config:DeleteConfigurationRecorder",
      ]
      Resource = "*"
    }]
  })
}

# ================================== 4. SSM Parameter Store thay Secrets Manager
#
# So sánh cho kỳ thi:
#
#   SSM Parameter Store (Standard)   MIỄN PHÍ · tối đa 4 KB · KHÔNG tự xoay vòng
#                                    · mã hoá bằng KMS nếu chọn SecureString
#   Secrets Manager                  $0,40/secret/tháng · tối đa 64 KB
#                                    · TỰ ĐỘNG XOAY VÒNG (tích hợp sẵn RDS,
#                                      Redshift, DocumentDB) · có cross-account
#
# KHÁC BIỆT QUYẾT ĐỊNH: tự động xoay vòng. Đề hỏi "lưu credential database và
# tự đổi mật khẩu định kỳ mà không sửa code" → Secrets Manager. Hỏi "lưu cấu
# hình / secret đơn giản với chi phí thấp nhất" → Parameter Store.
#
# Trong 12 tuần này ta luôn dùng Parameter Store để tiết kiệm $0,40/tháng.

resource "aws_ssm_parameter" "secret" {
  name        = "/${var.prefix}/app/mat-khau-db"
  description = "Secret mau, ma hoa bang AWS managed key (mien phi)"
  type        = "SecureString"
  value       = var.gia_tri_secret

  # KHÔNG chỉ định key_id → dùng AWS managed key `alias/aws/ssm`, MIỄN PHÍ.
  # Chỉ định customer managed key thì tốn $1/tháng cho key đó.
  # Với mục đích học, AWS managed key là đủ và đó cũng là lựa chọn đúng
  # khi bạn không cần kiểm soát vòng đời key.

  tags = { Name = "${var.prefix}-secret" }
}

resource "aws_ssm_parameter" "cau_hinh" {
  name  = "/${var.prefix}/app/muc-log"
  type  = "String" # cấu hình không nhạy cảm thì không cần mã hoá
  value = "INFO"
}

# ---- Lambda đọc secret ----

data "archive_file" "doc_secret" {
  type        = "zip"
  output_path = "${path.module}/.build/doc-secret.zip"

  source {
    filename = "handler.py"
    content  = <<-PY
      """Đọc secret từ SSM Parameter Store — cách làm ĐÚNG trong production.

      Vì sao không nhúng secret vào biến môi trường của Lambda:
        - Biến môi trường hiện NGUYÊN VĂN trong console và trong API
          GetFunctionConfiguration. Ai đọc được cấu hình hàm là đọc được secret.
        - Đổi secret phải deploy lại hàm.
        - Secret nằm trong file Terraform state.

      Đọc lúc chạy thì secret không bao giờ rời khỏi chỗ được mã hoá cho tới
      đúng lúc cần dùng, và quyền đọc kiểm soát được bằng IAM.
      """
      import json
      import os

      import boto3

      # Client tạo ở phạm vi module — chỉ một lần mỗi cold start.
      SSM = boto3.client("ssm")
      TIEN_TO = os.environ["TIEN_TO"]

      # Cache đơn giản trong bộ nhớ: execution context sống lại giữa các lần gọi,
      # nên lần thứ hai trở đi không phải gọi SSM nữa. Vừa nhanh hơn vừa tránh
      # chạm giới hạn tốc độ của Parameter Store.
      _cache = {}


      def lay_tham_so(ten: str, giai_ma: bool = True) -> str:
          if ten in _cache:
              return _cache[ten]
          r = SSM.get_parameter(Name=ten, WithDecryption=giai_ma)
          _cache[ten] = r["Parameter"]["Value"]
          return _cache[ten]


      def handler(event, context):
          secret = lay_tham_so(f"/{TIEN_TO}/app/mat-khau-db")
          muc_log = lay_tham_so(f"/{TIEN_TO}/app/muc-log", giai_ma=False)

          # KHÔNG BAO GIỜ in secret ra log. CloudWatch Logs giữ nó lại và ai
          # đọc được log là đọc được secret. Chỉ in đủ để xác nhận đã đọc được.
          return {
              "doc_duoc_secret": True,
              "do_dai_secret": len(secret),
              "bon_ky_tu_dau": secret[:4] + "...",
              "muc_log": muc_log,
              "tu_cache": len(_cache) > 0,
          }
    PY
  }
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "doc_secret" {
  name               = "${var.prefix}-doc-secret"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "doc_secret_logs" {
  role       = aws_iam_role.doc_secret.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Quyền tối thiểu: chỉ đọc tham số dưới đúng tiền tố này, và chỉ giải mã
# bằng AWS managed key của SSM.
resource "aws_iam_role_policy" "doc_secret" {
  name = "doc-tham-so"
  role = aws_iam_role.doc_secret.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${local.account}:parameter/${var.prefix}/*"
      },
      {
        # SecureString cần thêm quyền Decrypt trên KMS key.
        # Thiếu statement này thì GetParameter với WithDecryption=True
        # sẽ báo AccessDenied — và thông báo lỗi KHÔNG nói rõ là do KMS.
        # Đây là lỗi rất hay gặp và rất mất thời gian để tìm ra.
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.region}.amazonaws.com"
          }
        }
      },
    ]
  })
}

resource "aws_lambda_function" "doc_secret" {
  function_name = "${var.prefix}-doc-secret"
  role          = aws_iam_role.doc_secret.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  memory_size   = 128
  timeout       = 10

  filename         = data.archive_file.doc_secret.output_path
  source_code_hash = data.archive_file.doc_secret.output_base64sha256

  environment {
    variables = {
      # Chỉ để TIỀN TỐ ở đây, không để secret. Biến môi trường hiện nguyên văn
      # trong console.
      TIEN_TO = var.prefix
    }
  }
}

resource "aws_cloudwatch_log_group" "doc_secret" {
  name              = "/aws/lambda/${aws_lambda_function.doc_secret.function_name}"
  retention_in_days = 7
}

# ===================================================== GuardDuty (TỐN TIỀN)
#
# 30 ngày dùng thử miễn phí, sau đó tính theo lượng sự kiện phân tích —
# thường vài đô mỗi tháng cho account nhỏ.
#
# Plan gốc: "Bật GuardDuty, xem finding mẫu trong một ngày, rồi TẮT ĐI."
#
#   terraform apply -var enable_guardduty=true
#   aws guardduty create-sample-findings --detector-id <id>   (tạo finding giả)
#   terraform apply -var enable_guardduty=false

resource "aws_guardduty_detector" "this" {
  count = var.enable_guardduty ? 1 : 0

  enable = true

  # 6 giờ là khoảng xuất finding rẻ nhất. 15 phút thì nhanh hơn nhưng
  # với lab thì không cần.
  finding_publishing_frequency = "SIX_HOURS"

  tags = { Name = "${var.prefix}-guardduty" }
}

# =================================================== Bucket để thử Deny
#
# Dùng cho bài chứng minh "explicit Deny thắng Allow rộng".

resource "aws_s3_bucket" "thu_nghiem" {
  bucket        = "${var.prefix}-thu-nghiem-${local.account}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "thu_nghiem" {
  bucket                  = aws_s3_bucket.thu_nghiem.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
