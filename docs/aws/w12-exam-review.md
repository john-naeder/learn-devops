# Tuần 12 — Ôn tập: bảng đối chiếu và chiến thuật phòng thi

> Mười một tuần trước bạn học **từng dịch vụ**. Tuần này học thứ đề thi thật sự đo:
> **phân biệt hai dịch vụ gần giống nhau trong 90 giây, dưới một ràng buộc cụ thể.**
> Không có kiến thức mới ở đây. Chỉ có cách sắp xếp lại kiến thức cũ sao cho lấy ra được
> trong phòng thi.

Bài này khác các bài trước: nó là **bộ bảng đối chiếu** cộng với **chiến thuật làm bài**.
Đọc nó không đủ. Phải **tự viết lại từng bảng bằng tay** rồi mới đối chiếu. Nhận ra một
bảng đúng khi nhìn thấy nó là ảo giác về năng lực; dựng lại nó từ trí nhớ mới là năng
lực thật, và đó chính xác là thứ phòng thi đòi hỏi.

---

## Học xong bài này bạn phải trả lời được

1. Bốn domain nặng nhẹ ra sao, và điều đó đổi cách ôn của bạn như thế nào?
2. Với mỗi cặp dịch vụ hay bị nhầm, **một câu** phân biệt quyết định là gì?
3. Bốn cụm từ khoá ràng buộc phổ biến nhất dẫn tới **loại** đáp án nào?
4. Khi còn hai đáp án đều đúng về kỹ thuật, bạn dùng tiêu chí gì để chọn?
5. 48 giờ trước khi thi nên làm gì và tuyệt đối không nên làm gì?
6. Đâu là những chủ đề bạn dễ quên nhất, và vì sao chúng dễ quên?

---

## 1. Trọng số bốn domain và ý nghĩa chiến thuật

Theo **exam guide chính thức SAA-C03 (bản 1.1)**:

| Domain | Tên đầy đủ | Trọng số | Số câu ước tính trên 50 câu tính điểm |
|---|---|---|---|
| **1** | Design Secure Architectures | **30%** | ~15 |
| **2** | Design Resilient Architectures | **26%** | ~13 |
| **3** | Design High-Performing Architectures | **24%** | ~12 |
| **4** | Design Cost-Optimized Architectures | **20%** | ~10 |

Thông số bài thi: **65 câu** (50 tính điểm, 15 câu thử nghiệm không tính), **130 phút**,
đậu ở **720/1000**, chấm **bù giữa các domain** (compensatory scoring — không cần đạt
ngưỡng ở từng domain riêng, chỉ cần tổng đạt). Hai dạng câu: multiple choice (1 đúng
trong 4) và multiple response (2 hoặc nhiều đúng trong 5 trở lên). **Không trừ điểm khi
đoán.**

### Ba hệ quả chiến thuật rút ra từ bảng trên

**Một — Security 30% nhưng thực tế còn nặng hơn con số đó.** Câu hỏi Domain 2, 3, 4 vẫn
thường có một đáp án sai vì lý do bảo mật (public bucket, access key nhúng trong code,
SG mở 0.0.0.0/0). IAM và mã hoá là kiến thức được dùng lại ở mọi domain. Nếu chỉ còn
thời gian ôn một thứ, ôn tuần 1 và tuần 9.

**Hai — chấm bù nghĩa là đừng bỏ hẳn domain nào, nhưng cũng đừng cầu toàn.** Bạn có thể
sai 14 câu và vẫn đậu. Chiến lược tối ưu không phải "biết mọi thứ" mà là "không có lỗ
hổng nào rộng 15 câu".

**Ba — Domain 4 (20%) là domain rẻ nhất để lấy điểm.** Nó xoay quanh một danh sách rất
hẹp: NAT Gateway vs Gateway Endpoint, S3 storage class và lifecycle, Spot vs RI vs
Savings Plans, right-sizing, data transfer, log retention. Học thuộc danh sách đó là gần
như chắc chắn có ~10 câu.

---

## 2. Bộ bảng đối chiếu

Đây là phần chính của bài. Mỗi bảng kết thúc bằng **một dòng phân biệt quyết định** —
nếu chỉ nhớ được một dòng cho mỗi bảng thì nhớ dòng đó.

### 2.1 SQS · SNS · EventBridge · Kinesis Data Streams

| | **SQS** | **SNS** | **EventBridge** | **Kinesis Data Streams** |
|---|---|---|---|---|
| Mô hình | Queue, pull | Pub/sub, push | Event bus + rule, push | Stream có thứ tự theo shard |
| Số consumer mỗi message | **1** (message biến mất sau khi xử lý) | **N** subscriber, mỗi người một bản | **N** target khớp rule | **N** consumer đọc **cùng** dữ liệu |
| Giữ dữ liệu | Mặc định 4 ngày, tối đa **14 ngày** | Không giữ — gửi xong là xong | Không giữ (có archive/replay riêng) | Mặc định **24 giờ**, tới **365 ngày** |
| Tua lại được? | Không | Không | Qua archive + replay | **Có** — đọc lại từ một vị trí bất kỳ |
| Thứ tự | Standard: không đảm bảo. **FIFO: có** | Standard: không. FIFO: có | Không | **Có, trong mỗi shard** |
| Lọc | Không | **Filter policy** trên attribute | **Event pattern** rất mạnh (nội dung JSON) | Không |
| Mở rộng | Tự động, không giới hạn | Tự động | Tự động | **Bạn quản shard** (hoặc on-demand) |
| Chọn khi | Tách rời hai thành phần, đệm tải, xử lý một lần | Fanout một thông báo tới nhiều nơi | Định tuyến sự kiện theo nội dung, tích hợp SaaS, lịch cron | Nhiều consumer độc lập trên cùng luồng, cần tua lại, xử lý theo thứ tự |

> **Phân biệt quyết định:** SQS = *một message, một người xử lý, rồi biến mất*.
> Kinesis = *một bản ghi, nhiều người đọc, và đọc lại được*.
> SNS = *đẩy đi ngay, không giữ*. EventBridge = *SNS có bộ định tuyến thông minh*.

Mẫu kinh điển: **SNS → nhiều SQS** (fanout có đệm). Mỗi consumer có queue riêng nên một
consumer chậm không kéo tụt những consumer khác.

### 2.2 ALB · NLB · GWLB · Global Accelerator · CloudFront

