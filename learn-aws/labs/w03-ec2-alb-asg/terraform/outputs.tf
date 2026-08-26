output "alb_dns_name" {
  description = "Mở trong trình duyệt và refresh liên tục."
  value       = aws_lb.app.dns_name
}

output "alb_url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "asg_name" {
  value = aws_autoscaling_group.app.name
}

output "target_group_arn" {
  value = aws_lb_target_group.app.arn
}

output "transfer_bucket" {
  description = "Bucket trung chuyển cho Ansible."
  value       = aws_s3_bucket.transfer.id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "chi_phi_moi_gio" {
  description = "Đọc cái này trước khi gõ yes."
  value = format(
    "~$%.4f/giờ (ALB $0,0225 + %d x EC2 $0,0104 + %d x IPv4 $0,005). Lab 3 tiếng ~$%.2f. QUÊN 1 THÁNG ~$%.0f.",
    0.0225 + var.asg_desired * (0.0104 + (var.instances_in_public_subnet ? 0.005 : 0)),
    var.asg_desired,
    var.instances_in_public_subnet ? var.asg_desired : 0,
    (0.0225 + var.asg_desired * (0.0104 + (var.instances_in_public_subnet ? 0.005 : 0))) * 3,
    (0.0225 + var.asg_desired * (0.0104 + (var.instances_in_public_subnet ? 0.005 : 0))) * 730,
  )
}

output "lenh_xem_luan_phien" {
  description = "Chạy để thấy ALB đổi máy phục vụ."
  value       = "for i in $(seq 10); do curl -s http://${aws_lb.app.dns_name} | grep -o 'i-[0-9a-f]*' | head -1; sleep 1; done"
}
