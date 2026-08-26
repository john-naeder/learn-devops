# ---------------------------------------------------------------------------
# VPC dùng chung cho các lab cần mạng: tuần 2, 3, 5, 9.
#
# Bố cục: 1 VPC /16, mỗi AZ một public subnet /24 và một private subnet /24.
#   public  → có route 0.0.0.0/0 ra Internet Gateway
#   private → KHÔNG có route ra internet (trừ khi bật NAT)
#
# Điểm cần khắc vào đầu: public subnet và private subnet là hai subnet
# GIỐNG HỆT NHAU. Khác biệt duy nhất nằm ở route table gắn vào nó. Không có
# checkbox "public" nào cả. Đây là câu hỏi hay ra thi.
# ---------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # 10.0.0.0/16 → public  10.0.0.0/24, 10.0.1.0/24, ...
  #            → private 10.0.10.0/24, 10.0.11.0/24, ...
  # Tách xa nhau để nhìn octet thứ ba là biết ngay subnet loại gì.
  public_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i)]
  private_cidrs = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i + 10)]

  nat_count = var.enable_nat ? (var.single_nat_gateway ? 1 : var.az_count) : 0
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr

  # Cần cho SSM Session Manager và cho VPC endpoint hoạt động đúng.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

# ------------------------------------------------------------------ subnets

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = local.azs[count.index]

  # Instance trong subnet này tự nhận public IP. Lưu ý: public IPv4 giờ tính
  # tiền $0,005/giờ kể cả khi đang gắn vào instance đang chạy.
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

# ------------------------------------------------------- internet gateway

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-rt-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------------- NAT gateway
# Chỉ được tạo khi enable_nat = true. Đọc comment trong variables.tf trước khi bật.

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-eip-nat-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.this]
}

# ----------------------------------------------------- private route tables
# Mỗi AZ một route table riêng: cần thiết khi mỗi AZ có NAT riêng, và cũng là
# cách bố trí đúng để về sau thêm route đặc thù theo AZ.

resource "aws_route_table" "private" {
  count = var.az_count

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name}-rt-private-${local.azs[count.index]}" })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat ? var.az_count : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ----------------------------------------------------------- VPC endpoints
# Gateway Endpoint MIỄN PHÍ và là câu trả lời đúng cho "private subnet gọi S3
# với chi phí thấp nhất". Nó hoạt động bằng cách chèn một route vào route table,
# chứ không tạo ENI như Interface Endpoint (cái đó $0,01/giờ/AZ).

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.public.id],
  )

  tags = merge(var.tags, { Name = "${var.name}-vpce-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    aws_route_table.private[*].id,
    [aws_route_table.public.id],
  )

  tags = merge(var.tags, { Name = "${var.name}-vpce-dynamodb" })
}

data "aws_region" "current" {}

# --------------------------------------------------------------- flow logs

resource "aws_cloudwatch_log_group" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name}"
  retention_in_days = var.flow_logs_retention_days

  tags = var.tags
}

data "aws_iam_policy_document" "flow_assume" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_write" {
  count = var.enable_flow_logs ? 1 : 0

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow[0].arn}:*"]
  }
}

resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name               = "${var.name}-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0

  name   = "write-logs"
  role   = aws_iam_role.flow[0].id
  policy = data.aws_iam_policy_document.flow_write[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow[0].arn
  log_destination = aws_cloudwatch_log_group.flow[0].arn

  tags = merge(var.tags, { Name = "${var.name}-flow-logs" })
}
