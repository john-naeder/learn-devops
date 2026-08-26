output "table_name" {
  value = aws_dynamodb_table.app.name
}

output "table_arn" {
  value = aws_dynamodb_table.app.arn
}

output "stream_arn" {
  description = "ARN của stream — khác ARN của bảng."
  value       = aws_dynamodb_table.app.stream_arn
}

output "gsi_name" {
  value = "GSI1"
}

output "stream_lambda_name" {
  value = aws_lambda_function.stream.function_name
}

output "stream_log_group" {
  description = "Xem Lambda phản ứng với thay đổi ở đây."
  value       = aws_cloudwatch_log_group.stream.name
}

output "rds_endpoint" {
  description = "null nghĩa là RDS đang tắt — trạng thái nên có."
  value       = try(aws_db_instance.main[0].endpoint, null)
}

output "rds_secret_arn" {
  description = "Secrets Manager giữ mật khẩu do RDS tự sinh."
  value       = try(aws_db_instance.main[0].master_user_secret[0].secret_arn, null)
}

output "chi_phi" {
  value = var.enable_rds ? format(
    "RDS ĐANG BẬT: ~$%.3f/giờ (instance $0,016 + %d GB storage). 2 tiếng ~$%.2f. QUÊN 1 THÁNG ~$%.0f. ĐẶT HẸN GIỜ NGAY.",
    0.016 + (var.db_allocated_storage * 0.115 / 730),
    var.db_allocated_storage,
    (0.016 + (var.db_allocated_storage * 0.115 / 730)) * 2,
    (0.016 + (var.db_allocated_storage * 0.115 / 730)) * 730,
  ) : "Chỉ DynamoDB + Lambda — nằm trong hạn mức always free, ~$0."
}
