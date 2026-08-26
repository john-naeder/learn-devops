# ===========================================================================
# TUẦN 5 — Cơ sở dữ liệu
#
# Trọng tâm là DynamoDB vì nó MIỄN PHÍ trong hạn mức và bạn có thể nghịch
# thoải mái. RDS chỉ bật khi cần lấy $20 nhiệm vụ credit, rồi xoá.
#
# Bảng dưới đây dùng SINGLE-TABLE DESIGN — một bảng chứa nhiều loại thực thể,
# phân biệt bằng tiền tố của khoá. Đây là cách thiết kế DynamoDB đúng, và nó
# ngược hẳn với thói quen "mỗi thực thể một bảng" của SQL.
# ===========================================================================

# ============================================================== DynamoDB

resource "aws_dynamodb_table" "app" {
  name = "${var.prefix}-app"

  # PAY_PER_REQUEST (on-demand): trả theo từng request, không cần đoán capacity.
  #
  # So sánh cho kỳ thi:
  #   PAY_PER_REQUEST  không đoán tải, tự co giãn tức thì, đắt hơn ~7x mỗi request
  #                    → tải bất thường, mới ra mắt, hoặc lưu lượng thấp
  #   PROVISIONED      rẻ hơn nhiều nếu tải đều, có auto scaling, có Reserved Capacity
  #                    → tải ổn định và dự đoán được
  #
  # Free tier cho 25 WCU + 25 RCU PROVISIONED. On-demand thì tính theo request
  # và lab này dùng vài nghìn request → vẫn ~$0.
  billing_mode = "PAY_PER_REQUEST"

  # ---- Khoá chính ----
  # PK (partition key) quyết định object nằm ở partition nào. Chọn sai PK là
  # sai lầm không sửa được — phải tạo bảng mới và migrate.
  #
  # Nguyên tắc: PK phải có ĐỘ PHÂN TÁN CAO. Nếu 90% request đổ vào một giá trị
  # PK thì bạn có "hot partition" và bị throttle dù bảng còn thừa capacity.
  # Đây là câu hỏi thi rất hay gặp.
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

  # Chỉ khai báo attribute nào ĐƯỢC DÙNG LÀM KHOÁ. DynamoDB là schemaless —
  # mọi field khác cứ ghi vào tự do, không cần khai báo ở đây.
  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  # ---- Global Secondary Index ----
  #
  # GSI cho phép truy vấn theo một khoá KHÁC khoá chính. Không có GSI thì muốn
  # tìm theo field khác bạn phải Scan — đọc toàn bộ bảng, chậm và đắt.
  #
  # GSI vs LSI, phân biệt cho kỳ thi:
  #   GSI  partition key khác  · tạo/xoá bất cứ lúc nào · capacity riêng
  #        · chỉ eventually consistent
  #   LSI  partition key GIỐNG, chỉ đổi sort key · PHẢI tạo cùng lúc với bảng,
  #        không thêm sau được · dùng chung capacity · hỗ trợ strongly consistent
  #
  # Thực tế gần như luôn dùng GSI. LSI có giới hạn 10 GB mỗi partition key.
  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"

    # projection_type quyết định attribute nào được sao sang index:
    #   KEYS_ONLY  chỉ khoá — rẻ nhất, nhưng phải query lại bảng chính
    #   INCLUDE    khoá + vài attribute chỉ định
    #   ALL        toàn bộ — tiện nhất, tốn dung lượng gấp đôi
    # Đây là đánh đổi chi phí vs số lần đọc, và có trong đề thi.
  }

  # ---- TTL ----
  # DynamoDB tự xoá item khi tới thời điểm ghi trong field này (epoch giây).
  # MIỄN PHÍ HOÀN TOÀN — không tốn write capacity.
  #
  # Đây là đáp án cho "tự động dọn dữ liệu hết hạn với chi phí thấp nhất".
  # Lưu ý: xoá diễn ra trong vòng 48 giờ sau thời điểm TTL, không tức thì.
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # ---- Streams ----
  # Ghi lại mọi thay đổi trên bảng dưới dạng luồng sự kiện, giữ 24 giờ.
  # Đây là nền của kiến trúc event-driven: đổi dữ liệu → tự động kích hoạt xử lý.
  #
  # NEW_AND_OLD_IMAGES cho bạn cả trạng thái trước và sau — cần cho audit log
  # và cho việc phát hiện "field nào vừa đổi".
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  # Point-in-time recovery: khôi phục về bất kỳ giây nào trong 35 ngày qua.
  # TỐN TIỀN (~$0,20/GB/tháng) nên tắt trong lab. Bật trong production.
  point_in_time_recovery {
    enabled = false
  }

  tags = { Name = "${var.prefix}-app" }
}

# ------------------------------------------- Lambda tiêu thụ DynamoDB Stream