| | **ALB** | **NLB** | **GWLB** | **Global Accelerator** | **CloudFront** |
|---|---|---|---|---|---|
| Tầng | 7 (HTTP/HTTPS/gRPC) | 4 (TCP/UDP/TLS) | 3 (GENEVE) | 4 (TCP/UDP) | 7 (HTTP/HTTPS) |
| Định tuyến theo | Path, host, header, query, method | IP + port | Tất cả, đưa qua appliance | Không định tuyến — **tối ưu đường mạng** | Cache theo path + cache key |
| IP tĩnh | Không (dùng DNS name) | **Có, mỗi AZ một IP tĩnh**; gắn EIP được | — | **Có, 2 anycast IP** | Không |
| Hiệu năng | Cao | **Rất cao, độ trễ cực thấp, hàng triệu req/s** | Theo appliance | Đi vào mạng AWS ở edge gần nhất | Cache tại edge |
| WAF gắn được | **Có** | **Không** | Không | Không | **Có** |
| Chọn khi | Web app, microservice, container | TCP/UDP thuần, cần IP tĩnh, cực nhạy độ trễ | Chèn firewall/IDS của hãng thứ ba | Ứng dụng **không phải HTTP** cần tăng tốc toàn cầu, cần IP tĩnh, failover region nhanh | Nội dung tĩnh/động qua HTTP, cần cache và edge TLS |

> **Phân biệt quyết định:** CloudFront **cache nội dung**; Global Accelerator **không cache
> gì cả, nó tối ưu đường đi**. Đề nói "nội dung tĩnh, giảm tải origin" → CloudFront.
> Đề nói "game UDP / MQTT / VoIP toàn cầu, cần IP tĩnh" → Global Accelerator.

### 2.3 EBS · EFS · FSx · S3 · Instance store

| | **EBS** | **EFS** | **FSx** | **S3** | **Instance store** |
|---|---|---|---|---|---|
| Loại | Block | File (NFS) | File (SMB / Lustre / ONTAP / OpenZFS) | Object | Block |
| Gắn được mấy máy | 1 (Multi-Attach cho io1/io2 trong 1 AZ) | **Hàng nghìn**, đồng thời | Hàng nghìn | Không "gắn" — gọi qua API/HTTP | 1 |
| Phạm vi | **Một AZ** | **Nhiều AZ** (hoặc One Zone) | Theo cấu hình | **Region**, nhiều AZ | Gắn cứng vào host |
| Sống sau khi stop instance? | **Có** | Có | Có | Có | **KHÔNG — mất sạch** |
| Sống sau khi terminate? | Có (nếu tắt delete-on-termination) | Có | Có | Có | Không |
| Hiệu năng đỉnh | gp3 tới 16.000 IOPS; io2 Block Express cao hơn nhiều | Mở rộng theo dung lượng/throughput mode | Lustre: hàng trăm GB/s | Rất cao khi song song, độ trễ ms | **Cao nhất** — NVMe gắn trực tiếp |
| Chọn khi | Ổ đĩa cho một máy: OS, database | Nhiều máy chia sẻ file, Linux | Windows file share, HPC, ứng dụng cần POSIX cao cấp | Lưu trữ đối tượng, backup, data lake, web tĩnh | Cache, scratch, buffer tạm — **chấp nhận mất** |

> **Phân biệt quyết định:** Instance store **mất dữ liệu khi stop**. Đây là câu hỏi được
> hỏi đi hỏi lại. EBS là **một AZ, một máy**; EFS là **nhiều AZ, nhiều máy**.

Bốn loại FSx cần nhận ra: **Windows File Server** (SMB, Active Directory),
**Lustre** (HPC, ML, tích hợp S3), **NetApp ONTAP** (đa giao thức, snapshot, dedup),
**OpenZFS** (di trú từ ZFS).

### 2.4 RDS Multi-AZ · Read Replica · Aurora

| | **Multi-AZ** | **Read Replica** | **Aurora** |
|---|---|---|---|
| Mục đích | **Tính sẵn sàng** | **Mở rộng đọc** | Cả hai, ở mức cao hơn |
| Replication | **Đồng bộ** | **Bất đồng bộ** | Storage layer chia sẻ, 6 bản qua 3 AZ |
| Standby/replica phục vụ đọc? | **KHÔNG** (Multi-AZ cluster ba instance thì có) | **Có** | Tới 15 replica đều đọc được |
| Failover | **Tự động**, endpoint không đổi | **Thủ công** — phải promote | Tự động, dưới 30 giây thông thường |
| Cross-region | Không (cùng region, khác AZ) | **Có** | Có, qua **Global Database** |
| Ảnh hưởng RPO/RTO | RPO ~0, RTO tính bằng chục giây | Có độ trễ replication → RPO > 0 | RPO ~0 trong region |
| Trả tiền cho | Standby luôn chạy nhưng không phục vụ | Mỗi replica là một instance | Instance + storage dùng thật |

> **Phân biệt quyết định:** *"Chịu lỗi"* → **Multi-AZ**. *"Nhiều truy vấn đọc / báo cáo
> làm chậm production"* → **Read Replica**. Nhầm hai cái này là lỗi phổ biến nhất của
> Domain 2.

Aurora Global Database: RPO thường dưới 1 giây, RTO dưới 1 phút, dùng cho DR cross-region
và đọc cục bộ ở nhiều châu lục.

### 2.5 DynamoDB · RDS

| | **DynamoDB** | **RDS** |
|---|---|---|
| Mô hình | NoSQL key-value / document | Quan hệ, SQL |
| Truy vấn | Theo **partition key** (+ sort key); GSI/LSI cho đường truy cập khác | SQL tuỳ ý, JOIN, aggregate |
| Mở rộng | **Ngang, không giới hạn thực tế**, tự động | **Dọc** (đổi instance lớn hơn) + read replica |
| Hiệu năng | **Mili giây một chữ số**, ổn định ở mọi quy mô | Phụ thuộc instance và query |
| Schema | Chỉ khoá là cố định | Cố định, cần migration khi đổi |
| Vận hành | Serverless hoàn toàn | Có instance để chọn, vá, backup |
| Multi-Region | **Global Tables** (multi-active) | Read replica cross-region / Aurora Global |
| Chọn khi | Đường truy cập biết trước, quy mô lớn, độ trễ ổn định, serverless | Cần JOIN, transaction phức tạp, báo cáo tuỳ biến, schema quan hệ |

> **Phân biệt quyết định:** biết trước **cách truy vấn** → DynamoDB. Cần **truy vấn tuỳ
> ý** → RDS. Đề nhắc "hàng triệu request/giây với độ trễ ổn định" hoặc "không muốn quản
> lý server database" → DynamoDB.

Đi kèm: **DAX** (cache mili giây → micro giây, chỉ cho DynamoDB), **ElastiCache**
(cache cho RDS và cho session), **RDS Proxy** (gom connection, quan trọng khi Lambda gọi RDS).

### 2.6 Security Group · Network ACL

