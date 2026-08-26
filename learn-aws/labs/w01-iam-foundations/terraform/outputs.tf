output "bucket_name" {
  description = "Bucket của lab."
  value       = aws_s3_bucket.lab.id
}

output "bucket_arn" {
  description = "ARN bucket — chú ý nó KHÔNG có /* ở cuối."
  value       = aws_s3_bucket.lab.arn
}

output "reader_user_name" {
  description = "IAM user chỉ có quyền đọc."
  value       = aws_iam_user.reader.name
}

output "reader_user_arn" {
  description = "ARN của user — dùng làm --policy-source-arn cho Policy Simulator."
  value       = aws_iam_user.reader.arn
}

output "ec2_role_arn" {
  description = "Role cho EC2."
  value       = aws_iam_role.ec2_reader.arn
}

output "instance_profile_name" {
  description = "Instance profile — thứ duy nhất gắn role vào EC2 được."
  value       = aws_iam_instance_profile.ec2_reader.name
}

output "policy_arn" {
  description = "Identity policy dùng chung cho cả user lẫn role."
  value       = aws_iam_policy.reader.arn
}

output "account_id" {
  description = "Account ID."
  value       = data.aws_caller_identity.current.account_id
}
