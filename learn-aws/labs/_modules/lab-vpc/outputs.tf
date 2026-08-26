output "vpc_id" {
  description = "ID của VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR của VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Danh sách ID public subnet, theo thứ tự AZ."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Danh sách ID private subnet, theo thứ tự AZ."
  value       = aws_subnet.private[*].id
}

output "azs" {
  description = "Các AZ đang dùng."
  value       = local.azs
}

output "public_route_table_id" {
  description = "Route table của public subnet."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Route table của private subnet, mỗi AZ một cái."
  value       = aws_route_table.private[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "s3_endpoint_id" {
  description = "S3 Gateway Endpoint, null nếu không bật."
  value       = try(aws_vpc_endpoint.s3[0].id, null)
}

output "flow_log_group_name" {
  description = "Log group của flow logs, null nếu không bật."
  value       = try(aws_cloudwatch_log_group.flow[0].name, null)
}

output "nat_gateway_ids" {
  description = "NAT Gateway đang chạy. Rỗng là tốt — mỗi cái ~$33/tháng."
  value       = aws_nat_gateway.this[*].id
}