data "archive_file" "stream_lambda" {
  type        = "zip"
  output_path = "${path.module}/.build/stream-consumer.zip"

  source {
    filename = "handler.py"
    content  = <<-PY
      """Tiêu thụ DynamoDB Stream và ghi log những gì đã đổi.

      Đây là bộ khung tối thiểu của kiến trúc event-driven: mọi thay đổi trên
      bảng đều chảy qua đây, mà ứng dụng ghi dữ liệu không cần biết gì cả.
      """
      import json


      def handler(event, context):
          for rec in event["Records"]:
              loai = rec["eventName"]          # INSERT | MODIFY | REMOVE
              khoa = rec["dynamodb"].get("Keys", {})
              pk = khoa.get("PK", {}).get("S", "?")
              sk = khoa.get("SK", {}).get("S", "?")

              # REMOVE sinh ra bởi TTL có thêm userIdentity của service dynamodb.
              # Đây là cách phân biệt "người dùng xoá" với "TTL tự xoá".
              boi = rec.get("userIdentity", {}).get("principalId", "nguoi-dung")
              do_ttl = boi == "dynamodb.amazonaws.com"

              print(json.dumps({
                  "loai": loai,
                  "PK": pk,
                  "SK": sk,
                  "do_ttl_xoa": do_ttl,
              }, ensure_ascii=False))

          return {"da_xu_ly": len(event["Records"])}
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

resource "aws_iam_role" "stream" {
  name               = "${var.prefix}-stream-consumer"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
}

resource "aws_iam_role_policy_attachment" "stream_basic" {
  role       = aws_iam_role.stream.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Quyền đọc stream. Chú ý resource là ARN CỦA STREAM, không phải của bảng —
# hai ARN khác nhau và nhầm chỗ này là lỗi hay gặp.
resource "aws_iam_role_policy" "stream_read" {
  name = "doc-stream"
  role = aws_iam_role.stream.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:DescribeStream",
        "dynamodb:ListStreams",
      ]
      Resource = [aws_dynamodb_table.app.stream_arn]
    }]
  })
}

resource "aws_lambda_function" "stream" {
  function_name = "${var.prefix}-stream-consumer"
  role          = aws_iam_role.stream.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 128

  filename         = data.archive_file.stream_lambda.output_path
  source_code_hash = data.archive_file.stream_lambda.output_base64sha256
}

# Log group khai báo TƯỜNG MINH với retention.
#
# Nếu không tạo ở đây, Lambda tự tạo log group với retention = VĨNH VIỄN.
# Với 5 GB miễn phí mỗi tháng thì một hàm lỗi lặp vô hạn đủ ăn hết hạn mức.
# Đây là bẫy chi phí phổ biến nhất của serverless.
resource "aws_cloudwatch_log_group" "stream" {
  name              = "/aws/lambda/${aws_lambda_function.stream.function_name}"
  retention_in_days = 7
}

# Event source mapping nối stream vào Lambda.
resource "aws_lambda_event_source_mapping" "stream" {
  event_source_arn  = aws_dynamodb_table.app.stream_arn
  function_name     = aws_lambda_function.stream.arn
  starting_position = "LATEST"

  # Gom nhiều bản ghi vào một lần gọi để giảm số lần invoke.
  batch_size = 10

  # Chờ tối đa 5 giây để gom đủ batch. Đánh đổi giữa độ trễ và chi phí:
  # số lớn = ít invoke hơn = rẻ hơn, nhưng xử lý chậm hơn.
  maximum_batching_window_in_seconds = 5
}

# ================================================================== RDS
# Chỉ tạo khi enable_rds = true. Bật, làm bài, lấy $20, XOÁ.

module "vpc" {
  count  = var.enable_rds ? 1 : 0
  source = "../../_modules/lab-vpc"

  name       = var.prefix
  az_count   = 2
  enable_nat = false
}

resource "aws_db_subnet_group" "main" {
  count = var.enable_rds ? 1 : 0

  name = "${var.prefix}-db"

  # RDS BẮT BUỘC subnet group trải ít nhất 2 AZ, kể cả khi bạn chạy Single-AZ.
  # Lý do: để sau này bật Multi-AZ được mà không phải dựng lại.
  subnet_ids = module.vpc[0].private_subnet_ids

  tags = { Name = "${var.prefix}-db" }
}

resource "aws_security_group" "db" {
  count = var.enable_rds ? 1 : 0

  name        = "${var.prefix}-db"
  description = "PostgreSQL chi tu trong VPC"
  vpc_id      = module.vpc[0].vpc_id

  tags = { Name = "${var.prefix}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "db" {
  count = var.enable_rds ? 1 : 0

  security_group_id = aws_security_group.db[0].id
  description       = "PostgreSQL tu trong VPC"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = module.vpc[0].vpc_cidr
}

# Mật khẩu do RDS tự sinh và cất trong Secrets Manager.
#
# manage_master_user_password = true khiến RDS tự tạo + tự xoay vòng mật khẩu.
# Cách này tốt hơn nhiều so với đặt mật khẩu trong biến Terraform, vì biến đó
# sẽ nằm nguyên văn trong file state.
#
# LƯU Ý CHI PHÍ: secret do RDS quản lý tính $0,40/tháng. Với lab 2 tiếng thì
# ~$0,001, chấp nhận được. Nhưng nhớ rằng destroy phải xoá cả secret.
resource "aws_db_instance" "main" {
  count = var.enable_rds ? 1 : 0

  identifier     = "${var.prefix}-postgres"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = "labdb"
  username                    = "labadmin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.db[0].id]
  publicly_accessible    = false

  # KHÔNG bật Multi-AZ — nhân đôi giá. Xem giải thích ở variables.tf.
  multi_az = var.enable_multi_az

  # Backup 1 ngày là mức tối thiểu để bật được point-in-time recovery.
  # Đặt 0 sẽ TẮT hoàn toàn tính năng backup tự động.
  backup_retention_period = 1

  # Lab: xoá là xoá luôn, không giữ gì.
  # Production: BẮT BUỘC ngược lại — skip_final_snapshot = false.
  skip_final_snapshot        = true
  delete_automated_backups   = true
  deletion_protection        = false
  auto_minor_version_upgrade = true

  # Performance Insights bản free giữ 7 ngày. Bật vì miễn phí và hữu ích.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = { Name = "${var.prefix}-postgres" }
}
