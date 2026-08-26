# ===========================================================================
# TUẦN 3 — EC2, EBS, ALB, Auto Scaling
#
#   Internet → ALB (public, 2 AZ) → Target Group → ASG (2 máy, 2 AZ)
#
# Khoảnh khắc đáng giá nhất của lab: tắt nginx trên một máy, xem health check
# fail, rồi xem ASG tự thay máy đó. Đó là lúc "self-healing" thôi là chữ nghĩa.
# ===========================================================================

module "vpc" {
  source = "../../_modules/lab-vpc"

  name     = var.prefix
  az_count = 2

  enable_s3_endpoint = true
  enable_nat         = !var.instances_in_public_subnet # chỉ khi cố tình chọn chuẩn production
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  target_subnets = var.instances_in_public_subnet ? module.vpc.public_subnet_ids : module.vpc.private_subnet_ids
}

# ------------------------------------------------------------ Security Group
#
# Hai SG, và quan hệ giữa chúng mới là điểm học.

resource "aws_security_group" "alb" {
  name        = "${var.prefix}-alb"
  description = "ALB nhan HTTP tu internet"
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = "${var.prefix}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP tu internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_out" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "app" {
  name        = "${var.prefix}-app"
  description = "Chi nhan traffic tu ALB, khong nhan tu internet"
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = "${var.prefix}-app" }
}

# ĐÂY là mẫu quan trọng: nguồn của rule không phải một dải IP mà là MỘT SECURITY
# GROUP KHÁC. Nghĩa là "cho phép bất cứ thứ gì đang nằm trong SG của ALB".
#
# Vì sao tốt hơn viết CIDR:
#   - ALB có IP thay đổi liên tục, không cố định để mà viết CIDR.
#   - Máy có public IP nhưng người ngoài vẫn KHÔNG gọi thẳng vào được.
#   - Thêm máy vào ALB thì không phải sửa rule.
# Mẫu này hay ra thi dưới dạng "cách nào hạn chế truy cập chặt nhất".
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP chi tu ALB"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_out" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ------------------------------------------------------------------ IAM

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# Cần SSM để Ansible vào được máy mà không cần SSH key.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Bucket trung chuyển cho connection plugin aws_ssm của Ansible.
resource "aws_s3_bucket" "transfer" {
  bucket        = "${var.prefix}-ansible-transfer-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "transfer" {
  bucket                  = aws_s3_bucket.transfer.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role_policy" "transfer" {
  name = "ansible-transfer-bucket"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [aws_s3_bucket.transfer.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${aws_s3_bucket.transfer.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.prefix}-app-profile"
  role = aws_iam_role.app.name
}

# ------------------------------------------------------------ Launch template
#
# Launch template thay thế Launch Configuration (đã lỗi thời — nếu tài liệu nào
# còn dạy Launch Configuration thì tài liệu đó cũ). Template có phiên bản,
# và ASG trỏ tới một phiên bản cụ thể hoặc "$Latest".

resource "aws_launch_template" "app" {
  name_prefix   = "${var.prefix}-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  vpc_security_group_ids = [aws_security_group.app.id]

  # IMDSv2 bắt buộc — xem giải thích ở lab tuần 2.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2 # 2 vì container/agent có thể cần thêm 1 hop
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 8
      volume_type = "gp3"

      # QUAN TRỌNG: false ở đây nghĩa là volume SỐNG SÓT sau khi terminate
      # instance, và bạn phải trả $0,08/GB/tháng cho nó mãi mãi. Đây là
      # nguyên nhân số 1 của "EBS volume mồ côi". Luôn để true.
      delete_on_termination = true
      encrypted             = true
    }
  }

  # User data chạy MỘT LẦN lúc boot đầu tiên (cloud-init). Sửa user data thì
  # phải thay instance mới có tác dụng — đó là lý do có instance_refresh bên dưới.
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -eux
    dnf install -y nginx

    TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
      -H 'X-aws-ec2-metadata-token-ttl-seconds: 300')
    IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)
    AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/placement/availability-zone)

    cat > /usr/share/nginx/html/index.html <<HTML
    <!doctype html><meta charset="utf-8">
    <title>$IID</title>
    <body style="font-family:system-ui;padding:3rem;line-height:1.6">
      <h1>Instance: $IID</h1>
      <p>Availability Zone: <b>$AZ</b></p>
      <p>Cấu hình bởi: <b>user data (cloud-init)</b></p>
      <p>Refresh liên tục để thấy ALB đổi máy phục vụ.</p>
    </body>
    HTML

    # Endpoint riêng cho health check của ALB. Tách khỏi trang chính để lát nữa
    # có thể làm health check fail mà không phải tắt cả nginx.
    echo ok > /usr/share/nginx/html/health

    systemctl enable --now nginx
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.prefix}-app"
      Tier = "app"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------- ALB

