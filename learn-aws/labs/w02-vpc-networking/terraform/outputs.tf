output "vpc_id" {
  value = module.vpc.vpc_id
}

output "instance_id" {
  description = "Dùng cho: aws ssm start-session --target <id>"
  value       = aws_instance.private.id
}

output "instance_private_ip" {
  description = "IP riêng. Không có IP công cộng — đó là điểm của bài lab."
  value       = aws_instance.private.private_ip
}

output "bucket_name" {
  description = "Bucket để thử S3 Gateway Endpoint từ trong máy private."
  value       = aws_s3_bucket.lab.id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "flow_log_group" {
  description = "Log group chứa flow logs — tìm bản ghi REJECT ở đây."
  value       = module.vpc.flow_log_group_name
}

output "blocked_port" {
  description = "Port bị NACL chặn."
  value       = var.blocked_port
}

output "ssm_session_command" {
  description = "Lệnh vào máy. Không cần SSH key, không cần bastion."
  value       = "aws ssm start-session --target ${aws_instance.private.id} --region ${var.region} --profile ${var.profile}"
}

output "chi_phi_moi_gio" {
  description = "Ước tính chi phí khi lab đang chạy."
  value = format(
    "~$%.3f/giờ  (EC2 %s $0,0104 + %d interface endpoint x $0,01). Lab 3 tiếng ~$%.2f. ĐỂ QUÊN 1 THÁNG ~$%.0f.",
    0.0104 + (var.enable_ssm_endpoints ? 0.03 : 0),
    var.instance_type,
    var.enable_ssm_endpoints ? 3 : 0,
    (0.0104 + (var.enable_ssm_endpoints ? 0.03 : 0)) * 3,
    (0.0104 + (var.enable_ssm_endpoints ? 0.03 : 0)) * 730,
  )
}
