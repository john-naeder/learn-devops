# ===========================================================================
# TUẦN 8 — DNS, CDN và tầng biên
#
# Phần MIỄN PHÍ (mặc định bật):
#   - CloudFront với nhiều cache behavior, quan sát x-cache Hit/Miss
#   - CloudFront Function: security header, chuẩn hoá cache key, A/B testing
#   - Cache policy tự viết để thấy cache key được tạo từ những gì
#
# Phần TỐN TIỀN (mặc định tắt):
#   - Route 53 hosted zone      $0,50/tháng
#   - Health check              $0,50/tháng mỗi cái
#   → Bật để thử weighted/failover routing, xong XOÁ trong hai ngày.
#
# Routing policy là kiến thức NHỚ, không cần tay chạm. Nếu muốn tiết kiệm
# tuyệt đối thì để enable_route53 = false và học bằng bảng trong README.
# ===========================================================================

locals {
  bucket_name = "${var.prefix}-edge-${data.aws_caller_identity.current.account_id}"
}

# ------------------------------------------------------------- Origin S3

resource "aws_s3_bucket" "origin" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "origin" {
  bucket                  = aws_s3_bucket.origin.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Ba file để quan sát ba hành vi cache khác nhau.
resource "aws_s3_object" "trang_chu" {
  bucket       = aws_s3_bucket.origin.id
  key          = "index.html"
  content_type = "text/html; charset=utf-8"
  content      = <<-HTML
    <!doctype html><meta charset="utf-8">
    <title>Lab tuần 8 — tầng biên</title>
    <body style="font-family:system-ui;max-width:44rem;margin:3rem auto;padding:0 1rem;line-height:1.7">
    <h1>Tầng biên CloudFront</h1>
    <p>Ba đường dẫn dưới đây có ba cấu hình cache khác nhau. Mở DevTools → Network
    và so sánh header <code>x-cache</code> của từng cái.</p>
    <ul>
      <li><a href="/index.html">/index.html</a> — cache mặc định, TTL dài</li>
      <li><a href="/api/gio.json">/api/gio.json</a> — KHÔNG cache</li>
      <li><a href="/static/data.json">/static/data.json</a> — cache rất dài</li>
    </ul>
    <p>Thử thêm query string: <a href="/index.html?utm_source=facebook">?utm_source=facebook</a>
    — cache policy đã được cấu hình để BỎ QUA tham số utm_*, nên nó vẫn là cache Hit.</p>
    </body>
  HTML
}

resource "aws_s3_object" "api_gio" {
  bucket       = aws_s3_bucket.origin.id
  key          = "api/gio.json"
  content_type = "application/json"
  content = jsonencode({
    ghi_chu = "Duong dan /api/* KHONG duoc cache. Moi request deu di toi origin."
  })
}

resource "aws_s3_object" "static_data" {
  bucket       = aws_s3_bucket.origin.id
  key          = "static/data.json"
  content_type = "application/json"
  content = jsonencode({
    ghi_chu = "Duong dan /static/* cache 1 nam. Doi noi dung thi doi TEN FILE."
  })
}

# ----------------------------------------------------------------- OAC

resource "aws_cloudfront_origin_access_control" "origin" {
  name                              = "${var.prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ------------------------------------------------------- Cache policy tự viết
#
# ĐÂY LÀ PHẦN ĐÁNG HỌC NHẤT CỦA TUẦN.
#
# CACHE KEY là "vân tay" của một request. Hai request có cùng cache key thì
# CloudFront coi là cùng một thứ và trả cùng một bản cache.
#
# Cache key được tạo từ: đường dẫn + những header/cookie/query string mà BẠN
# chọn đưa vào. Càng đưa nhiều thứ vào, cache key càng đa dạng, tỉ lệ Hit
# càng THẤP — và bạn càng phải đi tới origin nhiều lần.
#
# Sai lầm kinh điển: đưa TẤT CẢ query string vào cache key. Khi đó
# /trang?utm_source=facebook và /trang?utm_source=google thành hai bản cache
# riêng, dù nội dung y hệt. Tỉ lệ Hit sụp đổ.
resource "aws_cloudfront_cache_policy" "bo_qua_utm" {
  name        = "${var.prefix}-bo-qua-utm"
  comment     = "Cache key bo qua tham so theo doi marketing"
  default_ttl = 86400
  min_ttl     = 0
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    query_strings_config {
      # Chỉ đưa những tham số THỰC SỰ đổi nội dung vào cache key.
      # utm_source, utm_campaign, fbclid... chỉ để theo dõi marketing,
      # không đổi nội dung → phải loại khỏi cache key.
      query_string_behavior = "whitelist"
      query_strings {
        items = ["trang", "ngon_ngu"]
      }
    }

    headers_config {
      # Đưa header vào cache key chỉ khi nội dung thực sự thay đổi theo nó.
      # Ví dụ Accept-Language nếu bạn phục vụ nhiều ngôn ngữ.
      header_behavior = "none"
    }

    cookies_config {
      # Cookie thường mang session ID — mỗi người một giá trị khác nhau.
      # Đưa cookie vào cache key nghĩa là mỗi người dùng một bản cache riêng,
      # tức là gần như KHÔNG CACHE GÌ CẢ.
      cookie_behavior = "none"
    }
  }
}

# ------------------------------------------------------ CloudFront Functions

# 1) Chèn security header vào response.
resource "aws_cloudfront_function" "security_headers" {
  name    = "${var.prefix}-security-headers"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Chen security header"

  code = <<-JS
    function handler(event) {
      var h = event.response.headers;
      h['strict-transport-security'] = { value: 'max-age=63072000; includeSubDomains' };
      h['x-content-type-options']    = { value: 'nosniff' };
      h['x-frame-options']           = { value: 'DENY' };
      h['referrer-policy']           = { value: 'strict-origin-when-cross-origin' };
      return event.response;
    }
  JS
}

# 2) Chuẩn hoá request TRƯỚC khi tính cache key.
#
# Chạy ở viewer-request: mọi request đều qua đây, kể cả request sẽ là cache Hit.
# Giới hạn: tối đa 1 ms CPU, không truy cập mạng, không đọc body.
resource "aws_cloudfront_function" "chuan_hoa" {
  name    = "${var.prefix}-chuan-hoa-request"
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Chuan hoa duong dan va gan nhom A/B"

  code = <<-JS
    function handler(event) {
      var req = event.request;

      // Thêm index.html cho đường dẫn kết thúc bằng "/".
      // Không làm việc này thì S3 trả 403 cho thư mục con — lỗi rất hay gặp
      // với SPA và với site nhiều thư mục.
      if (req.uri.endsWith('/')) {
        req.uri += 'index.html';
      }

      // Gán nhóm A/B ổn định dựa trên cookie đã có, hoặc bốc ngẫu nhiên.
      // Đưa nhóm vào header để cache policy có thể tách bản cache theo nhóm.
      var cookies = req.cookies || {};
      var nhom = cookies.nhom_ab ? cookies.nhom_ab.value : (Math.random() < 0.5 ? 'A' : 'B');
      req.headers['x-nhom-ab'] = { value: nhom };

      return req;
    }
  JS
}

# ----------------------------------------------------------- Distribution

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "${var.prefix} - lab tuan 8"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.origin.bucket_regional_domain_name
    origin_id                = "s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.origin.id
  }

  # ---- Mặc định: cache theo policy tự viết ----
  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.bo_qua_utm.id
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.chuan_hoa.arn
    }

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }
  }

  # ---- /api/* : KHÔNG cache ----
  #
  # ordered_cache_behavior được xét theo THỨ TỰ KHAI BÁO, và cái khớp đầu tiên
  # thắng. Đặt pattern rộng ("*") lên trước pattern hẹp là lỗi cấu hình kinh điển:
  # pattern hẹp sẽ không bao giờ được dùng tới.
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    # Managed-CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  }

  # ---- /static/* : cache rất lâu ----
  #
  # TTL 1 năm chỉ an toàn khi tên file có hash (app.a3f9c2.js). Đổi nội dung
  # thì đổi tên file → URL mới → không cần invalidate. MIỄN PHÍ.
  # Đây là cách làm chuẩn, thay cho việc invalidate ($0,005/path sau 1000 path đầu).
  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    # Managed-CachingOptimized
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress        = true
  }

  restrictions {
    geo_restriction {
      # Chặn theo quốc gia diễn ra ở EDGE, trước khi request tới origin.
      # Rẻ hơn nhiều so với chặn ở tầng ứng dụng.
      restriction_type = var.chan_quoc_gia == [] ? "none" : "blacklist"
      locations        = var.chan_quoc_gia
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # Dùng domain riêng thì cần ACM certificate, và cert đó BẮT BUỘC nằm ở
    # us-east-1 dù distribution phục vụ toàn cầu. Chi tiết rất hay ra thi.
  }

  tags = { Name = "${var.prefix}-cdn" }
}

