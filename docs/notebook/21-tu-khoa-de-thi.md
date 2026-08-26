# Từ khoá đề thi — dịch từ tiếng đề sang tên dịch vụ

> **Tra nhanh:** đề SAA viết bằng một thứ tiếng Anh có mã. File này giải mã: từ
> nào trỏ tới dịch vụ nào, từ nào là mồi, và con số nào loại được đáp án nào.

`Domain 1 · Secure (30%)` · `Domain 2 · Resilient (26%)` · `Domain 3 · High-Performing (24%)` · `Domain 4 · Cost-Optimized (20%)`

Bảng tra từ khoá chỉ có ích khi bạn biết **nó sai ở đâu**. Nửa sau của file —
[Bẫy từ khoá](#bẫy-từ-khoá) — quan trọng hơn nửa đầu.

---

## Bản đồ

| Mục | Đọc khi |
|---|---|
| [Ba loại từ trong một câu hỏi](#ba-loại-từ-trong-một-câu-hỏi) | bạn đang đọc đề mà không biết bám vào chữ nào |
| [Chi phí](#chi-phí) | đề có "cost", "expensive", "budget", "billing" |
| [Độ trễ](#độ-trễ) | đề có "latency", "response time", "fast" |
| [Thông lượng](#thông-lượng) | đề có "throughput", "requests per second", "bandwidth" |
| [Sẵn sàng và chịu lỗi](#sẵn-sàng-và-chịu-lỗi) | đề có "available", "failover", "outage", "RTO" |
| [Bảo mật](#bảo-mật) | đề có "secure", "encrypt", "credentials", "compliance" |
| [Vận hành](#vận-hành) | đề có "operational overhead", "manage", "automate" |
| ["Không được sửa code ứng dụng"](#không-được-sửa-code-ứng-dụng) | đề có "without modifying the application" |
| ["Cần audit"](#cần-audit) | đề có "audit", "who did what", "compliance evidence" |
| ["Phải giữ IP nguồn"](#phải-giữ-ip-nguồn) | đề có "source IP", "client IP", "allowlist" |
| [Hybrid và di trú](#hybrid-và-di-trú) | đề có "on-premises", "migrate", "data center" |
| [Toàn cầu](#toàn-cầu) | đề có "global users", "multiple Regions", "worldwide" |
| [Đọc định lượng](#đọc-định-lượng) | đề có con số — luôn luôn có ý nghĩa |
| [Bẫy từ khoá](#bẫy-từ-khoá) | bạn vừa chọn xong và thấy quá dễ |

Chọn xong dịch vụ thì kiểm chứng bằng [`20-cay-quyet-dinh.md`](20-cay-quyet-dinh.md);
so hai đáp án cuối bằng [`22-bang-so-sanh.md`](22-bang-so-sanh.md).

---

## Ba loại từ trong một câu hỏi

Đọc đề nhanh không phải là đọc nhanh, mà là **biết bỏ qua hai phần ba**.

| Loại từ | Ví dụ | Làm gì với nó |
|---|---|---|
| **Ràng buộc cứng** | "must", "cannot", "is required to", "regulatory" | loại thẳng mọi đáp án vi phạm — làm việc này TRƯỚC |
| **Tiêu chí so sánh** | "MOST cost-effective", "LEAST operational overhead", "MINIMIZES latency" | chỉ dùng để chọn giữa những đáp án ĐÃ thoả ràng buộc |
| **Bối cảnh** | tên công ty, ngành nghề, "recently migrated", số nhân viên | bỏ qua, trừ khi nó chứa một con số |

Trình tự đúng: **ràng buộc trước, tiêu chí sau**. Đề nào cũng có ít nhất một đáp
án rẻ hơn nhưng vi phạm ràng buộc — đó là mồi dành cho người đọc tiêu chí trước.

Ba chữ viết hoa đáng chú ý nhất:

- **MOST / LEAST** — có nhiều hơn một đáp án chạy được. Câu hỏi là "cái nào tốt nhất".
- **BEST** — thường đi kèm một đánh đổi ngầm. Đọc lại xem đề coi trọng gì.
- **Chỉ có một đáp án đúng về mặt kỹ thuật** — khi đề không viết hoa gì cả, ba
  đáp án kia thường sai *cơ chế*, không phải sai *mức độ*.

---

## Từ khoá theo nhóm ý định

### Chi phí

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "no upfront payment", "no commitment" | On-Demand, Lambda, Fargate, DynamoDB on-demand | loại mọi đáp án có chữ Reserved/Savings Plans |
| "steady state", "runs 24/7", "predictable for 3 years" | Savings Plans, Reserved Instance | có cam kết mới có giảm giá |
| "fault-tolerant", "can be interrupted", "flexible start time" | Spot | đây là ba cách đề mô tả "chịu được thu hồi" |
| "unpredictable", "spiky", "idle most of the time" | serverless (Lambda, Fargate, Aurora Serverless v2) | trả tiền theo dùng thật, idle gần $0 |
| "infrequently accessed", "accessed a few times a year" | S3 Standard-IA hoặc Glacier | đọc kỹ tần suất: tháng / quý / năm ra ba class khác nhau |
| "unknown or changing access pattern" | S3 Intelligent-Tiering | đây là câu khoá gần như độc quyền của Intelligent-Tiering |
| "must be retained 7 years for compliance", "rarely retrieved" | Glacier Deep Archive (+ Object Lock nếu cần WORM) | 12–48 giờ retrieval là chấp nhận được với dữ liệu tuân thủ |
| "reduce data transfer costs" | CloudFront, VPC endpoint, giữ traffic trong một AZ | egress ra internet là khoản tiền lớn nhất bị bỏ quên |
| "right-size", "instances are underutilized" | Compute Optimizer, chuyển gp2 sang gp3 | đây là câu hỏi "tối ưu cái đang có", không phải "đổi kiến trúc" |
| "single bill", "volume discount across accounts" | Organizations consolidated billing | không phải Cost Explorer |
| "alert when spending exceeds", "stop before it exceeds" | AWS Budgets (+ Budget Actions) | Cost Explorer chỉ **nhìn lại**, Budgets mới **cảnh báo trước** |
| "which team spent this" | cost allocation tags + Cost Explorer | tag phải bật activation ở Billing mới xuất hiện trong báo cáo |
| "eliminate idle database capacity" | Aurora Serverless v2, DynamoDB on-demand, dừng RDS ngoài giờ | |

Chi tiết ở [`10-chi-phi.md`](10-chi-phi.md).

### Độ trễ

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "microsecond" | DAX, ElastiCache, instance store | dưới mili-giây thì chỉ còn bộ nhớ và NVMe cục bộ |
| "sub-millisecond" | io2 Block Express, ElastiCache, instance store | gp3 là "single-digit ms", không phải sub-ms |
| "single-digit millisecond" | DynamoDB, EBS gp3/io1 | đây là cách AWS mô tả DynamoDB — thấy cụm này là gần như chắc |
| "lowest latency for users around the world" (HTTP) | CloudFront | có cache, có TLS ở edge |
| "lowest latency" + TCP/UDP / non-HTTP | Global Accelerator | không cache, tăng tốc ở lớp mạng |
| "reduce latency to the database" | ElastiCache, read replica cùng AZ, RDS Proxy | |
| "nodes must be physically close, HPC" | cluster placement group | cùng rack, băng thông cao nhất, rủi ro mất cả cụm |
| "latency to on-premises must be consistent" | Direct Connect | VPN đi qua internet nên không hứa được |
| "single-digit millisecond to end users in a metro area" | Local Zones | hiếm gặp; chỉ chọn khi đề nói rõ thành phố |
| "must run in the user's facility" | Outposts | |

### Thông lượng

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "millions of requests per second" | NLB, DynamoDB, S3, CloudFront, Lambda | ALB scale được nhưng NLB là câu trả lời khi đề nhấn con số này |
| "sustained sequential throughput", "large sequential reads" | EBS st1, S3, FSx for Lustre | HDD tính tiền theo MiB/s và thắng ở đọc tuần tự |
| "hundreds of GB/s to a shared file system" | FSx for Lustre | EFS không tới mức đó |
| "petabyte-scale analytics" | Redshift, EMR, Athena trên S3 data lake | |
| "ingest hundreds of thousands of records per second" | Kinesis Data Streams (tính số shard), Firehose | mỗi shard 1 MB/s hoặc 1.000 record/s |
| "10 Gbps sustained to on-premises" | Direct Connect | một tunnel VPN chỉ 1,25 Gbps |
| "100 Gbps between instances" | cluster placement group + ENA/EFA, instance type hỗ trợ | |
| "throughput of a single volume is not enough" | RAID 0 nhiều EBS volume, hoặc io2 Block Express | |

### Sẵn sàng và chịu lỗi

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "highly available" | ≥ 2 AZ cho mọi tầng | đây là **ràng buộc**, không phải tiêu chí — loại mọi đáp án single-AZ |
| "automatic failover" | RDS Multi-AZ, Aurora, ASG, Route 53 failover | "automatic" loại read replica (promote thủ công) |
| "no single point of failure" | ELB + ASG nhiều AZ, NAT mỗi AZ | NAT Gateway một AZ là SPOF hay bị bỏ sót |
| "survive the loss of an Availability Zone" | Multi-AZ | trong một Region |
| "survive the loss of a Region" | multi-Region: CRR, Global Tables, Aurora Global | Multi-AZ **không** trả lời được câu này |
| "self-healing", "replace unhealthy instances" | ASG + ELB health check | |
| "zero data loss", "RPO of zero" | replication đồng bộ (RDS Multi-AZ, Aurora trong Region) | xuyên Region thì RPO thấp nhất khả thi là ~1 giây |
| "a failure in one component must not affect others" | SQS, SNS, EventBridge | decoupling là câu trả lời kiến trúc, không phải thêm instance |
| "graceful degradation", "handle traffic spikes" | SQS làm vùng đệm trước worker | |
| "durable" | S3, EFS (11 số 9) | "durable" ≠ "available" — xem [Bẫy từ khoá](#bẫy-từ-khoá) |

Chi tiết ở [`11-san-sang-cao.md`](11-san-sang-cao.md).

### Bảo mật

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "most secure way for EC2 to access S3" | IAM role gắn vào instance | access key trong file luôn là mồi |
| "temporary credentials" | IAM role, STS AssumeRole, Cognito identity pool | |
| "credentials must rotate automatically" | Secrets Manager | Parameter Store **không** tự rotate |
| "store configuration values cheaply" | SSM Parameter Store | Standard parameter miễn phí; Secrets Manager tính tiền mỗi secret |
| "least privilege" | IAM policy hẹp + Access Analyzer | |
| "limit the maximum permissions a developer can grant" | permission boundary | delegation an toàn |
| "no account in the organization may disable CloudTrail" | SCP | trần cho cả account, kể cả root của account đó |
| "data must not traverse the public internet" | VPC endpoint, PrivateLink, Direct Connect | câu khoá gần như độc quyền của endpoint |
| "encrypt at rest" | KMS, SSE-S3, EBS encryption, RDS encryption | |
| "we must control and audit the encryption key" | KMS customer managed key | AWS managed key không đặt được policy |
| "keys must never leave our HSM" | CloudHSM | |
| "detect compromised credentials, crypto mining, unusual API calls" | GuardDuty | dựa trên CloudTrail, VPC Flow Logs, DNS logs |
| "discover sensitive data / PII in S3" | Macie | |
| "scan EC2 and container images for known CVEs" | Inspector | |
| "block SQL injection and cross-site scripting" | WAF (gắn vào ALB, CloudFront, API Gateway) | |
| "protect against large DDoS", "24/7 response team", "cost protection" | Shield Advanced | Shield Standard bật sẵn và miễn phí |
| "aggregate security findings across accounts" | Security Hub | |
| "require MFA for sensitive actions" | condition `aws:MultiFactorAuthPresent` | |
| "only from the corporate network" | condition `aws:SourceIp`, hoặc `aws:SourceVpce` | |
| "prevent accidental public access to buckets" | S3 Block Public Access ở tầng account | |
| "objects must not be deleted for 5 years" | S3 Object Lock (compliance mode) | governance mode xoá được bởi người có quyền đặc biệt |

Chi tiết ở [`05-security.md`](05-security.md).

### Vận hành

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "LEAST operational overhead", "minimal management" | dịch vụ managed / serverless | đây là tiêu chí xuất hiện nhiều nhất trong đề SAA hiện nay |
| "patch operating systems across hundreds of instances" | SSM Patch Manager | |
| "administrators must not use SSH or a bastion host" | SSM Session Manager | không mở cổng 22, có log phiên |
| "repeatable, version-controlled environments" | CloudFormation | |
| "detect manual changes to infrastructure" | CloudFormation drift detection, AWS Config | |
| "centralize logs from all accounts" | CloudWatch Logs + subscription filter, hoặc bucket S3 trung tâm | |
| "monitor memory and disk usage" | CloudWatch agent | hai metric này **không** có sẵn — đây là bẫy quen thuộc |
| "trace a request across microservices" | X-Ray | |
| "run a command on many instances without logging in" | SSM Run Command | |
| "standardize new accounts" | Control Tower, Organizations + SCP | |
| "automatically remediate non-compliant resources" | Config rule + SSM Automation, hoặc EventBridge → Lambda | |

Chi tiết ở [`07-quan-tri-giam-sat.md`](07-quan-tri-giam-sat.md).

### "Không được sửa code ứng dụng"

Cụm này xuất hiện dưới nhiều dạng: *"without modifying the application"*,
*"the application cannot be changed"*, *"a legacy application that the vendor no
longer supports"*, *"with minimal changes to the application code"*.

Nó là **ràng buộc cứng**, và nó loại đúng những đáp án hấp dẫn nhất.

| Nhu cầu | Bị loại vì cần sửa code | Đáp án đúng |
|---|---|---|
| Giảm tải đọc bằng cache | ElastiCache, DAX (phải gọi client cache) | CloudFront, API Gateway cache |
| Nhiều máy dùng chung thư mục | viết lại để dùng S3 SDK | EFS hoặc FSx — mount là xong |
| Ứng dụng ghi vào đĩa local, cần bền | đổi sang object storage | EBS + snapshot, hoặc EFS |
| Ứng dụng hard-code một địa chỉ IP | đổi thành DNS | NLB với IP tĩnh, hoặc Elastic IP |
| Cần mã hoá dữ liệu | client-side encryption | mã hoá phía server: SSE-S3/SSE-KMS, EBS/RDS encryption |
| Cần HTTPS | thêm TLS vào ứng dụng | kết thúc TLS ở ALB/CloudFront với chứng chỉ ACM |
| Giữ session khi scale ra nhiều máy | chuyển session sang DynamoDB/Redis | ALB sticky session (cookie) — giải pháp tạm nhưng không sửa code |
| Quá nhiều kết nối tới database | pooling trong ứng dụng | RDS Proxy |
| Cần chạy trên AWS y nguyên | container hoá, viết lại thành Lambda | EC2, hoặc VMware Cloud on AWS |

Ngược lại, khi đề nói *"the application is being rewritten"* hoặc *"the team is
modernizing"*, ràng buộc này biến mất và Lambda, DynamoDB, ElastiCache quay lại bàn.

### "Cần audit"

Bốn dịch vụ nghe giống nhau, trả lời bốn câu hỏi khác nhau.

| Câu hỏi thật của đề | Dịch vụ | Ghi nhớ |
|---|---|---|
| "ai đã gọi API nào, lúc nào, từ IP nào" | CloudTrail | mặc định chỉ ghi **management event**; muốn theo dõi từng object S3 hay từng item DynamoDB thì phải bật **data event** (tính tiền) |
| "cấu hình của tài nguyên này thay đổi thế nào theo thời gian" và "nó có tuân thủ không" | AWS Config | Config trả lời "trạng thái", CloudTrail trả lời "hành động" |
| "hệ thống đang chạy thế nào" | CloudWatch | metric và log vận hành, không phải bằng chứng tuân thủ |
| "gói tin nào bị chấp nhận hay từ chối trong VPC" | VPC Flow Logs | chỉ metadata, **không có payload** |
| "ai đã tải object này xuống" | CloudTrail data event, hoặc S3 server access log | server access log rẻ hơn nhưng chậm và best-effort |
| "log phải không sửa được, dù là admin" | S3 Object Lock, Glacier Vault Lock, CloudTrail log file validation | |
| "một chỗ xem cho tất cả account" | Organization trail của CloudTrail, CloudTrail Lake | |

### "Phải giữ IP nguồn"

| Thành phần trên đường đi | IP nguồn còn không | Cách lấy lại |
|---|---|---|
| NLB, target group theo **instance ID** | Còn nguyên | mặc định bật, không tắt được |
| NLB, target group theo **IP**, listener TCP/TLS | **Mất** theo mặc định | bật `preserve_client_ip.enabled`, hoặc dùng proxy protocol v2 |
| NLB, listener UDP / TCP_UDP | Còn nguyên | mặc định bật |
| ALB | Mất | đọc header `X-Forwarded-For` |
| CloudFront | Mất | `X-Forwarded-For`, hoặc header `CloudFront-Viewer-Address` |
| NAT Gateway | Mất — thay bằng IP của NAT | không lấy lại được; đây là mục đích của NAT |
| API Gateway | Mất | `$context.identity.sourceIp` |

Nếu ứng dụng cần IP thật chỉ để **chặn hoặc giới hạn tốc độ**, đáp án đúng thường
không phải "giữ IP nguồn" mà là **đưa việc chặn lên WAF** ở ALB hoặc CloudFront.

### Hybrid và di trú

| Đề nói | Trỏ tới |
|---|---|
| "extend the on-premises file share into AWS" | Storage Gateway (File Gateway) |
| "replace physical tape backup" | Storage Gateway (Tape Gateway) |
| "recurring incremental sync from NFS to S3" | DataSync |
| "migrate a database with almost no downtime" | DMS với CDC |
| "migrate Oracle to PostgreSQL" | DMS + Schema Conversion Tool |
| "no network connectivity, hundreds of TB" | thiết bị vật lý — xem [Nguồn nói khác](#nguồn-nói-khác) |
| "discover and plan the migration" | Migration Hub, Application Discovery Service |
| "the 7 Rs" | rehost, replatform, repurchase, refactor, retire, retain, relocate |

Chi tiết ở [`13-khoi-phuc-tham-hoa.md`](13-khoi-phuc-tham-hoa.md).

### Dữ liệu và phân tích

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "query data already in S3 without loading it" | Athena | không có cụm nào khác trỏ vào Athena rõ bằng cụm này |
| "complex joins, thousands of concurrent BI users" | Redshift | Athena tính tiền theo dữ liệu quét, không hợp truy vấn lặp lại dày |
| "Spark, Hive, custom processing" | EMR | |
| "catalog and discover schema automatically" | Glue Crawler + Data Catalog | |
| "ETL without managing servers" | Glue | |
| "full-text search, log analytics dashboard" | OpenSearch Service | |
| "visualize the data for business users" | QuickSight | |
| "stream into a data lake with no code" | Data Firehose | tự buffer, tự chuyển định dạng sang Parquet |
| "data lake with fine-grained permissions" | Lake Formation | |

Chi tiết ở [`09-analytics-bigdata` trong nguồn](../../aws-saa-c03/09-analytics-bigdata.md).

### Container và điều phối

| Đề nói | Trỏ tới |
|---|---|
| "existing Kubernetes manifests / Helm charts" | EKS |
| "simplest way to run containers on AWS" | ECS |
| "no EC2 instances to patch" | Fargate |
| "store container images privately" | ECR |
| "run thousands of batch jobs with dependencies" | AWS Batch |
| "each task needs its own IAM permissions" | ECS task role (không phải instance role) |
| "scale containers on a queue depth" | ECS service auto scaling theo CloudWatch metric của SQS |

### Toàn cầu

| Đề nói | Trỏ tới | Vì sao |
|---|---|---|
| "users around the world", nội dung HTTP | CloudFront | |
| "users around the world", giao thức không phải HTTP | Global Accelerator | |
| "writes must happen in multiple Regions" | DynamoDB Global Tables | Aurora Global chỉ ghi ở Region chính |
| "read latency in other Regions" | Aurora Global Database, read replica xuyên Region | |
| "content must differ by country" | Route 53 geolocation, hoặc CloudFront geo restriction | |
| "comply with data residency law" | chọn Region + SCP chặn Region khác | |
| "one static IP that works worldwide" | Global Accelerator | 2 anycast IP |
| "reduce upload time from remote offices" | S3 Transfer Acceleration | |

---

## Đọc định lượng

Đề SAA hiếm khi cho một con số vô nghĩa. Mỗi con số **loại được ít nhất một đáp án**.

| Con số trong đề | Nó đang nói gì | Loại được |
|---|---|---|
| "millions of requests per second" | quy mô vượt một instance, vượt cả ALB warm-up | mọi đáp án single-node; nghiêng về NLB, DynamoDB, S3, CloudFront |
| "thousands of requests per second" | bình thường với ALB + ASG | không loại được gì — đây là con số **bối cảnh** |
| "sub-millisecond" | phải là bộ nhớ hoặc NVMe cục bộ | DynamoDB thuần, EBS gp3, mọi thứ đi qua mạng nhiều chặng |
| "single-digit millisecond" | đúng mô tả DynamoDB và EBS SSD | đáp án Redshift, Athena, S3 Select |
| "petabyte" | quá EBS, quá RDS | EBS (64 TiB/volume), RDS (64 TiB); còn S3, Redshift, FSx for Lustre |
| "hundreds of terabytes" + "limited bandwidth" | tính thời gian truyền trước khi chọn | đáp án qua mạng nếu kết quả ra hàng tháng |
| "99.99% availability" | ~52 phút downtime mỗi năm | kiến trúc single-AZ; RDS Multi-AZ chỉ cam kết tới 99,95% |
| "99.999999999% durability" | đây là **độ bền** của S3/EFS | đừng đọc thành availability |
| "15 minutes" | đúng trần Lambda | nếu đề nói "up to 30 minutes" thì Lambda bị loại |
| "less than 1 second failover" | DNS không làm được | Route 53 failover; còn Global Accelerator, NLB |
| "1–2 minutes failover" | đúng tầm RDS Multi-AZ | |
| "24 hours RTO" | backup & restore là đủ | warm standby và active/active vì đắt không cần thiết |
| "5-minute RPO" | phải replicate liên tục | snapshot hằng đêm |
| "20,000 IOPS" | vẫn trong tầm gp3 (tới 80.000) | đáp án "phải dùng io2" nếu đề còn nhấn cost |
| "200,000 IOPS" | vượt gp3 | gp3; còn io2 Block Express hoặc nhiều volume RAID 0 |
| "256 KB messages" | đúng trần SQS/SNS/EventBridge | |
| "1 MB messages" | vượt trần SQS | SQS thuần; cần Extended Client + S3, hoặc Kinesis (1 MB/record) |
| "objects average 5 KB" | dưới ngưỡng tính tiền 128 KB của S3 IA | S3 Standard-IA và One Zone-IA trong câu hỏi cost |
| "5 TB single file" | đúng trần object S3, vượt trần một lần PUT (5 GB) | upload một lần; phải multipart |
| "10,000 concurrent connections to the database" | vượt sức RDS instance vừa | thêm read replica đơn thuần; nghiêng về RDS Proxy |

**Bảng đổi phần trăm sang thời gian chết** — đề hay cho SLA rồi hỏi kiến trúc:

| SLA | Downtime mỗi năm | Mỗi tháng | Kiến trúc tối thiểu |
|---|---|---|---|
| 99% | 3,65 ngày | 7,2 giờ | một instance |
| 99,9% | 8,8 giờ | 43,8 phút | Multi-AZ |
| 99,95% | 4,4 giờ | 21,9 phút | Multi-AZ (mức RDS Multi-AZ cam kết) |
| 99,99% | 52,6 phút | 4,4 phút | nhiều AZ, không có SPOF, có auto scaling |
| 99,999% | 5,3 phút | 26 giây | nhiều Region, active/active |

**Ví dụ đọc định lượng trọn một câu**

> A media company stores 4 PB of raw video in an on-premises SAN. Editors access
> roughly 2% of the footage each month; the rest is kept for licensing audits for
> 10 years. The company has a 1 Gbps internet link that is already 60% utilized.
> They need the archive in AWS within 6 weeks at the LOWEST cost.

Bốn con số, bốn quyết định:

| Con số | Loại được |
|---|---|
| **4 PB** | EBS (64 TiB mỗi volume) và RDS; còn S3, FSx for Lustre |
| **1 Gbps, đã dùng 60%** | băng thông thực ~400 Mbps → 4 PB mất hơn hai năm. Loại mọi đáp án truyền qua mạng |
| **6 tuần** | xác nhận phải dùng thiết bị vật lý hoặc kênh riêng |
| **2% truy cập mỗi tháng, giữ 10 năm** | chia hai tầng: phần nóng ở Standard hoặc Standard-IA, phần còn lại Deep Archive |

Đáp án cuối cùng không phải một dịch vụ mà là một **cặp**: chuyển vật lý vào S3,
rồi lifecycle rule đẩy phần lạnh xuống Deep Archive. Đề SAA rất hay chấm điểm ở
chỗ bạn có nhận ra rằng câu hỏi có **hai** quyết định độc lập hay không.

---

## Bẫy từ khoá

### Trông như A, thật ra B

| Từ khoá | Ai cũng nghĩ | Thật ra thường là | Điều kiện lật ngược |
|---|---|---|---|
| "real-time" | Kinesis | SQS | chỉ một consumer, không cần đọc lại |
| "real-time dashboard" | Kinesis Data Streams | CloudWatch, hoặc Firehose → OpenSearch | không ai viết consumer |
| "serverless" | Lambda | Fargate, Aurora Serverless, DynamoDB | công việc dài hơn 15 phút hoặc đã container hoá |
| "no server management" | Lambda | bất kỳ dịch vụ managed nào | đây là yêu cầu vận hành, không phải kiến trúc |
| "cache" | ElastiCache | CloudFront | thứ lặp lại là HTTP response, không phải query |
| "static IP" | Elastic IP | NLB hoặc Global Accelerator | phía sau có auto scaling |
| "high availability" cho S3 | bật gì đó | không phải làm gì cả | S3 Standard đã trải nhiều AZ sẵn |
| "durability" | availability | độ bền dữ liệu | 11 số 9 là durability; availability của S3 Standard là 99,99% thiết kế |
| "read replica" | HA | scale đọc | promote thủ công, replication bất đồng bộ |
| "Multi-AZ" | DR | HA trong một Region | Region chết là hết |
| "encryption in transit" | KMS | ACM + TLS | KMS lo dữ liệu **at rest** |
| "audit" | CloudWatch | CloudTrail | CloudWatch là vận hành, không phải bằng chứng |
| "track configuration changes" | CloudTrail | AWS Config | Config trả lời "trạng thái theo thời gian" |
| "block an IP address" | Security Group | NACL hoặc WAF | SG **không có** rule Deny |
| "firewall for the web app" | Security Group | WAF | SG là L3/L4, WAF là L7 |
| "monitor memory usage" | CloudWatch | CloudWatch **agent** | metric mặc định không có memory và disk |
| "queue" | SQS | có thể là Kinesis hoặc MQ | đề nói "existing JMS/AMQP application" → Amazon MQ |
| "microsecond latency for DynamoDB" | ElastiCache | DAX | DAX hiểu API DynamoDB, ElastiCache thì không |
| "gateway" | Internet Gateway | tuỳ ngữ cảnh: NAT, Storage, API, Transit, Gateway Endpoint | đọc lại danh từ đứng trước |
| "cheapest storage" | Glacier Deep Archive | tuỳ retrieval | phí lấy ra và min duration có thể lật ngược phép tính |
| "archive" | Glacier | có khi là Standard-IA | "archive" mà vẫn cần lấy trong mili-giây → Glacier Instant Retrieval |

### Cặp từ khoá xung đột

Khi hai tiêu chí đụng nhau, **ràng buộc thắng tiêu chí**. Bảng này nói bỏ nhánh nào.

| Cặp trong cùng một câu | Bỏ nhánh nào | Vì sao |
|---|---|---|
| "cost-effective" + "highly available" | bỏ mọi phương án single-AZ: One Zone-IA, một NAT Gateway, RDS Single-AZ | HA là ràng buộc; "cost-effective" chỉ dùng để chọn giữa các phương án **đã** HA |
| "cost-effective" + "must not traverse the internet" | bỏ NAT Gateway; chọn Gateway Endpoint nếu đích là S3/DynamoDB | Gateway Endpoint vừa riêng tư vừa miễn phí |
| "real-time" + "exactly once, in order" | bỏ Kinesis và SQS Standard | Kinesis là at-least-once; chỉ SQS FIFO cho cả thứ tự lẫn khử trùng lặp |
| "lowest latency" + "lowest cost" | ưu tiên latency, trừ khi đề viết hoa MOST cost-effective | đề hiếm khi bắt bạn chọn cả hai — xem chữ viết hoa |
| "minimal operational overhead" + "full control over the OS" | mâu thuẫn: đọc lại xem cái nào là "must" | "must have full control" là ràng buộc → EC2, dù overhead cao hơn |
| "serverless" + "runs continuously with steady load" | bỏ Lambda | Lambda đắt hơn ở tải đều 24/7; Fargate hoặc EC2 với Savings Plans rẻ hơn |
| "encrypted" + "cannot modify the application" | bỏ client-side encryption | mã hoá phía server là thứ duy nhất trong suốt với ứng dụng |
| "global" + "static IP" | bỏ CloudFront | CloudFront không cho IP tĩnh; Global Accelerator có 2 anycast IP |
| "high availability" + "data must stay in one country" | bỏ multi-Region xuyên biên giới | dùng nhiều AZ trong Region hợp pháp |
| "scale to zero" + "sub-second cold response" | bỏ Lambda ở đúng nhánh này, hoặc chấp nhận provisioned concurrency | scale-to-zero và cold start là hai mặt của một đồng xu |
| "no downtime" + "least cost" | bỏ backup & restore và pilot light | "no downtime" là ràng buộc, đẩy tối thiểu lên warm standby |
| "immediate retrieval" + "archive pricing" | bỏ Glacier Flexible và Deep Archive | chỉ Glacier Instant Retrieval thoả cả hai |

### Từ khoá vô nghĩa

Ba cụm sau **không** loại được đáp án nào; đừng để chúng dẫn dắt:

- **"best practice"** — mọi đáp án đều tự nhận là best practice.
- **"scalable"** — gần như mọi dịch vụ AWS đều scale; đọc con số đi kèm.
- **"secure"** đứng một mình — phải có tân ngữ ("secure the credentials",
  "secure the network path") mới trỏ được vào đâu.

---

## Từ điển cụm đề thi

Bốn mươi cụm tiếng Anh lặp đi lặp lại trong đề. Dịch sát nghĩa không đủ — cột
cuối mới là thứ đáng nhớ.

| Cụm trong đề | Nghĩa | Nó đang ép bạn làm gì |
|---|---|---|
| "operational overhead" | công sức vận hành | ưu tiên managed hơn tự dựng |
| "undifferentiated heavy lifting" | việc nặng không tạo giá trị riêng | giao cho AWS |
| "loosely coupled" | tách rời | chèn queue hoặc event bus vào giữa |
| "single point of failure" | điểm chết đơn lẻ | tìm thành phần chỉ có một bản |
| "elastic" | co giãn theo tải | auto scaling, không phải mua sẵn cho đỉnh |
| "burst" | tăng vọt ngắn hạn | vùng đệm, hoặc instance burstable |
| "steady state" | tải đều | cam kết dài hạn để giảm giá |
| "spiky" / "unpredictable" | thất thường | trả theo dùng |
| "eventually consistent" | nhất quán cuối cùng | đọc có thể thấy dữ liệu cũ vài trăm ms |
| "strongly consistent" | nhất quán mạnh | đắt hơn, chậm hơn, phải yêu cầu tường minh |
| "idempotent" | chạy lại không đổi kết quả | an toàn với at-least-once delivery |
| "at-least-once" | có thể trùng | consumer phải khử trùng lặp |
| "exactly-once" | đúng một lần | FIFO, hoặc idempotency ở tầng ứng dụng |
| "fan-out" | một nguồn ra nhiều đích | SNS, EventBridge |
| "backpressure" | tiêu thụ chậm hơn sản xuất | queue để hấp thụ |
| "dead-letter queue" | nơi chứa message xử lý mãi không xong | luôn cần khi dùng SQS hoặc Lambda async |
| "throttling" | bị giới hạn tốc độ | tăng quota, hoặc thêm vùng đệm |
| "cold start" | lần gọi đầu chậm | provisioned concurrency |
| "warm standby" | bản chạy thu nhỏ ở Region khác | chiến lược DR |
| "cutover" | thời điểm chuyển sang hệ thống mới | tối thiểu hoá downtime bằng CDC |
| "blast radius" | phạm vi thiệt hại khi hỏng | tách account, tách AZ, tách cell |
| "guardrails" | rào chắn | SCP, permission boundary, Config rule |
| "drift" | cấu hình lệch khỏi mô tả | Config, CloudFormation drift detection |
| "immutable" | không sửa được sau khi ghi | Object Lock, AMI mới thay vì vá tại chỗ |
| "ephemeral" | tạm, mất khi dừng | instance store, `/tmp` của Lambda |
| "stateless" | không giữ trạng thái cục bộ | scale ngang và dùng Spot được |
| "sticky session" | ghim client vào một backend | dấu hiệu ứng dụng đang stateful |
| "warm-up" / "pre-warm" | hâm nóng trước | ALB ở quy mô lớn, cache trước sự kiện |
| "hot partition" | một partition key nhận quá nhiều traffic | thiết kế lại partition key của DynamoDB |
| "chatty" | quá nhiều lượt gọi qua lại | gộp request, đưa hai bên lại gần nhau |
| "egress" | dữ liệu đi ra khỏi AWS | khoản tiền hay bị bỏ sót |
| "in-flight" | đang trên đường | message đã nhận nhưng chưa xoá |
| "visibility timeout" | thời gian message bị giấu khỏi consumer khác | đặt lớn hơn thời gian xử lý |
| "retention" | thời gian giữ lại | SQS 14 ngày, Kinesis tới 365 ngày |
| "quota" / "service limit" | trần mềm | phần lớn xin tăng được qua Service Quotas |
| "hard limit" | trần cứng | không xin tăng được — ví dụ 15 phút của Lambda |
| "graceful degradation" | suy giảm có kiểm soát | phục vụ bản rút gọn thay vì trả lỗi |
| "failback" | quay về hệ thống chính sau sự cố | phần hay bị quên trong kế hoạch DR |
| "read-after-write consistency" | đọc thấy ngay thứ vừa ghi | S3 có sẵn cho mọi thao tác từ 2020 |
| "cross-account" | xuyên tài khoản | role + trust policy, hoặc resource policy |

---

## Bảng số phải nhớ

| Con số | Của cái gì | Vì sao ra thi |
|---|---|---|
| 99,95% | SLA của RDS Multi-AZ | đề hỏi 99,99% thì Multi-AZ một mình không đủ |
| 99,99% | SLA của Aurora; availability thiết kế của S3 Standard | |
| 11 số 9 | durability của S3 và EFS | không phải availability |
| 15 phút | Lambda timeout | |
| 29 giây | API Gateway integration timeout mặc định | tăng được qua Service Quotas cho REST API Regional và private |
| 256 KB | message SQS, SNS, EventBridge | |
| 300 / 3.000 / 70.000 TPS | SQS FIFO thường / có batch / high throughput mode | |
| 1 MB/s hoặc 1.000 record/s | ghi vào một shard Kinesis | |
| 128 KB | ngưỡng tính tiền tối thiểu của S3 IA | |
| 30 / 90 / 180 ngày | min duration của IA / Glacier IR và Flexible / Deep Archive | |
| 3.000 IOPS + 125 MiB/s | baseline gp3 (mua thêm tới 80.000 IOPS, 2.000 MiB/s) | |
| 5 Gbps → 100 Gbps | NAT Gateway tự scale | |
| 1,25 Gbps | mỗi tunnel Site-to-Site VPN | |
| 400 KB | item DynamoDB lớn nhất | |
| 5 TB / 5 GB | object S3 lớn nhất / một lần PUT lớn nhất | |
| ~1 giây | lag của Aurora Global Database và DynamoDB Global Tables | |

---

## Bẫy đề thi

**Bẫy 1 — đọc tiêu chí trước ràng buộc**
Đề: "MOST cost-effective solution that is highly available". Mồi: S3 One Zone-IA, hoặc RDS Single-AZ. Đúng: phương án rẻ nhất **trong số** những phương án đã nhiều AZ.
Vì sao: "highly available" là must; "most cost-effective" chỉ để so sánh những cái đã hợp lệ.

**Bẫy 2 — "real-time" bị dịch thẳng thành Kinesis**
Đề: xử lý đơn hàng gần như tức thì, mỗi đơn đúng một lần, một service duy nhất tiêu thụ. Mồi: Kinesis Data Streams. Đúng: SQS.
Vì sao: Kinesis giải bài toán **nhiều consumer độc lập** và **đọc lại**. Không có hai thứ đó thì nó chỉ thêm shard để quản lý.

**Bẫy 3 — Security Group được chọn để CHẶN**
Đề: "block traffic from a specific IP range". Mồi: thêm deny rule vào Security Group. Đúng: NACL, hoặc WAF nếu là L7.
Vì sao: Security Group chỉ có Allow; không cho phép nghĩa là không nằm trong danh sách, không phải là có rule Deny.

**Bẫy 4 — CloudWatch được chọn cho câu hỏi audit**
Đề: "determine which user deleted the S3 bucket". Mồi: CloudWatch Logs. Đúng: CloudTrail.
Vì sao: CloudWatch ghi cái hệ thống **phát ra**; CloudTrail ghi cái người ta **gọi**. Muốn biết ai xoá từng object thì còn phải bật data event.

**Bẫy 5 — bỏ qua kích thước object trong câu hỏi cost**
Đề: 500 triệu file log 8 KB, đọc vài lần mỗi năm, "MOST cost-effective". Mồi: chuyển sang Standard-IA. Đúng: gộp file lại rồi mới archive, hoặc dùng Intelligent-Tiering.
Vì sao: IA tính tối thiểu 128 KB mỗi object; 8 KB bị tính như 128 KB, đắt gấp 16 lần phần dữ liệu thật.

**Bẫy 6 — "encryption in transit" bị trả lời bằng KMS**
Đề: "data must be encrypted in transit between the client and the load balancer". Mồi: bật KMS. Đúng: chứng chỉ ACM trên listener HTTPS của ALB.
Vì sao: KMS lo dữ liệu **at rest**. Mã hoá đường truyền là TLS, và trên AWS thì chứng chỉ đến từ ACM.

**Bẫy 7 — "highly available" bị trả lời bằng "tăng số instance"**
Đề: ứng dụng chạy 4 instance trong một AZ, cần "highly available". Mồi: tăng lên 8 instance. Đúng: trải instance ra ít nhất hai AZ.
Vì sao: HA đo bằng **số miền lỗi độc lập**, không phải số bản sao. Tám instance trong một AZ vẫn chết cùng nhau.

**Bẫy 8 — Interface Endpoint được chọn cho S3 vì thấy chữ "PrivateLink"**
Đề: instance private ghi vào S3, "must not use the public internet", "MOST cost-effective". Mồi: Interface Endpoint cho S3. Đúng: Gateway Endpoint.
Vì sao: Interface Endpoint cho S3 tồn tại và có ích khi truy cập từ on-prem, nhưng nó tính tiền theo giờ và theo GB. Từ trong VPC thì Gateway Endpoint làm đúng việc đó và miễn phí.

---

## Cây quyết định

Từ khoá dẫn bạn tới **nhóm bài toán**, không tới đáp án. Bảng dưới nối hai file.

| Từ khoá bạn vừa thấy | Mở cây nào trong [`20-cay-quyet-dinh.md`](20-cay-quyet-dinh.md) |
|---|---|
| "run", "host", "no server management" | Chọn compute |
| "cost", "commitment", "interruption" | Chọn purchasing model EC2 |
| "store", "archive", "shared", "IOPS" | Chọn storage |
| "database", "queries", "read scaling" | Chọn database |
| "decouple", "fan-out", "stream", "orchestrate" | Chọn cơ chế messaging |
| "distribute traffic", "static IP", "path-based" | Chọn load balancer |
| "private subnet", "without the internet" | Chọn cách cho private subnet ra ngoài |
| "on-premises", "consistent latency" | Chọn cách kết nối hybrid |
| "migrate 500 TB", "recurring sync" | Chọn cách chuyển dữ liệu khối lượng lớn |
| "RTO", "RPO", "another Region" | Chọn chiến lược DR |
| "reduce latency", "repeated reads" | Chọn nơi đặt cache |
| "another account", "third party", "restrict" | Chọn cách xác thực cross-account |

Nếu từ khoá không khớp cây nào, khả năng cao đó là từ **bối cảnh**. Quay lại
[Ba loại từ trong một câu hỏi](#ba-loại-từ-trong-một-câu-hỏi).

---

## Nối với thực hành

Từ khoá chỉ dính vào đầu khi bạn từng thấy nó **sai**.

| Nhóm từ khoá | Lab | Làm gì để từ khoá thành phản xạ |
|---|---|---|
| [Bảo mật](#bảo-mật) | [`w01-iam-foundations`](../../learn-aws/labs/w01-iam-foundations/) · [`w09-security-deep`](../../learn-aws/labs/w09-security-deep/) | thử "block an IP" bằng Security Group cho tới lúc tin rằng không có Deny |
| ["Phải giữ IP nguồn"](#phải-giữ-ip-nguồn) | [`w03-ec2-alb-asg`](../../learn-aws/labs/w03-ec2-alb-asg/) | in `X-Forwarded-For` ra access log và so với IP thật của bạn |
| [Chi phí](#chi-phí) | [`w04-s3-cloudfront`](../../learn-aws/labs/w04-s3-cloudfront/) | tạo 1.000 object 5 KB, đặt lifecycle sang IA, xem hoá đơn ước tính |
| [Vận hành](#vận-hành) | [`w02-vpc-networking`](../../learn-aws/labs/w02-vpc-networking/) · [`w10-observability-iac`](../../learn-aws/labs/w10-observability-iac/) | vào instance bằng Session Manager, rồi thử tìm metric memory trong CloudWatch |
| ["Cần audit"](#cần-audit) | [`w10-observability-iac`](../../learn-aws/labs/w10-observability-iac/) | tìm một hành động của chính bạn trong CloudTrail, rồi tìm cùng hành động đó trong Config |
| [Độ trễ](#độ-trễ) | [`w08-dns-cdn-edge`](../../learn-aws/labs/w08-dns-cdn-edge/) | đo thời gian phản hồi trước và sau khi bật CloudFront |

Quy trình và cảnh báo chi phí: [`learn-aws/labs/README.md`](../../learn-aws/labs/README.md).

---

## Nguồn nói khác

`aws-saa-c03/M-keywords-mapping.md` là bảng tra một chiều: keyword → service. Nó
đúng ở phần lớn dòng nhưng thiếu hẳn chiều ngược lại — chỗ mà keyword **đánh lừa**.
Dưới đây là các dòng đã sửa.

| Nguồn nói | Thực tế (2026-08) | Bằng chứng |
|---|---|---|
| `"99.99% availability"` → "Multi-AZ deployments, 4 nines SLA" | RDS Multi-AZ chỉ cam kết **tới 99,95%**; Aurora mới tới 99,99% | [RDS features](https://aws.amazon.com/rds/features/) |
| `"real-time"` → "Kinesis Data Streams, DynamoDB Streams" | thiếu điều kiện phân biệt; phần lớn câu "real-time" trong đề SAA là SQS | [SQS vs Kinesis](https://aws.amazon.com/sqs/faqs/) |
| `"high throughput"` → "EBS st1, S3 Transfer Acceleration" | Transfer Acceleration giải bài toán **khoảng cách địa lý**, không phải throughput. Và gp3 nay đạt 2.000 MiB/s, cao gấp bốn st1 | [EBS General Purpose SSD](https://docs.aws.amazon.com/ebs/latest/userguide/general-purpose.html) |
| `"microsecond latency"` → DynamoDB DAX, chú thích "Sub-millisecond" | microsecond và sub-millisecond là hai bậc khác nhau; DAX là **micro-giây cho đọc trúng cache** | [DAX](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DAX.html) |
| `"ledger"` → QLDB | QLDB ngoài phạm vi SAA-C03; đừng để nó là đáp án | [`../CONVENTIONS.md`](../CONVENTIONS.md) |
| `"archive"` → "S3 Glacier, Glacier Deep Archive" | thiếu Glacier Instant Retrieval — class duy nhất vừa "archive" vừa lấy được trong mili-giây | [S3 storage classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html) |
| `"disaster recovery"` xuất hiện hai lần với hai ánh xạ khác nhau | DR phải chọn theo RTO/RPO, không theo một tên dịch vụ | [DR whitepaper](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/disaster-recovery-workloads-on-aws.html) |
| Toàn bộ file không có mục "bẫy từ khoá" | đây là phần ăn điểm nhất; đã bổ sung ở [Bẫy từ khoá](#bẫy-từ-khoá) | |
| `aws-saa-c03/K-kich-ban-thi.md` tự nhận có "50+ scenarios" | file chỉ có **4 scenario** thật, phần còn lại là dòng `[Continued with 47 more scenarios...]` | đọc chính file đó |
| `aws-saa-c03/README.md` liệt kê F, G, H, I, J, N, O | bảy file không tồn tại; nội dung được viết mới ở `10`–`13` | xem [`README.md`](README.md) |

---

## Ngoài phạm vi

- **Từ khoá của đề Developer và SysOps** (CodeDeploy hook, X-Ray sampling rule chi tiết) — khác kỳ thi → [certification](https://aws.amazon.com/certification/).
- **Từ khoá ngành đặc thù** (HIPAA eligible service list, PCI scope) — SAA chỉ hỏi "có compliance thì dùng Artifact" → [AWS Artifact](https://docs.aws.amazon.com/artifact/).
- **Tên gọi cũ**: "AWS SSO" nay là IAM Identity Center, "Kinesis Data Firehose" nay là Amazon Data Firehose → [Data Firehose](https://docs.aws.amazon.com/firehose/).
- **Từ khoá Machine Learning** (SageMaker, Bedrock) — SAA-C03 chỉ hỏi ở mức "dịch vụ nào làm việc gì" → [`12-ml-ai` trong nguồn](../../aws-saa-c03/12-ml-ai.md).

---

## Tự kiểm tra

**1.** Một câu hỏi có cả "MOST cost-effective" và "must be highly available".
Bạn xử lý hai cụm này theo thứ tự nào, và vì sao thứ tự đó quan trọng?

<details><summary>Đáp án</summary>

Ràng buộc trước, tiêu chí sau. "Must be highly available" là **must** — nó loại
thẳng mọi đáp án chỉ có một AZ (S3 One Zone-IA, RDS Single-AZ, một NAT Gateway,
ASG với `min_size = 1` trong một subnet). Chỉ sau khi lọc xong mới so tiền giữa
những phương án còn lại. Làm ngược lại thì bạn sẽ chọn đúng đáp án rẻ nhất bảng —
và nó chính là mồi mà đề đặt sẵn, vì nó vi phạm ràng buộc.

</details>

**2.** Vì sao "durability 99.999999999%" không trả lời được câu hỏi "the application
must remain available if an Availability Zone fails"?

<details><summary>Đáp án</summary>

Hai chỉ số đo hai thứ khác nhau. **Durability** là xác suất dữ liệu **không bị
mất** — S3 đạt 11 số 9 bằng cách nhân bản object qua nhiều thiết bị và nhiều AZ.
**Availability** là xác suất bạn **đọc được** dữ liệu ngay lúc cần; S3 Standard
được thiết kế ở mức 99,99% và cam kết SLA 99,9%. Dữ liệu vẫn còn nguyên mà API
đang lỗi thì ứng dụng vẫn chết. Với One Zone-IA thì durability vẫn ghi 11 số 9,
nhưng mất AZ là mất dữ liệu — vì con số durability được tính **trong phạm vi một AZ**.

</details>

**3.** Đề nói "the legacy application cannot be modified" và cần giảm tải đọc cho
database. Vì sao ElastiCache là đáp án sai, và cái gì đúng?

<details><summary>Đáp án</summary>

ElastiCache không tự đứng chắn trước database. Ứng dụng phải chủ động hỏi cache
trước, xử lý trường hợp miss, rồi ghi kết quả vào cache — tất cả đều là code mới.
Ràng buộc "cannot be modified" loại nó. Những gì còn lại là các lớp **trong suốt**:
read replica (chỉ đổi connection string, thường là file cấu hình), RDS Proxy (đổi
endpoint), hoặc nếu cái lặp lại là HTTP response thì CloudFront và API Gateway cache
— cả hai nằm ngoài ứng dụng hoàn toàn.

</details>

**4.** Cùng một câu "we need to know who deleted the file", hai đáp án là CloudTrail
và S3 server access logs. Điều kiện nào trong đề quyết định chọn cái nào?

<details><summary>Đáp án</summary>

Ba điều kiện. **Một**, mức độ chính xác: CloudTrail data event ghi identity đầy đủ
(role, session, IP, MFA), giao trong vài phút, và có log file validation để chứng
minh không bị sửa — hợp với chữ "audit" hay "compliance evidence". **Hai**, chi
phí: data event tính tiền theo số sự kiện, còn server access log chỉ trả tiền lưu
trữ, nên đề nhấn "cost-effective" cho một bucket cực lớn sẽ nghiêng về access log.
**Ba**, độ trễ và độ tin cậy: server access log là best-effort và có thể trễ hàng
giờ, nên nó không dùng được cho điều tra sự cố.

</details>

**5.** Đề cho "the solution must handle 5 million requests per second" và bốn đáp
án lần lượt dùng ALB, NLB, API Gateway, CloudFront. Con số đó loại được gì?

<details><summary>Đáp án</summary>

Nó loại các phương án phải **giữ trạng thái ở lớp 7** cho từng request. ALB xử lý
được lượng lớn nhưng phải được warm-up và tính tiền theo LCU với chiều hướng đắt
ở quy mô này; API Gateway có throttle mặc định ở mức hàng chục nghìn request mỗi
giây và phải xin tăng quota. NLB hoạt động ở lớp 4, xử lý hàng triệu request mỗi
giây mà không cần warm-up. CloudFront cũng đạt được nếu nội dung cache được — nên
câu quyết định tiếp theo là *"nội dung có cache được không?"*. Cache được thì
CloudFront thắng vì phần lớn request không chạm origin; không cache được thì NLB.

</details>

**6.** Vì sao cụm "without traversing the public internet" gần như luôn dẫn tới
VPC endpoint, kể cả khi trong đáp án có NAT Gateway kèm chữ "private"?

<details><summary>Đáp án</summary>

NAT Gateway vẫn gửi gói **ra internet công cộng** — nó chỉ giấu IP riêng của
instance sau một IP công cộng. Instance ở private subnet gọi `s3.amazonaws.com`
qua NAT thì gói đi qua Internet Gateway và ra ngoài thật. VPC endpoint thì khác:
Gateway Endpoint chèn một prefix list vào route table để traffic tới S3 và DynamoDB
đi trong mạng AWS, còn Interface Endpoint dựng một ENI có IP riêng ngay trong subnet
của bạn. Chữ "private" trong "private subnet" nói về **địa chỉ**, không nói về
**đường đi** — đó chính là chỗ đề gài.

</details>
