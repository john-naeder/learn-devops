# Tuần 6 — Serverless, tuần build được portfolio

`Domain 2 · Resilient` `Domain 3 · Performance` `Domain 4 · Cost`

| | |
|---|---|
| **Chi phí** | **~$0,00** — nằm trọn trong hạn mức always free |
| **Dọn dẹp** | **ĐỪNG.** Đây là lab duy nhất nên **giữ chạy vĩnh viễn** |

Lab này hoàn thành nhiệm vụ credit **"deploy một Lambda function"** → nhận $20.
Tranh thủ vào Bedrock chạy một prompt để lấy nốt $20 nữa.

---

## Chạy

```bash
source ../../env.sh
cd terraform && terraform init && terraform apply    # ~90 giây
cd ../ansible && ansible-playbook site.yml           # test CRUD + đo cold start
cd .. && ./verify.sh
```

Thử tay:

```bash
cd terraform && terraform output -raw thu_nhanh
```

---

## Kiến trúc

```
Internet → HTTP API Gateway ($default stage, auto_deploy, throttle 20 rps)
              │  CORS xử lý ở đây, không phải trong code
              ▼
           Lambda python3.12, 256 MB, timeout 10s, X-Ray bật
              │  IAM: đúng 5 action trên đúng 1 bảng
              ▼
           DynamoDB PK=NGUOIDUNG#<ten>  SK=GHICHU#<id>  TTL 30 ngày
```

API đầy đủ CRUD: `GET/POST /ghichu`, `GET/PUT/DELETE /ghichu/{id}`, `GET /health`.

---

## Năm quyết định trong code đáng dừng lại

### 1. Client boto3 nằm NGOÀI handler

```python
TABLE = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])   # phạm vi module

def handler(event, context): ...
```

Lambda **giữ lại execution context** giữa các lần gọi. Dòng trên chỉ chạy một lần
mỗi **cold start**, không phải mỗi request. Đặt nó bên trong handler là lỗi hiệu năng
phổ biến nhất của Lambda — mỗi request sẽ phải dựng lại kết nối TLS tới DynamoDB.

Playbook `--tags coldstart` đo cho bạn thấy chênh lệch thật.

### 2. Memory quyết định cả CPU

Lambda **không có** nút chỉnh CPU. Bạn chỉnh memory, CPU tăng theo tỉ lệ thuận.
**1769 MB = đúng 1 vCPU.**

Hệ quả phản trực giác: **tăng memory có thể làm hàm rẻ hơn**, vì nó chạy xong nhanh
hơn nhiều so với phần giá tăng thêm. Với hàm nặng CPU, 512 MB thường rẻ hơn 128 MB.
Đây là câu hỏi tối ưu chi phí hay ra thi.

### 3. Lambda KHÔNG đặt trong VPC

Câu hỏi bẫy kinh điển: *"Lambda cần đọc DynamoDB, có cần đặt trong VPC không?"*

**Không.** DynamoDB và S3 là dịch vụ gọi qua API công khai. Đặt Lambda vào VPC chỉ
cần khi nó phải gọi tài nguyên **riêng tư** (RDS, ElastiCache). Làm thừa thì bạn nhận
thêm cold start, thêm phức tạp, và cần NAT Gateway (**~$33/tháng**) hoặc Interface
Endpoint để hàm ra được internet.

### 4. Quyền IAM tối thiểu

```hcl
Action = ["dynamodb:GetItem", "PutItem", "UpdateItem", "DeleteItem", "Query"]
Resource = [aws_dynamodb_table.ghichu.arn]
```

Chú ý những gì **không** có: không `Scan`, không `DeleteTable`, không bảng nào khác.
Gắn `AmazonDynamoDBFullAccess` cho nhanh là cách làm sai kinh điển — và đề thi
**luôn** coi least privilege là đáp án đúng.

### 5. `ConditionExpression` trong PUT

```python
ConditionExpression="attribute_exists(PK)"
```

Không có dòng này, `update_item` trên một id không tồn tại sẽ **tạo mới một item trống**
thay vì báo lỗi. Đây là hành vi hay gây bất ngờ của DynamoDB. Playbook có test đúng
trường hợp này.

---

## Throttling là hàng rào chi phí, không phải phiền toái

```hcl
throttling_rate_limit  = 20    # request/giây
throttling_burst_limit = 40
```