| | **Security Group** | **Network ACL** |
|---|---|---|
| Gắn vào | **ENI** (instance, endpoint, RDS...) | **Subnet** |
| Trạng thái | **Stateful** — reply tự động được cho về | **Stateless** — phải mở cả chiều về |
| Rule | **Chỉ ALLOW** | **ALLOW và DENY** |
| Thứ tự xét | Xét **tất cả** rule, có một Allow là qua | Theo **số thứ tự tăng dần**, khớp đầu tiên thắng |
| Mặc định | Chặn hết inbound, cho hết outbound | Default NACL cho hết cả hai chiều |
| Tham chiếu | Tham chiếu được **SG khác** làm nguồn | Chỉ CIDR |
| Dùng để | Kiểm soát chính, hằng ngày | Chặn theo IP/dải, phòng tuyến thô ở mức subnet |

> **Phân biệt quyết định:** cần **DENY một IP cụ thể** → NACL (SG không có DENY).
> Ephemeral port là bẫy của NACL: mở 443 inbound thôi chưa đủ, phải mở 1024–65535
> outbound cho gói trả về.

### 2.7 Gateway Endpoint · Interface Endpoint · NAT Gateway

| | **Gateway Endpoint** | **Interface Endpoint (PrivateLink)** | **NAT Gateway** |
|---|---|---|---|
| Cơ chế | Một **route** trong route table | Một **ENI** có IP riêng trong subnet | NAT ra internet qua IGW |
| Dịch vụ hỗ trợ | **Chỉ S3 và DynamoDB** | Hầu hết dịch vụ AWS + dịch vụ của bên thứ ba | Mọi đích trên internet |
| Traffic đi đâu | Trong mạng AWS | Trong mạng AWS | **Ra internet** |
| **Giá** | **MIỄN PHÍ** | ~$0,01/giờ/AZ + phí xử lý dữ liệu | **~$0,045/giờ + $0,045/GB** |
| Cross-region | Không | Không | — |
| Chọn khi | Private subnet cần S3/DynamoDB | Private subnet cần SSM, KMS, ECR, Secrets Manager... | Cần gọi ra internet thật (cập nhật gói, API bên ngoài) |

> **Phân biệt quyết định:** *"Private subnet gọi S3, chi phí thấp nhất"* → **Gateway
> Endpoint, miễn phí**. Đây là câu hỏi Domain 4 xuất hiện thường xuyên nhất, và NAT
> Gateway luôn là đáp án sai đắt tiền trong câu đó.

### 2.8 Secrets Manager · Parameter Store

| | **SSM Parameter Store** | **Secrets Manager** |
|---|---|---|
| Giá | Standard **miễn phí** | **$0,40/secret/tháng** + $0,05/10.000 API call |
| Kích thước | 4 KB (standard) / 8 KB (advanced) | **64 KB** |
| **Tự động xoay vòng** | **Không** | **Có** — tích hợp sẵn RDS/Aurora/Redshift/DocumentDB |
| Cross-account | Chỉ tham số advanced | **Có**, qua resource policy |
| Mã hoá | Tuỳ chọn `SecureString` (KMS) | **Luôn mã hoá** |
| Sinh mật khẩu ngẫu nhiên | Không | **Có** |

> **Phân biệt quyết định:** có chữ **"tự động xoay vòng credential"** → Secrets Manager.
> Có chữ **"chi phí thấp nhất"** → Parameter Store.

### 2.9 GuardDuty · Inspector · Macie · Config · CloudTrail (+ Security Hub, Detective)

| Dịch vụ | Trả lời câu hỏi | Từ khoá nhận diện |
|---|---|---|
| **GuardDuty** | *Có ai đang tấn công không?* | hành vi bất thường, IP độc hại, đào coin, credential bị lộ, port scan |
| **Inspector** | *Máy có lỗ hổng không?* | CVE, quét lỗ hổng, EC2/ECR/Lambda, network reachability |
| **Macie** | *Dữ liệu nhạy cảm nằm đâu trong S3?* | PII, số thẻ, GDPR, phân loại dữ liệu |
| **Detective** | *Vì sao chuyện này xảy ra?* | điều tra, nguyên nhân gốc, dựng lại dòng thời gian |
| **Security Hub** | *Tình hình an ninh tổng thể?* | dashboard chung, CIS Benchmark, AWS FSBP, PCI DSS |
| **AWS Config** | *Cấu hình ra sao, có tuân thủ không?* | drift cấu hình, lịch sử cấu hình, compliance rule, remediation |
| **CloudTrail** | *Ai đã làm gì, lúc nào?* | audit, API call, "ai đã xoá cái này" |

> **Phân biệt quyết định:** GuardDuty = **mối đe doạ đang diễn ra**. Inspector = **lỗ
> hổng đang tồn tại**. Config = **cấu hình sai lệch**. CloudTrail = **ai đã gọi API**.
> Macie nhìn **nội dung**, Config nhìn **cấu hình**.

### 2.10 Bốn chiến lược DR

| | **Backup & Restore** | **Pilot Light** | **Warm Standby** | **Multi-Site Active/Active** |
|---|---|---|---|---|
| RTO | Giờ → ngày | Chục phút | Phút | **~0** |
| RPO | Giờ | Phút | Giây | **~0** |
| Chi phí | **Thấp nhất** | Thấp | Trung bình | **Cao nhất** |
| Region phụ có gì | Chỉ backup | Dữ liệu đã replicate + hạ tầng **đang tắt** | Bản **thu nhỏ đang chạy** | Bản **đầy đủ, phục vụ traffic** |
| Khi sự cố | Dựng lại từ IaC + restore | Promote replica, bật ASG, đổi DNS | Scale up, đổi DNS | Health check tự loại region hỏng |

> **Phân biệt quyết định:** RTO là *bao lâu mới chạy lại*, RPO là *mất bao nhiêu dữ liệu*.
> Từ khoá "chi phí thấp nhất" kéo xuống Backup & Restore; "không được downtime" kéo lên
> Multi-Site.

### 2.11 S3 storage class

| Class | Số AZ | Thời gian lưu tối thiểu | Truy xuất | Chọn khi |
|---|---|---|---|---|
| **Standard** | ≥3 | Không | Mili giây | Dữ liệu nóng, truy cập thường xuyên |
| **Intelligent-Tiering** | ≥3 | Không | Mili giây (tầng nóng) | **Không đoán được mẫu truy cập**; có phí monitoring/object, **không có phí truy xuất** |
| **Standard-IA** | ≥3 | **30 ngày** | Mili giây | Truy cập ít nhưng cần ngay, dữ liệu quan trọng |
| **One Zone-IA** | **1** | **30 ngày** | Mili giây | Truy cập ít, **tạo lại được** (bản sao thứ hai, thumbnail) |
| **Glacier Instant Retrieval** | ≥3 | **90 ngày** | **Mili giây** | Archive nhưng thỉnh thoảng cần ngay (ảnh y tế) |
| **Glacier Flexible Retrieval** | ≥3 | **90 ngày** | Expedited 1–5 phút · Standard 3–5 giờ · Bulk 5–12 giờ (miễn phí) | Backup, archive, chờ được vài giờ |
| **Glacier Deep Archive** | ≥3 | **180 ngày** | **12 giờ** (standard) hoặc **48 giờ** (bulk) | Lưu trữ tuân thủ 7–10 năm, rẻ nhất |

