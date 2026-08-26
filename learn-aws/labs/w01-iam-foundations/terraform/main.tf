# ===========================================================================
# TUẦN 1 — IAM: user, role, identity policy, resource policy, trust policy
#
# Toàn bộ lab này MIỄN PHÍ. IAM không tính tiền, S3 lưu vài KB cũng không.
#
# Mục tiêu không phải là "tạo được IAM user" — console làm việc đó trong 10 giây.
# Mục tiêu là thấy tận mắt bốn loại policy khác nhau và biết cái nào chặn cái nào:
#
#   1. Identity policy  — gắn vào user/role: "danh tính này được làm gì"
#   2. Resource policy  — gắn vào bucket:    "ai được đụng vào tôi"
#   3. Trust policy     — gắn vào role:      "ai được phép hóa thân thành tôi"
#   4. Permission boundary — trần quyền tối đa (học sâu ở tuần 9)
# ===========================================================================

locals {
  # Tên bucket S3 phải duy nhất TOÀN CẦU, không chỉ trong account bạn.
  # Ghép account ID vào là cách đơn giản nhất để chắc chắn không đụng ai.
  bucket_name = "${var.prefix}-iam-lab-${data.aws_caller_identity.current.account_id}"
}

# --------------------------------------------------------------- 1. Bucket

resource "aws_s3_bucket" "lab" {
  bucket = local.bucket_name

  # force_destroy = true để `terraform destroy` xóa được cả khi bucket còn file.
  # Trong môi trường thật thì TUYỆT ĐỐI không đặt thế này.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "lab" {
  bucket = aws_s3_bucket.lab.id

  # Bốn công tắc này là hàng rào cuối cùng: kể cả khi bucket policy hay ACL
  # lỡ mở public, chúng vẫn chặn. Bật hết là mặc định đúng.
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "sample" {
  bucket  = aws_s3_bucket.lab.id
  key     = "readme.txt"
  content = "File mẫu cho lab tuần 1. Nếu bạn đọc được nội dung này bằng user w01-reader thì identity policy đã hoạt động.\n"
}

resource "aws_s3_object" "secret" {
  bucket  = aws_s3_bucket.lab.id
  key     = "private/luong.txt"
  content = "Dữ liệu nhạy cảm giả lập. user w01-reader ĐƯỢC đọc file này — hãy nghĩ xem vì sao, rồi sửa policy để chặn.\n"
}

# ------------------------------------------------- 2. Identity policy (user)
#
# Đây là policy bạn được yêu cầu "viết tay" trong plan tuần 1.
# aws_iam_policy_document là cách Terraform sinh ra JSON — nó validate cú pháp
# lúc plan, thay vì để bạn phát hiện lỗi sau khi đã apply.
#
# Đọc kỹ hai Resource ARN dưới đây, chúng KHÁC NHAU và đây là lỗi kinh điển:
#   arn:aws:s3:::bucket      → bản thân cái bucket (dùng cho ListBucket)
#   arn:aws:s3:::bucket/*    → các object BÊN TRONG (dùng cho GetObject)
# Viết s3:GetObject trên ARN không có /* thì policy sẽ không bao giờ khớp.

data "aws_iam_policy_document" "reader" {
  statement {
    sid    = "DocObjectsReadOnly"
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.lab.arn}/*",
    ]
  }

  statement {
    sid    = "ListBucketItself"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.lab.arn,
    ]
  }
}

resource "aws_iam_policy" "reader" {
  name        = "${var.prefix}-s3-reader"
  description = "Chỉ đọc object trong đúng một bucket. Không ghi, không xóa."
  policy      = data.aws_iam_policy_document.reader.json
}

resource "aws_iam_user" "reader" {
  name = "${var.prefix}-reader"

  # force_destroy xóa luôn access key / login profile khi destroy user.
  force_destroy = true
}

resource "aws_iam_user_policy_attachment" "reader" {
  user       = aws_iam_user.reader.name
  policy_arn = aws_iam_policy.reader.arn
}

# ------------------------------------------------------ 3. Role cho EC2
#
# Câu hỏi thi: "ứng dụng trên EC2 cần đọc S3, cách nào an toàn nhất?"
# Đáp án luôn là ROLE, không bao giờ là access key nhúng trong code.
#
# Vì sao role tốt hơn access key:
#   - Credential được cấp tạm thời và tự xoay vòng, không có gì để lộ.
#   - Không có bí mật nào nằm trong AMI, trong git, trong biến môi trường.
#   - Thu hồi quyền = sửa role, hiệu lực ngay, không phải đi tìm key.

data "aws_iam_policy_document" "ec2_trust" {
  # ĐÂY là trust policy. Nó KHÔNG nói role được làm gì — nó nói AI ĐƯỢC PHÉP
  # hóa thân thành role này. Hai thứ hoàn toàn khác nhau, và đây là chỗ người
  # mới hay nhầm nhất.
  statement {
    sid     = "EC2CanAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_reader" {
  name               = "${var.prefix}-ec2-reader"
  description        = "Role cho EC2 đọc bucket lab. So sánh với user w01-reader để thấy khác biệt."
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ec2_reader" {
  role       = aws_iam_role.ec2_reader.name
  policy_arn = aws_iam_policy.reader.arn
}

# Instance profile là cái "vỏ bọc" duy nhất cho phép gắn role vào EC2.
# Bạn không gắn role thẳng vào instance được — luôn phải qua instance profile.
# Console tự tạo nó giúp bạn nên nhiều người không biết nó tồn tại; ở đây
# bạn phải khai báo tay, và đó chính là điểm học.
resource "aws_iam_instance_profile" "ec2_reader" {
  name = "${var.prefix}-ec2-reader"
  role = aws_iam_role.ec2_reader.name
}

# --------------------------------------- 4. Resource policy (bucket policy)
#
# Cùng một bucket có thể vừa bị chặn bởi identity policy, vừa bị chặn bởi
# resource policy. Quyền cuối cùng là GIAO của các Allow, và bất kỳ Deny nào
# cũng thắng tuyệt đối.
#
# Statement dưới đây từ chối mọi request không dùng TLS. Đây là mẫu bucket policy
# phổ biến nhất trong thực tế và hay xuất hiện trong đề thi.

data "aws_iam_policy_document" "bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.lab.arn,
      "${aws_s3_bucket.lab.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "lab" {
  bucket = aws_s3_bucket.lab.id
  policy = data.aws_iam_policy_document.bucket.json

  # Public access block phải tồn tại trước khi gắn policy, nếu không S3 có thể
  # từ chối policy vì nghi ngờ mở public.
  depends_on = [aws_s3_bucket_public_access_block.lab]
}

# ------------------------------------------------------- 5. Access Analyzer
#
# MIỄN PHÍ. Nó quét mọi policy trong account và báo cho bạn biết resource nào
# đang cho phép truy cập từ NGOÀI account — thứ mà mắt người đọc policy JSON
# rất dễ bỏ sót.

resource "aws_accessanalyzer_analyzer" "this" {
  count = var.enable_access_analyzer ? 1 : 0

  analyzer_name = "${var.prefix}-analyzer"
  type          = "ACCOUNT"
}
