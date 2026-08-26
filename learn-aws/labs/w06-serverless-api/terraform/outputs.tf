output "api_url" {
  description = "URL gốc của API."
  value       = aws_apigatewayv2_api.api.api_endpoint
}

output "table_name" {
  value = aws_dynamodb_table.ghichu.name
}

output "lambda_name" {
  value = aws_lambda_function.api.function_name
}

output "lambda_log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "access_log_group" {
  value = aws_cloudwatch_log_group.access.name
}

output "thu_nhanh" {
  description = "Dán vào terminal để thử API ngay."
  value       = <<-EOT
    API=${aws_apigatewayv2_api.api.api_endpoint}

    curl -s $API/health | jq
    curl -s -X POST $API/ghichu -H 'content-type: application/json' \
      -H 'x-nguoi-dung: nam' -d '{"noi_dung":"Ghi chú đầu tiên"}' | jq
    curl -s $API/ghichu -H 'x-nguoi-dung: nam' | jq
  EOT
}

output "chi_phi" {
  value = "~$0,00 — Lambda, DynamoDB, CloudWatch đều trong hạn mức always free. Lab này NÊN giữ chạy."
}
