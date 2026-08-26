# ===========================================================================
# TUẦN 7 — Tách rời hệ thống
#
#                    ┌─→ SQS đơn hàng ─→ Lambda xử lý ─→ (lỗi) ─→ DLQ
#   SNS topic ──fanout┤
#                    └─→ SQS kho hàng ─→ Lambda kho
#
#   EventBridge (lịch) ─→ Lambda báo cáo
#   Step Functions ─→ 3 bước có retry và catch
#
# Toàn bộ MIỄN PHÍ: SNS 1M publish, SQS 1M request, Step Functions 4000
# state transition, Lambda 1M invoke — mỗi tháng.
#
# Ý chính của cả tuần: producer KHÔNG BIẾT consumer là ai. Thêm một consumer
# mới không phải sửa một dòng nào ở phía producer. Đó là "tách rời".
# ===========================================================================

# ============================================================ SNS — fanout

resource "aws_sns_topic" "su_kien" {
  name = "${var.prefix}-su-kien"

  tags = { Name = "${var.prefix}-su-kien" }
}

# ================================================== SQS — hai hàng đợi

# DLQ phải được tạo TRƯỚC hàng đợi chính, vì hàng đợi chính trỏ tới nó.
#
# DLQ là gì: nơi message bị đẩy sang sau khi đã thử xử lý thất bại đủ số lần.
# Không có DLQ thì message lỗi quay vòng vô tận — vừa tốn tiền vừa chặn hàng đợi.
# Đề thi hỏi "làm sao xử lý message không xử lý được" → DLQ.
resource "aws_sqs_queue" "don_hang_dlq" {
  name = "${var.prefix}-don-hang-dlq"

  # Giữ 14 ngày (tối đa) để bạn có thời gian điều tra rồi xử lý lại.
  message_retention_seconds = 1209600

  tags = { Name = "${var.prefix}-don-hang-dlq" }
}

resource "aws_sqs_queue" "don_hang" {
  name = "${var.prefix}-don-hang"

  # ---- visibility timeout ----
  # Khi một consumer nhận message, message đó bị ẩn khỏi hàng đợi trong khoảng
  # thời gian này. Nếu consumer không xoá message trước khi hết hạn, message
  # HIỆN LẠI và consumer khác sẽ nhận được — tức là XỬ LÝ TRÙNG.
  #
  # QUY TẮC VÀNG: visibility timeout phải LỚN HƠN timeout của Lambda.
  # Ở đây Lambda timeout 10s, visibility 60s — dư dả.
  # Đặt ngược lại là công thức chắc chắn để có xử lý trùng lặp, và đó chính là
  # một câu hỏi thi rất hay gặp.
  visibility_timeout_seconds = 60

  # ---- long polling ----
  # 0 = short polling: consumer hỏi liên tục, phần lớn trả về rỗng, tốn request.
  # 20 = long polling: giữ kết nối tối đa 20 giây chờ message tới.
  # Long polling giảm mạnh số request rỗng → rẻ hơn và độ trễ thấp hơn.
  # Luôn dùng 20. Đây cũng là đáp án cho "giảm chi phí SQS".
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.don_hang_dlq.arn
    # Thử 3 lần rồi bỏ cuộc. Số nhỏ để lab thấy DLQ nhanh;
    # production thường 5, và nên kèm exponential backoff.
    maxReceiveCount = 3
  })

  tags = { Name = "${var.prefix}-don-hang" }
}

resource "aws_sqs_queue" "kho_hang" {
  name                       = "${var.prefix}-kho-hang"
  visibility_timeout_seconds = 60
  receive_wait_time_seconds  = 20

  tags = { Name = "${var.prefix}-kho-hang" }
}

# ------------------------------------------ Cho phép SNS ghi vào SQS
#
# Đây là RESOURCE POLICY trên hàng đợi. SNS không tự nhiên có quyền ghi —
# phải cấp tường minh, và điều kiện aws:SourceArn giới hạn đúng topic này
# (chống confused deputy, giống bài CloudFront tuần 4).

