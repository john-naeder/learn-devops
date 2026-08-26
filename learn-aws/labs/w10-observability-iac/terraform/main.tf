# ===========================================================================
# TUẦN 10 — Giám sát, vận hành và hạ tầng dạng mã
#
# Plan gốc gọi đây là "kỹ năng đi làm quan trọng nhất trong cả khóa", và đúng
# vậy: dựng được hệ thống là một chuyện, biết nó đang hỏng lại là chuyện khác.
#
# Lab dựng bốn thứ:
#   1. Alarm trên metric Errors → SNS → email THẬT của bạn
#   2. Metric filter: biến dòng log thành metric
#   3. Composite alarm: gộp nhiều alarm, giảm nhiễu
#   4. Dashboard gom mọi số liệu vào một chỗ
#
# Cộng thêm bài IaC: backend S3 + DynamoDB lock cho remote state.
#
# Chi phí: CloudWatch cho 10 metric tuỳ chỉnh + 10 alarm + 5 GB log miễn phí
# mỗi tháng. Lab này dùng ít hơn thế → ~$0.
# ===========================================================================

# ============================================ Ứng dụng để mà quan sát

data "archive_file" "app" {
  type        = "zip"
  output_path = "${path.module}/.build/app.zip"

  source {
    filename = "handler.py"
    content  = <<-PY
      """Hàm mẫu, có thể ép lỗi và ép chậm để sinh tín hiệu quan sát.

      Payload điều khiển hành vi:
        {"gay_loi": true}      → ném exception  (sinh metric Errors)
        {"cham_ms": 3000}      → ngủ 3 giây     (sinh Duration cao)
      """
      import json
      import os
      import random
      import time


      def handler(event, context):
          bat_dau = time.time()
          gay_loi = event.get("gay_loi", False)
          cham_ms = int(event.get("cham_ms", 0))
          nguoi_dung = event.get("nguoi_dung", "khach")

          if cham_ms:
              time.sleep(cham_ms / 1000.0)

          ms = (time.time() - bat_dau) * 1000

          # Log có CẤU TRÚC (JSON), không phải chuỗi tự do.
          #
          # Vì sao quan trọng: CloudWatch Logs Insights parse JSON tự động,
          # nên bạn query được `| filter thoi_gian_ms > 1000` mà không cần
          # viết biểu thức chính quy. Log dạng "Xu ly xong trong 1234ms" thì
          # phải parse bằng regex, chậm và dễ vỡ.
          #
          # Đây là thói quen phân biệt người biết vận hành với người không.
          print(json.dumps({
              "muc": "ERROR" if gay_loi else "INFO",
              "nguoi_dung": nguoi_dung,
              "thoi_gian_ms": round(ms, 1),
              "request_id": context.aws_request_id,
              "bo_nho_cap_phat": context.memory_limit_in_mb,
          }, ensure_ascii=False))

          if gay_loi:
              raise RuntimeError("Loi co chu y de kich hoat CloudWatch Alarm")

          return {"ok": True, "thoi_gian_ms": round(ms, 1)}
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

resource "aws_iam_role" "app" {
  name               = "${var.prefix}-app"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "app_logs" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "app" {
  function_name = "${var.prefix}-app"
  role          = aws_iam_role.app.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  memory_size   = 128
  timeout       = 30

  filename         = data.archive_file.app.output_path
  source_code_hash = data.archive_file.app.output_base64sha256

  tags = { Name = "${var.prefix}-app" }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/lambda/${aws_lambda_function.app.function_name}"
  retention_in_days = var.log_retention_days
}

# ================================================================== SNS
#
# Email subscription CẦN BẠN BẤM XÁC NHẬN trong hộp thư. Cho tới lúc đó,
# trạng thái là "PendingConfirmation" và alarm sẽ kêu vào hư không.
#
# Terraform KHÔNG chờ được việc này — nó không thể tự bấm link trong email.
# Đây là một trong số ít chỗ IaC phải dừng lại chờ con người.

resource "aws_sns_topic" "canh_bao" {
  name = "${var.prefix}-canh-bao"

  tags = { Name = "${var.prefix}-canh-bao" }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.email_canh_bao == "" ? 0 : 1

  topic_arn = aws_sns_topic.canh_bao.arn
  protocol  = "email"
  endpoint  = var.email_canh_bao
}

# ==================================================== 1. Alarm trên Errors

resource "aws_cloudwatch_metric_alarm" "loi" {
  alarm_name        = "${var.prefix}-lambda-co-loi"
  alarm_description = "Lambda ${aws_lambda_function.app.function_name} co loi trong 1 phut"

  namespace   = "AWS/Lambda"
  metric_name = "Errors"
  statistic   = "Sum"
  period      = 60

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  evaluation_periods  = 1

  # ---- treat_missing_data: tham số bị hiểu sai nhiều nhất ----
  #
  #   missing    (mặc định) giữ nguyên trạng thái trước đó
  #   notBreaching  coi như bình thường  ← đúng cho metric lỗi
  #   breaching     coi như đang lỗi     ← đúng cho metric "hệ thống còn sống"
  #   ignore        không đánh giá
  #
  # Lambda KHÔNG phát metric Errors khi không có lỗi nào — nó không gửi số 0.
  # Nếu để "missing" thì alarm sẽ mắc kẹt ở trạng thái ALARM mãi sau lần lỗi
  # đầu tiên, vì không bao giờ có dữ liệu mới để đưa nó về OK.
  #
  # Đây là lỗi cấu hình rất phổ biến và có trong đề thi.
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.canh_bao.arn]
  ok_actions    = [aws_sns_topic.canh_bao.arn]

  tags = { Name = "${var.prefix}-alarm-loi" }
}

# ------------------------------------------ Alarm trên độ trễ (percentile)
#
# Dùng p99 chứ không dùng Average.
#
# Vì sao: trung bình che giấu đuôi phân phối. 1000 request, 990 cái nhanh 50ms
# và 10 cái chậm 10 giây → trung bình chỉ ~150ms, trông rất ổn. Nhưng 1% người
# dùng đang có trải nghiệm tệ hại.
#
# p99 = 99% request nhanh hơn giá trị này. Đó mới là thứ phản ánh trải nghiệm
# tồi tệ nhất mà đa số người dùng thực sự gặp.
resource "aws_cloudwatch_metric_alarm" "cham" {
  alarm_name        = "${var.prefix}-lambda-p99-cham"
  alarm_description = "p99 Duration vuot ${var.nguong_p99_ms}ms"

  namespace          = "AWS/Lambda"
  metric_name        = "Duration"
  extended_statistic = "p99"
  period             = 60

  dimensions = {
    FunctionName = aws_lambda_function.app.function_name
  }

  comparison_operator = "GreaterThanThreshold"
  threshold           = var.nguong_p99_ms
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.canh_bao.arn]

  tags = { Name = "${var.prefix}-alarm-cham" }
}

# ============================================= 2. Metric filter từ log
#
# Biến một dòng log thành một metric có thể đặt alarm.
#
# Dùng khi metric bạn cần KHÔNG tồn tại sẵn: số lần đăng nhập thất bại, số đơn
# hàng bị huỷ, số lần gọi một API cụ thể... Những thứ chỉ ứng dụng của bạn biết.
#
# Đây là cách RẺ: bạn đã trả tiền cho log rồi, metric filter không tính thêm.
# Cách kia là gọi PutMetricData từ trong code — tốn phí API mỗi lần gọi.
# (Cách thứ ba, tốt nhất cho khối lượng lớn: Embedded Metric Format.)
resource "aws_cloudwatch_log_metric_filter" "loi_ung_dung" {
  name           = "${var.prefix}-dem-loi-ung-dung"
  log_group_name = aws_cloudwatch_log_group.app.name

  # Cú pháp lọc JSON của CloudWatch Logs. Nhờ ứng dụng in log dạng JSON có
  # cấu trúc nên viết được thế này. Nếu log là chuỗi tự do thì phải dùng
  # biểu thức chính quy, vừa chậm vừa dễ vỡ khi đổi format.
  pattern = "{ $.muc = \"ERROR\" }"

  metric_transformation {
    name      = "SoLoiUngDung"
    namespace = "${var.prefix}/UngDung"
    value     = "1"

    # BẮT BUỘC đặt default_value = 0.
    # Không có nó, metric filter chỉ phát số liệu khi CÓ lỗi — và alarm rơi
    # vào đúng cái bẫy treat_missing_data đã nói ở trên.
    default_value = 0
    unit          = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "loi_ung_dung" {
  alarm_name        = "${var.prefix}-loi-ung-dung"
  alarm_description = "Dem so dong log co muc ERROR"

  namespace   = "${var.prefix}/UngDung"
  metric_name = "SoLoiUngDung"
  statistic   = "Sum"
  period      = 60

  comparison_operator = "GreaterThanThreshold"
  threshold           = 2
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.canh_bao.arn]
}

# ==================================================== 3. Composite alarm
#
# Bài toán: hệ thống hỏng thật thì NHIỀU alarm kêu cùng lúc. Bạn nhận 8 email
# cho một sự cố, và lần sau bạn bắt đầu bỏ qua email — đó là "alarm fatigue",
# nguyên nhân thật sự khiến sự cố bị bỏ lỡ.
#
# Composite alarm gộp điều kiện: chỉ kêu khi CẢ HAI thứ cùng sai, tức là khi
# nhiều khả năng có sự cố thật chứ không phải một trục trặc thoáng qua.
resource "aws_cloudwatch_composite_alarm" "he_thong_hong" {
  alarm_name        = "${var.prefix}-he-thong-co-van-de"
  alarm_description = "Chi keu khi CO LOI VA CHAM cung luc - giam nhieu canh bao"

  alarm_rule = join(" AND ", [
    "ALARM(${aws_cloudwatch_metric_alarm.loi.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.cham.alarm_name})",
  ])

  alarm_actions = [aws_sns_topic.canh_bao.arn]

  tags = { Name = "${var.prefix}-composite" }
}

# ======================================================== 4. Dashboard

resource "aws_cloudwatch_dashboard" "chinh" {
  dashboard_name = "${var.prefix}-tong-quan"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Lambda — số lần gọi và số lỗi"
          region = var.region
          view   = "timeSeries"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.app.function_name],
            [".", "Errors", ".", "."],
            [".", "Throttles", ".", "."],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Độ trễ — trung bình che giấu đuôi, hãy nhìn p99"
          region = var.region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.app.function_name, { stat = "Average", label = "trung bình" }],
            ["...", { stat = "p50", label = "p50" }],
            ["...", { stat = "p99", label = "p99" }],
            ["...", { stat = "Maximum", label = "tệ nhất" }],
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title   = "Lỗi ứng dụng (từ metric filter trên log)"
          region  = var.region
          view    = "timeSeries"
          period  = 60
          stat    = "Sum"
          metrics = [["${var.prefix}/UngDung", "SoLoiUngDung"]]
        }
      },
      {
        # Widget log: chạy query Logs Insights ngay trong dashboard.
        type = "log", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "20 request chậm nhất"
          region = var.region
          query = join("\n", [
            "SOURCE '${aws_cloudwatch_log_group.app.name}'",
            "| fields @timestamp, nguoi_dung, thoi_gian_ms, request_id",
            "| filter ispresent(thoi_gian_ms)",
            "| sort thoi_gian_ms desc",
            "| limit 20",
          ])
          view = "table"
        }
      },
    ]
  })
}

