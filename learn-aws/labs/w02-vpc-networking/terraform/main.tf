# ===========================================================================
# TUẦN 2 — VPC: xương sống của mọi câu hỏi thi
#
# Dựng tay từng thành phần, KHÔNG dùng VPC wizard. Mục đích là để bạn thấy
# chúng ghép vào nhau ra sao — wizard làm hộ thì bạn không học được gì.
#
# Kiến trúc:
#   VPC 10.0.0.0/16, 2 AZ
#   ├── public  10.0.0.0/24, 10.0.1.0/24    → route 0.0.0.0/0 ra IGW
#   ├── private 10.0.10.0/24, 10.0.11.0/24  → KHÔNG có đường ra internet
#   ├── S3 Gateway Endpoint                  → MIỄN PHÍ, cho private gọi S3
#   ├── 3 Interface Endpoint cho SSM         → MẤT TIỀN, cho vào máy private
#   └── Flow Logs → CloudWatch
#
#   EC2 t3.micro trong private subnet, không public IP, không SSH key.
# ===========================================================================

module "vpc" {
  source = "../../_modules/lab-vpc"

  name     = var.prefix
  cidr     = "10.0.0.0/16"
  az_count = 2

  enable_s3_endpoint       = true  # miễn phí, luôn bật
  enable_dynamodb_endpoint = true  # miễn phí luôn
  enable_nat               = false # ~$33/tháng — không cần, xem variables.tf
  enable_flow_logs         = var.enable_flow_logs

  flow_logs_retention_days = 1 # lab 1 buổi, giữ 1 ngày là thừa
}

# --------------------------------------------------------------- AMI mới nhất
# Lấy AMI qua SSM Public Parameter thay vì hardcode ID: AMI ID khác nhau ở mỗi
# region và đổi mỗi lần AWS phát hành bản vá. Hardcode là cách chắc chắn để
# code của bạn hỏng sau ba tháng.

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ------------------------------------------------------- IAM cho SSM
# Đây là lý do tuần 1 phải học instance profile. Không có role này thì SSM
# Session Manager không bao giờ thấy được máy của bạn.

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.prefix}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# Managed policy của AWS. Nó cấp đúng quyền SSM Agent cần, không hơn.
# Tự viết lại policy này là việc vô ích và dễ sai.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Quyền trên bucket lab. Hai mục đích:
#   1. Chứng minh S3 Gateway Endpoint hoạt động (GetObject/ListBucket).
#   2. Connection plugin amazon.aws.aws_ssm của Ansible dùng S3 làm kênh
#      chuyển file hai chiều, nên cần thêm PutObject/DeleteObject.
#      Traffic đó cũng đi qua Gateway Endpoint — tức là Ansible điều khiển
#      được một máy hoàn toàn không có đường ra internet.
resource "aws_iam_role_policy" "s3_lab" {
  name = "lab-bucket-access"
  role = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.lab.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.lab.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.prefix}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# ------------------------------------------------------- Security Group
#
# SECURITY GROUP LÀ STATEFUL: cho phép chiều đi thì chiều về tự động được phép,
# không cần rule ngược. Đây là khác biệt cốt lõi với NACL và là câu hỏi thi kinh điển.
#
# Chú ý: SG dưới đây KHÔNG có một rule inbound nào. Máy vẫn vào được bằng
# Session Manager, vì SSM hoạt động theo chiều NGƯỢC — agent trên máy chủ động
# gọi ra endpoint, chứ không phải bạn gọi vào. Không mở port nào là đúng nhất.

