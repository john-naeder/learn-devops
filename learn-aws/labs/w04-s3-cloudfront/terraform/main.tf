# ===========================================================================
# TUẦN 4 — S3 + CloudFront + Origin Access Control
#
#   Người dùng → CloudFront → (OAC, ký SigV4) → S3 bucket ĐÓNG HOÀN TOÀN
#
# Điểm mấu chốt: bucket KHÔNG public, KHÔNG bật static website hosting.
# Chỉ CloudFront gọi vào được, và nó chứng minh danh tính bằng chữ ký SigV4.
# Gọi thẳng URL S3 → 403.
#
# OAC (Origin Access Control) là bản thay thế của OAI (Origin Access Identity).
# Tài liệu nào còn dạy OAI là tài liệu cũ — OAC hỗ trợ SSE-KMS và mọi region,
# OAI thì không. Đề thi mới dùng OAC.
# ===========================================================================

locals {
  bucket_name = "${var.prefix}-site-${data.aws_caller_identity.current.account_id}"
  site_dir    = "${path.module}/../site"

  # Content type phải đúng, nếu không trình duyệt tải file về thay vì hiển thị.
  mime = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".svg"  = "image/svg+xml"
    ".txt"  = "text/plain"
  }
}

# ================================================================ Bucket chính

resource "aws_s3_bucket" "site" {
  bucket        = local.bucket_name
  force_destroy = true # lab thôi; production thì tuyệt đối không
}

# CHẶN PUBLIC HOÀN TOÀN. Đây không mâu thuẫn với việc website chạy được —
# CloudFront không truy cập với tư cách "public", nó ký request bằng SigV4.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning: mỗi lần ghi đè tạo một version mới thay vì mất bản cũ.
#
# BẪY DỌN DẸP KINH ĐIỂN: bật versioning rồi thì "xoá file" chỉ tạo ra một
# delete marker, bucket vẫn còn dữ liệu và vẫn tính tiền. Muốn bucket thật sự
# trống phải xoá TẤT CẢ version. force_destroy = true ở trên lo việc đó,
# nhưng nếu bạn xoá bằng console thì phải tự làm.
resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Mã hoá lúc lưu. SSE-S3 (AES256) miễn phí và bật mặc định từ 2023.
# SSE-KMS với customer managed key thì mất $1/tháng cho key — không cần cho lab.
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    # Giảm số lần gọi KMS khi dùng SSE-KMS. Với AES256 thì không ảnh hưởng,
    # nhưng để đây làm mẫu vì đề thi có hỏi về chi phí KMS request.
    bucket_key_enabled = true
  }
}

# --------------------------------------------------------------- Lifecycle
#
# Bài toán chọn storage class là nội dung thi trọng tâm của tuần này.
#
#   Standard          truy cập thường xuyên           $0,023/GB
#   Standard-IA       ít truy cập, cần ngay           $0,0125/GB  (tối thiểu 30 ngày)
#   One Zone-IA       như trên, chấp nhận mất 1 AZ    $0,01/GB
#   Glacier Instant   archive nhưng cần ngay lập tức  $0,004/GB   (tối thiểu 90 ngày)
#   Glacier Flexible  archive, chờ vài phút đến giờ   $0,0036/GB  (tối thiểu 90 ngày)
#   Glacier Deep      archive sâu, chờ 12 giờ         $0,00099/GB (tối thiểu 180 ngày)
#
# NGƯỠNG TỐI THIỂU là chỗ hay bị bẫy: chuyển object sang Glacier rồi xoá sau
# 10 ngày thì bạn vẫn bị tính đủ 90 ngày.