Ba điều hay bị bỏ sót: các lớp IA/Glacier có **phí truy xuất theo GB**; có **kích thước
object tối thiểu tính tiền 128 KB**; và xoá trước thời gian tối thiểu vẫn bị tính đủ.

> **Phân biệt quyết định:** *"không biết mẫu truy cập"* → **Intelligent-Tiering**.
> *"tạo lại được, rẻ hơn"* → **One Zone-IA**. *"archive nhưng phải lấy trong vài mili
> giây"* → **Glacier Instant Retrieval**. *"rẻ nhất, chờ được cả ngày"* → **Deep Archive**.

### 2.12 Route 53 routing policy

| Policy | Cơ chế | Chọn khi |
|---|---|---|
| **Simple** | Một record, một hoặc nhiều giá trị, không health check | Trường hợp cơ bản nhất |
| **Weighted** | Chia traffic theo tỉ lệ bạn đặt | **Canary / blue-green**, thử nghiệm A/B |
| **Latency** | Trả về region có **độ trễ thấp nhất** với người dùng | Ứng dụng đa region, tối ưu hiệu năng |
| **Failover** | Primary + secondary, chuyển khi health check fail | **DR active/passive** |
| **Geolocation** | Theo **vị trí người dùng** (châu lục, quốc gia, bang) | Nội dung theo ngôn ngữ, tuân thủ pháp lý, bản quyền |
| **Geoproximity** | Theo khoảng cách địa lý tới tài nguyên, có **bias** dịch chuyển được | Điều chỉnh dần luồng traffic giữa các region |
| **Multivalue answer** | Trả về tới 8 bản ghi lành mạnh, client tự chọn | "Load balancing kiểu DNS" cho hệ thống nhỏ |

> **Phân biệt quyết định:** *"độ trễ thấp nhất"* → **Latency**, không phải Geolocation.
> *"người dùng ở Đức phải thấy nội dung Đức"* → **Geolocation**, không phải Latency.
> *"chuyển 10% traffic sang phiên bản mới"* → **Weighted**.

Nhắc lại từ tuần 8: **Alias record** trỏ tới tài nguyên AWS (ALB, CloudFront, S3 website,
API Gateway), **miễn phí truy vấn**, và là cách duy nhất đặt được ở **zone apex**
(`example.com` không có `www`). CNAME không đặt được ở apex.

### 2.13 Savings Plans · Reserved Instance · Spot · On-Demand

| | **On-Demand** | **Spot** | **Reserved Instance** | **Savings Plans** |
|---|---|---|---|---|
| Giảm giá | 0 | **tới ~90%** | tới **72%** (Standard) / **66%** (Convertible) | tới **66%** (Compute) / **72%** (EC2 Instance) |
| Cam kết | Không | Không | 1 hoặc 3 năm, theo **cấu hình instance** | 1 hoặc 3 năm, theo **$/giờ** |
| Bị thu hồi | Không | **Có**, báo trước **2 phút** | Không | Không |
| Giữ chỗ công suất | Không | Không | **Chỉ zonal RI** | **Không bao giờ** |
| Phủ những gì | — | EC2 (và Fargate Spot, EMR...) | EC2, RDS, ElastiCache, OpenSearch, Redshift... theo từng dịch vụ | Compute SP: **EC2 + Fargate + Lambda** |
| Bán lại | — | — | **Standard RI bán được** trên Marketplace | Không |

> **Phân biệt quyết định:** Savings Plans cam kết bằng **tiền**, RI cam kết bằng **hiện
> vật**. Chỉ **zonal RI** giữ chỗ công suất. Đề nhắc "Fargate và Lambda" → phải là
> Compute Savings Plans, RI không phủ được.

Bổ sung: **Dedicated Host** cho giấy phép phần mềm tính theo socket/core vật lý;
**On-Demand Capacity Reservation** khi chỉ cần đảm bảo có máy mà không muốn cam kết dài hạn.

### 2.14 Lambda · Fargate · ECS trên EC2 · EC2

| | **Lambda** | **Fargate** | **ECS/EKS trên EC2** | **EC2** |
|---|---|---|---|---|
| Đơn vị | Function | Task/Pod | Task/Pod trên instance bạn quản | Máy ảo |
| Bạn quản gì | Chỉ code | Container image + task definition | Cả instance: vá, scale, AMI | Toàn bộ OS |
| Thời gian chạy tối đa | **15 phút** | Không giới hạn | Không giới hạn | Không giới hạn |
| Khởi động | Mili giây → giây (**cold start**) | Chục giây | Nhanh nếu instance đã sẵn | Phút |
| Tính tiền | Theo request + GB-giây, **không dùng thì $0** | Theo vCPU/RAM của task, theo giây | Theo **instance**, kể cả khi rảnh | Theo instance |
| Spot | Không | **Fargate Spot** có | Có | Có |
| GPU / phần cứng đặc biệt | Không | Không | **Có** | **Có** |
| Chọn khi | Event-driven, tải rời rạc, "ít vận hành nhất" | Container không muốn quản instance | Cần GPU, cần tuỳ biến kernel/daemon, mật độ cao để tiết kiệm | Cần toàn quyền OS, phần mềm cũ, giấy phép đặc thù |

> **Phân biệt quyết định:** *"chạy lâu hơn 15 phút"* → **không phải Lambda**, hãy nghĩ
> Fargate hoặc Step Functions chia nhỏ. *"ít thao tác vận hành nhất"* trong bối cảnh
> container → **Fargate**. *"cần GPU"* → **EC2 hoặc ECS trên EC2**.

### 2.15 STS · Permission boundary · SCP · Session policy · Resource policy

| | Là gì | Cấp quyền? | Áp lên ai |
|---|---|---|---|
| **Identity policy** | Policy gắn vào user/group/role | **Có** | Principal |
| **Resource policy** | Policy gắn vào tài nguyên (bucket policy, key policy, trust policy) | **Có** | Ai truy cập tài nguyên đó |
| **Permission boundary** | **Trần** quyền tối đa cho một identity | **Không** — chỉ giới hạn | Một user/role cụ thể |
| **SCP** | Guardrail của Organizations | **Không** — chỉ giới hạn | Mọi principal trong account/OU (**trừ management account** và service-linked role) |
| **Session policy** | Policy truyền vào lúc `AssumeRole` | **Không** — chỉ thu hẹp thêm | Phiên đó |
| **STS** | Dịch vụ cấp **credential tạm thời** (`AssumeRole`, `GetSessionToken`) | Cấp qua role | — |

Thứ tự đánh giá (vẽ được từ trí nhớ là ăn điểm Domain 1):

