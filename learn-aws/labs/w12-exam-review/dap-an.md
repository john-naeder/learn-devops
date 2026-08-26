# Đáp án 10 bảng so sánh

> ⚠️ **Tự điền hết bảng trong `README.md` trước khi mở file này.**
>
> Nhận ra một bảng đúng khi nhìn thấy nó là ảo giác về năng lực. Tự dựng lại được
> từ trí nhớ mới là năng lực thật, và đó chính là thứ phòng thi đòi hỏi.

---

## 1. SQS · SNS · EventBridge · Kinesis

| | SQS | SNS | EventBridge | Kinesis Data Streams |
|---|---|---|---|---|
| Mô hình | Hàng đợi, **kéo** (poll) | Pub/sub, **đẩy** (push) | Bus sự kiện + luật định tuyến | Luồng phân mảnh, **kéo** |
| Số consumer mỗi message | **Một** — xử lý xong là xoá | Mọi subscriber đều nhận | Mọi target khớp luật | **Nhiều** consumer đọc **cùng** dữ liệu |
| Giữ dữ liệu | Tối đa 14 ngày, xoá sau khi xử lý | **Không giữ** | **Không giữ** (có archive riêng) | **1–365 ngày** |
| Tua lại được? | Không | Không | Không (trừ archive/replay) | **Có** — đọc lại từ mọi vị trí |
| Đảm bảo thứ tự | Chỉ FIFO queue | Chỉ FIFO topic | Không | **Có, trong mỗi shard** |
| Chọn khi | Xử lý nền, đệm tải, tách rời | Thông báo, fanout ra nhiều đích | Tích hợp SaaS, luật phức tạp, schedule | Phân tích thời gian thực, cần replay |

**Câu hỏi phân biệt then chốt:** cần **nhiều consumer độc lập đọc cùng một dữ liệu**
và **tua lại được** → **Kinesis**. Mỗi message chỉ cần **một** consumer xử lý rồi bỏ → **SQS**.

---

## 2. EBS · EFS · S3 · FSx · Instance store

| | EBS | EFS | S3 | FSx | Instance store |
|---|---|---|---|---|---|
| Loại | Block | File (NFS) | Object | File (SMB/Lustre) | Block |
| Gắn được mấy máy | **1** (Multi-Attach io1/io2: vài máy) | **Hàng nghìn** đồng thời | Không "gắn" — gọi qua API | Nhiều | **1** |
| Đa AZ? | **Không** — bó vào 1 AZ | **Có** | **Có** (11 số 9 độ bền) | Tuỳ loại | Không |
| Sống sau khi stop instance? | **Có** | Có | Có | Có | **KHÔNG — mất sạch** |
| Chọn khi | Ổ đĩa cho 1 máy, database | Nhiều máy dùng chung file | Lưu trữ object, tĩnh, backup | Windows SMB / HPC Lustre | Cache, scratch, IOPS cực cao tạm thời |

**Bẫy kinh điển:** instance store **mất dữ liệu khi stop instance** (không chỉ khi terminate).
Đề mô tả "dữ liệu biến mất sau khi khởi động lại máy" → instance store.

---

## 3. Multi-AZ · Read Replica · Aurora Global Database

| | Multi-AZ | Read Replica | Global Database |
|---|---|---|---|
| Mục đích | **Chịu lỗi** (HA) | **Mở rộng đọc** | **DR + đọc toàn cầu** |
| Standby/replica phục vụ đọc? | **KHÔNG** | **CÓ** | **CÓ** |
| Đồng bộ | **Synchronous** | **Asynchronous** (có độ trễ) | Asynchronous, độ trễ < 1 giây |
| Failover | **Tự động**, đổi bản ghi DNS | **Thủ công** (promote) | Promote region phụ, RTO < 1 phút |
| Cross-region? | Không (cùng region) | **Có thể** | **Bắt buộc** khác region |
| Giá | **Gấp đôi** | Cộng thêm mỗi replica | Cao nhất |

**Câu bẫy:** *"database quá tải vì quá nhiều truy vấn đọc"* → **Read Replica**.
Multi-AZ **không giảm tải một chút nào** vì standby không phục vụ đọc.

---

## 4. Security Group · Network ACL

| | Security Group | Network ACL |
|---|---|---|
| Áp dụng ở mức | **ENI** (instance) | **Subnet** |
| Stateful hay stateless | **Stateful** — cho chiều đi thì chiều về tự động được | **Stateless** — phải viết rule cả hai chiều |
| Có rule Deny? | **Không** — chỉ Allow | **Có** cả Allow và Deny |
| Thứ tự xét rule | Xét **tất cả** rule cùng lúc | Theo **số thứ tự**, khớp đầu tiên là dừng |
| Mặc định | Chặn hết inbound, mở hết outbound | Cho hết cả hai chiều |
| Nguồn rule | CIDR **hoặc security group khác** | Chỉ CIDR |