resource "aws_s3_bucket_lifecycle_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  # Phải chờ versioning bật xong, nếu không rule về noncurrent version vô nghĩa.
  depends_on = [aws_s3_bucket_versioning.site]

  rule {
    id     = "chuyen-sang-glacier"
    status = "Enabled"

    filter {} # áp dụng cho toàn bộ bucket

    transition {
      days          = var.glacier_after_days
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id     = "don-version-cu"
    status = "Enabled"

    filter {}

    # Version cũ không ai đọc nhưng vẫn tính tiền đầy đủ. Không có rule này
    # thì bật versioning là công thức để hoá đơn phình dần mãi mãi.
    noncurrent_version_expiration {
      noncurrent_days = var.expire_noncurrent_after_days
    }
  }

  rule {
    id     = "don-upload-do-dang"
    status = "Enabled"

    filter {}

    # Multipart upload thất bại để lại các phần đã tải lên — chúng KHÔNG hiện
    # trong danh sách object nhưng VẪN TÍNH TIỀN. Đây là nguồn chi phí ẩn
    # mà rất nhiều người không bao giờ phát hiện ra.
    abort_incomplete_multipart_upload {
      days_after_initiation = 3
    }
  }
}

# ------------------------------------------------------------ Nội dung site

resource "aws_s3_object" "site_files" {
  for_each = fileset(local.site_dir, "**/*")

  bucket = aws_s3_bucket.site.id
  key    = each.value
  source = "${local.site_dir}/${each.value}"

  # etag để Terraform phát hiện file đã đổi và upload lại.
  etag = filemd5("${local.site_dir}/${each.value}")

  content_type = lookup(local.mime, regex("\\.[^.]+$", each.value), "application/octet-stream")
}

# ==================================================== CloudFront + OAC

# OAC thay thế OAI. Nó khiến CloudFront ký mọi request tới origin bằng SigV4,
# nên bucket policy có thể tin tưởng chính xác distribution nào đang gọi.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.prefix}-oac"
  description                       = "OAC cho bucket site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "${var.prefix} - lab tuan 4"

  # PriceClass_100 = chỉ dùng edge location ở Bắc Mỹ và châu Âu — rẻ nhất.
  # PriceClass_All phủ toàn cầu (gồm cả Việt Nam) nhưng đắt hơn.
  # Với 1 TB free thì khác biệt không đáng kể, nhưng đây là một lựa chọn
  # tối ưu chi phí có thật và có trong đề thi.
  price_class = "PriceClass_100"

  origin {
    # QUAN TRỌNG: dùng bucket_regional_domain_name (REST endpoint), KHÔNG dùng
    # website_endpoint. Website endpoint bắt buộc bucket phải public — đúng
    # thứ ta đang cố tránh. Đây là lỗi cấu hình phổ biến nhất của mẫu này.
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-site"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "redirect-to-https" # ép HTTPS
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    # Managed-CachingOptimized: policy dựng sẵn của AWS, nén gzip/brotli,
    # bỏ qua cookie và query string khi tạo cache key.
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # CloudFront Function chèn security header. Rẻ hơn Lambda@Edge khoảng 6 lần
    # và chạy ở mọi edge location, nhưng chỉ xử lý được viewer request/response
    # và giới hạn 1ms. Phân biệt hai cái này là câu hỏi thi.
    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.headers.arn
    }
  }

  # Cache behavior riêng cho /api/* — bài tập tuần 8 sẽ dùng lại chỗ này.
  # Đường dẫn API thì KHÔNG được cache, nếu không người dùng nhận dữ liệu cũ.
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "s3-site"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    # Managed-CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Chứng chỉ mặc định *.cloudfront.net. Dùng domain riêng thì cần ACM
    # cert và cert đó BẮT BUỘC nằm ở us-east-1 dù distribution là toàn cầu —
    # một chi tiết rất hay ra thi.
    cloudfront_default_certificate = true
  }

  # SPA: mọi đường dẫn không tồn tại trả về index.html thay vì trang lỗi S3.
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  tags = { Name = "${var.prefix}-cdn" }
}

