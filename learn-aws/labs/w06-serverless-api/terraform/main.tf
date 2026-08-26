# ===========================================================================
# TUẦN 6 — Serverless: HTTP API Gateway → Lambda → DynamoDB
#
# Đây là mẫu kiến trúc được hỏi nhiều nhất trong đề SAA, và cũng là thứ
# duy nhất trong 12 tuần bạn NÊN GIỮ CHẠY VĨNH VIỄN — nó nằm trọn trong
# hạn mức always free và là hiện vật mang đi phỏng vấn.
#
# Chi phí ở mức dùng của lab: ~$0,00
#   Lambda      1 triệu request + 400.000 GB-giây / tháng   always free
#   DynamoDB    25 GB + 25 WCU/RCU                          always free
#   HTTP API    1 triệu request / tháng                     12 tháng đầu
#   CloudWatch  5 GB log / tháng                            always free
# ===========================================================================

# ============================================================== DynamoDB

resource "aws_dynamodb_table" "ghichu" {
  name         = "${var.prefix}-ghichu"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "PK"
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = { Name = "${var.prefix}-ghichu" }
}

# ================================================================= Lambda

data "archive_file" "api" {
  type        = "zip"
  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/.build/api.zip"
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

resource "aws_iam_role" "api" {
  name               = "${var.prefix}-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

# Quyền ghi log. Đây là quyền tối thiểu tuyệt đối của MỌI Lambda —
# không có nó thì hàm chạy được nhưng bạn không thấy gì trong CloudWatch,
# và debug trở thành đoán mò.
resource "aws_iam_role_policy_attachment" "api_logs" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# QUYỀN TỐI THIỂU trên DynamoDB.
#
# Chú ý những gì KHÔNG có ở đây: không dynamodb:Scan, không DeleteTable,
# không quyền lên bảng nào khác. Nếu mã Lambda bị khai thác, kẻ tấn công
# cũng chỉ làm được đúng năm thao tác này trên đúng một bảng.
#
# Đối chiếu: gắn AmazonDynamoDBFullAccess cho nhanh là cách làm sai kinh điển,
# và đề thi luôn coi "least privilege" là đáp án đúng.
resource "aws_iam_role_policy" "api_ddb" {
  name = "ghichu-crud"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
      ]
      Resource = [aws_dynamodb_table.ghichu.arn]
    }]
  })
}

resource "aws_lambda_function" "api" {
  function_name = "${var.prefix}-api"
  role          = aws_iam_role.api.arn
  handler       = "handler.handler"
  runtime       = "python3.12"

  filename         = data.archive_file.api.output_path
  source_code_hash = data.archive_file.api.output_base64sha256

  # MEMORY QUYẾT ĐỊNH CẢ CPU.
  #
  # Lambda không có nút chỉnh CPU riêng — bạn chỉnh memory, và CPU tăng theo
  # tỉ lệ thuận. 1769 MB = đúng 1 vCPU.
  #
  # Hệ quả phản trực giác: tăng memory có thể làm hàm RẺ HƠN, vì nó chạy xong
  # nhanh hơn nhiều so với phần giá tăng thêm. Với hàm nặng CPU thì 512 MB
  # thường rẻ hơn 128 MB. Đây là câu hỏi tối ưu chi phí hay ra thi.
  #
  # 256 MB cho API CRUD nhẹ này là điểm cân bằng tốt.
  memory_size = 256

  # API phải trả lời nhanh. Timeout ngắn để một request kẹt không tiêu tốn
  # 15 phút GB-giây. Timeout tối đa của Lambda là 900 giây.
  timeout = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.ghichu.name
      TTL_NGAY   = tostring(var.ttl_ngay)
    }
  }

  # KHÔNG đặt Lambda vào VPC.
  #
  # Lambda trong VPC chỉ cần khi nó phải gọi tài nguyên riêng tư (RDS, ElastiCache).
  # DynamoDB và S3 là dịch vụ công khai gọi qua API — đặt Lambda vào VPC để gọi
  # chúng là thêm độ phức tạp, thêm cold start, và cần NAT Gateway (~$33/tháng)
  # hoặc Interface Endpoint để hàm ra được internet.
  #
  # Đề thi hay bẫy chỗ này: "Lambda cần đọc DynamoDB, có cần đặt trong VPC không?"
  # → KHÔNG.

  tracing_config {
    # X-Ray: 100.000 trace/tháng miễn phí. Tuần 10 sẽ dùng để xem
    # thời gian đi đâu trong một request.
    mode = "Active"
  }

  tags = { Name = "${var.prefix}-api" }
}

