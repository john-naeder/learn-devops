# Học AWS từ số 0 đến SAA-C03 trong 12 tuần, gần như không tốn tiền

> Bản markdown của `aws-saa-plan.html`. Trang HTML có thanh tiến độ lưu trong trình duyệt;
> bản này để đọc trong terminal, grep, và commit lên git.
> Mỗi tuần đều có link tới thư mục lab tương ứng trong [`labs/`](labs/README.md).

**Bối cảnh:** Account tạo ngày 10/08/2026 → rơi vào mô hình Free Tier mới của AWS.
Không còn "750 giờ EC2 miễn phí 12 tháng". Bạn có một túi credit và một cái đồng hồ đếm ngược.

| | |
|---|---|
| Ngày mở account | 10/08/2026 (sau mốc 15/07/2025) |
| Free plan kết thúc | **10/02/2027** |
| Ngân sách | $100–200 credit, không phải giờ miễn phí |
| Chi tiêu mục tiêu | **< $15** cho toàn bộ 12 tuần lab |
| Region | `us-east-1`, một region duy nhất |

---

## Mục lục

- [1. Free tier của bạn thực sự có gì](#1-free-tier-của-bạn-thực-sự-có-gì)
- [2. Bảng bẫy tiền](#2-bảng-bẫy-tiền)
- [3. Ngày 0 — khóa ví lại](#3-ngày-0--khóa-ví-lại)
- [4. Lộ trình 12 tuần](#4-lộ-trình-12-tuần)
- [5. Capstone](#5-capstone--thứ-bạn-còn-lại-sau-12-tuần)
- [6. Kỳ thi SAA-C03](#6-kỳ-thi-saa-c03)
- [7. Tài nguyên](#7-tài-nguyên)
- [8. Tám quy tắc giữ hóa đơn bằng không](#8-tám-quy-tắc-giữ-hóa-đơn-bằng-không)

---

## 1. Free tier của bạn thực sự có gì

Ngày 15/07/2025 AWS thay toàn bộ cơ chế Free Tier. Mọi bài blog hay khoá học nói
"bạn được 750 giờ t2.micro mỗi tháng trong 12 tháng" đều viết cho account mở **trước** mốc đó.
Account của bạn thì không.

### Bạn nhận được gì

- **$100 credit** ngay khi mở account.
- **+$100** nữa nếu hoàn thành 5 nhiệm vụ onboarding, mỗi nhiệm vụ $20.
- Quyền dùng **hơn 30 dịch vụ "always free"** — vĩnh viễn, không hết hạn.

### Bạn mất gì so với ngày xưa

- Không còn gói 12 tháng miễn phí cho EC2, RDS, S3.
- Mọi giờ EC2, mọi GB S3 giờ **trừ thẳng vào credit**.
- Free plan không dùng được Savings Plans, Reserved Instances, một phần Marketplace.

### ⚠️ Điều quan trọng nhất trong cả tài liệu này

Nếu bạn chọn **Free account plan** lúc đăng ký: hết 6 tháng hoặc hết credit — cái nào tới trước —
**AWS tự động đóng account của bạn** và bạn mất quyền truy cập vào toàn bộ tài nguyên lẫn dữ liệu.
AWS giữ nội dung 90 ngày để bạn kịp nâng cấp lên Paid plan, sau đó xóa vĩnh viễn.

**Hệ quả thực tế:** đừng để dự án nào bạn quan tâm sống duy nhất trên account này.
Code đẩy lên GitHub, hạ tầng viết bằng Terraform/CloudFormation để dựng lại được ở bất cứ đâu.
Vào Billing console kiểm tra xem bạn đang ở Free plan hay Paid plan — nếu là Paid plan thì
account không bị đóng, nhưng vượt credit là bị tính tiền thật.

*Đây chính là lý do tồn tại của thư mục `labs/`: toàn bộ hạ tầng nằm dưới dạng mã,
account chết thì `terraform apply` ở account mới là xong.*

### Cách lấy nốt $100 còn lại

Năm nhiệm vụ, mỗi cái $20. Làm hết trong tuần 1–5, vì chúng trùng khớp với những gì bạn
phải học dù sao đi nữa. Danh sách chính xác nằm ở **Billing and Cost Management → Free Tier**
trong console — hãy đối chiếu, đừng tin mù bảng dưới.

- [ ] Launch rồi terminate một EC2 instance — làm ở [tuần 3](labs/w03-ec2-alb-asg/)
- [ ] Cấu hình một RDS database — làm ở [tuần 5](labs/w05-databases/), **xóa ngay trong 2 tiếng**
- [ ] Deploy một Lambda function — làm ở [tuần 6](labs/w06-serverless-api/)
- [ ] Test một prompt trong Amazon Bedrock — 5 phút, không cần học sâu
- [ ] Tạo một budget trong AWS Budgets — làm ngay hôm nay, ở Ngày 0

### Những thứ luôn miễn phí — sân chơi chính của bạn

Đây là lý do lộ trình này dồn trọng tâm vào serverless: bạn có thể build và chạy 24/7
một ứng dụng thật mà gần như không tốn đồng credit nào.

| Dịch vụ | Hạn mức miễn phí hàng tháng | Dùng để học gì |
|---|---|---|
| Lambda | 1M request + 400.000 GB-giây | Compute, event-driven, cold start |
| DynamoDB | 25 GB + 25 WCU/25 RCU | NoSQL, partition key, GSI, Streams |
| CloudFront | 1 TB out + 10M request | CDN, cache, OAC, edge |
| CloudWatch | 10 metric + 10 alarm + 5 GB log | Monitoring, alarm, Logs Insights |
| SNS / SQS | 1M publish / 1M request | Decoupling, fanout, DLQ |
| Step Functions | 4.000 state transition | Orchestration, retry, catch |
| Cognito | ~10.000 người dùng hoạt động | Authentication, user pool |
| Data transfer out | 100 GB / tháng | Đủ thoải mái cho mọi lab |
| IAM, VPC, Security Group | Miễn phí hoàn toàn | Nền tảng — học nhiều nhất ở đây |
| CloudFormation, Auto Scaling | Miễn phí (chỉ trả cho tài nguyên tạo ra) | IaC, elasticity |
| CloudTrail | 1 trail management event | Audit, governance |
| SSM Parameter Store | Standard parameter miễn phí | Thay thế Secrets Manager khi học |

### Chọn region — quyết định một lần, không đổi

Dùng **us-east-1 (N. Virginia)** cho toàn bộ lộ trình. Rẻ nhất, có đủ mọi dịch vụ,
mọi tutorial đều viết cho nó. Latency cao hơn từ Việt Nam nhưng khi học thì điều đó
không quan trọng. `ap-southeast-1` (Singapore) gần hơn nhưng đắt hơn khoảng 10–25%.

Ngoại lệ duy nhất: tuần 4 và tuần 11 khi làm cross-region replication — lúc đó mới bật
region thứ hai, và xóa sạch ngay sau đó. **Tài nguyên bị bỏ quên ở một region bạn không
bao giờ mở lại chính là cách phổ biến nhất để đốt sạch credit.**

---

## 2. Bảng bẫy tiền

Học thuộc bảng này trước khi bấm nút Create bất cứ thứ gì. Giá tham khảo tại `us-east-1`,
quy đổi ra một tháng chạy liên tục — hãy kiểm tra lại trên trang pricing chính thức.

| Tài nguyên | Giá xấp xỉ | Nếu chạy 1 tháng | Phán quyết |
|---|---|---|---|
| EC2 t3.micro | $0,0104 / giờ | ~$7,5 | ◐ Lab 3 tiếng = $0,03 |
| EBS gp3 8 GB | $0,08 / GB-tháng | ~$0,64 | ◐ Volume mồ côi vẫn tính tiền |
| Public IPv4 / Elastic IP | $0,005 / giờ / IP | ~$3,6 | ◐ Tính cả khi không dùng |
| Application Load Balancer | $0,0225 / giờ + LCU | ~$17 | ◐ Chỉ bật trong buổi lab |
| RDS db.t4g.micro | $0,016 / giờ + storage | ~$14 | ◐ Bật 2 tiếng rồi xóa |
| Route 53 hosted zone | $0,50 / zone / tháng | ~$0,5 | ◐ Chấp nhận được |
| KMS customer managed key | $1 / key / tháng | ~$1 | ◐ Dùng AWS managed key thay thế |
| Secrets Manager | $0,40 / secret / tháng | ~$0,4 | ◐ Dùng Parameter Store |
| **VPC Interface Endpoint** | $0,01 / giờ / AZ | ~$7,2 | ● Gateway Endpoint thì miễn phí |
| **NAT Gateway** | $0,045 / giờ + $0,045 / GB | ~$33 | ● **Kẻ giết credit số 1** |
| **Site-to-Site VPN** | $0,05 / giờ | ~$36 | ● Chỉ học lý thuyết |
| **Transit Gateway** | $0,05 / giờ / attachment | ~$36+ | ● Chỉ học lý thuyết |
| **Global Accelerator** | $0,025 / giờ | ~$18 | ● Chỉ học lý thuyết |
| **EKS control plane** | $0,10 / giờ | ~$73 | ● Ngoài phạm vi SAA |
| **Redshift / OpenSearch / EMR** | từ $0,25 / giờ | ~$180+ | ● Tuyệt đối không bật |
| **Direct Connect** | Cần cổng vật lý | — | ● Không lab được |

### Bài học kiến trúc ẩn trong bảng này

NAT Gateway đắt gấp bốn lần cái EC2 mà nó phục vụ. Đó không phải chuyện vặt của sinh viên
nghèo — đó chính là **Domain 4 của đề thi SAA**. Khi đề hỏi "làm sao để private subnet gọi S3
mà giảm chi phí", đáp án là **S3 Gateway Endpoint** (miễn phí), không phải NAT Gateway.
Bạn sẽ nhớ điều này mãi mãi vì đã tự tay tránh nó.

> Trong `labs/`, mọi NAT Gateway đều nằm sau biến `enable_nat = false`. Muốn bật phải
> sửa tay và đọc dòng comment ghi giá. Đó là cố ý.

---

## 3. Ngày 0 — khóa ví lại

Khoảng 2 tiếng. Làm hết **trước khi tạo tài nguyên đầu tiên**. Đây không phải thủ tục
hành chính — đây là nội dung thi thật, phần Security chiếm 30% đề.

- [ ] **Bật MFA cho root account** (Google Authenticator trên điện thoại). Xong thì cất root đi, không dùng nữa.
- [ ] **Tạo một admin user riêng** qua IAM Identity Center (khuyến nghị) hoặc IAM user với policy `AdministratorAccess`. Bật MFA cho nó luôn.
- [ ] **Tạo 3 budget:** zero-spend budget, budget $5/tháng, budget $20/tháng. Gắn email cảnh báo ở ngưỡng 50% / 80% / 100%. *Đây cũng là 1 trong 5 nhiệm vụ ăn $20.*
- [ ] **Bật Cost Anomaly Detection** — miễn phí, gửi mail khi chi tiêu bất thường.
- [ ] **Bật Free Tier usage alerts** trong Billing preferences.
- [ ] **Cài AWS CLI v2** và cấu hình profile → chạy `scripts/setup-tools.sh` (cài luôn Terraform + Ansible).
- [ ] **Bật CloudTrail** — một trail management event là miễn phí. Vào xem event log để hiểu console thực chất chỉ là API call.
- [ ] **Kiểm tra bạn đang ở Free plan hay Paid plan** tại Billing console → Free Tier, ghi lại số dư credit hiện tại.
- [ ] **Tạo repo GitHub** cho toàn bộ lab. Mọi template và script đều commit vào đó — vì account AWS này có ngày hết hạn, repo thì không.

### Cài công cụ trên WSL / Ubuntu

```bash
# Cài một phát cả Terraform, Ansible, AWS CLI v2 (không cần sudo)
./scripts/setup-tools.sh

# Cấu hình profile (dùng access key của IAM user vừa tạo, KHÔNG dùng root)
aws configure --profile learn
# region: us-east-1   output: json

# Kiểm tra
aws sts get-caller-identity --profile learn
```

### Ba lệnh bạn sẽ chạy mỗi ngày

Đã gói sẵn thành script:

```bash
./scripts/cost-check.sh      # chi tiêu 7 ngày gần nhất, tách theo service
./scripts/find-orphans.sh    # EC2 đang chạy, EBS mồ côi, EIP, ALB, RDS bị quên
```

Bản lệnh thô, nếu bạn muốn hiểu script làm gì:

```bash
# Hôm nay tiêu bao nhiêu?
aws ce get-cost-and-usage --profile learn \
  --time-period Start=$(date -d '7 days ago' +%F),End=$(date +%F) \
  --granularity DAILY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Còn EC2 nào đang chạy không?
aws ec2 describe-instances --profile learn --region us-east-1 \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[InstanceId,InstanceType,LaunchTime]" --output table

# Còn EBS volume mồ côi nào không?
aws ec2 describe-volumes --profile learn --region us-east-1 \
  --filters "Name=status,Values=available" \
  --query "Volumes[].[VolumeId,Size,CreateTime]" --output table
```

---

## 4. Lộ trình 12 tuần

Nhịp đề xuất: **5 buổi × 2 giờ mỗi tuần**. Bắt đầu 17/08/2026, kết thúc phần học khoảng
08/11/2026, thi trong tháng 11 — vẫn còn ba tháng free plan để làm dự án DR hybrid sau đó.
Mỗi tuần chia đôi: khoảng 60% đọc và xem, 40% gõ tay vào console và CLI.

### Nghi thức bắt buộc cuối mỗi buổi lab

Chưa dọn dẹp thì buổi học chưa kết thúc. Thứ tự xóa luôn ngược với thứ tự tạo:
Auto Scaling Group → Load Balancer → Target Group → Instance → EBS volume → Snapshot → Elastic IP.

Với `labs/`, nghi thức đó gọn lại thành một dòng:

```bash
cd labs/w03-ec2-alb-asg/terraform && terraform destroy -auto-approve
```

---

### Tuần 1 — Nền móng và quyền hạn

`Domain 1 · Security` `Domain 4 · Cost` · **Miễn phí 100%** · [→ lab](labs/w01-iam-foundations/)

**Học:** Mô hình cloud và shared responsibility model. Region, Availability Zone, Edge location,
Local Zone — và tại sao AZ là đơn vị của tính sẵn sàng. IAM cho thật kỹ: user, group, role, policy;
phân biệt identity policy với resource policy; trust policy là gì; vì sao role tốt hơn access key.
IAM Identity Center. Các mô hình giá: On-Demand, Spot, Reserved Instance, Savings Plan,
Dedicated Host — chỉ cần hiểu khi nào chọn cái nào.

**Lab:**
- Viết tay một IAM policy JSON chỉ cho phép `s3:GetObject` trên đúng một bucket, gắn vào user test, rồi kiểm chứng bằng **IAM Policy Simulator**.
- Tạo một IAM role cho EC2, hiểu instance profile là gì.
- Bật **IAM Access Analyzer** (miễn phí) và đọc kết quả.
- Vào Cost Explorer, tự tay dựng một report lọc theo service.

**Kiểm tra:**
- [ ] Hoàn thành lab IAM + Policy Simulator
- [ ] Giải thích được bằng lời: khác nhau giữa role và user, giữa identity policy và resource policy

---

### Tuần 2 — VPC, xương sống của mọi câu hỏi

`Domain 1 + 2` · **~$0,10** · [→ lab](labs/w02-vpc-networking/)

**Học:** CIDR và cách chia subnet. Public subnet khác private subnet ở chỗ nào (gợi ý: chỉ ở
route table). Internet Gateway, route table, NAT Gateway và NAT instance.
**Security Group so với Network ACL** — stateful với stateless, đây là câu hỏi kinh điển.
VPC Peering và vì sao nó không transitive. VPC Endpoint: Gateway (S3, DynamoDB — miễn phí)
so với Interface/PrivateLink (mất tiền). VPC Flow Logs. DNS trong VPC.

**Lab:**
- Dựng tay một VPC `10.0.0.0/16` trải 2 AZ, mỗi AZ một public và một private subnet. **Không dùng wizard.**
- Launch một `t3.micro` ở private subnet và kết nối vào bằng **SSM Session Manager** — không bastion, không public IP, không SSH key. Đúng cách và cũng là rẻ nhất.
- Tạo **S3 Gateway Endpoint** để instance private đọc được S3 mà không cần NAT Gateway. Tự tay chứng minh nó hoạt động.
- Bật Flow Logs vào CloudWatch, chặn một port bằng NACL, rồi tìm gói tin bị REJECT trong log.

**Dọn dẹp:**
- [ ] Terminate EC2 instance
- [ ] Xóa Flow Logs và log group
- [ ] Giữ lại VPC — VPC không mất phí, tuần sau còn dùng

---

### Tuần 3 — EC2, EBS, Load Balancer, Auto Scaling

`Domain 2 + 3` · **~$1** · [→ lab](labs/w03-ec2-alb-asg/)

**Học:** Họ instance và cách đọc tên. User data, metadata, IMDSv2. AMI và snapshot.
Các loại EBS: gp3, io2, st1, sc1 — và instance store khác gì. **EBS so với EFS so với S3**:
một câu hỏi thi rất hay gặp. Load balancer: ALB (layer 7), NLB (layer 4), Gateway LB —
target group, health check, sticky session. Auto Scaling Group: launch template,
scaling policy (target tracking, step, scheduled), lifecycle hook, cooldown. Placement group.

**Lab — buổi tốn tiền nhất cả khóa, làm gọn trong 3 tiếng:**
- Launch template với user data tự cài nginx và in ra instance ID.
- ASG min 1 / desired 2 / max 3 trải 2 AZ, đặt sau một ALB.
- Refresh trang liên tục để thấy request đi luân phiên giữa các instance.
- Tắt nginx trên một máy, xem health check fail và ASG tự thay thế. *Đây là khoảnh khắc "à hóa ra self-healing là thế".*
- Tạo snapshot một EBS volume, xóa volume, rồi restore lại từ snapshot.
- Xong nhiệm vụ credit "launch và terminate EC2" — nhận $20.

**Dọn dẹp — theo đúng thứ tự:**
- [ ] Xóa Auto Scaling Group (đặt desired = 0 trước)
- [ ] Xóa Load Balancer, rồi xóa Target Group
- [ ] Terminate mọi instance còn lại
- [ ] Xóa EBS volume ở trạng thái `available`
- [ ] Xóa snapshot và AMI tự tạo
- [ ] Release toàn bộ Elastic IP
- [ ] Sáng hôm sau mở Cost Explorer kiểm tra lại

---

### Tuần 4 — S3 và các loại lưu trữ

`Domain 1 + 3 + 4` · **~$0,05** · [→ lab](labs/w04-s3-cloudfront/)

**Học:** Storage class và bài toán chọn lớp: Standard, Intelligent-Tiering, Standard-IA,
One Zone-IA, Glacier Instant Retrieval, Glacier Flexible Retrieval, Glacier Deep Archive —
nhớ đặc điểm truy xuất và ngưỡng lưu tối thiểu. Lifecycle policy. Versioning và MFA delete.
Replication CRR/SRR. Mã hóa: SSE-S3, SSE-KMS, SSE-C, client-side. Bucket policy so với ACL
so với Block Public Access. Presigned URL. Static website hosting. Transfer Acceleration.
Và EFS, FSx — biết use case là đủ.

**Lab:**
- Host một trang tĩnh trên S3, đặt CloudFront phía trước với **Origin Access Control**, khóa bucket khỏi truy cập public trực tiếp.
- Bật versioning, upload đè file vài lần, khôi phục phiên bản cũ, hiểu delete marker.
- Viết lifecycle rule chuyển object sang Glacier sau 30 ngày và xóa version cũ sau 7 ngày.
- Tạo presigned URL bằng CLI, gửi cho bạn bè, xem nó hết hạn.
- Viết bucket policy chỉ cho phép truy cập từ đúng một địa chỉ IP.
- Bật cross-region replication sang một region khác, kiểm chứng, rồi tắt ngay.

**Dọn dẹp:**
- [ ] Xóa **tất cả object version** — bật versioning nghĩa là xóa file thường không làm bucket trống
- [ ] Xóa bucket ở region thứ hai (bẫy quên kinh điển)
- [ ] Giữ CloudFront + bucket chính lại — sẽ dùng cho capstone

---

### Tuần 5 — Cơ sở dữ liệu

`Domain 2 + 3` · **~$0,10** · [→ lab](labs/w05-databases/)

**Học:** RDS: các engine, backup tự động, snapshot, point-in-time recovery, RDS Proxy.
**Multi-AZ so với Read Replica** — câu hỏi ra thi gần như chắc chắn: Multi-AZ là để chịu lỗi
(standby không phục vụ đọc), Read Replica là để mở rộng đọc. Aurora: tầng lưu trữ chia 6 bản
qua 3 AZ, replica, Global Database, Serverless v2. DynamoDB: partition key và sort key,
LSI so với GSI, on-demand so với provisioned, DAX, Streams, TTL, Global Tables.
ElastiCache: Redis so với Memcached. Redshift, Neptune, DocumentDB, Timestream —
chỉ cần nhận ra use case.

**Lab:**
- **DynamoDB** (miễn phí, chơi thoải mái): tạo bảng, thiết kế partition key, thêm GSI, so sánh Query với Scan trên vài nghìn item, bật TTL, bật Streams và nối vào một Lambda.
- **RDS** (đặt hẹn giờ 2 tiếng): tạo `db.t4g.micro` Single-AZ, kết nối từ EC2, tạo snapshot, restore từ snapshot, rồi **xóa và bỏ chọn "create final snapshot"**. Xong nhiệm vụ credit — nhận $20.

**⚠️ Cấm trong tuần này:** Không bật Multi-AZ (nhân đôi giá). Không bật Aurora (đắt hơn nhiều
và không có instance nhỏ rẻ). Không bật ElastiCache cluster. Ba thứ này học bằng tài liệu và
sơ đồ — kiến thức thi được không đòi hỏi bạn phải chạy chúng.

**Kiểm tra:**
- [ ] Đã xóa RDS instance và toàn bộ snapshot của nó
- [ ] Viết được bảng so sánh Multi-AZ với Read Replica bằng lời của mình

---

### Tuần 6 — Serverless, tuần build được portfolio

`Domain 2 + 3 + 4` · **Miễn phí** · [→ lab](labs/w06-serverless-api/)

**Học:** Lambda: runtime, quan hệ giữa memory và CPU, timeout tối đa 15 phút, cold start và
cách giảm, layer, biến môi trường, Lambda trong VPC (và cái giá của nó), reserved so với
provisioned concurrency, event source mapping. API Gateway: REST so với HTTP so với WebSocket API,
stage, authorizer, throttling, CORS. S3 event notification. Mẫu kiến trúc kinh điển
API Gateway → Lambda → DynamoDB.

**Lab — cái này giữ lại chạy vĩnh viễn:**
- Xây một REST API thật: **HTTP API Gateway → Lambda (Python) → DynamoDB**. Gợi ý: rút gọn URL, hoặc API ghi chú có CRUD đầy đủ.
- Deploy bằng IaC, không click chuột. Commit lên GitHub.
- Nối frontend tĩnh ở S3 + CloudFront từ tuần 4 vào API này. Bạn vừa có một ứng dụng full-stack chạy trên AWS với chi phí gần bằng không — bỏ vào CV được.
- Xong nhiệm vụ credit "deploy Lambda" — nhận $20. Tranh thủ vào Bedrock chạy một prompt để lấy nốt $20 nữa.

**⚠️ Đặt retention cho log ngay:** CloudWatch log group mặc định **giữ log vĩnh viễn**.
Với 5 GB miễn phí mỗi tháng thì một Lambda bị lỗi lặp vô hạn cũng đủ ăn hết.

```bash
./scripts/set-log-retention.sh 7     # ép 7 ngày cho MỌI log group
```

**Kiểm tra:**
- [ ] API chạy được end-to-end
- [ ] Template IaC đã commit lên GitHub
- [ ] Đã đặt retention 7 ngày cho mọi log group

---

### Tuần 7 — Tách rời hệ thống và tích hợp

`Domain 2 · Resilient` · **Miễn phí** · [→ lab](labs/w07-decoupling/)

**Học:** SQS: standard so với FIFO, visibility timeout, dead-letter queue, long polling, delay queue.
SNS: fanout, filter policy, các loại subscriber. Mẫu SNS → nhiều SQS. EventBridge: rule, schedule,
custom bus, đối chiếu với CloudWatch Events. Step Functions: Standard so với Express, retry, catch,
map, parallel. **Kinesis Data Streams so với Data Firehose so với SQS** — đề thi rất thích so sánh
bộ ba này. Amazon MQ dành cho khi nào.

**Lab:**
- Fanout: một SNS topic đẩy vào hai SQS queue, mỗi queue một Lambda consumer khác nhau.
- Cố tình làm Lambda lỗi, xem message rơi vào dead-letter queue sau số lần thử đã cấu hình.
- Nghịch visibility timeout để tự thấy hiện tượng xử lý trùng lặp.
- EventBridge rule chạy theo lịch, kích hoạt Lambda mỗi 5 phút.
- Step Functions ba bước có retry và catch — dùng giao diện kéo thả rồi đọc lại ASL JSON sinh ra.

**Kiểm tra:**
- [ ] Đã **tắt EventBridge schedule** — để chạy mãi sẽ sinh log vô ích
- [ ] Nói được khi nào chọn SQS, khi nào chọn Kinesis

---

### Tuần 8 — DNS, CDN và tầng biên

`Domain 3 · Performance` · **~$0,50** · [→ lab](labs/w08-dns-cdn-edge/)

**Học:** Route 53: các loại record, alias khác CNAME ra sao và tại sao alias miễn phí.
Bảy routing policy — simple, weighted, latency, failover, geolocation, geoproximity, multivalue —
cùng health check. CloudFront: origin, OAC, cache behavior, TTL, invalidation, signed URL và
signed cookie, CloudFront Functions so với Lambda@Edge. **CloudFront so với Global Accelerator**:
cái đầu cache nội dung tĩnh, cái sau tối ưu đường mạng cho TCP/UDP. ACM cấp chứng chỉ miễn phí.
WAF và Shield ở mức nhận biết.

**Lab:**
- Trên distribution CloudFront đã có: thêm cache behavior riêng cho `/api/*`, chạy invalidation, quan sát header `X-Cache` đổi giữa Hit và Miss.
- Viết một CloudFront Function chèn security header.
- **Nếu chấp nhận chi $0,50:** tạo một hosted zone, thử weighted và failover routing với health check, rồi xóa zone sau hai ngày. Nếu muốn tiết kiệm tuyệt đối thì học phần này qua tài liệu — routing policy là kiến thức nhớ, không cần tay chạm.

**Kiểm tra:**
- [ ] Thuộc bảng 7 routing policy và khi nào dùng cái nào
- [ ] Đã xóa hosted zone nếu có tạo

---

### Tuần 9 — Bảo mật chuyên sâu, miền nặng nhất của đề

`Domain 1 · 30% đề thi` · **Miễn phí** · [→ lab](labs/w09-security-deep/)

**Học:** Logic đánh giá quyền của IAM cho thật chắc: explicit deny thắng tất cả, rồi tới SCP,
rồi resource policy và identity policy hợp lại. Permission boundary. Service Control Policy trong
Organizations. Cross-account role kèm external ID. STS và `AssumeRole`. Cognito user pool so với
identity pool. KMS: customer managed key so với AWS managed key, key policy, envelope encryption,
rotation. Secrets Manager so với SSM Parameter Store — khác biệt chính là tự động xoay vòng và giá.
WAF rule, Shield Standard so với Advanced. GuardDuty, Inspector, Macie, Security Hub, Detective —
nhận diện đúng công cụ cho đúng bài toán là đủ.

**Lab:**
- Tạo hai IAM role trong cùng account và mô phỏng luồng cross-account `AssumeRole`, đọc kỹ trust policy.
- Gắn permission boundary cho một role rồi tự chứng minh nó chặn được cả quyền admin.
- Lưu một secret bằng SSM Parameter Store kiểu SecureString (miễn phí) và đọc từ Lambda — đúng cách làm thật, mà lại không mất $0,40/tháng.
- Bật GuardDuty, xem finding mẫu trong một ngày, rồi **tắt đi**.

**Kiểm tra:**
- [ ] Vẽ được sơ đồ thứ tự đánh giá quyền IAM
- [ ] Đã tắt GuardDuty

---

### Tuần 10 — Giám sát, vận hành và hạ tầng dạng mã

`Domain 2 + 4` · **Miễn phí** · [→ lab](labs/w10-observability-iac/)

**Học:** CloudWatch: metric, namespace, dimension, custom metric, alarm và composite alarm,
dashboard, Logs Insights, CloudWatch Agent, Embedded Metric Format. CloudTrail: management event
so với data event, organization trail. X-Ray cho tracing. AWS Config cho compliance (và cảnh giác
giá). Systems Manager: Session Manager, Patch Manager, Parameter Store, Run Command.
Trusted Advisor và Health Dashboard. CloudFormation: cấu trúc template, stack, change set,
drift detection, nested stack, StackSet. Biết CDK, SAM, Elastic Beanstalk tồn tại và dùng khi nào.

**Lab — kỹ năng đi làm quan trọng nhất trong cả khóa:**
- Đặt alarm trên metric `Errors` của Lambda, đẩy thông báo qua SNS về email của bạn. Cố tình gây lỗi để nhận được mail thật.
- Viết một query Logs Insights tìm request chậm nhất.
- Dựng một dashboard gom số liệu Lambda, DynamoDB và API Gateway.
- **Viết lại toàn bộ hạ tầng của tuần 6 bằng IaC.** Deploy, sửa, xem trước thay đổi bằng `terraform plan`, rồi `terraform destroy` xóa sạch trong một lệnh. Đây chính là nút "dọn dẹp" hoàn hảo mà bạn đã ao ước suốt 9 tuần qua.
- Chuyển state lên S3 backend + DynamoDB lock — bài học remote state.

**Kiểm tra:**
- [ ] Nhận được email cảnh báo thật từ CloudWatch Alarm
- [ ] Hạ tầng deploy và destroy thành công bằng một lệnh

---

### Tuần 11 — Di trú, hybrid và khôi phục thảm họa

`Domain 2 · Resilient` · **Gần như miễn phí** · [→ lab](labs/w11-dr-hybrid/)

**Học:** Bảy chiến lược di trú (7R). Migration Hub, Application Discovery Service, AWS MGN,
DMS kèm SCT. Storage Gateway ba kiểu: File, Volume, Tape. DataSync và Transfer Family.
Snowball, Snowmobile — chọn theo dung lượng và thời gian. **Direct Connect so với Site-to-Site VPN**,
và mẫu DX có VPN dự phòng. Transit Gateway, PrivateLink. Outposts, Local Zones, Wavelength.
Và trọng tâm: **bốn chiến lược DR** — Backup & Restore, Pilot Light, Warm Standby,
Multi-Site Active/Active — cùng RTO và RPO tương ứng. AWS Backup. Route 53 failover với health check.

**Lab:**
- Tạo một AWS Backup plan cho EBS snapshot theo lịch.
- Bật S3 cross-region replication như một bài Backup & Restore thu nhỏ.
- Vẽ kiến trúc cho cả bốn cấp DR, ghi rõ RTO/RPO và chi phí ước tính của từng cấp.
- Đọc whitepaper *Disaster Recovery of Workloads on AWS* — đọc trọn vẹn, không lướt.

**Tuần này là bản lề cho mục tiêu dài hạn của bạn.** Đây chính là nền cho dự án thiết kế DR site
cho hybrid cloud và on-premise mà bạn muốn làm sau. Direct Connect, Transit Gateway và
Site-to-Site VPN không lab được vì quá đắt — nhưng phần thiết kế thì học hoàn toàn bằng tài liệu
và sơ đồ, và đó mới là phần đề thi hỏi. Giữ lại toàn bộ sơ đồ bạn vẽ tuần này.

**Kiểm tra:**
- [ ] Vẽ xong 4 sơ đồ DR kèm RTO/RPO
- [ ] Đã tắt CRR và xóa bucket ở region phụ

---

### Tuần 12 — Ôn tập và thi thử

`Cả 4 domain` · **Miễn phí** · [→ lab](labs/w12-exam-review/)

**Học:** Đọc Well-Architected Framework, cả sáu trụ cột. Đọc lại trang FAQ chính thức của
S3, EC2, VPC, RDS, DynamoDB, Lambda — riêng việc này đã phủ một phần rất lớn của đề.
Rồi tự tay lập các bảng so sánh dưới đây; **viết ra bằng tay, không copy**.

**Mười bảng so sánh phải tự viết được:**

1. SQS · SNS · EventBridge · Kinesis
2. EBS · EFS · S3 · FSx · Instance store
3. Multi-AZ · Read Replica · Global Database
4. Security Group · Network ACL
5. ALB · NLB · Gateway Load Balancer
6. CloudFront · Global Accelerator
7. Cognito user pool · identity pool
8. SQS Standard · SQS FIFO
9. Gateway Endpoint · Interface Endpoint · NAT Gateway
10. Bốn chiến lược DR theo RTO/RPO và chi phí

**Lịch thi thử:**
- Bốn bài full 65 câu, bấm giờ đúng 130 phút, ngồi liền mạch không nghỉ.
- Sau mỗi bài: review **toàn bộ** câu sai *và* mọi câu đúng nhưng do đoán. Ghi vào một sổ lỗi.
- Ngưỡng đăng ký thi thật: đạt **từ 80% trở lên ở hai bài liên tiếp**. Chưa đạt thì lùi lịch một tuần và cày lại đúng những miền yếu.

**Kiểm tra:**
- [ ] Thi thử #1
- [ ] Thi thử #2
- [ ] Thi thử #3
- [ ] Thi thử #4 — đạt ≥ 80% hai bài liên tiếp
- [ ] Đặt lịch thi SAA-C03 tại Pearson VUE

---

## 5. Capstone — thứ bạn còn lại sau 12 tuần

Chứng chỉ mở cửa vòng lọc CV. Thứ khiến bạn qua được vòng phỏng vấn là một hệ thống bạn tự dựng
và giải thích được từng lựa chọn. Kiến trúc dưới đây chạy hoàn toàn trong hạn mức always-free,
nên bạn có thể để nó sống suốt và demo bất cứ lúc nào.

| Tầng | Dịch vụ | Chi phí | Chứng minh được điều gì |
|---|---|---|---|
| Frontend | S3 + CloudFront + OAC | ~$0 | Static hosting, CDN, khóa origin |
| API | API Gateway HTTP API | ~$0 | REST, throttling, CORS |
| Compute | Lambda (Python) | ~$0 | Serverless, IAM role tối thiểu quyền |
| Dữ liệu | DynamoDB + Streams | ~$0 | Thiết kế NoSQL, GSI, event-driven |
| Bất đồng bộ | SQS + DLQ + Lambda | ~$0 | Decoupling, xử lý lỗi |
| Xác thực | Cognito user pool | ~$0 | Auth, JWT authorizer |
| Quan sát | CloudWatch alarm + dashboard | ~$0 | Vận hành, cảnh báo |
| Hạ tầng | Terraform / CloudFormation | ~$0 | IaC, tái lập được ở account khác |

**Điều làm nên khác biệt:** Viết một file `README.md` giải thích **vì sao** mỗi lựa chọn được
đưa ra, kèm ước tính chi phí ở mức 1.000 người dùng và ở mức 1 triệu người dùng, cùng một mục
"nếu làm lại tôi sẽ đổi gì". Đó chính xác là tư duy mà đề SAA kiểm tra, và cũng là câu người
phỏng vấn sẽ hỏi.

---

## 6. Kỳ thi SAA-C03

Tính đến thời điểm viết, **SAA-C03 vẫn là phiên bản chính thức** trên tài liệu certification
của AWS. Có vài blog nói về "SAA-C04" nhưng không có nguồn chính thức nào từ AWS xác nhận —
hãy tự kiểm tra lại trang certification của AWS trước khi mua tài liệu ôn.

### Thông số bài thi

- **65 câu** — 50 câu tính điểm, 15 câu thử nghiệm không tính
- **130 phút**
- **720 / 1000** điểm để đậu, chấm bù giữa các miền
- **150 USD**, thi tại Pearson VUE hoặc online có giám thị
- Trắc nghiệm một đáp án hoặc nhiều đáp án, không trừ điểm khi đoán

### Trọng số bốn miền

| Miền | Trọng số |
|---|---|
| Thiết kế kiến trúc bảo mật | **30%** |
| Thiết kế kiến trúc có khả năng phục hồi | 26% |
| Thiết kế kiến trúc hiệu năng cao | 24% |
| Thiết kế kiến trúc tối ưu chi phí | 20% |

### Ba mẹo lấy điểm rẻ nhất

- **Bảo mật nặng nhất — 30%.** Nếu chỉ còn thời gian ôn một thứ, ôn IAM và mã hóa.
- **Loại trừ trước, chọn sau.** Phần lớn câu hỏi có hai đáp án sai rõ ràng. Trong hai đáp án còn lại, đọc lại đề tìm từ khóa ràng buộc: "chi phí thấp nhất", "ít thao tác vận hành nhất", "thay đổi code ít nhất". Từ khóa đó mới là thứ quyết định.
- **"Ít thao tác vận hành nhất" gần như luôn nghĩa là managed hoặc serverless.** "Chi phí thấp nhất" thì thường là Spot, S3 lifecycle, hoặc Gateway Endpoint thay NAT.

**Về phí thi:** săn voucher giảm 50% dành cho người đã có một chứng chỉ AWS, hoặc qua các
chương trình như AWS Educate và AWS re/Start. Nếu ngân sách quá chặt, thi **CLF-C02** (100 USD)
trước cũng là một đường vòng hợp lý — đậu là được voucher giảm giá cho kỳ thi tiếp theo.
Nhưng nếu tự tin, đi thẳng SAA-C03 vẫn tiết kiệm hơn.

---

## 7. Tài nguyên

### Miễn phí, chất lượng cao

- **AWS Skill Builder** — gói free có learning plan cho Solutions Architect Associate và bộ 20 câu hỏi luyện tập chính thức
- **Exam Guide chính thức** — đọc kỹ danh sách in-scope và out-of-scope services, đây là ranh giới ôn tập của bạn
- **Trang FAQ của AWS** — S3, EC2, VPC, RDS, DynamoDB, Lambda. Đọc hết sáu trang này là bước có hiệu suất cao nhất mà hầu hết mọi người bỏ qua
- **Whitepaper** — Well-Architected Framework, Security Pillar, và Disaster Recovery of Workloads on AWS
- **workshops.aws** — workshop chính thức, có kèm hướng dẫn dọn dẹp tài nguyên
- **AWS Cloud Quest** — học qua game, miễn phí phần Cloud Practitioner

### Đáng bỏ tiền — tổng dưới 30 USD

- **Bộ đề luyện Tutorials Dojo cho SAA-C03** (~15 USD) — phần giải thích từng đáp án là thứ đắt giá nhất, không phải bản thân câu hỏi
- **Khóa video của Stephane Maarek trên Udemy** (~12–15 USD khi giảm giá — Udemy giảm giá gần như liên tục, đừng bao giờ mua giá gốc)

*Đừng mua nhiều hơn hai thứ này. Mua thêm khóa học chỉ tạo cảm giác đang tiến bộ chứ không tạo ra tiến bộ.*

---

## 8. Tám quy tắc giữ hóa đơn bằng không

1. **Một region duy nhất.** `us-east-1`. Đổi region là công thức để quên tài nguyên.
2. **Không dọn dẹp thì buổi lab chưa xong.** Không có ngoại lệ, kể cả khi đã 1 giờ sáng.
3. **Gắn tag `Project=learn` cho mọi thứ.** Rồi dùng Tag Editor để tìm và xóa hàng loạt khi cần.
4. **Mở Cost Explorer mỗi sáng, 30 giây.** Phát hiện sau một ngày tốn vài xu; phát hiện sau một tháng thì hết credit.
5. **Thấy chữ Gateway, Cluster, Dedicated, Multi-AZ, Provisioned — tra giá trước khi bấm Create.** Năm từ này là nơi tiền bốc hơi.
6. **Không để EC2 chạy qua đêm.** Bao giờ cũng vậy.
7. **Đặt retention 7 ngày cho mọi CloudWatch log group.** Mặc định là giữ vĩnh viễn.
8. **Ưu tiên IaC hơn click chuột** ngay khi bạn đủ khả năng. `terraform destroy` là nút dọn dẹp đáng tin cậy duy nhất tồn tại.

### ⏰ Đặt ba mốc nhắc nhở vào lịch ngay hôm nay

| Ngày | Việc phải làm |
|---|---|
| **10/11/2026** | Còn 3 tháng free plan. Kiểm tra số dư credit, quyết định có nâng cấp lên Paid plan hay không. |
| **10/01/2027** | Còn 1 tháng. Export mọi thứ cần giữ, đảm bảo toàn bộ hạ tầng đã nằm dưới dạng mã trên GitHub. |
| **10/02/2027** | Free plan hết hạn, account sẽ tự đóng nếu không nâng cấp. AWS giữ dữ liệu thêm 90 ngày. |

---

*Giá tham khảo tại `us-east-1` và có thể thay đổi — luôn đối chiếu trang pricing chính thức
trước khi tạo tài nguyên. Thông tin Free Tier dựa trên tài liệu AWS Billing về mô hình áp dụng
cho account mở sau 15/07/2025; thông số kỳ thi lấy từ exam guide SAA-C03 chính thức.*