resource "aws_cloudfront_function" "headers" {
  name    = "${var.prefix}-security-headers"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Chen security header vao moi response"

  code = <<-JS
    function handler(event) {
      var r = event.response;
      var h = r.headers;

      // Ép trình duyệt chỉ dùng HTTPS trong 2 năm tới.
      h['strict-transport-security'] = { value: 'max-age=63072000; includeSubDomains' };
      // Chặn trình duyệt tự đoán content type (chống MIME sniffing).
      h['x-content-type-options']    = { value: 'nosniff' };
      // Không cho trang bị nhúng trong iframe của site khác (chống clickjacking).
      h['x-frame-options']           = { value: 'DENY' };
      h['referrer-policy']           = { value: 'strict-origin-when-cross-origin' };

      return r;
    }
  JS
}

# ------------------------------------------------------------ Bucket policy
#
# ĐÂY là mảnh ghép làm cho OAC hoạt động.
#
# Điều kiện AWS:SourceArn quan trọng hơn nó trông có vẻ: không có nó thì BẤT KỲ
# distribution CloudFront nào của BẤT KỲ AI cũng đọc được bucket của bạn.
# Đó gọi là lỗ hổng "confused deputy" và AWS đặc biệt nhấn mạnh trong tài liệu.

data "aws_iam_policy_document" "site" {
  statement {
    sid    = "ChiCloudFrontDuocDoc"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }

  # Mọi request không dùng TLS đều bị từ chối, kể cả từ CloudFront.
  statement {
    sid    = "TuChoiKhongTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.site.arn,
      "${aws_s3_bucket.site.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Bài tập: bật enable_ip_restriction=true để chỉ IP của bạn đọc được bucket.
  #
  # CHÚ Ý: điều này sẽ LÀM HỎNG CloudFront, vì CloudFront gọi từ IP edge chứ
  # không phải IP của bạn. Đó chính là điểm của bài tập — hai yêu cầu bảo mật
  # có thể mâu thuẫn nhau, và bạn phải hiểu thứ tự đánh giá policy để gỡ.
  dynamic "statement" {
    for_each = var.enable_ip_restriction ? [1] : []

    content {
      sid    = "ChiMotIP"
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.site.arn}/*"]

      condition {
        test     = "NotIpAddress"
        variable = "aws:SourceIp"
        values   = [var.allowed_ip]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site.json

  depends_on = [aws_s3_bucket_public_access_block.site]
}

# ============================================ Cross-Region Replication (tuỳ chọn)
#
# Bật để làm bài "Backup & Restore thu nhỏ" của tuần 11, xong TẮT NGAY.
#
# Ba điều kiện bắt buộc của CRR, đều hay ra thi:
#   1. CẢ HAI bucket phải bật versioning.
#   2. Phải có IAM role cho S3 assume để đọc nguồn và ghi đích.
#   3. Chỉ object tạo SAU khi bật rule mới được nhân bản. Object cũ thì phải
#      dùng S3 Batch Replication riêng.

resource "aws_s3_bucket" "replica" {
  count    = var.enable_crr ? 1 : 0
  provider = aws.replica

  bucket        = "${local.bucket_name}-replica"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "replica" {
  count    = var.enable_crr ? 1 : 0
  provider = aws.replica

  bucket = aws_s3_bucket.replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "replication_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count = var.enable_crr ? 1 : 0

  name               = "${var.prefix}-s3-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_trust.json
}

resource "aws_iam_role_policy" "replication" {
  count = var.enable_crr ? 1 : 0

  name = "replicate"
  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = [aws_s3_bucket.site.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
        ]
        Resource = ["${aws_s3_bucket.site.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Resource = ["${aws_s3_bucket.replica[0].arn}/*"]
      },
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "site" {
  count = var.enable_crr ? 1 : 0

  bucket = aws_s3_bucket.site.id
  role   = aws_iam_role.replication[0].arn

  # Versioning phải sẵn sàng trước khi cấu hình replication.
  depends_on = [
    aws_s3_bucket_versioning.site,
    aws_s3_bucket_versioning.replica,
  ]

  rule {
    id     = "nhan-ban-toan-bo"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD_IA" # bản sao ít khi đọc → lớp rẻ hơn
    }
  }
}
