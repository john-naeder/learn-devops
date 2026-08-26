output "lab_builder_role_arn" {
  description = "ARN của role làm lab. Dán vào ~/.aws/config để tạo profile lab-builder."
  value       = aws_iam_role.lab_builder.arn
}

output "lab_boundary_arn" {
  description = <<-EOT
    ARN của permission boundary.

    Bạn sẽ cần ARN này trong MỌI lab có tạo IAM role hoặc IAM user, vì boundary
    từ chối tạo danh tính mới không mang chính nó. Trong Terraform:
    `permissions_boundary = <ARN này>`.
  EOT
  value       = aws_iam_policy.lab_boundary.arn
}

output "budget_name" {
  description = "Tên budget — guard.sh tra tên này để xác nhận ngân sách còn sống."
  value       = aws_budgets_budget.lab.name
}

output "allowed_regions" {
  description = "Region mà boundary cho phép. Gọi API ngoài danh sách này sẽ bị Deny."
  value       = var.allowed_regions
}

output "aws_config_profile" {
  description = "Dán nguyên khối này vào cuối ~/.aws/config, rồi dùng `--profile lab-builder`."
  value       = <<-EOT

    # ---- dán vào ~/.aws/config -------------------------------------------
    [profile ${var.role_name}]
    role_arn       = ${aws_iam_role.lab_builder.arn}
    source_profile = ${var.admin_profile}
    region         = ${var.allowed_regions[0]}
    output         = json
    # ----------------------------------------------------------------------

    Kiểm tra ngay sau khi dán:
      aws sts get-caller-identity --profile ${var.role_name}

    ARN trả về phải chứa  assumed-role/${var.role_name}/
    Nếu nó chứa :root hoặc :user/ thì bạn đang dùng nhầm profile — dừng lại.
  EOT
}

output "next_steps" {
  description = "Việc cần làm ngay sau khi apply."
  value       = <<-EOT
    1. Mở hộp thư ${var.notify_email} và BẤM XÁC NHẬN nếu AWS gửi mail đăng ký.
       Budget không xác nhận thì cảnh báo không bao giờ tới.
    2. Dán khối `aws_config_profile` ở trên vào ~/.aws/config
    3. export AWS_PROFILE=${var.role_name}
    4. ./guard.sh          ← chạy trước MỌI buổi lab
  EOT
}