```
explicit DENY ở bất kỳ đâu  →  TỪ CHỐI, dừng
        ↓ không có
SCP cho phép?               →  không → TỪ CHỐI
        ↓ có
Permission boundary?        →  không → TỪ CHỐI
        ↓ có / không gắn
Session policy?             →  không → TỪ CHỐI
        ↓ có / không có
Identity policy HOẶC resource policy có ALLOW?  →  có → CHO PHÉP
        ↓ không
implicit deny → TỪ CHỐI
```

> **Phân biệt quyết định:** SCP, permission boundary và session policy **không bao giờ
> cấp quyền**, chúng chỉ cắt bớt. Quyền phải đến từ identity policy hoặc resource policy.

### 2.16 Ba cặp phụ hay ra kèm

**SQS Standard vs FIFO**

| | Standard | FIFO |
|---|---|---|
| Thứ tự | Nỗ lực tốt nhất, **không đảm bảo** | **Đảm bảo** trong mỗi message group |
| Giao hàng | **Ít nhất một lần** (có thể trùng) | **Đúng một lần** |
| Throughput | Không giới hạn | 300 TPS/API (3.000 msg/s có batching); high throughput mode cao hơn nhiều |
| Tham số bắt buộc | — | `MessageGroupId`; `MessageDeduplicationId` nếu không bật content-based dedup |

**Cognito user pool vs identity pool**

| | User pool | Identity pool (Federated Identities) |
|---|---|---|
| Trả về | **JWT** (id/access/refresh token) | **Credential AWS tạm thời** qua STS |
| Dùng để | Xác thực người dùng, đăng ký, MFA, social login | Cho phép app gọi thẳng dịch vụ AWS (S3, DynamoDB) |
| Đi với | API Gateway authorizer, ALB | SDK trong app di động/web |

**CloudFront vs S3 Transfer Acceleration**

CloudFront tăng tốc **đọc** (cache ở edge). Transfer Acceleration tăng tốc **upload** vào
S3 từ xa (đi vào edge rồi qua backbone AWS). Đề nói "người dùng toàn cầu upload file lớn
lên S3" → **Transfer Acceleration**.

---

## Bảng quyết định — cách đọc một câu hỏi SAA

Cấu trúc gần như mọi câu hỏi:

```
[ Bối cảnh: công ty làm gì, hệ thống hiện tại thế nào ]        ← thường bỏ được 60%
[ Vấn đề hoặc yêu cầu mới ]                                     ← đọc kỹ
[ RÀNG BUỘC QUYẾT ĐỊNH — thường là mệnh đề cuối cùng ]          ← đây mới là câu hỏi thật
"Which solution meets these requirements with the LEAST operational overhead?"
```

**Đọc mệnh đề cuối trước, rồi mới đọc lên trên.** Nhiều đáp án đúng về kỹ thuật; chỉ một
đáp án đúng với ràng buộc đó.

### Từ khoá ràng buộc → hướng đáp án

| Từ khoá trong đề | Nghiêng về loại đáp án nào |
|---|---|
| **"MOST cost-effective" / "lowest cost"** | Spot, S3 lifecycle + storage class rẻ hơn, **Gateway Endpoint thay NAT**, Savings Plans, right-sizing, tắt tài nguyên rảnh, Parameter Store thay Secrets Manager |
| **"LEAST operational overhead" / "minimal management"** | **Managed / serverless**: Lambda, Fargate, DynamoDB, Aurora Serverless, S3, SQS, Secrets Manager rotation, AWS Backup, SSM. Loại mọi đáp án có chữ "cài đặt", "tự viết script", "chạy cron trên EC2" |
| **"HIGHEST availability" / "fault tolerant"** | Multi-AZ, nhiều AZ trong ASG, ALB health check, Aurora, S3 (đã multi-AZ sẵn); nếu nói cấp region thì multi-Region |
| **"MINIMUM downtime" (khi di trú)** | **DMS với CDC**, blue/green, read replica rồi promote, AWS MGN cutover |
| **"MINIMAL changes to the application"** | Replatform, Storage Gateway, RDS thay database tự quản, ElastiCache, EFS thay NFS on-prem |
| **"real-time" / "sub-second"** | Kinesis, ElastiCache/DAX, NLB, DynamoDB |
| **"decouple"** | SQS, SNS, EventBridge |
| **"process out of order is not acceptable"** | **SQS FIFO** hoặc Kinesis (thứ tự theo shard) |
| **"multiple consumers need the same data"** | **Kinesis**, hoặc SNS fanout → nhiều SQS. Không phải một SQS queue |
| **"must run longer than 15 minutes"** | **Không phải Lambda** → Fargate, ECS, Batch, Step Functions |
| **"static IP address"** | **NLB** hoặc **Global Accelerator** |
| **"data must stay on premises"** | **Outposts** |
| **"encrypt existing RDS/EBS"** | Snapshot → copy có mã hoá → restore. Không có nút bật tại chỗ |
| **"rotate credentials automatically"** | **Secrets Manager** |
| **"who deleted this"** | **CloudTrail** |
| **"is this resource compliant"** | **AWS Config** |
| **"prevent even administrators from doing X"** | **SCP** (hoặc explicit Deny), không phải IAM policy |
| **"unpredictable access pattern"** (S3) | **Intelligent-Tiering** |
| **"scale reads"** | **Read Replica** hoặc cache, không phải Multi-AZ |

---

## Kỹ thuật loại trừ đáp án

Phần lớn câu hỏi có **hai đáp án sai rõ ràng**. Loại chúng trước rồi mới suy nghĩ.

### Bảy dấu hiệu của một đáp án sai

1. **Vi phạm bảo mật cơ bản.** Bucket public, SG mở `0.0.0.0/0` cho port 22 hoặc 3306,
   access key nhúng trong code hay trong user data, dùng IAM user thay vì role cho EC2.
   Loại ngay, kể cả khi phần còn lại nghe hợp lý.
2. **Dịch vụ dùng sai việc.** "Gắn WAF vào NLB", "dùng Config để phát hiện tấn công",
   "dùng CloudFront để tăng tốc UDP", "Multi-AZ để mở rộng đọc". Đây là chỗ 16 bảng ở
   trên trả điểm.
3. **Vi phạm giới hạn cứng.** Lambda 15 phút, `kms:Encrypt` 4 KB, Gateway Endpoint chỉ
   S3/DynamoDB, chứng chỉ CloudFront phải ở us-east-1, VPC Peering không transitive.
4. **Nhiều thao tác thủ công khi đề đòi "least operational overhead".** Đáp án có
   "cài agent", "viết cron", "quản lý cluster", "SSH vào từng máy" gần như luôn sai
   trong câu có từ khoá đó.