**Chi tiết hay bị quên:** SG có thể tham chiếu **một SG khác** làm nguồn — thứ NACL không làm được.
Đó là cách đúng để "chỉ cho ALB gọi vào app" (xem tuần 3).

---

## 5. ALB · NLB · Gateway Load Balancer

| | ALB | NLB | GWLB |
|---|---|---|---|
| Tầng OSI | **7** (HTTP/HTTPS) | **4** (TCP/UDP/TLS) | **3** (IP) |
| Định tuyến theo | Path, host, header, query string, method | IP + port | Toàn bộ gói tin (GENEVE) |
| IP tĩnh? | Không (dùng DNS) | **Có** — một IP tĩnh mỗi AZ | — |
| Hiệu năng | Cao | **Cực cao, độ trễ cực thấp** | — |
| Chọn khi | Web app, microservice, container | Giao thức không phải HTTP, cần IP tĩnh, độ trễ tối thiểu | Chèn thiết bị bảo mật bên thứ ba (firewall, IDS) |

---

## 6. CloudFront · Global Accelerator

| | CloudFront | Global Accelerator |
|---|---|---|
| Làm gì | **Cache nội dung** ở edge location | **Tối ưu đường mạng** qua backbone AWS |
| Giao thức | HTTP/HTTPS | **TCP/UDP bất kỳ** |
| IP tĩnh? | Không | **Có — 2 IP anycast tĩnh** |
| Giúp gì | Giảm tải origin, tăng tốc nội dung tĩnh | Giảm độ trễ và jitter, failover nhanh giữa region |
| Chọn khi | Web, API, video, nội dung tĩnh | Game, VoIP, IoT, ứng dụng cần IP tĩnh |
| Giá tham khảo | 1 TB/tháng miễn phí | **~$18/tháng** cố định + data |

**Đề hỏi:** *"cần IP tĩnh và tối ưu độ trễ cho giao thức không phải HTTP"* → **Global Accelerator**.

---

## 7. Cognito user pool · identity pool

| | User pool | Identity pool (Federated Identities) |
|---|---|---|
| Trả về cái gì | **JWT token** (ID token, access token) | **Credential AWS tạm thời** (qua STS) |
| Dùng để | **Xác thực** — ai đang đăng nhập | **Uỷ quyền** — cho phép gọi thẳng dịch vụ AWS |
| Ví dụ tình huống | Đăng nhập vào API Gateway bằng JWT authorizer | Ứng dụng di động upload thẳng lên S3 |

**Cách nhớ:** user pool = **"anh là ai"** (danh tính). identity pool = **"anh được làm gì trên AWS"**
(chìa khoá tạm thời).

Hai thứ hay dùng **cùng nhau**: đăng nhập qua user pool → đổi JWT lấy credential ở identity pool.

---

## 8. SQS Standard · SQS FIFO

| | Standard | FIFO |
|---|---|---|
| Thứ tự | **Không đảm bảo** (best-effort) | **Đảm bảo** trong mỗi message group |
| Số lần giao | **Ít nhất một lần** — có thể trùng | **Đúng một lần** (khử trùng 5 phút) |
| Throughput | Gần như **không giới hạn** | 300 msg/s (**3.000** với batch, cao hơn với high-throughput mode) |
| Tên hàng đợi | Bất kỳ | Phải kết thúc bằng **`.fifo`** |
| Tham số bắt buộc thêm | — | **`MessageGroupId`** và **`MessageDeduplicationId`** |
| Giá | Rẻ hơn | Đắt hơn |

**Hệ quả thiết kế:** Standard có thể giao trùng → consumer **phải idempotent**.
Đây là điều đề thi hay kiểm tra dưới dạng "làm sao xử lý message trùng".

---

## 9. Gateway Endpoint · Interface Endpoint · NAT Gateway

| | Gateway Endpoint | Interface Endpoint (PrivateLink) | NAT Gateway |
|---|---|---|---|
| Cơ chế | **Chèn route** vào route table | Tạo **ENI** trong subnet | Dịch địa chỉ ra internet |
| Dịch vụ hỗ trợ | **Chỉ S3 và DynamoDB** | Hầu hết dịch vụ AWS + dịch vụ bên thứ ba | Mọi thứ ra internet |
| Traffic ra internet? | **Không** — ở trong mạng AWS | **Không** | **Có** |
| Cross-region? | Không | Không | — |
| **Giá** | **MIỄN PHÍ** | **$0,01/giờ/AZ** + $0,01/GB (~$7,2/tháng mỗi AZ) | **$0,045/giờ + $0,045/GB** (~$33/tháng) |
| Chọn khi | Private subnet gọi S3/DynamoDB | Private subnet gọi dịch vụ AWS khác | Private subnet cần ra internet thật |