data "aws_iam_policy_document" "origin" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.origin.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "origin" {
  bucket     = aws_s3_bucket.origin.id
  policy     = data.aws_iam_policy_document.origin.json
  depends_on = [aws_s3_bucket_public_access_block.origin]
}

# ===================================================== Route 53 (TỐN TIỀN)
#
# Hosted zone $0,50/tháng, mỗi health check $0,50/tháng.
# Bật để thử routing policy, XOÁ trong hai ngày. Chi phí thực tế ~$0,05.
#
# Lưu ý: domain trong var.ten_mien KHÔNG cần bạn sở hữu thật. Bạn vẫn tạo được
# hosted zone và record, vẫn xem được cấu hình routing policy — chỉ là phân giải
# DNS công cộng sẽ không trỏ về đây. Với mục đích học thì thế là đủ.

resource "aws_route53_zone" "lab" {
  count = var.enable_route53 ? 1 : 0

  name    = var.ten_mien
  comment = "Lab tuan 8 - XOA SAU 2 NGAY"

  tags = { Name = "${var.prefix}-zone" }
}

# Health check: Route 53 gọi endpoint này định kỳ từ nhiều nơi trên thế giới.
# Endpoint hỏng → record trỏ tới nó bị loại khỏi kết quả DNS.
resource "aws_route53_health_check" "chinh" {
  count = var.enable_route53 ? 1 : 0

  fqdn              = aws_cloudfront_distribution.cdn.domain_name
  type              = "HTTPS"
  resource_path     = "/index.html"
  port              = 443
  failure_threshold = 3
  request_interval  = 30

  tags = { Name = "${var.prefix}-health-chinh" }
}