resource "aws_security_group" "instance" {
  name        = "${var.prefix}-instance"
  description = "Khong co inbound. SSM hoat dong bang outbound tu agent."
  vpc_id      = module.vpc.vpc_id

  tags = { Name = "${var.prefix}-instance" }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.instance.id
  description       = "Cho phep ra, can de goi SSM va S3 endpoint"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# SG cho các Interface Endpoint: chỉ nhận HTTPS từ trong VPC.
resource "aws_security_group" "endpoints" {
  name        = "${var.prefix}-endpoints"
  description = "Interface endpoint chi nhan HTTPS tu trong VPC"
  vpc_id      = module.vpc.vpc_id

  tags = { Name = "${var.prefix}-endpoints" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_https" {
  security_group_id = aws_security_group.endpoints.id
  description       = "HTTPS tu trong VPC"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = module.vpc.vpc_cidr
}

# --------------------------------------------- Interface Endpoint cho SSM
# MẤT TIỀN — ~$0,01/giờ mỗi endpoint mỗi AZ. Ba endpoint, một AZ = ~$0,03/giờ.
# Đặt ở đúng một subnet để giảm nửa chi phí (đánh đổi: mất AZ đó là mất kết nối).

locals {
  ssm_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = var.enable_ssm_endpoints ? toset(local.ssm_services) : toset([])

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type = "Interface"

  # Chỉ MỘT subnet. Production thì trải mọi AZ.
  subnet_ids         = [module.vpc.private_subnet_ids[0]]
  security_group_ids = [aws_security_group.endpoints.id]

  # Bắt buộc: để tên DNS chính thức của dịch vụ trỏ về endpoint riêng tư này.
  # Không bật thì agent vẫn gọi ra internet và sẽ thất bại.
  private_dns_enabled = true

  tags = { Name = "${var.prefix}-vpce-${each.key}" }
}

# ---------------------------------------------------------------- EC2

resource "aws_instance" "private" {
  ami           = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  # Đặt đúng subnet có Interface Endpoint, nếu không sẽ không kết nối được.
  subnet_id              = module.vpc.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  # Không public IP. Đây là điểm của bài lab.
  associate_public_ip_address = false

  # IMDSv2 bắt buộc. IMDSv1 cho phép lấy credential của instance chỉ bằng một
  # request GET đơn giản — nếu app có lỗ hổng SSRF thì kẻ tấn công lấy được
  # credential role. IMDSv2 yêu cầu PUT lấy token trước, chặn được SSRF.
  # Đây là câu hỏi bảo mật hay ra thi.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"

    # Xoá volume khi terminate. Mặc định của AWS đã là true cho root volume,
    # nhưng ghi rõ ra để nhớ: volume mồ côi ở trạng thái "available" vẫn tính
    # tiền $0,08/GB/tháng và là thứ bị bỏ quên nhiều nhất.
    delete_on_termination = true
    encrypted             = true
  }

  tags = { Name = "${var.prefix}-private-instance" }
}

# --------------------------------------------------------------- S3 bucket
# Dùng để chứng minh S3 Gateway Endpoint hoạt động: máy không có đường ra
# internet vẫn đọc được file này.

resource "aws_s3_bucket" "lab" {
  bucket        = "${var.prefix}-endpoint-test-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "lab" {
  bucket                  = aws_s3_bucket.lab.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "proof" {
  bucket  = aws_s3_bucket.lab.id
  key     = "proof.txt"
  content = <<-EOT
    Nếu bạn đọc được dòng này TỪ TRONG máy private subnet, nghĩa là:
      - máy không có public IP
      - VPC không có NAT Gateway
      - nhưng vẫn tới được S3

    Đường đi là S3 Gateway Endpoint. Nó miễn phí, và nó chính là đáp án cho
    câu hỏi thi "private subnet cần gọi S3 với chi phí thấp nhất".
  EOT
}

# ------------------------------------------------------- Network ACL
#
# NACL LÀ STATELESS: cho phép chiều đi KHÔNG tự động cho phép chiều về.
# Bạn phải viết rule cho cả hai chiều. Đây là khác biệt với Security Group.
#
# NACL cũng khác SG ở chỗ: có rule DENY (SG chỉ có Allow), và xét theo số thứ tự
# từ nhỏ đến lớn, gặp rule khớp đầu tiên là dừng.
#
# NACL dưới đây chặn port 8080 để bạn thấy bản ghi REJECT trong Flow Logs.

resource "aws_network_acl" "private" {
  vpc_id     = module.vpc.vpc_id
  subnet_ids = [module.vpc.private_subnet_ids[0]]

  tags = { Name = "${var.prefix}-nacl-private" }
}

# Rule 90 — chặn port mục tiêu. Số nhỏ hơn 100 nên nó được xét TRƯỚC rule allow.
# Đổi thành 110 rồi apply lại để tự thấy thứ tự rule quan trọng thế nào.
resource "aws_network_acl_rule" "deny_port" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 90
  egress         = false
  protocol       = "tcp"
  rule_action    = "deny"
  cidr_block     = "0.0.0.0/0"
  from_port      = var.blocked_port
  to_port        = var.blocked_port
}

resource "aws_network_acl_rule" "allow_in" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}

# Rule outbound: BẮT BUỘC phải có vì NACL stateless. Bỏ rule này đi thì máy
# không gọi được SSM và bạn mất luôn đường vào — thử xem, đó là bài học đắt giá
# nhưng miễn phí.
resource "aws_network_acl_rule" "allow_out" {
  network_acl_id = aws_network_acl.private.id
  rule_number    = 100
  egress         = true
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
}
