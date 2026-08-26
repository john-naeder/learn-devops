# Bảng so sánh — mọi cặp dễ nhầm, gom một chỗ

> **Tra nhanh:** bạn đã còn đúng hai đáp án và cần một dòng để chốt. Cột cuối mỗi
> bảng là **từ trong đề** dùng để phân biệt — đó là thứ làm bảng này khác một bảng
> thuộc tính.

`Domain 1 · Secure (30%)` · `Domain 2 · Resilient (26%)` · `Domain 3 · High-Performing (24%)` · `Domain 4 · Cost-Optimized (20%)`

Mọi bảng đều **hàng là lựa chọn, cột cuối là từ khoá phân biệt**. Đọc từ phải sang
trái sẽ nhanh hơn: tìm cụm mà đề vừa dùng, rồi nhìn sang tên ở đầu hàng.

Con số tính đến **2026-08**. Chỗ nào nguồn `aws-saa-c03/` nói khác, xem
[Nguồn nói khác](#nguồn-nói-khác).

---

## Bản đồ

| Nhóm | Bảng |
|---|---|
| [Compute](#compute) | [EC2 · Lambda · Fargate](#ec2--lambda--fargate) · [ECS · EKS](#ecs--eks) |
| [Storage](#storage) | [S3 · EBS · EFS · FSx · instance store](#s3--ebs--efs--fsx--instance-store) · [S3 storage class](#s3-storage-class) · [EBS volume type](#ebs-volume-type) |
| [Database](#database) | [Multi-AZ · read replica](#rds-multi-az--read-replica) · [RDS · Aurora · DynamoDB](#rds--aurora--dynamodb) · [Redis · Memcached](#redis--memcached) · [DAX · ElastiCache](#dax--elasticache) |
| [Networking](#networking) | [SG · NACL](#security-group--nacl) · [ALB · NLB · GWLB](#alb--nlb--gwlb) · [CloudFront · Global Accelerator](#cloudfront--global-accelerator) · [VPN · Direct Connect](#vpn--direct-connect) · [Gateway · Interface endpoint](#gateway-endpoint--interface-endpoint) |
| [Tích hợp](#tích-hợp) | [SQS · SNS · EventBridge · Kinesis](#sqs--sns--eventbridge--kinesis) · [SQS Standard · FIFO](#sqs-standard--sqs-fifo) · [Step Functions Standard · Express](#step-functions-standard--express) · [API Gateway REST · HTTP](#api-gateway-rest-api--http-api) |
| [Giám sát](#giám-sát) | [CloudTrail · CloudWatch · Config](#cloudtrail--cloudwatch--config) |
| [Bảo mật](#bảo-mật) | [IAM user · role · group](#iam-user--role--group) · [Secrets Manager · Parameter Store](#secrets-manager--parameter-store) · [KMS · CloudHSM](#kms--cloudhsm) · [SSE-S3 · SSE-KMS · SSE-C](#sse-s3--sse-kms--sse-c) · [Cognito user pool · identity pool](#cognito-user-pool--identity-pool) · [SCP · IAM policy · permission boundary](#scp--iam-policy--permission-boundary) |
| [Di trú và IaC](#di-trú-và-iac) | [DataSync · Storage Gateway · Snow](#datasync--storage-gateway--snow) · [CloudFormation · Terraform](#cloudformation--terraform) |

Ba mục cuối: [Bảng số phải nhớ](#bảng-số-phải-nhớ), [Bẫy đề thi](#bẫy-đề-thi),
[Tự kiểm tra](#tự-kiểm-tra).

---

## Compute

### EC2 · Lambda · Fargate

| | Đơn vị bạn quản | Trần cứng | Cách tính tiền | Thời gian có máy mới | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **EC2** | OS, patch, agent, dung lượng | không có trần thời gian chạy | theo giây (tối thiểu 60 giây với Linux) khi instance đang chạy | 1–3 phút qua ASG | "full control", "lift and shift", "licensed software", "kernel module", "GPU" |
| **Lambda** | chỉ mã nguồn | 15 phút, 10 GB RAM, 10 GB `/tmp`, gói 250 MB giải nén, payload đồng bộ 6 MB | theo GB-giây + số lần gọi; idle không mất tiền | mili-giây (cold start: chục ms tới vài giây) | "event-driven", "pay per invocation", "runs a few times an hour", "no capacity to manage" |
| **Fargate** | image và task definition | 16 vCPU, 120 GB RAM, 200 GB đĩa tạm; không có GPU | theo vCPU-giây và GB-giây khi task đang chạy | vài chục giây | "already containerized", "no servers to patch", "long-running container" |

Vì sao ba cái này bị trộn: cả ba đều "chạy code của bạn". Ranh giới thật là **thời
gian một lần chạy** và **ai chịu trách nhiệm cho OS**. Xem
[cây chọn compute](20-cay-quyet-dinh.md#1-chọn-compute).

### ECS · EKS

| | Mặt phẳng điều khiển | Quyền cho từng workload | Chi phí control plane | Khi nào nó là đáp án | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **ECS** | AWS tự lo, khái niệm riêng của AWS (cluster, service, task) | IAM task role — gắn thẳng, không cần add-on | miễn phí | team chưa dùng Kubernetes, muốn ít khái niệm nhất | "simplest way to run containers", "deeply integrated with AWS", "no Kubernetes experience" |
| **EKS** | Kubernetes API do AWS vận hành | IRSA hoặc EKS Pod Identity — phải cấu hình OIDC | tính theo giờ mỗi cluster | đã có manifest/Helm, cần chạy giống on-prem hoặc cloud khác | "existing Kubernetes manifests", "Helm", "portable across clouds", "CRD", "operator" |

Vì sao ranh giới không phải hiệu năng: cả hai chạy trên cùng EC2 hoặc Fargate.
Ranh giới là **hệ sinh thái công cụ đã có sẵn** của đội.

---

## Storage

### S3 · EBS · EFS · FSx · instance store

| | Giao diện | Ai gắn được | Phạm vi hỏng | Dung lượng | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **S3** | HTTP API (object) | mọi thứ có credential | nhiều AZ | không giới hạn; object tối đa 5 TB | "objects", "static website", "data lake", "backup", "publicly accessible" |
| **EBS** | block device | một instance (io2 Multi-Attach: 16 instance cùng AZ) | một AZ | 64 TiB mỗi volume | "attached to the instance", "boot volume", "database on EC2", "IOPS" |
| **EFS** | NFS v4 | nhiều instance, nhiều AZ, cả on-prem qua DX/VPN | nhiều AZ (One Zone: một AZ) | tự co giãn, petabyte | "shared file system", "POSIX", "multiple instances read and write", "Linux" |
| **FSx** | SMB, Lustre, NFS, iSCSI tuỳ bản | nhiều client | tuỳ bản, có Multi-AZ | tới petabyte | "Windows", "Active Directory", "SMB", "HPC", "Lustre", "NetApp" |
| **Instance store** | block device gắn thẳng vào máy chủ vật lý | đúng một instance | mất khi stop hoặc terminate | theo instance type | "temporary", "scratch", "cache", "buffer", "highest IOPS" |

Vì sao đây là bảng quan trọng nhất của Domain 3: chọn sai loại storage thì mọi
tối ưu phía sau đều vô nghĩa. Câu hỏi phân biệt là **ứng dụng nói giao thức gì**.

### S3 storage class

| | Số AZ | Thời gian lưu tối thiểu | Kích thước tính tiền tối thiểu | Thời gian lấy ra | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Standard** | ≥ 3 | không | không | mili-giây | "frequently accessed", "active" |
| **Intelligent-Tiering** | ≥ 3 | không | không (object < 128 KB không được tự tier) | mili-giây | "unknown", "changing", "unpredictable access pattern" |
| **Standard-IA** | ≥ 3 | 30 ngày | 128 KB | mili-giây | "infrequently accessed but needs immediate access" |
| **One Zone-IA** | 1 | 30 ngày | 128 KB | mili-giây | "can be recreated", "non-critical", "secondary copy" |
| **Glacier Instant Retrieval** | ≥ 3 | 90 ngày | 128 KB | mili-giây | "archive" **và** "immediate retrieval", "once a quarter" |
| **Glacier Flexible Retrieval** | ≥ 3 | 90 ngày | 40 KB | 1–5 phút (expedited), 3–5 giờ (standard), 5–12 giờ (bulk, miễn phí) | "archive", "retrieval within hours is acceptable" |
| **Glacier Deep Archive** | ≥ 3 | 180 ngày | 40 KB | 12 giờ (standard), 48 giờ (bulk) | "7 years", "10 years", "regulatory retention", "rarely if ever accessed" |

Vì sao ba con số cột giữa quyết định nhiều hơn giá lưu trữ: xoá trước hạn vẫn bị
tính đủ, và object nhỏ bị làm tròn lên. Một bucket đầy file 5 KB chuyển sang IA
sẽ **đắt hơn** Standard.

### EBS volume type

| | IOPS tối đa | Throughput tối đa | Dung lượng | Độ bền | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **gp3** | 80.000 (baseline 3.000) | 2.000 MiB/s (baseline 125) | 1 GiB – 64 TiB | 99,8–99,9% | mặc định cho mọi thứ; "cost-effective", "general purpose", "boot volume" |
| **gp2** | 16.000 (3 IOPS mỗi GiB) | 250 MiB/s | 1 GiB – 16 TiB | 99,8–99,9% | chỉ xuất hiện như thứ **cần thay bằng gp3** |
| **io1** | 64.000 (50:1) | 1.000 MiB/s | 4 GiB – 16 TiB | 99,8–99,9% | "legacy provisioned IOPS" |
| **io2 Block Express** | 256.000 (1.000:1) | 4.000 MiB/s | 4 GiB – 64 TiB | **99,999%** | "mission critical", "sub-millisecond", "highest durability", "SAP HANA", "Oracle" |
| **st1** | 500 | 500 MiB/s | 125 GiB – 16 TiB | 99,8–99,9% | "large sequential", "big data", "log processing" — **không dùng làm boot volume** |
| **sc1** | 250 | 250 MiB/s | 125 GiB – 16 TiB | 99,8–99,9% | "cold", "lowest cost per GB", "accessed a few times a month" |

Vì sao gp3 gần như luôn đúng: nó tách IOPS khỏi dung lượng, rẻ hơn gp2 khoảng 20%
mỗi GiB, và trần 80.000 IOPS đã phủ gần hết workload trong đề. Chỉ nhảy sang io2
khi đề nói **sub-millisecond**, **99,999% durability**, hoặc con số IOPS vượt 80.000.

---

## Database

### RDS Multi-AZ · read replica

| | Kiểu sao chép | Standby phục vụ đọc | Chuyển đổi khi hỏng | Xuyên Region | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Multi-AZ (một standby)** | **đồng bộ** | không | **tự động**, 60–120 giây, endpoint không đổi | không | "automatic failover", "high availability", "no data loss", "minimal downtime" |
| **Multi-AZ DB cluster (hai standby đọc được)** | đồng bộ | có | tự động, thường dưới 35 giây | không | "readable standbys", "faster failover" |
| **Read replica** | **bất đồng bộ** | có (endpoint riêng) | **thủ công** — phải promote | có | "offload read traffic", "reporting queries", "read scaling", "replica in another Region" |

Vì sao đây là cặp bị đổi chỗ nhiều nhất trong đề: cả hai đều "tạo thêm một bản
database". Nhưng Multi-AZ giải bài toán **sống sót**, read replica giải bài toán
**hiệu năng đọc**. Đề nào có cả hai yêu cầu thì đáp án là **cả hai**, hoặc Aurora —
vì Aurora replica vừa phục vụ đọc vừa là ứng viên failover.

### RDS · Aurora · DynamoDB

| | Mô hình dữ liệu | Ghi | Đọc mở rộng bằng | Dung lượng | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **RDS** | quan hệ, 6 engine (MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Db2) | một writer, scale dọc | 5–15 read replica tuỳ engine | 64 TiB (SQL Server 16 TiB) | "must use Oracle", "SQL Server", "existing MySQL version", "specific engine" |
| **Aurora** | quan hệ, tương thích MySQL và PostgreSQL | một writer, storage tự co giãn | tới 15 Aurora replica, chung một tầng storage | 128 TiB | "MySQL-compatible", "5x throughput", "fast cloning", "Global Database", "serverless" |
| **DynamoDB** | key-value và document | không trần, phân mảnh theo partition key | tự động; thêm DAX nếu cần micro-giây | không giới hạn | "single-digit millisecond at any scale", "millions of requests", "key lookups", "no schema" |

Vì sao ranh giới không phải "SQL hay NoSQL": ranh giới là **access pattern có cố
định không**. DynamoDB scale vô hạn vì nó từ chối truy vấn tuỳ hứng.

### Redis · Memcached

| | Cấu trúc dữ liệu | Bền vững và bản sao | Failover | Mở rộng | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Redis (và Valkey)** | string, hash, list, set, sorted set, stream, pub/sub, Lua | có snapshot, có replica, có Multi-AZ | tự động | cluster mode: shard + replica | "leaderboard", "pub/sub", "persistence", "replication", "geospatial", "Multi-AZ cache" |
| **Memcached** | chỉ key-value dạng chuỗi | **không** có bản sao, mất node là mất dữ liệu | không | thêm hoặc bớt node, đa luồng trên một node | "simplest caching model", "scale out and in", "multi-threaded", "cache can be lost" |

Vì sao đề vẫn hỏi Memcached dù Redis mạnh hơn mọi mặt: đề dùng nó để kiểm tra bạn
có đọc kỹ chữ **"data can be lost without impact"** hay không.

### DAX · ElastiCache

| | Cache cái gì | Phải sửa code không | Độ trễ đọc trúng cache | Ghi | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **DAX** | chỉ DynamoDB (item cache và query cache) | đổi client sang DAX SDK; API giữ nguyên | micro-giây | write-through, ghi thẳng qua DynamoDB | "DynamoDB" **và** "microsecond", "read-heavy DynamoDB table" |
| **ElastiCache** | bất kỳ dữ liệu gì bạn tự đặt vào | có — phải viết logic cache-aside hoặc write-through | sub-mili-giây | do bạn quyết định | "cache database query results", "session store", "rate limiting", "any data source" |

Vì sao DAX không thay được ElastiCache và ngược lại: DAX **hiểu** giao thức
DynamoDB nên trong suốt với ứng dụng DynamoDB; ElastiCache là một kho key-value
trống, ứng dụng phải tự biết khi nào hỏi nó.

---

## Networking

### Security Group · NACL

| | Gắn ở đâu | Có trạng thái | Có luật DENY | Cách duyệt luật | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Security Group** | ENI của từng tài nguyên | **stateful** — trả lời tự động được cho qua | **không**, chỉ ALLOW | duyệt toàn bộ, hợp nhất mọi rule | "allow traffic from the web tier", "reference another security group" |
| **NACL** | subnet | **stateless** — phải mở cả chiều về, kể cả ephemeral port 1024–65535 | **có** | theo số thứ tự, dừng ở luật khớp đầu tiên | "block a specific IP range", "deny", "subnet level", "additional layer" |

Vì sao đây là câu hỏi Domain 1 kinh điển: chỉ có một trong hai chặn được, và chỉ
có một trong hai tham chiếu được tới nhóm khác. Đề hỏi "block" thì gần như luôn
là NACL — hoặc WAF nếu là tầng ứng dụng.

### ALB · NLB · GWLB

| | Lớp | Giao thức | IP tĩnh | Giữ IP nguồn | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **ALB** | 7 | HTTP, HTTPS, gRPC, WebSocket | không | không — dùng `X-Forwarded-For` | "path-based", "host-based", "header", "cookie", "WAF", "Lambda target", "redirect" |
| **NLB** | 4 | TCP, UDP, TLS | **có**, một IP mỗi AZ, gán được Elastic IP | có (target theo instance ID; target theo IP với TCP/TLS thì phải bật) | "static IP", "millions of requests per second", "extreme low latency", "PrivateLink", "UDP", "preserve the source IP" |
| **GWLB** | 3 và 4 | mọi IP traffic, bọc trong GENEVE cổng 6081 | không áp dụng | có — appliance thấy gói nguyên bản | "third-party firewall", "IDS/IPS", "inline inspection", "transparent appliance" |

Vì sao CLB gần như luôn là mồi: nó chỉ đúng khi đề nói **"legacy"** hoặc nhắc
EC2-Classic. Nếu đề mô tả yêu cầu hiện đại nào đó, CLB thiếu tính năng ấy.

### CloudFront · Global Accelerator

| | Lớp | Có cache | Địa chỉ | Origin hoặc endpoint | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **CloudFront** | 7 (HTTP/HTTPS) | **có** — đây là lý do nó tồn tại | tên miền, không có IP tĩnh | S3, ALB, EC2, bất kỳ HTTP origin nào | "static content", "video streaming", "cache at the edge", "WAF at the edge", "signed URL", "OAC" |
| **Global Accelerator** | 4 (TCP/UDP) | không | **2 anycast IP tĩnh** toàn cầu | ALB, NLB, EC2, Elastic IP ở nhiều Region | "non-HTTP", "gaming", "VoIP", "IoT", "static anycast IP", "instant regional failover", "multi-Region active-active" |

Vì sao chọn nhầm rất tốn điểm: cả hai đều "tăng tốc cho người dùng toàn cầu".
Câu phân biệt là *"nội dung có lặp lại để cache không?"* và *"có cần IP tĩnh không?"*.

### VPN · Direct Connect

| | Đường truyền | Băng thông | Mã hoá | Thời gian có | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Site-to-Site VPN** | internet công cộng | 1,25 Gbps mỗi tunnel, 2 tunnel mỗi kết nối | IPsec sẵn có | vài chục phút | "quickly", "temporary", "backup connection", "encrypted over the internet", "low cost" |
| **Direct Connect** | cáp riêng tới một DX location | dedicated 1/10/100 Gbps; hosted 50 Mbps – 25 Gbps | **không** mặc định — thêm IPsec trên DX hoặc MACsec | tuần đến tháng | "consistent latency", "predictable bandwidth", "dedicated", "reduce data transfer cost", "large sustained transfer" |

Vì sao đáp án hay là **cả hai**: "highly available hybrid connectivity" với ràng
buộc chi phí thì mẫu chuẩn là DX làm chính, VPN làm dự phòng. Bỏ ràng buộc chi phí
thì là hai DX ở hai location.

### Gateway endpoint · Interface endpoint

| | Dịch vụ hỗ trợ | Hình thức | Chi phí | Dùng được từ on-prem | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Gateway endpoint** | **chỉ S3 và DynamoDB** | prefix list trong route table, không có ENI | **miễn phí** | **không** | "S3", "DynamoDB", "no additional cost", "without an internet gateway" |
| **Interface endpoint (PrivateLink)** | hầu hết dịch vụ AWS, và service của bên thứ ba | ENI có IP riêng trong subnet của bạn | theo giờ mỗi AZ + theo GB | **có**, qua DX hoặc VPN | "from on-premises", "SSM", "Secrets Manager", "KMS", "SaaS partner", "private DNS" |

Vì sao đề rất thích cặp này: nó kiểm tra hai thứ cùng lúc — bạn có nhớ Gateway
endpoint chỉ phục vụ hai dịch vụ không, và bạn có đọc thấy chữ "from on-premises"
không. Interface endpoint cho S3 **có tồn tại** và đúng khi truy cập từ on-prem;
từ trong VPC mà đề nhấn cost thì Gateway endpoint thắng.

---

## Tích hợp

### SQS · SNS · EventBridge · Kinesis

| | Mô hình | Dữ liệu còn sau khi xử lý | Đảm bảo giao | Kích thước tối đa | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **SQS** | hàng đợi, consumer kéo về | **không** — consumer gọi `DeleteMessage` | at-least-once (Standard), exactly-once trong 5 phút khử trùng lặp (FIFO) | 256 KB | "decouple", "buffer", "worker pool", "process each message once" |
| **SNS** | pub/sub, đẩy tới subscriber | không lưu | at-least-once; subscriber chết thì retry rồi vào DLQ | 256 KB | "notify multiple systems", "fan-out", "SMS", "email", "push notification" |
| **EventBridge** | bus sự kiện, rule lọc theo **nội dung** | không lưu (archive và replay là tính năng riêng) | at-least-once, retry tới 24 giờ | 256 KB | "route based on event content", "SaaS integration", "schedule", "schema registry", "without changing producers" |
| **Kinesis Data Streams** | log có thứ tự theo shard | **còn** trong 24 giờ đến 365 ngày | at-least-once; thứ tự đảm bảo trong một shard | 1 MB mỗi record | "multiple independent consumers", "replay", "ordered by partition", "clickstream", "time window" |

Vì sao câu "real-time" không phân biệt được gì: cả bốn đều trả về trong mili-giây.
Câu phân biệt là **"dữ liệu còn lại cho ai khác đọc không"** và **"ai quyết định
ai nhận"**. Xem [cây chọn messaging](20-cay-quyet-dinh.md#5-chọn-cơ-chế-messaging).

### SQS Standard · SQS FIFO

| | Thứ tự | Trùng lặp | Thông lượng | Ràng buộc | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Standard** | best-effort, có thể đảo | có thể trùng — consumer phải idempotent | không trần | không | "high throughput", "order does not matter", "at-least-once is acceptable" |
| **FIFO** | đúng thứ tự trong mỗi `MessageGroupId` | khử trùng lặp trong cửa sổ 5 phút bằng `MessageDeduplicationId` | 300 TPS mỗi API action, 3.000 với batch, tới 70.000 khi bật high throughput mode | tên queue phải kết thúc bằng `.fifo` | "exactly once", "in the exact order", "financial transactions", "command sequence" |

Vì sao con số 300 hay bị dùng sai: nó là trần **mặc định**, không phải trần tuyệt
đối. Đề nói "ordered processing at 20,000 messages per second" thì FIFO vẫn khả thi
với high throughput mode — đáp án "phải bỏ thứ tự" là mồi.

### Step Functions Standard · Express

| | Thời gian tối đa | Ngữ nghĩa thực thi | Cách tính tiền | Lịch sử thực thi | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Standard** | 1 năm | exactly-once | theo số **state transition** | xem trực tiếp trong console, giữ 90 ngày | "human approval", "wait for hours", "audit each step", "long-running workflow" |
| **Express** | 5 phút | at-least-once | theo số lần chạy + thời gian + bộ nhớ | phải gửi sang CloudWatch Logs | "high volume", "hundreds of thousands per second", "event processing", "short-lived" |

Vì sao đây là câu hỏi về **giá** nhiều hơn về kỹ thuật: Standard tính tiền mỗi
bước, nên workflow 20 bước chạy hàng triệu lần sẽ rất đắt. Express đảo mô hình giá.

### API Gateway REST API · HTTP API

| | Tính năng đặc trưng | Xác thực | Giá tương đối | Hạn chế | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **REST API** | cache, usage plan và API key, request/response validation và transform, private API trong VPC, canary deployment, WAF | IAM, Cognito, Lambda authorizer, resource policy | đắt hơn | nhiều tính năng hơn nghĩa là nhiều thứ phải cấu hình hơn | "API keys", "usage plans", "rate limit per customer", "caching", "private API", "AWS WAF", "request validation" |
| **HTTP API** | tối giản, độ trễ thấp hơn, CORS và JWT có sẵn | IAM, JWT/OIDC, Lambda authorizer | rẻ hơn đáng kể | **không** có cache, usage plan, hay tích hợp WAF trực tiếp | "lowest cost", "simple proxy to Lambda", "JWT from an OIDC provider", "minimal features" |

Vì sao đề hay gài: "cost-effective API" nghe như HTTP API, nhưng nếu cùng câu có
"throttle per customer" hoặc "cache responses" thì ràng buộc thắng và đáp án là REST.

---

## Giám sát

### CloudTrail · CloudWatch · Config

| | Ghi lại cái gì | Câu hỏi nó trả lời | Lưu ở đâu | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|
| **CloudTrail** | lệnh gọi API: ai, lúc nào, từ đâu, thành công hay không | "**ai đã làm** việc này" | 90 ngày trong Event history; lâu hơn thì gửi sang S3 hoặc CloudTrail Lake | "audit", "who deleted", "API activity", "compliance evidence", "unauthorized API call" |
| **CloudWatch** | metric, log, alarm, dashboard | "hệ thống đang **chạy thế nào**" | Logs group, Metrics 15 tháng | "monitor", "alarm", "CPU utilization", "custom metric", "scale when", "log query" |
| **Config** | ảnh chụp cấu hình tài nguyên theo thời gian + đánh giá tuân thủ | "tài nguyên này **từng như thế nào**, và nó có đúng chuẩn không" | S3 + timeline trong console | "configuration history", "compliance rule", "was this bucket ever public", "detect drift", "remediate automatically" |

Vì sao ba cái bị trộn: cả ba đều "ghi lại thứ gì đó". Mẹo nhớ: **CloudTrail ghi
động từ, Config ghi tính từ, CloudWatch ghi con số.**

X-Ray là cái thứ tư hay xuất hiện cùng: nó trả lời "**request này đi qua những
service nào và chậm ở đâu**" — thấy chữ "distributed tracing" hoặc "which
microservice is the bottleneck" thì là X-Ray.

---

## Bảo mật

### IAM user · role · group

| | Có credential dài hạn | Ai dùng được | Có phải principal không | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|
| **User** | có (mật khẩu, access key) | một con người hoặc một ứng dụng cũ | có | "individual person", "console login", "long-term access key" — thường là **đáp án sai** |
| **Group** | không | chỉ là cái túi đựng user | **không** — không đặt được vào trường `Principal` | "apply the same permissions to many developers" |
| **Role** | **không** — nhận credential tạm qua STS | EC2, Lambda, ECS, account khác, người dùng liên kết | có | "EC2 needs to access S3", "cross-account", "temporary credentials", "federated users", "third party" |

Vì sao role gần như luôn là đáp án đúng khi đề có chữ "most secure": credential
tạm hết hạn tự động, không nằm trong file cấu hình, và xoay vòng mà không ai phải làm gì.

### Secrets Manager · Parameter Store

| | Tự xoay vòng | Kích thước | Chi phí | Tính năng riêng | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Secrets Manager** | **có** — Lambda rotation, tích hợp sẵn với RDS, Redshift, DocumentDB | 64 KB | tính tiền mỗi secret mỗi tháng + mỗi lần gọi API | resource policy cho cross-account, tạo được mật khẩu ngẫu nhiên | "automatically rotate", "database credentials", "cross-account secret" |
| **Parameter Store** | không (phải tự dựng bằng EventBridge + Lambda) | 4 KB standard, 8 KB advanced | Standard **miễn phí** | phân cấp theo đường dẫn, tham chiếu được từ CloudFormation | "configuration values", "no rotation needed", "lowest cost", "hierarchy of parameters" |

Vì sao đề gài bằng chữ "cost-effective": Parameter Store Standard miễn phí, nên
nếu đề **không** đòi rotation thì Secrets Manager là đáp án đắt không cần thiết.

### KMS · CloudHSM

| | Ai vận hành HSM | Tính thuê chung | Tích hợp dịch vụ AWS | Nếu mất key | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **KMS** | AWS | multi-tenant | gần như mọi dịch vụ, bật một nút | AWS vẫn giữ được bản sao trong vòng chờ xoá 7–30 ngày | "encrypt at rest", "audit key usage", "rotate the key", "control who can use the key" |
| **CloudHSM** | **bạn** | **single-tenant**, cluster riêng | phải tự tích hợp, hoặc dùng làm custom key store cho KMS | mất thật, AWS không vào được | "FIPS 140-3 Level 3", "single-tenant HSM", "AWS must not have access", "we manage the cluster", "SQL Server TDE with our own HSM" |

Vì sao CloudHSM hiếm khi là đáp án: nó chỉ đúng khi đề nói rõ **AWS không được
chạm vào key** hoặc nêu chuẩn FIPS cụ thể. Mọi câu "encrypt at rest" thông thường
đều là KMS.

### SSE-S3 · SSE-KMS · SSE-C

| | Ai giữ key | Audit từng lần dùng key | Đặt được policy trên key | Chi phí và giới hạn | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **SSE-S3** | S3 | không | không | miễn phí; mặc định cho object mới | "encrypt at rest" và không nói gì thêm |
| **SSE-KMS** | KMS (AWS managed hoặc customer managed) | **có**, qua CloudTrail | có, với customer managed key | tính tiền mỗi lần gọi KMS — bật S3 Bucket Keys để giảm | "audit", "rotate annually", "restrict who can decrypt", "separate key per team" |
| **SSE-C** | **bạn**, gửi kèm mỗi request | không | không áp dụng | bắt buộc HTTPS; mất key là mất dữ liệu | "we supply the key with each request", "AWS must not store the key" |

Vì sao đây là câu hỏi Domain 1 hay ra: bốn đáp án nghe giống nhau và chỉ một chữ
trong đề — "audit", "rotate", "we supply" — quyết định.

### Cognito user pool · identity pool

| | Nó tạo ra cái gì | Dùng để | Hỗ trợ khách vãng lai | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|
| **User pool** | JWT (id token, access token) | **xác thực**: đăng ký, đăng nhập, MFA, quên mật khẩu, liên kết với Google/Facebook/SAML | không | "sign-up and sign-in", "user directory", "MFA for app users", "authenticate against the API" |
| **Identity pool** | credential tạm của AWS qua STS | **uỷ quyền**: cho phép app gọi thẳng S3, DynamoDB với quyền theo từng user | **có** — unauthenticated identity | "access AWS resources directly from the mobile app", "temporary AWS credentials", "guest access" |

Vì sao hay bị nhầm: cả hai đều thuộc Cognito và thường dùng chung. Mẹo: **user
pool trả về token cho ứng dụng của bạn; identity pool đổi token đó lấy quyền vào AWS.**

### SCP · IAM policy · permission boundary

| | Gắn ở đâu | Cấp được quyền | Cắt được quyền | Ảnh hưởng tới root của account | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **Identity policy** | user, group, role | **có** | có (bằng Deny) | không | "grant the application permission to" |
| **Resource policy** | S3 bucket, KMS key, SQS, SNS, Lambda, ECR... | **có**, kể cả cross-account | có | không | "allow another account to read this bucket", "who can access this resource" |
| **Permission boundary** | user, role | không | **có** — đặt trần cho identity đó | không | "developers may create roles but never exceed", "safe delegation" |
| **SCP** | OU hoặc account trong Organizations | không | **có** — đặt trần cho cả account | **có** | "no account may disable CloudTrail", "restrict all accounts to specific Regions", "guardrail" |

Vì sao quy tắc một dòng đủ cho phần lớn câu hỏi: **explicit Deny thắng tất cả;
quyền hiệu lực là phần giao của mọi lớp; SCP và boundary chỉ cắt xuống, không bao
giờ cộng thêm.** Bỏ identity policy đi thì principal không làm được gì, dù SCP và
boundary có "Allow" rộng đến đâu.

---

## Di trú và IaC

### DataSync · Storage Gateway · Snow

| | Vai trò | Sau khi xong thì sao | Yêu cầu mạng | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|
| **DataSync** | công cụ **chuyển** dữ liệu, chạy theo lịch, tự kiểm tra toàn vẹn | hết việc; on-prem không còn vai trò | cần đường mạng đủ | "one-time or recurring transfer", "NFS to S3", "verify data integrity", "scheduled sync" |
| **Storage Gateway** | thành phần **hybrid thường trực**, đứng ở on-prem | vẫn chạy mãi; ứng dụng cũ tiếp tục đi qua nó | cần mạng nhưng có cache tại chỗ | "continue to access as a file share", "iSCSI volumes", "replace tape library", "low-latency access to recently used data" |
| **Snow (thiết bị vật lý)** | chuyển dữ liệu **ngoại tuyến** | thiết bị trả lại AWS | không cần mạng | "no or limited connectivity", "petabytes within weeks", "remote location" |

Vì sao câu phân biệt không phải dung lượng: dung lượng chỉ chọn giữa "qua mạng"
hay "qua thiết bị". Câu phân biệt DataSync với Storage Gateway là **"on-prem còn
đọc dữ liệu đó sau khi chuyển xong không"**.

### CloudFormation · Terraform

| | Ai vận hành state | Xử lý lỗi giữa chừng | Phạm vi | Vai trò trong đề SAA | Đề thi phân biệt bằng từ nào |
|---|---|---|---|---|---|
| **CloudFormation** | AWS giữ state trong stack | **tự rollback** về trạng thái trước | chỉ AWS; StackSets triển khai nhiều account và Region | đây là đáp án mặc định cho IaC | "AWS native", "no additional tooling", "roll back automatically", "deploy to many accounts and Regions" |
| **Terraform** | bạn giữ state file (S3 + khoá bằng DynamoDB) | dừng lại, để bạn quyết định | nhiều nhà cung cấp, kể cả SaaS | xuất hiện như "third-party IaC" | "multi-cloud", "existing Terraform modules", "the team already uses" |
| **CDK** | sinh ra CloudFormation | như CloudFormation | AWS | dùng ngôn ngữ lập trình thay vì YAML | "define infrastructure in TypeScript/Python" |

Vì sao SAA hỏi ít về Terraform: đề chỉ cần bạn biết CloudFormation là công cụ IaC
gốc của AWS và biết StackSets giải bài toán nhiều account. Trong repo này thì
ngược lại — lab dựng bằng Terraform, xem
[`learn-aws/labs/README.md`](../../learn-aws/labs/README.md).

---

## Bảng số phải nhớ

Chỉ những con số dùng để **chốt giữa hai đáp án** trong chính các bảng ở trên.

| Con số | Của cái gì |
|---|---|
| 15 phút / 10 GB RAM / 10 GB `/tmp` / 6 MB payload | trần cứng của Lambda |
| 16 vCPU / 120 GB RAM | trần của một task Fargate |
| 5 TB / 5 GB | object S3 lớn nhất / một lần PUT lớn nhất |
| 128 KB | kích thước tính tiền tối thiểu của S3 IA và Glacier Instant Retrieval |
| 40 KB | kích thước tính tiền tối thiểu của Glacier Flexible và Deep Archive |
| 30 / 90 / 180 ngày | thời gian lưu tối thiểu của IA / Glacier IR và Flexible / Deep Archive |
| 3.000 → 80.000 IOPS, 125 → 2.000 MiB/s | dải của gp3 |
| 256.000 IOPS / 4.000 MiB/s / 99,999% | io2 Block Express |
| 64 TiB | dung lượng tối đa một EBS volume (gp3, io2 Block Express) |
| 60–120 giây | thời gian failover của RDS Multi-AZ một standby |
| 15 | số Aurora replica tối đa |
| 128 TiB / 64 TiB | dung lượng Aurora / RDS |
| 400 KB | item DynamoDB lớn nhất |
| 256 KB | message SQS, SNS, EventBridge |
| 1 MB | record Kinesis lớn nhất |
| 300 / 3.000 / 70.000 TPS | SQS FIFO thường / có batch / high throughput mode |
| 5 phút | cửa sổ khử trùng lặp của SQS FIFO; cũng là trần của Step Functions Express |
| 1 năm | trần của Step Functions Standard |
| 29 giây | integration timeout mặc định của API Gateway |
| 24 giờ → 365 ngày | retention của Kinesis Data Streams |
| 14 ngày | retention tối đa của SQS |
| 1,25 Gbps | mỗi tunnel Site-to-Site VPN |
| 5 Gbps → 100 Gbps | NAT Gateway tự co giãn |
| 6081 | cổng GENEVE của GWLB |
| 1024–65535 | dải ephemeral port phải mở ở NACL cho chiều về |

---

## Bẫy đề thi

**Bẫy 1 — đọc bảng theo cột "tính năng" thay vì cột "từ khoá"**
Đề: "which service should the company use". Mồi: chọn cái nhiều tính năng nhất. Đúng: cái khớp với ràng buộc trong đề.
Vì sao: mọi bảng ở trên đều có một hàng "mạnh hơn" — Redis mạnh hơn Memcached, REST API nhiều tính năng hơn HTTP API, io2 nhanh hơn gp3. Đề chấm điểm ở chỗ bạn có nhận ra rằng **không phải câu nào cũng cần cái mạnh hơn**.

**Bẫy 2 — quên rằng NACL là stateless**
Đề: đã cho phép HTTP vào ở NACL nhưng client vẫn treo. Mồi: kiểm tra Security Group. Đúng: mở dải ephemeral port 1024–65535 cho chiều outbound của NACL.
Vì sao: Security Group tự nhớ kết nối, NACL thì không. Đây là câu hỏi "vì sao nó không chạy" hay gặp nhất.

**Bẫy 3 — chọn Interface endpoint cho S3 khi đang ở trong VPC**
Đề: instance private ghi vào S3, "most cost-effective", "must not use the internet". Mồi: Interface endpoint. Đúng: Gateway endpoint.
Vì sao: Gateway endpoint miễn phí và làm đúng việc đó. Interface endpoint cho S3 chỉ cần khi truy cập **từ on-premises**.

**Bẫy 4 — coi read replica là giải pháp HA**
Đề: "the database must fail over automatically". Mồi: thêm read replica ở AZ khác. Đúng: Multi-AZ.
Vì sao: replica dùng sao chép bất đồng bộ và phải promote bằng tay — hai điều kiện đều mâu thuẫn với chữ "automatically".

**Bẫy 5 — dùng SQS FIFO rồi kết luận không đủ throughput**
Đề: "process transactions in order at 20,000 messages per second". Mồi: bỏ yêu cầu thứ tự và dùng Standard. Đúng: FIFO với high throughput mode.
Vì sao: 300 TPS là mặc định, không phải trần. High throughput mode đạt tới 70.000 TPS mỗi API action.

**Bẫy 6 — chọn Secrets Manager cho dữ liệu không phải secret**
Đề: lưu vài trăm giá trị cấu hình cho ứng dụng, "lowest cost". Mồi: Secrets Manager. Đúng: Parameter Store Standard.
Vì sao: Secrets Manager tính tiền mỗi secret mỗi tháng; Parameter Store Standard miễn phí. Chỉ trả tiền khi bạn thật sự cần **rotation**.

---

## Cây quyết định

Bảng nói "khác nhau chỗ nào". Cây nói "đi đường nào tới đó". Khi bạn còn **ba**
đáp án trở lên thì dùng cây trước, rồi mới quay lại bảng để chốt hai cái cuối.

| Còn phân vân giữa | Mở |
|---|---|
| EC2, Lambda, Fargate, ECS, EKS | [cây chọn compute](20-cay-quyet-dinh.md#1-chọn-compute) |
| S3 class, EBS type, EFS, FSx | [cây chọn storage](20-cay-quyet-dinh.md#3-chọn-storage) |
| RDS, Aurora, DynamoDB, Redshift | [cây chọn database](20-cay-quyet-dinh.md#4-chọn-database) |
| SQS, SNS, EventBridge, Kinesis, Step Functions | [cây chọn messaging](20-cay-quyet-dinh.md#5-chọn-cơ-chế-messaging) |
| ALB, NLB, GWLB, CLB | [cây chọn load balancer](20-cay-quyet-dinh.md#6-chọn-load-balancer) |
| NAT, endpoint, PrivateLink | [cây cho private subnet ra ngoài](20-cay-quyet-dinh.md#7-chọn-cách-cho-private-subnet-ra-ngoài) |
| VPN, DX, TGW, peering | [cây kết nối hybrid](20-cay-quyet-dinh.md#8-chọn-cách-kết-nối-hybrid) |
| DataSync, Storage Gateway, Snow, DMS | [cây chuyển dữ liệu](20-cay-quyet-dinh.md#9-chọn-cách-chuyển-dữ-liệu-khối-lượng-lớn) |
| SSE-S3, SSE-KMS, SSE-C, CloudHSM | [cây chọn cơ chế mã hoá](20-cay-quyet-dinh.md#13-chọn-cơ-chế-mã-hoá) |

Không nhớ nổi đề đang thuộc nhóm nào thì quay về
[`21-tu-khoa-de-thi.md`](21-tu-khoa-de-thi.md).

---

## Nối với thực hành

Một bảng chỉ thành kiến thức khi bạn từng thấy cột bên phải **sai** trên máy thật.

| Bảng | Lab | Việc làm cho bảng dính vào đầu |
|---|---|---|
| [SG · NACL](#security-group--nacl) | [`w02-vpc-networking`](../../learn-aws/labs/w02-vpc-networking/) | chặn một IP bằng SG cho tới lúc tin rằng không có Deny; rồi mở NACL mà quên ephemeral port |
| [Gateway · Interface endpoint](#gateway-endpoint--interface-endpoint) | [`w02-vpc-networking`](../../learn-aws/labs/w02-vpc-networking/) | vào instance bằng SSM qua Interface Endpoint, rồi `aws s3 ls` qua Gateway Endpoint |
| [ALB · NLB · GWLB](#alb--nlb--gwlb) | [`w03-ec2-alb-asg`](../../learn-aws/labs/w03-ec2-alb-asg/) | in `X-Forwarded-For` ra log, so với IP thật |
| [S3 storage class](#s3-storage-class) | [`w04-s3-cloudfront`](../../learn-aws/labs/w04-s3-cloudfront/) | đặt lifecycle, đợi object đổi class, thử xoá sớm |
| [Multi-AZ · read replica](#rds-multi-az--read-replica) | [`w05-databases`](../../learn-aws/labs/w05-databases/) | bật RDS hai tiếng, ép failover, bấm giờ |
| [SQS · SNS · EventBridge · Kinesis](#sqs--sns--eventbridge--kinesis) | [`w07-decoupling`](../../learn-aws/labs/w07-decoupling/) | SNS fan-out ra hai queue, giết một consumer, xem DLQ |
| [CloudFront · Global Accelerator](#cloudfront--global-accelerator) | [`w08-dns-cdn-edge`](../../learn-aws/labs/w08-dns-cdn-edge/) | đổi cache key và xem tỉ lệ hit đảo chiều |
| [SCP · IAM policy · permission boundary](#scp--iam-policy--permission-boundary) | [`w09-security-deep`](../../learn-aws/labs/w09-security-deep/) | tự tay dựng một boundary rồi thử vượt rào |
| [CloudTrail · CloudWatch · Config](#cloudtrail--cloudwatch--config) | [`w10-observability-iac`](../../learn-aws/labs/w10-observability-iac/) | tìm một hành động của chính bạn trong cả ba nơi |

Lab tự viết không có lời giải: [`learn-aws/labs-self/CONVENTIONS.md`](../../learn-aws/labs-self/CONVENTIONS.md).

---

## Nguồn nói khác

`aws-saa-c03/Q-service-comparisons.md` và `aws-saa-c03/14-so-sanh-services.md` là
nguồn của phần lớn bảng ở đây. Các chỗ sai đã sửa:

| Nguồn nói | Thực tế (2026-08) | Bằng chứng |
|---|---|---|
| gp3: 16.000 IOPS, 1.000 MB/s, 16 TB | **80.000 IOPS, 2.000 MiB/s, 64 TiB** | [EBS General Purpose SSD](https://docs.aws.amazon.com/ebs/latest/userguide/general-purpose.html) |
| io2 và io2 Block Express là hai dòng riêng, io2 tối đa 64.000 IOPS | mọi volume io2 tạo sau 21-11-2023 đều **là** Block Express | [Provisioned IOPS SSD](https://docs.aws.amazon.com/ebs/latest/userguide/provisioned-iops.html) |
| Kinesis: "Duplicate Messages — Exactly-once (with processing)" | Kinesis Data Streams là **at-least-once**; exactly-once phải làm ở tầng ứng dụng | [Kinesis Data Streams](https://docs.aws.amazon.com/streams/latest/dev/kinesis-record-processor-duplicates.html) |
| EventBridge: "Message Retention — No retention" | EventBridge retry tới **24 giờ**, và có archive + replay | [EventBridge archive](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-archive.html) |
| Transit Gateway: "Bandwidth — 50 Gbps per AZ" | ~50 Gbps mỗi **VPC attachment** | [Transit Gateway quotas](https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-quotas.html) |
| SQS FIFO chỉ 300/3.000 TPS | high throughput mode đạt tới **70.000 TPS mỗi API action** | [SQS FAQs](https://aws.amazon.com/sqs/faqs/) |
| S3 Intelligent-Tiering có min duration 30 ngày | **không còn** min duration; object < 128 KB không bị tính phí monitoring và cũng không được tự tier | [S3 FAQs](https://aws.amazon.com/s3/faqs/) |
| "99.99% availability → Multi-AZ deployments, 4 nines SLA" (file M) | RDS Multi-AZ cam kết **tới 99,95%**; Aurora mới tới 99,99% | [RDS features](https://aws.amazon.com/rds/features/) |
| Snow Family là lựa chọn di trú mặc định | **Snowball Edge không còn nhận khách hàng mới** và AWS dừng hỗ trợ 31-12-2026; đề SAA-C03 vẫn hỏi | [Snowball Edge availability change](https://docs.aws.amazon.com/snowball/latest/developer-guide/snowball-edge-availability-change.html) |
| Bảng nào cũng thiếu cột "đề phân biệt bằng từ nào" | đã thêm vào mọi bảng — đó là điểm khác biệt của file này | |
| `aws-saa-c03/README.md` liệt kê F, G, H, I, J, N, O | bảy file không tồn tại; nội dung viết mới ở `10`–`13` | xem [`README.md`](README.md) |

---

## Ngoài phạm vi

- **FSx for OpenZFS và FSx for NetApp ONTAP chi tiết** — SAA chỉ cần "đa giao thức thì chọn ONTAP" → [FSx](https://docs.aws.amazon.com/fsx/).
- **Aurora Serverless v1** — đã bị thay bằng v2, đừng chọn nó → [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html).
- **KMS custom key store trên CloudHSM** — mức Security Specialty → [custom key store](https://docs.aws.amazon.com/kms/latest/developerguide/custom-key-store-overview.html).
- **Terraform state locking, workspace, module registry** — thuộc phần lab, không phải đề thi → [`learn-aws/labs/README.md`](../../learn-aws/labs/README.md).
- **Amazon MQ (ActiveMQ, RabbitMQ)** — chỉ cần nhớ: đề nói "existing JMS or AMQP application" thì là MQ, không phải SQS → [Amazon MQ](https://docs.aws.amazon.com/amazon-mq/).

---

## Tự kiểm tra

**1.** Đề mô tả một ứng dụng cần "the lowest possible cost per GB" cho 200 TB log
đọc khoảng một lần mỗi tháng. Vì sao Glacier Deep Archive có thể là đáp án sai dù
nó rẻ nhất trên bảng giá lưu trữ?

<details><summary>Đáp án</summary>

Vì "một lần mỗi tháng" nghĩa là bạn sẽ **lấy ra** 200 TB mười hai lần một năm, và
Deep Archive tính phí retrieval cao cùng thời gian chờ 12–48 giờ. Cộng phí lấy ra
vào thì tổng chi phí có thể vượt Standard-IA hoặc Glacier Instant Retrieval. Thêm
nữa, min duration 180 ngày phạt mọi object bị xoá sớm. Bài học chung: "rẻ nhất
trên bảng giá lưu trữ" và "rẻ nhất trong tổng chi phí" là hai câu hỏi khác nhau,
và đề luôn cho tần suất truy cập để bạn tính được điều đó.

</details>

**2.** Vì sao một NACL đã có rule cho phép inbound HTTP vẫn có thể làm client treo,
trong khi Security Group với đúng một rule inbound HTTP thì chạy được?

<details><summary>Đáp án</summary>

Security Group là **stateful**: nó ghi nhớ kết nối đi vào và tự cho phép gói trả
lời đi ra, bất kể rule outbound. NACL là **stateless**: mỗi chiều được đánh giá
độc lập. Gói trả lời của một phiên HTTP đi ra từ cổng 80 tới **ephemeral port**
của client, nằm trong dải 1024–65535. Nếu outbound rule của NACL không mở dải đó
thì gói trả lời bị chặn, client không nhận được gì và treo tới lúc timeout. Đây
cũng là lý do NACL luôn cần rule theo cặp.

</details>

**3.** Một đội đang dùng ElastiCache for Redis làm cache cho DynamoDB và muốn
chuyển sang DAX. Họ phải đổi gì trong ứng dụng, và vì sao đó lại là lập luận để
chọn DAX ngay từ đầu?

<details><summary>Đáp án</summary>

Với Redis, ứng dụng phải tự viết logic: hỏi cache trước, xử lý miss, gọi DynamoDB,
ghi ngược vào cache, đặt TTL, và xử lý invalidation khi ghi. Chuyển sang DAX thì
toàn bộ logic đó biến mất — DAX nói đúng API DynamoDB, nên chỉ cần đổi client sang
DAX SDK và trỏ vào cluster endpoint; mọi `GetItem`, `Query`, `PutItem` giữ nguyên
và DAX tự làm write-through. Vì thế với bảng DynamoDB đọc nhiều, DAX vừa ít code
hơn vừa không có nguy cơ cache lệch dữ liệu. Đánh đổi: DAX **chỉ** dùng được với
DynamoDB, còn Redis cache được bất cứ thứ gì.

</details>

**4.** Đề nói "the company needs an API that can throttle each customer separately
and must be as inexpensive as possible". Vì sao HTTP API là đáp án sai?

<details><summary>Đáp án</summary>

"Throttle each customer separately" chỉ làm được bằng **usage plan gắn với API
key**, và HTTP API không có tính năng đó. Đây là một ràng buộc cứng, còn "as
inexpensive as possible" là tiêu chí so sánh — ràng buộc thắng. Đáp án là REST API
với usage plan. Nếu bỏ vế throttle đi thì HTTP API mới đúng, vì nó rẻ hơn đáng kể
và độ trễ thấp hơn. Đây là mẫu câu hỏi rất phổ biến: một cụm rẻ tiền hấp dẫn đặt
cạnh một ràng buộc mà chỉ đáp án đắt hơn đáp ứng được.

</details>

**5.** Vì sao "explicit Deny thắng tất cả" không đủ để giải thích kết quả khi một
role có identity policy `Allow s3:*` nhưng SCP của account không nhắc gì tới S3?

<details><summary>Đáp án</summary>

Vì SCP hoạt động theo mô hình **allow-list**, không phải deny-list. Nếu SCP không
liệt kê `s3:*` trong một câu Allow nào thì hành động đó **không nằm trong trần**,
và nó bị chặn — dù không có Deny nào cả. Đó là lý do SCP mặc định của
Organizations là `FullAWSAccess`: gỡ nó ra mà không thay bằng gì thì cả account
mất sạch quyền. Câu "explicit Deny thắng tất cả" chỉ mô tả một nửa; nửa còn lại là
"quyền hiệu lực là **phần giao** của mọi lớp, và mỗi lớp phải Allow một cách chủ động".

</details>

**6.** Đề mô tả on-prem có 800 TB dữ liệu, đường truyền 500 Mbps dùng chung, và
yêu cầu "the on-premises application must keep accessing recent files with
low latency after migration". Hai quyết định độc lập ở đây là gì?

<details><summary>Đáp án</summary>

**Quyết định một — cách chuyển khối dữ liệu:** 800 TB qua 500 Mbps dùng chung mất
hơn nửa năm, nên phải dùng thiết bị vật lý hoặc kênh riêng, không phải DataSync
đơn thuần. **Quyết định hai — kiến trúc sau khi chuyển:** cụm "must keep accessing
recent files with low latency" nói rằng on-prem vẫn là người dùng thường trực, nên
cần Storage Gateway (File Gateway hoặc Volume Gateway cached) để giữ dữ liệu nóng
ở local. Đề SAA rất hay ghép hai quyết định vào một câu, và đáp án đúng là đáp án
duy nhất giải cả hai — chọn đúng cách chuyển mà bỏ vế truy cập sau đó là mất điểm.

</details>
