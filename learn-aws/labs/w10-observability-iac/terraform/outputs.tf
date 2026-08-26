output "lambda_name" {
  value = aws_lambda_function.app.function_name
}

output "log_group" {
  value = aws_cloudwatch_log_group.app.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.canh_bao.arn
}

output "email_da_dang_ky" {
  description = "Rỗng nghĩa là chưa đặt email — bạn sẽ KHÔNG nhận được cảnh báo nào."
  value       = var.email_canh_bao
}

output "alarm_loi" {
  value = aws_cloudwatch_metric_alarm.loi.alarm_name
}

output "alarm_cham" {
  value = aws_cloudwatch_metric_alarm.cham.alarm_name
}

output "composite_alarm" {
  value = aws_cloudwatch_composite_alarm.he_thong_hong.alarm_name
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.chinh.dashboard_name}"
}

output "backend_bucket" {
  description = "null nghĩa là chưa tạo hạ tầng remote state."
  value       = try(aws_s3_bucket.state[0].id, null)
}

output "backend_lock_table" {
  value = try(aws_dynamodb_table.lock[0].name, null)
}

output "backend_config_mau" {
  description = "Dán khối này vào versions.tf rồi chạy: terraform init -migrate-state"

  # Dùng join() thay heredoc: heredoc không đặt được trong biểu thức ba ngôi
  # vì dấu kết thúc EOT bắt buộc phải đứng riêng một dòng.
  value = var.tao_backend ? join("\n", [
    "  backend \"s3\" {",
    "    bucket         = \"${try(aws_s3_bucket.state[0].id, "")}\"",
    "    key            = \"${var.prefix}-observability/terraform.tfstate\"",
    "    region         = \"${var.region}\"",
    "    dynamodb_table = \"${try(aws_dynamodb_table.lock[0].name, "")}\"",
    "    encrypt        = true",
    "    profile        = \"${var.profile}\"",
    "  }",
  ]) : "Chạy: terraform apply -var tao_backend=true để tạo hạ tầng remote state trước."
}

output "chi_phi" {
  value = "~$0,00 — CloudWatch cho 10 metric tuỳ chỉnh + 10 alarm + 5 GB log miễn phí mỗi tháng. Lab dùng ít hơn thế."
}