5. **Đắt hơn hẳn khi đề đòi "most cost-effective".** NAT Gateway khi có Gateway Endpoint;
   Multi-Region khi chỉ cần Multi-AZ; provisioned capacity khi tải thất thường.
6. **Giải quyết đúng nhưng thừa.** Kiến trúc lớn hơn yêu cầu vẫn là sai. SAA luôn thưởng
   cho **đáp án nhỏ nhất vừa đủ**.
7. **Chứa từ tuyệt đối đáng ngờ.** "Đảm bảo không bao giờ mất dữ liệu", "loại bỏ hoàn
   toàn độ trễ" — hiếm khi đúng.

### Khi còn hai đáp án đều hợp lý

Áp dụng theo đúng thứ tự này:

```
1. Đọc lại mệnh đề ràng buộc cuối câu. Áp bảng từ khoá ở trên.
2. Đáp án nào MANAGED hơn?              → thường thắng
3. Đáp án nào ÍT THÀNH PHẦN hơn?        → thường thắng
4. Đáp án nào RẺ hơn ở cùng mức đáp ứng? → thường thắng
5. Đáp án nào ĐÚNG BẢN CHẤT dịch vụ hơn? (đọc lại bảng đối chiếu)
6. Vẫn không chắc → đoán, đánh dấu, đi tiếp. KHÔNG BAO GIỜ để trống.
```

### Với câu multiple response

Đề nói rõ "Choose TWO" hoặc "Choose THREE". Chọn **đúng số lượng** — thiếu hoặc thừa đều
là sai cả câu, không có điểm một phần. Chiến thuật: tìm hai đáp án **bổ sung cho nhau**
(ví dụ một về mạng + một về IAM), không phải hai đáp án nói cùng một điều.

### Quản lý thời gian

130 phút / 65 câu = **2 phút mỗi câu**, nhưng đừng chia đều:

- **Vòng 1 (~90 phút):** làm hết, **đánh dấu** câu lưỡng lự, **không dừng quá 3 phút** ở
  bất kỳ câu nào. Câu dài 8 dòng bối cảnh thường không khó hơn câu 3 dòng.
- **Vòng 2 (~30 phút):** quay lại câu đã đánh dấu.
- **Vòng 3 (~10 phút):** rà câu multiple response, đếm lại số đáp án đã chọn.

---

## Số phải thuộc

Bảng này gom từ cả 12 tuần. Chỉ giữ những con số thật sự hay xuất hiện.

| Con số | Nội dung |
|---|---|
| **65 / 130 / 720** | Số câu / phút / điểm đậu (trên thang 1000) |
| **30 / 26 / 24 / 20** | Trọng số 4 domain: Secure / Resilient / High-Performing / Cost |
| **15 phút** | Thời gian chạy tối đa của Lambda |
| **4 KB** | Giới hạn `kms:Encrypt` trực tiếp; cũng là giới hạn biến môi trường Lambda và tham số Parameter Store standard |
| **256 KB** | Kích thước message tối đa của SQS |
| **14 ngày / 4 ngày** | Retention tối đa / mặc định của SQS |
| **30 giây / 12 giờ** | Visibility timeout mặc định / tối đa của SQS |
| **24 giờ → 365 ngày** | Retention của Kinesis Data Streams: mặc định → tối đa |
| **1 MB/s ghi, 2 MB/s đọc** | Thông lượng mỗi shard Kinesis |
| **30 / 90 / 180 ngày** | Thời gian lưu tối thiểu: Standard-IA và One Zone-IA / Glacier IR và GFR / Deep Archive |
| **128 KB** | Kích thước object tối thiểu tính tiền ở các lớp IA |
| **1–35 ngày** | Retention automated backup của RDS |
| **35 ngày** | Cửa sổ PITR của DynamoDB |
| **1,25 Gbps** | Băng thông tối đa mỗi tunnel Site-to-Site VPN |
| **1/10/100/400 Gbps** | Tốc độ cổng Direct Connect dedicated |
| **5 phút / 1 phút** | Chu kỳ metric EC2 basic / detailed monitoring |
| **15 ngày / 63 ngày / 455 ngày** | Retention metric CloudWatch ở chu kỳ 1 phút / 5 phút / 1 giờ |
| **90 ngày** | CloudTrail Event history |
| **Never expire** | Retention mặc định của CloudWatch log group |
| **~90% / 2 phút** | Giảm giá tối đa của Spot / thời gian báo trước khi bị thu hồi |
| **72% / 66%** | Giảm tối đa: Standard RI và EC2 Instance SP / Convertible RI và Compute SP |
| **1 hoặc 3 năm** | Kỳ hạn RI và Savings Plans |
| **us-east-1** | Region bắt buộc cho chứng chỉ ACM dùng với CloudFront |
| **$3.000/tháng** | Shield Advanced, cam kết 1 năm |
| **6 trụ cột** | Well-Architected: Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization, **Sustainability** |

---

## Bẫy kinh điển — những chủ đề dễ quên nhất

Danh sách này là chỗ điểm rơi nhiều nhất, xếp theo mức độ hay bị quên.

1. **Multi-AZ không phục vụ đọc.** Standby của RDS Multi-AZ **không** nhận query. Muốn
   mở rộng đọc là Read Replica. Đây là bẫy được cài nhiều nhất trong toàn bộ đề.
2. **Instance store mất dữ liệu khi stop.** Không phải khi terminate — khi **stop**.
3. **VPC Peering không transitive.** A↔B và B↔C không cho A↔C. Cần Transit Gateway.
4. **NACL là stateless.** Mở inbound 443 thôi chưa đủ; phải mở outbound ephemeral port
   1024–65535 cho gói trả về.
5. **Security Group không có rule DENY.** Muốn chặn một IP cụ thể phải dùng NACL.
6. **Gateway Endpoint chỉ có S3 và DynamoDB.** Mọi dịch vụ khác là Interface Endpoint
   (và Interface Endpoint mất tiền).
7. **Chứng chỉ ACM cho CloudFront phải ở us-east-1.**
8. **Alias record đặt được ở zone apex, CNAME thì không.** Và alias miễn phí truy vấn.
9. **Không bật được mã hoá cho RDS/EBS đang chạy.** Phải snapshot → copy có mã hoá →
   restore.
10. **S3 Replication chỉ áp cho object tạo sau khi bật rule**, và cả hai bucket phải bật
    versioning.
11. **Direct Connect không mã hoá mặc định.**
12. **SCP không cấp quyền và không áp lên management account.**
13. **Key policy của KMS là điều kiện cần** — IAM policy một mình không đủ.
14. **CloudWatch không có metric RAM/disk của EC2** nếu chưa cài CloudWatch Agent.
15. **CloudWatch log group mặc định giữ log vĩnh viễn.**
16. **`treat_missing_data` mặc định là `missing`** — làm alarm metric lỗi kẹt ở `ALARM`.
17. **CloudTrail không ghi data event mặc định.** `s3:GetObject` phải bật riêng và tính tiền.
18. **WAF không gắn được vào NLB.**
19. **Xoá RDS instance là mất automated backup**; chỉ manual snapshot còn lại.
20. **Lambda trong VPC không tự có internet.** Cần NAT Gateway hoặc VPC Endpoint —
    và đặt Lambda vào VPC chỉ cần thiết khi nó phải gọi tài nguyên có IP riêng.