resource "aws_iam_role_policy_attachment" "api_xray" {
  role       = aws_iam_role.api.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Khai báo log group TƯỜNG MINH để ép retention.
# Không làm việc này thì Lambda tự tạo log group giữ log VĨNH VIỄN.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = var.log_retention_days
}

# ======================================================== HTTP API Gateway
#
# HTTP API (v2) chứ không phải REST API (v1). Khác biệt cho kỳ thi:
#
#   HTTP API   rẻ hơn ~70%, độ trễ thấp hơn, CORS dựng sẵn, JWT authorizer sẵn
#              → thiếu: API key, usage plan, request validation, WAF trực tiếp
#   REST API   đủ tính năng: API key, usage plan, caching, WAF, mô hình validate
#              → đắt hơn, phức tạp hơn
#
# Quy tắc chọn: mặc định HTTP API. Chỉ dùng REST API khi cần một tính năng
# mà HTTP API không có.

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.prefix}-api"
  protocol_type = "HTTP"
  description   = "API ghi chu - lab tuan 6"

  # CORS xử lý ngay ở tầng API Gateway, không cần code trong Lambda.
  # Đây là một trong những thứ HTTP API làm gọn hơn hẳn REST API.
  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["content-type", "x-nguoi-dung", "authorization"]
    max_age       = 300
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn

  # Payload format 2.0 là mặc định của HTTP API và có cấu trúc event khác 1.0.
  # Mã trong src/handler.py đọc `routeKey` — thứ chỉ tồn tại ở format 2.0.
  payload_format_version = "2.0"
}

locals {
  routes = [
    "GET /health",
    "GET /ghichu",
    "POST /ghichu",
    "GET /ghichu/{id}",
    "PUT /ghichu/{id}",
    "DELETE /ghichu/{id}",
  ]
}

resource "aws_apigatewayv2_route" "routes" {
  for_each = toset(local.routes)

  api_id    = aws_apigatewayv2_api.api.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.api.id
  name   = "$default"

  # auto_deploy: thay đổi route có hiệu lực ngay, không cần bấm Deploy.
  # REST API thì phải deploy thủ công sang stage — một khác biệt hay gây bối rối.
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn

    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      # Tách riêng độ trễ của Lambda và tổng độ trễ: nếu tổng lớn hơn nhiều
      # so với integrationLatency thì nút thắt nằm ở API Gateway, không phải code.
      integrationLatency = "$context.integrationLatency"
      responseLatency    = "$context.responseLatency"
    })
  }

  # THROTTLING — hàng rào chi phí quan trọng nhất của lab này.
  #
  # Không có nó, một vòng lặp lỗi trong script test (hoặc một con bot) có thể
  # gọi hàng triệu lần và ăn sạch hạn mức miễn phí trong vài phút.
  # Đặt thấp là cố ý: lab không cần hơn.
  default_route_settings {
    throttling_rate_limit  = var.throttle_rate
    throttling_burst_limit = var.throttle_burst
  }
}

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.prefix}-api"
  retention_in_days = var.log_retention_days
}

# Cho phép API Gateway gọi Lambda.
#
# Đây là RESOURCE POLICY gắn vào Lambda, không phải identity policy.
# Nhớ lại tuần 1: hai hướng khác nhau. Thiếu cái này thì API trả 500 và
# log Lambda TRỐNG TRƠN — vì hàm chưa từng được gọi. Lỗi kinh điển.
resource "aws_lambda_permission" "api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"

  # Giới hạn đúng API này, không phải mọi API trong account.
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