Không có nó, một vòng lặp lỗi trong script test (hoặc một con bot) có thể gọi hàng
triệu lần và **ăn sạch hạn mức miễn phí trong vài phút**, rồi bắt đầu tính tiền thật.

Điểm quan trọng: `429` nghĩa là API Gateway đã chặn **trước khi** gọi Lambda —
bạn không trả tiền cho request bị chặn. Chạy `--tags throttle` để tự thấy.

---

## Bẫy tiền lớn nhất của serverless: log giữ vĩnh viễn

Lambda **tự tạo** log group với retention = **vĩnh viễn** nếu bạn không khai báo.
Với 5 GB miễn phí mỗi tháng, một hàm lỗi lặp vô hạn đủ ăn hết.

Code khai báo tường minh cả hai log group:

```hcl
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${aws_lambda_function.api.function_name}"
  retention_in_days = 7
}
```

Quét toàn account bất cứ lúc nào:

```bash
../../scripts/set-log-retention.sh 7
```

---

## HTTP API vs REST API — bảng phải thuộc

| | HTTP API (v2) | REST API (v1) |
|---|---|---|
| Giá | **Rẻ hơn ~70%** | Đắt hơn |
| Độ trễ | Thấp hơn | Cao hơn |
| CORS | Cấu hình sẵn | Phải tự làm |
| JWT authorizer | **Có sẵn** | Cần Lambda authorizer |
| API key + usage plan | **Không** | Có |
| Request validation | **Không** | Có |
| Caching | **Không** | Có |
| WAF | **Không trực tiếp** | Có |
| Deploy | `auto_deploy` | Phải deploy thủ công sang stage |

**Quy tắc chọn:** mặc định HTTP API. Chỉ dùng REST API khi cần một tính năng
mà HTTP API không có.

---

## `aws_lambda_permission` — thiếu là 500 và log trống

```hcl
resource "aws_lambda_permission" "api" {
  principal  = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}
```

Đây là **resource policy** gắn vào Lambda — nhớ lại tuần 1, khác hướng với identity policy.

Thiếu nó: API trả `500`, và **log Lambda trống trơn**. Log trống là manh mối quan trọng
nhất — nó nghĩa là hàm **chưa từng được gọi**, nên vấn đề nằm ở tầng cho phép chứ không
phải trong code. Rất nhiều người mất hàng giờ đọc lại code Python trong tình huống này.

---

## Nối vào frontend tuần 4 để thành capstone

Distribution CloudFront ở [tuần 4](../w04-s3-cloudfront/) đã có sẵn cache behavior
riêng cho `/api/*` với caching **tắt**. Thêm API này làm origin thứ hai là bạn có
một ứng dụng full-stack chạy trên AWS với chi phí gần bằng không.

Viết `README.md` cho repo capstone giải thích **vì sao** mỗi lựa chọn được đưa ra,
kèm ước tính chi phí ở mức 1.000 và 1 triệu người dùng. Đó chính xác là câu người
phỏng vấn sẽ hỏi.

---

## Checklist

- [ ] `terraform apply`, API trả 200 trên `/health`
- [ ] `ansible-playbook site.yml` — cả 7 assert CRUD đều pass
- [ ] Chạy `--tags coldstart`, ghi lại chênh lệch lạnh/ấm bằng ms
- [ ] Chạy `--tags throttle`, thấy 429 xuất hiện
- [ ] `./verify.sh` — mục 3 (cách ly dữ liệu) và mục 7 (không có Scan) đều đạt
- [ ] Giải thích được vì sao client boto3 nằm ngoài handler
- [ ] Giải thích được vì sao Lambda không cần vào VPC
- [ ] Viết được bảng HTTP API vs REST API
- [ ] Đã đặt retention 7 ngày cho **mọi** log group: `../../scripts/set-log-retention.sh 7`
- [ ] Commit toàn bộ lên GitHub
- [ ] Nhận $20 nhiệm vụ "deploy Lambda" + $20 nhiệm vụ Bedrock
- [ ] **KHÔNG destroy** — giữ chạy làm capstone

---

## Nếu vẫn muốn dọn

```bash
cd terraform && terraform destroy
```

Nhưng cân nhắc: lab này tốn ~$0 và là hiện vật đáng giá nhất bạn có sau 12 tuần.
Chứng chỉ mở cửa vòng lọc CV; **thứ này** mới là cái giúp bạn qua vòng phỏng vấn.