data "aws_iam_policy_document" "sqs_nhan_sns" {
  for_each = {
    don_hang = aws_sqs_queue.don_hang.arn
    kho_hang = aws_sqs_queue.kho_hang.arn
  }

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [each.value]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.su_kien.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "don_hang" {
  queue_url = aws_sqs_queue.don_hang.id
  policy    = data.aws_iam_policy_document.sqs_nhan_sns["don_hang"].json
}

resource "aws_sqs_queue_policy" "kho_hang" {
  queue_url = aws_sqs_queue.kho_hang.id
  policy    = data.aws_iam_policy_document.sqs_nhan_sns["kho_hang"].json
}

# ------------------------------------------------------- Subscription
#
# raw_message_delivery = true: SQS nhận đúng nội dung bạn publish.
# false (mặc định): SNS bọc message trong một phong bì JSON và consumer phải
# tự bóc lớp "Message" bên trong. Đây là chi tiết hay làm người mới bối rối.

resource "aws_sns_topic_subscription" "don_hang" {
  topic_arn            = aws_sns_topic.su_kien.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.don_hang.arn
  raw_message_delivery = true

  # FILTER POLICY — mấu chốt của fanout thông minh.
  #
  # Hàng đợi này CHỈ nhận message có thuộc tính loai_su_kien = don-hang.
  # Việc lọc diễn ra ở SNS, TRƯỚC khi message được gửi đi — nên bạn không
  # trả tiền cho message không liên quan, và consumer không phải viết code lọc.
  #
  # Đề thi: "làm sao để mỗi consumer chỉ nhận loại sự kiện nó quan tâm" → filter policy.
  filter_policy = jsonencode({
    loai_su_kien = ["don-hang"]
  })
}

resource "aws_sns_topic_subscription" "kho_hang" {
  topic_arn            = aws_sns_topic.su_kien.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.kho_hang.arn
  raw_message_delivery = true

  # Hàng đợi kho quan tâm cả hai loại → nhận nhiều hơn.
  filter_policy = jsonencode({
    loai_su_kien = ["don-hang", "nhap-kho"]
  })
}

# ============================================================== Lambda

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ---- Lambda xử lý đơn hàng (cố tình làm được cho hỏng) ----

data "archive_file" "don_hang" {
  type        = "zip"
  output_path = "${path.module}/.build/don-hang.zip"

  source {
    filename = "handler.py"
    content  = <<-PY
      """Xử lý message đơn hàng.

      Hàm này có một công tắc gây lỗi: nếu biến môi trường GAY_LOI=true thì
      nó ném exception cho MỌI message. Dùng để quan sát cơ chế thử lại và DLQ.
      """
      import json
      import os


      def handler(event, context):
          gay_loi = os.environ.get("GAY_LOI", "false").lower() == "true"

          for rec in event["Records"]:
              than = rec["body"]
              # approximateReceiveCount cho biết message này đã bị thử lần thứ mấy.
              # Khi số này vượt maxReceiveCount (3), SQS đẩy message sang DLQ.
              lan_thu = rec["attributes"]["ApproximateReceiveCount"]

              print(json.dumps({
                  "noi_dung": than,
                  "lan_thu": lan_thu,
                  "message_id": rec["messageId"],
              }, ensure_ascii=False))

              if gay_loi:
                  # Ném exception → Lambda báo thất bại → SQS KHÔNG xoá message
                  # → message hiện lại sau visibility timeout → thử lại.
                  raise RuntimeError(
                      f"Loi co chu y (lan thu {lan_thu}). "
                      "Sau 3 lan message se sang DLQ."
                  )

          return {"da_xu_ly": len(event["Records"])}
    PY
  }
}

resource "aws_iam_role" "don_hang" {
  name               = "${var.prefix}-don-hang"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# Managed policy này cấp quyền đọc VÀ XOÁ message khỏi hàng đợi.
# Quyền xoá quan trọng: consumer phải tự xoá message sau khi xử lý xong,
# nếu không message sẽ quay lại. SQS không tự xoá gì cả.
resource "aws_iam_role_policy_attachment" "don_hang_sqs" {
  role       = aws_iam_role.don_hang.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_lambda_function" "don_hang" {
  function_name = "${var.prefix}-xu-ly-don-hang"
  role          = aws_iam_role.don_hang.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  memory_size   = 128

  # PHẢI nhỏ hơn visibility_timeout_seconds của hàng đợi (60s).
  timeout = 10

  filename         = data.archive_file.don_hang.output_path
  source_code_hash = data.archive_file.don_hang.output_base64sha256

  environment {
    variables = {
      GAY_LOI = tostring(var.gay_loi_don_hang)
    }
  }
}

resource "aws_cloudwatch_log_group" "don_hang" {
  name              = "/aws/lambda/${aws_lambda_function.don_hang.function_name}"
  retention_in_days = 7
}

resource "aws_lambda_event_source_mapping" "don_hang" {
  event_source_arn = aws_sqs_queue.don_hang.arn
  function_name    = aws_lambda_function.don_hang.arn

  # Gom tối đa 5 message mỗi lần gọi. Cẩn thận: nếu MỘT message trong batch
  # lỗi mà không bật report_batch_item_failures thì CẢ BATCH bị thử lại,
  # kể cả những message đã xử lý thành công.
  batch_size = 5

  # Bật để Lambda báo riêng message nào hỏng, chỉ message đó bị thử lại.
  # Cần code trả về {"batchItemFailures": [...]} — bài tập mở rộng.
  function_response_types = []
}

# ---- Lambda kho hàng (luôn thành công) ----

data "archive_file" "kho_hang" {
  type        = "zip"
  output_path = "${path.module}/.build/kho-hang.zip"

  source {
    filename = "handler.py"
    content  = <<-PY
      import json


      def handler(event, context):
          for rec in event["Records"]:
              print(json.dumps({
                  "kho_nhan": rec["body"],
                  "message_id": rec["messageId"],
              }, ensure_ascii=False))
          return {"da_xu_ly": len(event["Records"])}
    PY
  }
}

resource "aws_iam_role" "kho_hang" {
  name               = "${var.prefix}-kho-hang"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "kho_hang_sqs" {
  role       = aws_iam_role.kho_hang.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_lambda_function" "kho_hang" {
  function_name = "${var.prefix}-xu-ly-kho-hang"
  role          = aws_iam_role.kho_hang.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  memory_size   = 128
  timeout       = 10

  filename         = data.archive_file.kho_hang.output_path
  source_code_hash = data.archive_file.kho_hang.output_base64sha256
}

resource "aws_cloudwatch_log_group" "kho_hang" {
  name              = "/aws/lambda/${aws_lambda_function.kho_hang.function_name}"
  retention_in_days = 7
}

resource "aws_lambda_event_source_mapping" "kho_hang" {
  event_source_arn = aws_sqs_queue.kho_hang.arn
  function_name    = aws_lambda_function.kho_hang.arn
  batch_size       = 5
}

# ======================================================== EventBridge lịch

data "archive_file" "bao_cao" {
  type        = "zip"
  output_path = "${path.module}/.build/bao-cao.zip"

  source {
    filename = "handler.py"
    content  = <<-PY
      import json
      from datetime import datetime, timezone


      def handler(event, context):
          print(json.dumps({
              "chay_luc": datetime.now(timezone.utc).isoformat(),
              "nguon": event.get("source"),
              "loai": event.get("detail-type"),
          }, ensure_ascii=False))
          return {"ok": True}
    PY
  }
}

resource "aws_iam_role" "bao_cao" {
  name               = "${var.prefix}-bao-cao"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "bao_cao_logs" {
  role       = aws_iam_role.bao_cao.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "bao_cao" {
  function_name = "${var.prefix}-bao-cao-dinh-ky"
  role          = aws_iam_role.bao_cao.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  memory_size   = 128
  timeout       = 10

  filename         = data.archive_file.bao_cao.output_path
  source_code_hash = data.archive_file.bao_cao.output_base64sha256
}

resource "aws_cloudwatch_log_group" "bao_cao" {
  name              = "/aws/lambda/${aws_lambda_function.bao_cao.function_name}"
  retention_in_days = 7
}

# MẶC ĐỊNH TẮT — và đây là chủ ý.
#
# Một rule chạy mỗi 5 phút mà bạn quên tắt sẽ sinh 8640 lần gọi mỗi tháng
# cùng lượng log tương ứng. Không đủ để hết hạn mức, nhưng đủ để làm bẩn
# CloudWatch và che mất tín hiệu thật. Plan gốc nhắc riêng điều này ở tuần 7.
resource "aws_cloudwatch_event_rule" "dinh_ky" {
  name                = "${var.prefix}-moi-5-phut"
  description         = "Chay Lambda bao cao dinh ky"
  schedule_expression = var.lich_chay
  state               = var.bat_lich ? "ENABLED" : "DISABLED"
}

resource "aws_cloudwatch_event_target" "bao_cao" {
  rule      = aws_cloudwatch_event_rule.dinh_ky.name
  target_id = "lambda"
  arn       = aws_lambda_function.bao_cao.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bao_cao.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dinh_ky.arn
}

# ========================================================= Step Functions

data "aws_iam_policy_document" "sfn_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn" {
  name               = "${var.prefix}-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_trust.json
}

resource "aws_iam_role_policy" "sfn" {
  name = "goi-lambda"
  role = aws_iam_role.sfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["lambda:InvokeFunction"]
      Resource = [
        "${aws_lambda_function.don_hang.arn}:*",
        aws_lambda_function.don_hang.arn,
        "${aws_lambda_function.kho_hang.arn}:*",
        aws_lambda_function.kho_hang.arn,
      ]
    }]
  })
}

# STANDARD vs EXPRESS — phân biệt cho kỳ thi:
#
#   Standard  tối đa 1 năm · exactly-once · có lịch sử thực thi đầy đủ trong
#             console · tính tiền theo state transition (4000/tháng miễn phí)
#             → quy trình dài, cần audit, cần idempotent nghiêm ngặt
#
#   Express   tối đa 5 phút · at-least-once · log vào CloudWatch · tính tiền
#             theo số lần chạy và thời lượng · rẻ hơn nhiều khi tần suất cao
#             → xử lý sự kiện tần suất cao, luồng ngắn
#
# Lab dùng Standard để bạn xem được sơ đồ thực thi trực quan trong console.
resource "aws_sfn_state_machine" "quy_trinh" {
  name     = "${var.prefix}-quy-trinh-don-hang"
  role_arn = aws_iam_role.sfn.arn
  type     = "STANDARD"

  definition = jsonencode({
    Comment = "Quy trinh 3 buoc co retry va catch"
    StartAt = "KiemTraDonHang"

    States = {
      # ---- Bước 1: có retry ----
      KiemTraDonHang = {
        Type     = "Task"
        Resource = aws_lambda_function.kho_hang.arn
        Comment  = "Buoc nay co the tam thoi that bai"

        # RETRY xử lý lỗi TẠM THỜI (throttle, timeout mạng).
        # Exponential backoff: chờ 2s, rồi 4s, rồi 8s.
        # Đây là thứ bạn nên có ở MỌI Task gọi dịch vụ ngoài.
        Retry = [
          {
            ErrorEquals = [
              "Lambda.ServiceException",
              "Lambda.AWSLambdaException",
              "Lambda.SdkClientException",
              "Lambda.TooManyRequestsException",
            ]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          },
        ]

        # CATCH xử lý lỗi VĨNH VIỄN — hết retry vẫn hỏng thì đi nhánh khác
        # thay vì để cả quy trình chết.
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "XuLyLoi"
            ResultPath  = "$.loi" # giữ input gốc, thêm chi tiết lỗi vào $.loi
          },
        ]

        Next = "ChoXacNhan"
      }

      # ---- Bước 2: Wait ----
      # Wait KHÔNG tốn tiền theo thời gian chờ trong Standard workflow.
      # Đây là điểm mạnh lớn: chờ 30 ngày cũng chỉ tính là một state transition.
      # Với Lambda thì chờ đồng nghĩa với trả tiền GB-giây.
      ChoXacNhan = {
        Type    = "Wait"
        Seconds = 3
        Next    = "GhiNhanKho"
      }

      # ---- Bước 3 ----
      GhiNhanKho = {
        Type     = "Task"
        Resource = aws_lambda_function.kho_hang.arn
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 2
            MaxAttempts     = 2
            BackoffRate     = 2.0
          },
        ]
        End = true
      }

      XuLyLoi = {
        Type = "Pass"
        Result = {
          trang_thai = "that-bai"
          ghi_chu    = "Da vao nhanh catch thay vi lam sap ca quy trinh"
        }
        End = true
      }
    }
  })

  tags = { Name = "${var.prefix}-quy-trinh" }
}