21. **`FilterExpression` của DynamoDB không giảm chi phí đọc.** Nó lọc **sau** khi đã đọc.
    Muốn rẻ thì thiết kế khoá cho đúng, hoặc dùng GSI.
22. **Visibility timeout của SQS phải lớn hơn thời gian xử lý của consumer**, nếu không
    message bị xử lý trùng.
23. **Aurora storage 6 bản qua 3 AZ là chống lỗi, không phải backup.** Xoá nhầm dữ liệu
    thì cả 6 bản đều mất theo.
24. **Savings Plans không giữ chỗ công suất.** Chỉ zonal RI và Capacity Reservation mới giữ.
25. **Cost allocation tag phải kích hoạt thủ công và không hồi tố.**

---

## Nối với lab

[`labs/w12-exam-review/`](../../learn-aws/labs/w12-exam-review/) có **khung trống của
mười bảng** cùng file `dap-an.md` để đối chiếu. Quy trình đúng:

```
1. Copy khung bảng ra một file riêng
2. Điền TAY, không mở bài này, không mở dap-an.md
3. Đối chiếu, đánh dấu ô sai
4. Ô nào sai thì quay lại đọc đúng mục trong docs/aws/wNN-*.md
5. Ba ngày sau điền lại bảng đó lần nữa
```

Bước 5 là bước hầu hết mọi người bỏ. Nó là bước duy nhất chứng minh bạn nhớ chứ không
phải vừa đọc xong.

### Lịch thi thử

Bốn bài full 65 câu, **bấm giờ đúng 130 phút, ngồi liền mạch không nghỉ**. Đứng dậy pha
cà phê giữa chừng là bạn đang luyện một thứ khác với kỳ thi thật.

Sau mỗi bài, review **toàn bộ câu sai** *và* **mọi câu đúng do đoán**. Câu đúng do đoán
nguy hiểm hơn câu sai: nó cho bạn cảm giác đã hiểu.

Mẫu sổ lỗi — cột "Vì sao tôi sai" là cột duy nhất thực sự quan trọng:

```
Bài | Câu | Domain    | Chọn | Đúng | Vì sao sai              | Đã ôn lại
----|-----|-----------|------|------|-------------------------|----------
1   | 12  | Security  | B    | D    | Nhầm SG với NACL        | w02 ✓
1   | 31  | Cost      | A    | A(đoán)| Không chắc giá NAT    | w02 ✓
```

**Ngưỡng đăng ký thi thật: đạt ≥ 80% ở hai bài liên tiếp.** Chưa đạt thì lùi một tuần và
cày lại đúng domain yếu — **đừng làm thêm đề mới**. Làm nhiều đề mà không sửa lỗ hổng chỉ
tạo cảm giác bận rộn.

---

## Checklist 48 giờ trước khi thi

### T-48 giờ

- [ ] Đọc lại **16 bảng đối chiếu** trong bài này, tự viết lại 5 bảng bạn yếu nhất
- [ ] Đọc lại **sổ lỗi** của cả bốn bài thi thử — chỉ đọc cột "Vì sao sai"
- [ ] Đọc lại bảng **Số phải thuộc**
- [ ] Vẽ lại từ trí nhớ: **sơ đồ đánh giá quyền IAM** và **bảng 4 chiến lược DR**
- [ ] Xác nhận trên trang certification chính thức: **SAA-C03 vẫn là bản hiện hành?**

### T-24 giờ

- [ ] Kiểm tra thông tin đặt lịch: giờ, múi giờ, địa điểm hoặc link online, giấy tờ tuỳ thân
- [ ] Nếu thi online: chạy **system test** của Pearson VUE, dọn sạch bàn làm việc, kiểm
      tra webcam và đường mạng
- [ ] Đọc lướt **6 trang FAQ**: S3, EC2, VPC, RDS, DynamoDB, Lambda — chỉ lướt tiêu đề mục
- [ ] Đọc lại danh sách **out-of-scope services** trong exam guide để biết cái gì **không**
      cần lo
- [ ] **Không làm đề mới.** Một bài kém vào lúc này chỉ phá tâm lý, không sửa được gì

### T-12 giờ

- [ ] Ngủ đủ. Đây là hạng mục có tỉ lệ điểm trên công sức cao nhất trong toàn bộ checklist
- [ ] Không học gì mới

### Sáng ngày thi

- [ ] Ăn sáng, đến sớm 30 phút (hoặc đăng nhập sớm 30 phút nếu thi online)
- [ ] Nhắc lại với chính mình ba nguyên tắc: **đọc mệnh đề cuối trước**, **loại hai đáp
      án sai rõ ràng**, **không để trống câu nào**
- [ ] Chạy `./scripts/find-orphans.sh --all` lần cuối — đừng để một hoá đơn bất ngờ làm
      hỏng ngày thi

### Trong phòng thi

- [ ] Vòng 1 không quá 3 phút mỗi câu, đánh dấu câu lưỡng lự
- [ ] Với câu multiple response: đếm lại số đáp án đã chọn
- [ ] Còn 10 phút: rà soát, **không đổi đáp án trừ khi tìm được lý do cụ thể**

---

## Tự kiểm tra

<details>
<summary>1. Đề mô tả một ứng dụng cần "xử lý message theo đúng thứ tự, không được trùng lặp, khoảng 200 message/giây". Chọn gì?</summary>

SQS FIFO. 200 TPS nằm trong hạn mức mặc định 300 TPS mỗi API action, nên không cần bật
high throughput mode. Standard queue sai vì không đảm bảo thứ tự và giao **ít nhất một
lần** (có thể trùng). Kinesis cũng đảm bảo thứ tự trong shard nhưng nặng hơn cần thiết
ở đây, và đề không nói gì tới nhiều consumer hay tua lại.
</details>

<details>
<summary>2. "Ba đội phân tích cần đọc cùng một luồng sự kiện click, mỗi đội xử lý độc lập, và cần chạy lại dữ liệu 3 ngày trước khi sửa lỗi code." Chọn gì và vì sao không phải SQS?</summary>

Kinesis Data Streams với retention ≥ 3 ngày. SQS sai ở cả hai vế: message bị xoá sau khi
một consumer xử lý nên ba đội không đọc được cùng dữ liệu, và SQS không tua lại được.
SNS fanout tới ba SQS giải được vế "ba đội" nhưng vẫn không giải được vế "chạy lại".
</details>