# ================================= Bài IaC: backend S3 + DynamoDB lock
#
# Từ trước tới giờ state nằm ở file local terraform.tfstate. Với một người thì
# ổn. Với một đội thì hỏng: hai người apply cùng lúc sẽ ghi đè state của nhau
# và tài nguyên trở thành mồ côi.
#
# Remote state giải quyết bằng hai thứ:
#   S3        lưu state ở một chỗ chung, có versioning để khôi phục
#   DynamoDB  khoá — người thứ hai apply sẽ bị chặn cho tới khi người đầu xong
#
# Bài toán con gà quả trứng: Terraform không tự tạo được backend cho chính nó.
# Nên ta tạo hạ tầng backend TRƯỚC (bằng local state), rồi mới trỏ vào.
# Xem hướng dẫn từng bước trong README.md.

resource "aws_s3_bucket" "state" {
  count = var.tao_backend ? 1 : 0

  bucket = "${var.prefix}-tfstate-${data.aws_caller_identity.current.account_id}"

  # KHÔNG đặt force_destroy: state file là thứ bạn tuyệt đối không muốn
  # xoá nhầm. Muốn xoá thật thì phải xoá tay, và đó là chủ ý.

  tags = { Name = "${var.prefix}-tfstate" }
}

# Versioning trên bucket state là BẮT BUỘC, không phải tuỳ chọn.
# Nó là cách duy nhất khôi phục khi state bị hỏng hoặc bị apply nhầm.
resource "aws_s3_bucket_versioning" "state" {
  count = var.tao_backend ? 1 : 0

  bucket = aws_s3_bucket.state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  count = var.tao_backend ? 1 : 0

  bucket                  = aws_s3_bucket.state[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# State file chứa MỌI THỨ ở dạng nguyên văn: mật khẩu, khoá, endpoint riêng tư.
# Mã hoá là bắt buộc.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  count = var.tao_backend ? 1 : 0

  bucket = aws_s3_bucket.state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "lock" {
  count = var.tao_backend ? 1 : 0

  name         = "${var.prefix}-tflock"
  billing_mode = "PAY_PER_REQUEST" # dùng cực ít → gần như $0

  # Terraform yêu cầu ĐÚNG tên khoá này, không đổi được.
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = { Name = "${var.prefix}-tflock" }
}