# ---- WEIGHTED routing: chia lưu lượng theo tỉ lệ ----
#
# Dùng cho canary deployment và A/B testing ở tầng DNS.
# weight 90/10 nghĩa là 90% truy vấn nhận record này, 10% nhận record kia.
resource "aws_route53_record" "weighted_chinh" {
  count = var.enable_route53 ? 1 : 0

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "app.${var.ten_mien}"
  type    = "CNAME"
  ttl     = 60

  set_identifier = "chinh-90"

  weighted_routing_policy {
    weight = 90
  }

  records = [aws_cloudfront_distribution.cdn.domain_name]
}

resource "aws_route53_record" "weighted_canary" {
  count = var.enable_route53 ? 1 : 0

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "app.${var.ten_mien}"
  type    = "CNAME"
  ttl     = 60

  set_identifier = "canary-10"

  weighted_routing_policy {
    weight = 10
  }

  records = [aws_cloudfront_distribution.cdn.domain_name]
}

# ---- FAILOVER routing: chính/dự phòng ----
#
# PRIMARY có health check. Health check fail → Route 53 tự trả SECONDARY.
# Đây là nền của chiến lược DR "Pilot Light" và "Warm Standby" ở tuần 11.
resource "aws_route53_record" "failover_primary" {
  count = var.enable_route53 ? 1 : 0

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "dr.${var.ten_mien}"
  type    = "CNAME"
  ttl     = 60

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.chinh[0].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  records = [aws_cloudfront_distribution.cdn.domain_name]
}

resource "aws_route53_record" "failover_secondary" {
  count = var.enable_route53 ? 1 : 0

  zone_id = aws_route53_zone.lab[0].zone_id
  name    = "dr.${var.ten_mien}"
  type    = "CNAME"
  ttl     = 60

  set_identifier = "secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  # Trong thực tế đây sẽ là endpoint ở region khác.
  records = ["example.com"]
}
