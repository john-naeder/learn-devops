output "sns_topic_arn" {
  value = aws_sns_topic.su_kien.arn
}

output "queue_don_hang_url" {
  value = aws_sqs_queue.don_hang.url
}

output "queue_kho_hang_url" {
  value = aws_sqs_queue.kho_hang.url
}

output "dlq_url" {
  description = "Message thất bại 3 lần sẽ nằm ở đây."
  value       = aws_sqs_queue.don_hang_dlq.url
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.quy_trinh.arn
}

output "log_group_don_hang" {
  value = aws_cloudwatch_log_group.don_hang.name
}

output "log_group_kho_hang" {
  value = aws_cloudwatch_log_group.kho_hang.name
}

output "lich_dang_bat" {
  description = "EventBridge rule có đang chạy không. false là trạng thái nên có."
  value       = var.bat_lich
}

output "che_do_gay_loi" {
  value = var.gay_loi_don_hang ? "ĐANG BẬT — message đơn hàng sẽ rơi vào DLQ sau 3 lần thử" : "tắt — xử lý bình thường"
}

output "chi_phi" {
  value = "~$0,00 — SNS 1M publish, SQS 1M request, Step Functions 4000 transition, Lambda 1M invoke đều miễn phí mỗi tháng."
}