<details>
<summary>3. Ứng dụng chạy trên EC2 trong private subnet, cần đọc file từ S3 và lấy secret từ Secrets Manager. Kiến trúc rẻ nhất là gì?</summary>

**Gateway Endpoint** cho S3 (miễn phí) và **Interface Endpoint** cho Secrets Manager
(mất tiền theo giờ và theo AZ, nhưng vẫn rẻ hơn NAT Gateway nếu lưu lượng đáng kể).
Không cần NAT Gateway. Nếu đề chỉ hỏi phần S3 thì đáp án là Gateway Endpoint, và mọi đáp
án có NAT Gateway đều sai về chi phí.
</details>

<details>
<summary>4. "Báo cáo cuối tháng chạy query nặng làm chậm hệ thống đặt hàng." Multi-AZ hay Read Replica?</summary>

Read Replica, và trỏ công cụ báo cáo vào endpoint của replica. Multi-AZ sai vì standby
không phục vụ đọc — bật Multi-AZ chỉ làm tăng gấp đôi chi phí mà không giảm tải một chút
nào. Đây là bẫy được cài nhiều nhất trong đề.
</details>

<details>
<summary>5. Đề có hai đáp án: (A) EC2 Auto Scaling chạy script xử lý ảnh, (B) S3 event → Lambda xử lý ảnh. Ràng buộc là "least operational overhead". Chọn gì, và nếu ràng buộc đổi thành "ảnh 4K mất 25 phút mỗi tấm" thì sao?</summary>

Với "least operational overhead" → B, Lambda: không có instance để vá, để scale, để trả
tiền khi rảnh. Nhưng nếu mỗi tấm mất 25 phút thì Lambda **hết cách** vì giới hạn cứng 15
phút — lúc đó đáp án là Fargate (hoặc AWS Batch), không phải quay về EC2 tự quản. Đây là
mẫu câu hỏi đổi một chi tiết để đảo đáp án.
</details>

<details>
<summary>6. "Lưu 500 TB log tuân thủ trong 7 năm, gần như không bao giờ đọc, nhưng nếu kiểm toán yêu cầu thì phải lấy được trong vòng 2 ngày." Chọn storage class nào?</summary>

S3 Glacier Deep Archive. Thời gian lưu tối thiểu 180 ngày không thành vấn đề với chu kỳ
7 năm, và bulk retrieval trong 48 giờ vừa khớp ràng buộc "2 ngày". Glacier Flexible
Retrieval cũng lấy được nhưng đắt hơn mà không cần thiết — đề đã nói rõ chờ được 2 ngày.
Nếu ràng buộc là "vài phút" thì phải lên Glacier Instant Retrieval hoặc Flexible với
expedited.
</details>

<details>
<summary>7. Vì sao "dùng IAM policy để cấm mọi người tắt CloudTrail" là đáp án sai trong một câu hỏi về Organizations?</summary>

Vì admin của account đó sửa được chính IAM policy của mình, nên biện pháp tự nó bị vô
hiệu hoá. Cần một tầng cao hơn: **SCP với `Deny` cho `cloudtrail:StopLogging` và
`cloudtrail:DeleteTrail`** gắn ở OU hoặc root. SCP không sửa được từ trong account con.
Lưu ý SCP vẫn không áp lên management account.
</details>

<details>
<summary>8. Bạn còn 2 phút, còn 1 câu chưa làm và 3 câu đã đánh dấu. Làm gì?</summary>

Trả lời câu chưa làm trước — kể cả đoán bừa, vì không trừ điểm khi đoán, và một câu để
trống chắc chắn mất điểm trong khi đoán ngẫu nhiên có xác suất 25%. Sau đó mới xem lại
câu đánh dấu nếu còn giây nào. Không bao giờ nộp bài với một câu trống.
</details>

---

## Ngoài phạm vi

- **Câu hỏi mẫu chính thức** — 20 câu practice trong AWS Skill Builder gói free; làm
  trước bài thi thử đầu tiên. [Skill Builder](https://skillbuilder.aws/)
- **AWS Certified Solutions Architect – Professional** — kiến trúc multi-account phức tạp,
  migration quy mô lớn; không cần cho SAA.
- **Dịch vụ nằm trong danh sách out-of-scope của exam guide** — CDK, CodeBuild/CodeDeploy/
  CodeCommit, Cloud9, CloudShell, Lightsail, OpsWorks, toàn bộ IoT, phần lớn Machine
  Learning, Elemental Media*, Amazon MWAA. Đọc đủ danh sách trong Appendix của exam guide;
  đó là ranh giới ôn tập của bạn.
- **SAA-C04** — tính đến thời điểm viết, không có nguồn chính thức nào từ AWS xác nhận.
  Tự kiểm tra lại trang certification trước khi mua tài liệu ôn.

---

## Nguồn

- [AWS Certified Solutions Architect – Associate (SAA-C03) Exam Guide, v1.1 — trọng số domain và danh sách out-of-scope](https://d1.awsstatic.com/training-and-certification/docs-sa-assoc/AWS-Certified-Solutions-Architect-Associate_Exam-Guide.pdf)
- [AWS Certified Solutions Architect – Associate — trang chứng chỉ chính thức](https://aws.amazon.com/certification/certified-solutions-architect-associate/)
- [AWS Well-Architected Framework — sáu trụ cột](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)
- [Amazon S3 Glacier storage classes — thời gian lưu tối thiểu và thời gian truy xuất](https://docs.aws.amazon.com/AmazonS3/latest/userguide/glacier-storage-classes.html)
- [Amazon S3 Glacier — expedited 1–5 phút, standard 3–5 giờ, bulk 5–12 giờ, Deep Archive 12–48 giờ](https://aws.amazon.com/s3/storage-classes/glacier/)
- [Amazon SQS FAQs — throughput của FIFO queue](https://aws.amazon.com/sqs/faqs/)
- [Troubleshoot FIFO throttling issues in Amazon SQS — 300 TPS, 3.000 msg/s có batching](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/troubleshooting-fifo-throttling-issues.html)
- [CloudWatch metric retention và resolution](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html)
- [Compute Savings Plans — mức giảm giá và kỳ hạn](https://aws.amazon.com/savingsplans/compute-pricing/)
- [Amazon EC2 Reserved Instances — Standard vs Convertible, regional vs zonal](https://aws.amazon.com/ec2/pricing/reserved-instances/)
- [AWS Direct Connect FAQs — tốc độ cổng](https://aws.amazon.com/directconnect/faqs/)
- [AWS Site-to-Site VPN quotas — 1,25 Gbps mỗi tunnel](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-limits.html)
- [AWS Certificate Manager FAQs — chứng chỉ CloudFront phải ở us-east-1](https://aws.amazon.com/certificate-manager/faqs/)
- [Working with CloudTrail event history — 90 ngày](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html)
