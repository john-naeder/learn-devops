output "role_ben_thu_ba_arn" {
  description = "Role cần external ID mới assume được."
  value       = aws_iam_role.ben_thu_ba.arn
}

output "external_id" {
  description = "Bí mật để assume role bên thứ ba."
  value       = var.external_id
  sensitive   = true
}

output "role_bi_gioi_han_arn" {
  description = "Có AdministratorAccess nhưng bị permission boundary chặn."
  value       = aws_iam_role.bi_gioi_han.arn
}

output "role_admin_co_deny_arn" {
  description = "AdministratorAccess + explicit Deny vài hành động."
  value       = aws_iam_role.admin_co_deny.arn
}

output "boundary_arn" {
  value = aws_iam_policy.boundary.arn
}

output "secret_path" {
  value = aws_ssm_parameter.secret.name
}

output "lambda_doc_secret" {
  value = aws_lambda_function.doc_secret.function_name
}

output "bucket_thu_nghiem" {
  value = aws_s3_bucket.thu_nghiem.id
}

output "guardduty_id" {
  description = "null nghĩa là GuardDuty đang tắt — trạng thái nên có."
  value       = try(aws_guardduty_detector.this[0].id, null)
}

output "chi_phi" {
  value = var.enable_guardduty ? "GuardDuty ĐANG BẬT — miễn phí 30 ngày đầu, sau đó vài đô/tháng. TẮT KHI XONG." : "~$0,00 — IAM, SSM Parameter Store Standard, Lambda đều miễn phí."
}