> Bảng này bạn đã **tự tay trải nghiệm** ở tuần 2 và tự tay trả tiền cho nó.
>
> **Đề hỏi "private subnet gọi S3 với chi phí thấp nhất" → Gateway Endpoint.**
> Không bao giờ là NAT Gateway.

---

## 10. Bốn chiến lược DR

| | Backup & Restore | Pilot Light | Warm Standby | Multi-Site Active/Active |
|---|---|---|---|---|
| **RTO** | Giờ → ngày | Chục phút | Phút | **Gần bằng 0** |
| **RPO** | Giờ | Phút | Giây | **Gần bằng 0** |
| **Chi phí** | **Thấp nhất** | Thấp | Trung bình | **Cao nhất** |
| Ở region phụ có gì | Chỉ backup, không hạ tầng | Dữ liệu đã sao chép + hạ tầng lõi **tắt** | Bản sao **thu nhỏ đang chạy** | Bản sao **đầy đủ, phục vụ traffic thật** |
| Khi sự cố phải làm gì | Dựng lại từ IaC + khôi phục dữ liệu | Promote replica, **bật** compute, đổi DNS | **Scale up**, đổi DNS | Health check tự loại region hỏng |

**RTO** = Recovery **Time** Objective — bao lâu thì chạy lại được (**T**hời gian ngừng).
**RPO** = Recovery **Point** Objective — mất bao nhiêu dữ liệu (**P**hần dữ liệu mất).

---

## Bảng bổ sung — những chỗ repo này đã cho bạn trải nghiệm trực tiếp

Đây không nằm trong 10 bảng chuẩn, nhưng đều là thứ bạn đã tự tay chạm và đều ra thi.

### Lambda trong VPC — khi nào cần

| Lambda cần gọi | Trong VPC? |
|---|---|
| DynamoDB, S3, SQS, SNS (API công khai) | **KHÔNG** |
| RDS, ElastiCache, endpoint riêng tư | **CÓ** |

Đặt Lambda vào VPC khi không cần = thêm cold start, thêm phức tạp, và cần NAT Gateway
(~$33/tháng) hoặc Interface Endpoint để hàm ra được internet. *(tuần 6)*

### `treat_missing_data` của CloudWatch Alarm

| Giá trị | Dùng cho |
|---|---|
| `notBreaching` | **Metric lỗi** (Lambda không gửi Errors=0 khi không lỗi) |
| `breaching` | **Metric heartbeat** ("hệ thống còn sống") |
| `missing` (mặc định) | Hiếm khi đúng |
| `ignore` | Metric rời rạc |

Để `missing` trên metric lỗi → alarm **kẹt ở ALARM vĩnh viễn**. *(tuần 10)*

### Ba giá trị của Policy Simulator

| | Nghĩa | Dừng ở bước nào |
|---|---|---|
| `allowed` | Có Allow, không Deny | 4 |
| `implicitDeny` | **Không ai cho phép** | rơi xuống đáy |
| `explicitDeny` | **Có người cấm** | 1 — không gì cứu được |

*(tuần 9)*

### Parameter Store vs Secrets Manager

| | Parameter Store (Standard) | Secrets Manager |
|---|---|---|
| Giá | **Miễn phí** | $0,40/secret/tháng |
| **Tự động xoay vòng** | **Không** | **Có** |

Khác biệt quyết định là **tự động xoay vòng**. *(tuần 9)*

### Alias vs CNAME

| | Alias | CNAME |
|---|---|---|
| Zone apex (`example.com`) | **Được** | **Không** |
| Giá | **Miễn phí** | Tính theo truy vấn |

*(tuần 8)*

### HTTP API vs REST API

| | HTTP API | REST API |
|---|---|---|
| Giá | **Rẻ hơn ~70%** | Đắt hơn |
| API key, usage plan, caching, request validation | **Không có** | Có |

Mặc định chọn HTTP API; chỉ dùng REST khi cần một tính năng nó không có. *(tuần 6)*

### Query vs Scan trong DynamoDB

`FilterExpression` **KHÔNG** làm giảm lượng đọc. DynamoDB đọc toàn bộ, tính tiền toàn bộ,
rồi mới lọc trước khi trả về. *(tuần 5 — bạn đã đo thấy chênh lệch hàng trăm lần)*

### SQS visibility timeout vs Lambda timeout

**Visibility timeout phải LỚN HƠN Lambda timeout.** Ngược lại là công thức chắc chắn
để có xử lý trùng lặp. *(tuần 7)*