resource "aws_lb" "app" {
  name               = "${var.prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]

  # ALB BẮT BUỘC phải nằm ở ít nhất 2 AZ. Đây là yêu cầu cứng của AWS, và cũng
  # là lý do kiến trúc: một AZ chết thì vẫn còn AZ kia phục vụ.
  subnets = module.vpc.public_subnet_ids

  # Lab thì tắt để destroy nhanh; production thì luôn bật.
  enable_deletion_protection = false

  tags = { Name = "${var.prefix}-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  # Health check là thứ quyết định máy nào được nhận traffic.
  # Ba con số dưới đây đáng thuộc:
  #   interval             — bao lâu kiểm tra một lần
  #   unhealthy_threshold  — fail mấy lần thì coi là hỏng
  #   → thời gian phát hiện = interval x unhealthy_threshold = 10 x 2 = 20 giây
  # Đặt nhanh thế này để lab thấy kết quả ngay; production thường chậm hơn để
  # tránh loại nhầm máy chỉ vì một lần chậm.
  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # Thời gian chờ trước khi rút máy khỏi target group. Mặc định 300 giây làm
  # destroy lâu lê thê; 30 giây là đủ cho lab.
  deregistration_delay = 30

  tags = { Name = "${var.prefix}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ------------------------------------------------------- Auto Scaling Group

resource "aws_autoscaling_group" "app" {
  name                = "${var.prefix}-asg"
  vpc_zone_identifier = local.target_subnets

  min_size         = var.asg_min
  desired_capacity = var.asg_desired
  max_size         = var.asg_max

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app.arn]

  # ELB thay vì EC2: mặc định ASG chỉ hỏi "máy còn sống không" (EC2 check).
  # Đặt ELB nghĩa là "ứng dụng còn trả lời không" — nginx chết thì ASG thay máy,
  # dù máy vẫn đang chạy. Đây chính là thứ làm nên self-healing, và là một
  # câu hỏi thi rất hay gặp.
  health_check_type = "ELB"

  # Cho máy 60 giây khởi động trước khi bắt đầu chấm health check, nếu không
  # ASG sẽ giết máy ngay khi nó còn đang cài nginx.
  health_check_grace_period = 60

  # Thay máy dần khi launch template đổi, thay vì phải destroy cả ASG.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.prefix}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "learn"
    propagate_at_launch = true
  }

  # ASG không nhận default_tags của provider, phải khai báo tay.
  # Ansible dùng đúng tag này để tìm máy.
  tag {
    key                 = "Lab"
    value               = "w03-ec2-alb-asg"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------- Scaling policy
#
# Target tracking: bạn nói "giữ CPU trung bình ở 50%", AWS tự tính cần thêm hay
# bớt bao nhiêu máy. Đây là loại policy nên dùng mặc định, và là đáp án đúng khi
# đề hỏi "cách đơn giản nhất để tự động co giãn".
#
# Ba loại policy cần phân biệt cho kỳ thi:
#   target tracking — giữ một chỉ số ở mức mong muốn   (đơn giản nhất, ưu tiên)
#   step scaling    — thêm N máy theo từng bậc chỉ số  (kiểm soát chi tiết hơn)
#   scheduled       — co giãn theo giờ                 (khi biết trước tải)

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.prefix}-cpu-50"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}
