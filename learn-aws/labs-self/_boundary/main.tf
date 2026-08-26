# ===========================================================================
# Hàng rào an toàn cho toàn bộ labs-self/
#
# Apply MỘT LẦN, bằng profile admin (`learn`). Sau đó không đụng vào nữa.
# Mọi buổi lab về sau chạy bằng profile `lab-builder` — role bị chính file này
# nhốt lại.
#
#   terraform init
#   terraform apply -var 'notify_email=ban@example.com'
#
# Ba thứ được dựng:
#   1. aws_iam_policy.lab_boundary  — trần quyền, AWS tự ép ở tầng API
#   2. aws_iam_role.lab_builder     — role người học assume, admin nhưng bị chặn trần
#   3. aws_budgets_budget.lab       — lưới an toàn cuối cùng khi (1) bỏ lọt
# ===========================================================================

provider "aws" {
  region  = var.region
  profile = var.admin_profile

  default_tags {
    tags = {
      # CỐ Ý khác giá trị tag của lab (`owner = "labs-self"`).
      # _lib/cleanup.sh lọc đúng chuỗi "labs-self", nên hàng rào không bao giờ
      # lọt vào danh sách bị dọn. Đừng đổi giá trị này.
      owner     = "labs-self-infra"
      lab       = "_boundary"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  # Ghép ARN bằng tay thay vì tham chiếu aws_iam_policy.lab_boundary.arn.
  # Lý do: policy này Deny việc sửa CHÍNH NÓ, nên nếu tham chiếu tài nguyên thì
  # Terraform sẽ thấy một vòng lặp phụ thuộc (policy -> document -> policy).
  # ARN của IAM là chuỗi đoán trước được, nên ghép tay là cách thoát vòng lặp.
  boundary_arn = "arn:${local.partition}:iam::${local.account_id}:policy/${var.boundary_name}"
  role_arn     = "arn:${local.partition}:iam::${local.account_id}:role/${var.role_name}"

  # Danh tính đang chạy apply. Nếu bạn đang dùng một role (ARN dạng
  # arn:aws:sts::...:assumed-role/TenRole/PhienLamViec) thì ARN đó KHÔNG dùng
  # làm Principal trong trust policy được — phải quy về ARN của role gốc.
  caller_arn = data.aws_caller_identity.current.arn
  caller_principal = startswith(local.caller_arn, "arn:${local.partition}:sts::") ? (
    "arn:${local.partition}:iam::${local.account_id}:role/${split("/", local.caller_arn)[1]}"
  ) : local.caller_arn

  trust_principals = length(var.trusted_principal_arns) > 0 ? var.trusted_principal_arns : [local.caller_principal]

  # Dịch vụ global: endpoint của chúng nằm ngoài mô hình region, hoặc luôn báo
  # aws:RequestedRegion = us-east-1. Chặn theo region sẽ làm hỏng cả IAM lẫn
  # Cost Explorer lẫn CloudFront, nên phải chừa ra.
  global_services = [
    "iam:*",
    "sts:*",
    "organizations:*",
    "account:*",
    "cloudfront:*",
    "route53:*",
    "route53domains:*",
    "budgets:*",
    "ce:*",
    "cur:*",
    "support:*",
    "waf:*",
    "wafv2:*",
    "shield:*",
    "globalaccelerator:*",
    "health:*",
    "tag:*",
    "trustedadvisor:*",
    "pricing:*",
    "s3:ListAllMyBuckets",
    "ec2:DescribeRegions",
  ]

  # Danh sách "đốt tiền nhanh, lab không cần". Mỗi dòng kèm giá tham khảo
  # us-east-1 quy ra một tháng chạy liên tục — xem bảng bẫy tiền trong
  # ../../aws-saa-plan.md
  money_burners = [
    "ec2:CreateNatGateway",    # ~$33/tháng — kẻ giết credit số 1
    "ec2:*TransitGateway*",    # ~$36/tháng mỗi attachment
    "ec2:*ClientVpn*",         # ~$72/tháng endpoint + $0,05/giờ mỗi kết nối
    "ec2:CreateVpnConnection", # Site-to-Site VPN ~$36/tháng
    "ec2:CreateVpnGateway",
    "ec2:CreateCustomerGateway",
    "ec2:AllocateAddress", # Elastic IP $3,6/tháng, tính CẢ khi không gắn
    # vào đâu. Không lab nào cần IP tĩnh:
    # public IPv4 tự gán là đủ, và ALB tự lo IP.
    "ec2:AllocateHosts",    # Dedicated Host — từ ~$1.500/tháng
    "ec2:RequestSpotFleet", # fleet tự nhân bản, khó đếm trước
    "ec2:CreateFleet",
    "ec2:CreateCapacityReservation", # trả tiền kể cả khi không chạy máy
    "ec2:PurchaseReservedInstancesOffering",
    "ec2:PurchaseHostReservation",
    "ec2:PurchaseCapacityBlock",
    "savingsplans:CreateSavingsPlan", # cam kết 1–3 NĂM, không huỷ được
    "rds:PurchaseReservedDBInstancesOffering",
    "elasticache:Create*", # node nhỏ nhất cũng ~$12/tháng
    "elasticache:Purchase*",
    "kinesis:CreateStream", # shard provisioned ~$11/tháng mỗi shard
    "kinesis:UpdateShardCount",
    "directconnect:*",     # cổng vật lý, không lab được
    "globalaccelerator:*", # ~$18/tháng
    "networkmanager:*",
    "outposts:*",
    "eks:*",      # ~$73/tháng riêng control plane
    "redshift:*", # từ ~$180/tháng
    "redshift-serverless:*",
    "elasticmapreduce:*", # EMR, từ ~$180/tháng
    "emr-serverless:*",
    "emr-containers:*",
    "sagemaker:*", # notebook quên tắt = vài trăm đô
    "es:*",        # OpenSearch (prefix cũ)
    "opensearch:*",
    "aoss:*",
    "kafka:*", # MSK, từ ~$150/tháng
    "kafka-cluster:*",
    "mq:*",       # Amazon MQ ~$30/tháng
    "fsx:*",      # từ ~$40/tháng
    "transfer:*", # Transfer Family $0,30/giờ = ~$216/tháng
    "storagegateway:*",
    "datasync:*",
    "network-firewall:*", # ~$300/tháng
    "workspaces:*",
    "appstream:*",
    "braket:*",
    "groundstation:*",
    "airflow:*", # MWAA từ ~$350/tháng
    "quicksight:*",
    "managedblockchain:*",
    "shield:CreateSubscription", # Shield Advanced $3.000/THÁNG, cam kết 1 năm
    "wafv2:CreateWebACL",        # $5/tháng mỗi WebACL + $1 mỗi rule
    "waf:CreateWebACL",
    "waf-regional:CreateWebACL",
    "macie2:*",                      # $1/GB sau bản dùng thử
    "detective:*",                   # ~$2/GB dữ liệu nạp vào
    "route53domains:RegisterDomain", # mua domain thật, tiền thật
    "route53domains:TransferDomain",
    "route53domains:RenewDomain",
    "lambda:PutProvisionedConcurrencyConfig", # tính tiền cả khi không có request
  ]
}

# ===========================================================================
# 1. Permission boundary
# ===========================================================================
#
# Cách đọc policy này: một Allow "*" mở toang, rồi một chuỗi Deny bóp lại.
# Trong IAM, explicit Deny thắng mọi Allow — kể cả AdministratorAccess — nên
# thứ tự statement không quan trọng, chỉ nội dung mới quan trọng.
#
# Viết theo kiểu "Allow rộng rồi Deny hẹp" thay vì "liệt kê Allow" là cố ý:
# 12 lab dùng hàng chục dịch vụ, liệt kê Allow sẽ chặn nhầm liên tục và người
# học sẽ mất thời gian gỡ hàng rào thay vì học kiến trúc.

data "aws_iam_policy_document" "lab_boundary" {

  # --- Nền: cho phép mọi thứ ------------------------------------------------
  # Permission boundary KHÔNG cấp quyền. Nó chỉ đặt trần. Statement này là cái
  # trần "tối đa = mọi thứ", và toàn bộ giá trị của file nằm ở các Deny bên dưới.
  statement {
    sid       = "BaseAllowAll"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  # --- Một region duy nhất --------------------------------------------------
  statement {
    sid         = "DenyOutsideAllowedRegions"
    effect      = "Deny"
    not_actions = local.global_services
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  # --- Chỉ instance rẻ ------------------------------------------------------
  # Resource phải là instance/* vì khoá ec2:InstanceType chỉ tồn tại trên
  # resource instance của RunInstances, không tồn tại trên volume hay ENI.
  statement {
    sid       = "DenyExpensiveInstanceTypes"
    effect    = "Deny"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:${local.partition}:ec2:*:*:instance/*"]

    condition {
      test     = "StringNotEquals"
      variable = "ec2:InstanceType"
      values   = var.allowed_instance_types
    }
  }

  # --- Chỉ database class rẻ ------------------------------------------------
  # Lưu ý về rds:CreateDBCluster: request tạo cluster KHÔNG mang khoá
  # rds:DatabaseClass. Với toán tử phủ định (StringNotEquals), khoá vắng mặt
  # làm điều kiện đúng, nên CreateDBCluster bị chặn HOÀN TOÀN.
  # Đó là kết quả mong muốn: Aurora / DocumentDB / Neptune đều đắt hơn nhiều
  # và kế hoạch tuần 5 đã cấm — xem README mục "Xung đột đã biết".
  statement {
    sid       = "DenyExpensiveDbClass"
    effect    = "Deny"
    actions   = ["rds:CreateDBInstance", "rds:CreateDBCluster"]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "rds:DatabaseClass"
      values   = var.allowed_db_classes
    }
  }

  # Multi-AZ nhân đôi hoá đơn RDS mà không dạy thêm gì so với một sơ đồ.
  statement {
    sid       = "DenyRdsMultiAz"
    effect    = "Deny"
    actions   = ["rds:CreateDBInstance"]
    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "rds:MultiAz"
      values   = ["true"]
    }
  }

  # --- Chặn Auto Scaling Group phình to -------------------------------------
  statement {
    sid    = "DenyRunawayAutoScaling"
    effect = "Deny"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]
    resources = ["*"]

    condition {
      test     = "NumericGreaterThan"
      variable = "autoscaling:MaxSize"
      values   = [tostring(var.max_asg_size)]
    }
  }

  # --- Dịch vụ đốt tiền nhanh mà lab không cần ------------------------------
  statement {
    sid       = "DenyMoneyBurners"
    effect    = "Deny"
    actions   = local.money_burners
    resources = ["*"]
  }

  # ==========================================================================
  # Tự bảo vệ — phần dễ bị quên nhất khi tự viết boundary
  #
  # Một boundary mà chủ thể bị nhốt có thể tự tháo thì không phải hàng rào,
  # chỉ là một lời nhắc. Bốn statement dưới đây bịt bốn đường thoát:
  #   a. sửa nội dung chính policy này
  #   b. gỡ boundary khỏi role/user
  #   c. tạo một danh tính MỚI không có boundary rồi assume sang
  #   d. đổi luật chơi ở tầng cao hơn (Organizations / account)
  # ==========================================================================

  # (a)
  statement {
    sid    = "ProtectBoundaryItself"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeletePolicy",
    ]
    resources = [local.boundary_arn]
  }

  # (a') giữ luôn cả role lab-builder: không tự xoá, không tự sửa trust policy.
  statement {
    sid    = "ProtectBuilderRole"
    effect = "Deny"
    actions = [
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = [local.role_arn]
  }

  # (b)
  statement {
    sid    = "DenyRemovingAnyBoundary"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteUserPermissionsBoundary",
    ]
    resources = ["*"]
  }

  # (c) Mọi user/role tạo mới BẮT BUỘC mang đúng boundary này.
  #
  # Hệ quả bạn sẽ gặp ngay ở lab đầu tiên có IAM: mỗi `aws_iam_role` bạn viết
  # phải có `permissions_boundary`. Thiếu nó thì AccessDenied — và đó là hàng
  # rào làm đúng việc, không phải bug. Xem README, mục "Đọc lỗi AccessDenied".
  #
  # iam:CreateServiceLinkedRole CỐ Ý không nằm trong danh sách: ELB và Auto
  # Scaling cần service-linked role, và AWS không cho gắn boundary vào chúng.
  statement {
    sid    = "DenyPrincipalWithoutBoundary"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateRole",
      "iam:PutUserPermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
    }
  }

  # (c') Chống leo thang qua CREDENTIAL, không qua policy.
  #
  # Lỗ này tinh vi hơn (c) và rất hay bị bỏ sót khi tự viết boundary: role bị
  # nhốt không cần tạo danh tính mới — nó chỉ cần lấy credential của một danh
  # tính SẴN CÓ mà không mang boundary. Ba đường:
  #
  #   iam:CreateAccessKey        trên user admin  -> có key vĩnh viễn của admin
  #   iam:CreateLoginProfile     trên user admin  -> đặt mật khẩu console
  #   iam:UpdateAssumeRolePolicy trên role admin  -> sửa trust policy để tự
  #                                                  assume sang, thoát rào
  #
  # Chặn bằng NotResource theo tiền tố tên: chỉ được đụng vào danh tính do
  # chính lab tạo ra (self-wXX-...) — mà những danh tính đó thì statement (c)
  # đã bắt buộc phải mang boundary rồi. Đây chính là "điều kiện dựa trên
  # prefix" mà CONVENTIONS.md nhắc tới.
  statement {
    sid    = "DenyCredentialEscalation"
    effect = "Deny"
    actions = [
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachUserPolicy",
      "iam:PutUserPolicy",
      "iam:AddUserToGroup",
    ]
    not_resources = [
      "arn:${local.partition}:iam::${local.account_id}:user/self-w*",
      "arn:${local.partition}:iam::${local.account_id}:role/self-w*",
    ]
  }

  # (c'') Đúc credential dài hạn — chặn TUYỆT ĐỐI, không theo prefix.
  #
  # Bốn action này là cách biến một danh tính thành một bộ credential cầm đi
  # được. Khác với nhóm trên, ở đây không nới theo tên: kể cả user do chính
  # lab tạo ra cũng không được cấp access key.
  #
  # Vừa là hàng rào vừa là bài học tuần 1: nếu bạn thấy mình sắp tạo access
  # key, nghĩa là bạn đang chọn USER ở chỗ đáng lẽ chọn ROLE — đúng cái bẫy
  # đề thi hay giăng. Credential tạm thời của role hết hạn sau vài giờ;
  # access key thì sống tới khi có người phát hiện.
  statement {
    sid    = "DenyLongLivedCredentials"
    effect = "Deny"
    actions = [
      "iam:CreateAccessKey",
      "iam:UpdateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
    ]
    resources = ["*"]
  }

  # (d)
  statement {
    sid       = "DenyOrgAndAccount"
    effect    = "Deny"
    actions   = ["organizations:*", "account:*", "billingconductor:*"]
    resources = ["*"]
  }

  # Ngân sách là lưới an toàn cuối cùng. Ai gỡ được nó thì gỡ được tất cả.
  statement {
    sid    = "DenyBudgetTampering"
    effect = "Deny"
    actions = [
      "budgets:ModifyBudget",
      "budgets:CreateBudget*",
      "budgets:UpdateBudget*",
      "budgets:DeleteBudget*",
      "budgets:DeleteNotification",
      "budgets:DeleteSubscriber",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lab_boundary" {
  name        = var.boundary_name
  description = "Trần quyền cho mọi lab trong labs-self. Dựng bằng profile admin, không sửa được từ role lab-builder."
  policy      = data.aws_iam_policy_document.lab_boundary.json
}

# ===========================================================================
# 2. Role lab-builder
# ===========================================================================
#
# Quyền hiệu dụng = GIAO của hai tập:
#
#     AdministratorAccess   ∩   lab_boundary   =   quyền thật sự có
#     (identity policy)         (trần quyền)
#
# Bỏ AdministratorAccess đi thì role không có quyền gì cả, vì boundary một
# mình KHÔNG cấp quyền. Đây là điểm bị hiểu sai nhiều nhất về permission
# boundary, và cũng là điểm đề thi hay hỏi.

data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AllowLearnerToAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.trust_principals
    }
  }
}

resource "aws_iam_role" "lab_builder" {
  name                 = var.role_name
  description          = "Role làm lab. Admin trên giấy tờ, nhưng bị permission boundary bóp lại."
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  permissions_boundary = aws_iam_policy.lab_boundary.arn
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy_attachment" "lab_builder_admin" {
  role       = aws_iam_role.lab_builder.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AdministratorAccess"
}

# ===========================================================================
# 3. Ngân sách
# ===========================================================================
#
# Boundary chặn được "tạo cái đắt tiền". Nó KHÔNG chặn được "cái rẻ tiền chạy
# quên tắt 30 ngày", cũng không chặn được tiền tính theo lượng dữ liệu hay số
# request. Ngân sách bắt đúng chỗ đó — muộn hơn, nhưng bắt được.

resource "aws_budgets_budget" "lab" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Cảnh báo theo chi tiêu THỰC TẾ.
  dynamic "notification" {
    for_each = var.budget_thresholds
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.notify_email]
    }
  }

  # Cảnh báo theo DỰ BÁO: mail này tới trước khi tiền thật sự mất, và đó mới
  # là loại cảnh báo cứu được ví. Một NAT Gateway bật lúc 1 giờ sáng sẽ kích
  # hoạt cảnh báo dự báo trong vòng vài giờ.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.notify_email]
  }
}
