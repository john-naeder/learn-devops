# Sẵn sàng cao — HA, fault tolerance, và chỗ hệ thống gãy

> **Tra nhanh:** bạn đang cầm một câu hỏi có chữ `highly available`, `fault-tolerant`
> hay `resilient` và cần biết ba từ đó **không đồng nghĩa**, rồi tìm điểm gãy trong
> kiến trúc đề mô tả.

`Domain 2 · Design Resilient Architectures (26% đề)`

26% của 65 câu là khoảng **17 câu** — miền lớn thứ hai. Phần khôi phục thảm họa của
miền này nằm ở file riêng: [`13-khoi-phuc-tham-hoa.md`](13-khoi-phuc-tham-hoa.md).
File này lo phần "hệ thống chạy tiếp khi một mảnh chết".

---

## Bản đồ

| Mục | Khi nào bạn cần đọc mục này |
|---|---|
| [1. Ba từ khác nhau](#1-ha-vs-fault-tolerance-vs-dr--ba-từ-đề-thi-dùng-khác-nhau) | Đề dùng `highly available` hay `fault-tolerant` — chúng dẫn tới đáp án khác nhau |
| [2. Rà single point of failure](#2-rà-single-point-of-failure) | Đề mô tả một kiến trúc và hỏi "điểm yếu ở đâu" |
| [3. Multi-AZ nghĩa là gì cho từng dịch vụ](#3-multi-az-nghĩa-là-gì--mỗi-dịch-vụ-một-kiểu) | Đề nói "enable Multi-AZ" — nhưng Multi-AZ của RDS khác Aurora khác EFS |
| [4. Health check ở từng tầng](#4-health-check--tầng-nào-phát-hiện-được-cái-gì) | Đề hỏi "vì sao traffic vẫn đi vào instance hỏng" |
| [5. Stateless và tách state](#5-stateless--tách-state-ra-đâu) | Đề nhắc session, sticky session, "users get logged out" |
| [6. Decoupling](#6-decoupling--để-một-mảnh-chết-không-kéo-cả-hệ-thống) | Đề nhắc "tightly coupled", "backend cannot keep up", spike |
| [7. Auto healing](#7-auto-healing--tự-sửa-mà-không-cần-người) | Đề nhắc "without manual intervention", "automatically replace" |
| [8. Multi-Region: khi nào thật sự cần](#8-multi-region--khi-nào-thật-sự-cần-và-cái-giá) | Đề nhắc Region outage, global users, RTO/RPO chặt |
| [9. Quorum và split brain](#9-quorum-và-split-brain--mức-khái-niệm) | Đề hỏi vì sao cần 3 AZ chứ không phải 2 |
| [Bảng số phải nhớ](#bảng-số-phải-nhớ) | 30 phút trước giờ thi |

---

## 1. HA vs fault tolerance vs DR — ba từ đề thi dùng khác nhau

Đây là chỗ mất điểm oan nhiều nhất, vì tiếng Việt lẫn tiếng Anh đời thường dùng ba
từ này lẫn lộn. Đề thi thì không.

| | High Availability | Fault Tolerance | Disaster Recovery |
|---|---|---|---|
| Hứa gì | Hệ thống **quay lại** hoạt động nhanh | Hệ thống **không hề gián đoạn** | Hệ thống **dựng lại được** sau thảm họa |
| Có downtime không | Có, ngắn (giây đến phút) | **Không** | Có, tính bằng RTO |
| Mất dữ liệu | Không (nếu replication đồng bộ) | Không | Có thể, tính bằng RPO |
| Phạm vi lỗi chịu được | Mất một instance, một AZ | Mất một thành phần **bất kỳ** mà không ai nhận ra | Mất cả một Region |
| Ví dụ AWS | RDS Multi-AZ (failover 60–120 giây) | Aurora với replica + ALB, S3, DynamoDB | Backup cross-Region, Pilot Light, Warm Standby |
| Chi phí | Trung bình | Cao nhất | Tùy chiến lược |

Ba câu để phân biệt trong đầu:

- **HA = phục hồi nhanh.** Có một khoảng thời gian hệ thống không phục vụ được, chỉ
  là nó ngắn. Cơ chế điển hình: standby thụ động + failover tự động.
- **Fault tolerance = dư thừa đang hoạt động.** Không có "failover" vì không có gì
  phải chuyển — mọi thành phần đều đang phục vụ, mất một cái thì cái khác gánh.
  Cơ chế điển hình: N+1 hoặc N+M active.
- **DR = kế hoạch cho việc mất cả một khu vực.** Nó là về *thời gian dựng lại* và
  *lượng dữ liệu mất*, không phải về việc chạy liên tục.

**Bẫy cụ thể:** đề nói *"the database must remain available with no downtime during
an Availability Zone failure"*. Từ `no downtime` loại **RDS Multi-AZ** (có failover
60–120 giây) và chọn **Aurora với reader ở AZ khác** hoặc **RDS Multi-AZ DB cluster**
(failover dưới 35 giây, gần nhất với "no downtime" trong danh sách RDS). Nếu đề chỉ
nói `highly available` thì RDS Multi-AZ là đủ và rẻ hơn.

### Từ availability ra số 9

| Availability | Downtime mỗi năm | Downtime mỗi tháng | Kiến trúc điển hình |
|---|---|---|---|
| 99% | 3,65 ngày | 7,2 giờ | Một instance, không HA |
| 99,9% ("ba số 9") | 8,77 giờ | 43,8 phút | Multi-AZ, một Region |
| 99,95% | 4,38 giờ | 21,9 phút | RDS Multi-AZ DB cluster |
| 99,99% ("bốn số 9") | 52,6 phút | 4,38 phút | Multi-AZ đầy đủ + auto healing |
| 99,999% ("năm số 9") | 5,26 phút | 26 giây | Multi-Region active-active |

Hai điều rút ra, và đề thi có ra cả hai:

1. **Availability của một chuỗi phụ thuộc là tích các thành phần.** ALB 99,99% ×
   EC2 99,99% × RDS 99,95% = 99,93%. Thêm một thành phần vào đường đi bắt buộc là
   **giảm** availability tổng, trừ khi thành phần đó có dư thừa.
2. **Bốn số 9 gần như là trần của một Region.** Muốn năm số 9 thì phải multi-Region,
   và giá nhảy vọt. Đề dùng con số 99,99% để gợi ý "multi-AZ là đủ" và 99,999% để
   gợi ý "cần multi-Region".

**Durability không phải availability.** S3 có durability 99,999999999% (khả năng
mất dữ liệu) nhưng availability SLA chỉ 99,9% (khả năng gọi được API). Đề trộn hai
con số này để bẫy.

---

## 2. Rà single point of failure

SPOF là bất kỳ thành phần nào mà **mất nó thì cả hệ thống ngừng**. Cách rà nhanh:
đi dọc đường đi của một request và hỏi "cái này có mấy cái?".

```
Người dùng
   │
   ▼ DNS          Route 53 — global, AWS lo. KHÔNG phải SPOF của bạn.
   │              (SPOF nếu bạn tự chạy DNS trên một EC2)
   ▼ CDN          CloudFront — global. Không SPOF.
   │
   ▼ Load balancer  ALB/NLB — CÓ node ở mỗi AZ bạn bật subnet.
   │                SPOF nếu bạn chỉ bật MỘT subnet.  ← lỗi hay gặp
   │
   ▼ Compute      EC2 trong ASG — SPOF nếu min=1, hoặc nếu ASG chỉ có subnet 1 AZ.
   │              SPOF nếu instance chạy ngoài ASG.   ← lỗi hay gặp
   │
   ▼ State/session  SPOF nếu session nằm trên đĩa local của instance.  ← lỗi hay gặp
   │
   ▼ Database     RDS single-AZ = SPOF. RDS Multi-AZ = không.
   │              NHƯNG: read replica KHÔNG phải HA cho writer.        ← bẫy
   │
   ▼ Storage      EBS gắn 1 AZ = SPOF cho instance đó.
   │              EFS/S3 = trải nhiều AZ, không SPOF.
   │
   ▼ Phụ thuộc ngoài  NAT Gateway đơn = SPOF cho mọi outbound của private subnet.
                      Interface endpoint chỉ ở 1 AZ = SPOF.            ← lỗi hay gặp
```

Sáu SPOF mà đề thi cài nhiều nhất:

1. **Một NAT Gateway cho cả VPC.** NAT Gateway gắn với một AZ. AZ đó chết là mọi
   private subnet mất đường ra internet, kể cả subnet ở AZ khỏe mạnh. Sửa: một NAT
   Gateway mỗi AZ, mỗi route table trỏ về NAT cùng AZ.
2. **ALB chỉ bật một subnet.** ALB đòi tối thiểu 2 subnet ở 2 AZ khi tạo, nhưng
   target có thể vẫn dồn vào một AZ.
3. **Session trên local disk.** Instance chết là người dùng đăng xuất. Xem [mục 5](#5-stateless--tách-state-ra-đâu).
4. **RDS single-AZ.** Kể cả có read replica.
5. **Instance chạy ngoài ASG.** Không có gì thay thế nó khi nó chết.
6. **ElastiCache Redis một node.** Không có replica thì mất node là mất cache, và
   với nhiều kiến trúc thì mất cache = sập database phía sau (cache stampede).

**Bẫy quan trọng: read replica không phải là HA.** RDS read replica là bản sao
**bất đồng bộ**, dùng để scale đọc. Khi primary chết, read replica **không tự động**
được promote — bạn phải promote thủ công, và có thể mất dữ liệu chưa kịp replicate.
Muốn HA cho RDS thì bật **Multi-AZ**, thứ dùng standby **đồng bộ** và tự failover.
Hai tính năng này độc lập và có thể bật cùng lúc. Đề rất hay đưa "add a read
replica" làm đáp án sai cho câu hỏi HA.

---

## 3. Multi-AZ nghĩa là gì — mỗi dịch vụ một kiểu

Nút "Multi-AZ" của từng dịch vụ làm những việc khác nhau. Đây là bảng cần thuộc.

| Dịch vụ | "Multi-AZ" nghĩa là gì cụ thể | Standby có phục vụ traffic không | Failover mất bao lâu |
|---|---|---|---|
| **ELB (ALB/NLB)** | Một node LB ở mỗi AZ bạn bật subnet; Route 53 trả nhiều IP | Có, tất cả đều phục vụ | Không có khái niệm failover |
| **Auto Scaling Group** | ASG trải instance đều qua các subnet bạn khai báo; tự cân bằng lại (`AZRebalance`) | Có, tất cả đều phục vụ | Thay thế instance: vài phút |
| **RDS Multi-AZ (instance deployment)** | Một standby ở AZ khác, replication **đồng bộ**, **không đọc được** | **Không** — standby hoàn toàn thụ động | **60–120 giây**, đổi CNAME |
| **RDS Multi-AZ DB cluster** | **Hai** readable standby ở 2 AZ khác, replication native của engine | **Có**, đọc được | **Dưới 35 giây** (điển hình ~20 giây) |
| **Aurora** | Storage tự nhân **6 bản trên 3 AZ**; compute là 1 writer + tới 15 reader | Reader phục vụ đọc | **Dưới 30 giây** nếu có reader; ~10 phút nếu không |
| **EFS (Regional)** | File system trải nhiều AZ; một mount target mỗi AZ | Có | Trong suốt |
| **EFS One Zone** | Chỉ **một AZ** — rẻ hơn ~47% nhưng mất AZ là mất dữ liệu | — | Không có |
| **ElastiCache Redis (cluster mode disabled)** | 1 primary + tới 5 replica; bật **Multi-AZ with automatic failover** thì replica ở AZ khác được promote | Replica đọc được | **Dưới 60 giây** thường thấy |
| **ElastiCache Memcached** | Không có replication. "Multi-AZ" chỉ là trải node qua AZ | Mỗi node độc lập | **Không có failover** — mất node là mất phần dữ liệu đó |
| **S3 (trừ One Zone-IA)** | Tự động ≥3 AZ, không có nút bật | Có | Trong suốt |
| **DynamoDB** | Tự động 3 AZ, không có nút bật | Có | Trong suốt |
| **EBS** | **Không có Multi-AZ.** Volume nằm trong đúng một AZ | — | — |

Năm điều rút ra, mỗi điều là một câu hỏi thi:

1. **RDS Multi-AZ standby không đọc được.** Đáp án "bật Multi-AZ để giảm tải đọc"
   luôn sai. Muốn giảm tải đọc thì **read replica**. Ngoại lệ duy nhất là
   **Multi-AZ DB cluster** (hai standby đọc được) — nếu đề liệt kê nó thì đọc kỹ.
2. **Aurora tách storage khỏi compute.** Storage đã sẵn 6 bản trên 3 AZ ngay cả khi
   bạn chỉ có một instance. Nhưng nếu chỉ có một instance thì **compute vẫn là SPOF**
   — Aurora phải dựng instance mới, mất khoảng 10 phút. Thêm một reader thì failover
   xuống dưới 30 giây. Đề hỏi "Aurora single instance có HA không" → dữ liệu an
   toàn nhưng khả dụng thì không.
3. **Memcached không có failover.** Nếu đề nói cần HA cho cache → **Redis**, không
   phải Memcached. Memcached đúng cho cache đơn giản, đa luồng, có thể mất mà không sao.
4. **EFS One Zone là bẫy chi phí.** Rẻ hơn nhưng phá HA. Cùng logic với S3 One Zone-IA.
5. **EBS không bao giờ multi-AZ.** Muốn dữ liệu block sống sót qua AZ thì phải
   snapshot (snapshot lưu ở S3, tức là regional) hoặc đổi sang EFS.

### Cross-zone load balancing — chi tiết nhỏ hay ra thi

| | ALB | NLB |
|---|---|---|
| Cross-zone mặc định | **Bật** | **Tắt** |
| Phí data transfer cross-AZ khi bật | **Không tính** | **Có tính** |
| Tắt/bật được | Được (theo target group) | Được |

Không bật cross-zone thì mỗi node LB chỉ gửi traffic tới target trong **AZ của
chính nó**. Nếu AZ-a có 2 target và AZ-b có 8 target, mỗi target ở AZ-a nhận
**gấp 4 lần** lượng traffic. Đề mô tả "một số instance quá tải trong khi số khác
nhàn rỗi" → nghĩ tới cross-zone và phân bố target không đều.

---

## 4. Health check — tầng nào phát hiện được cái gì

Ba tầng health check, ba mục đích khác nhau. Đề thi hỏi "vì sao instance hỏng vẫn
nhận traffic" và câu trả lời luôn nằm ở việc dùng nhầm tầng.

| | Kiểm tra cái gì | Hành động khi fail | Không phát hiện được |
|---|---|---|---|
| **EC2 status check** (hạ tầng) | `system` (host của AWS), `instance` (OS của bạn) | Không làm gì, trừ khi bạn đặt CloudWatch alarm hoặc auto recovery | Ứng dụng chết mà OS còn sống |
| **ASG health check — kiểu EC2** (mặc định) | Chỉ EC2 status check | Terminate + launch instance mới | Ứng dụng chết, tiến trình treo, cổng đóng |
| **ASG health check — kiểu ELB** | Kết quả health check của ELB | Terminate + launch instance mới | Lỗi ngoài phạm vi endpoint được check |
| **ELB target health check** | HTTP GET tới path bạn chỉ định (hoặc TCP) | **Ngừng gửi traffic** tới target đó, nhưng **không** giết nó | Lỗi phụ thuộc mà endpoint không kiểm tra |
| **Route 53 health check** | Endpoint public, từ nhiều vị trí trên thế giới | Rút bản ghi DNS khỏi kết quả trả về | Lỗi chỉ ảnh hưởng một phần người dùng |

**Bẫy số một của mục này:** ASG mặc định dùng health check kiểu **EC2**. Nếu ứng
dụng của bạn treo nhưng OS vẫn chạy, EC2 status check vẫn PASS → ASG coi instance
khỏe → không thay thế. Trong khi đó ALB đã ngừng gửi traffic tới nó. Kết quả:
capacity thực tế giảm mà ASG không biết, không scale bù.

Sửa: đổi ASG sang **health check type ELB** với `health_check_grace_period` đủ dài
cho ứng dụng khởi động. Đây là câu hỏi ra thi rất thường xuyên, thường dưới dạng
*"instances are marked unhealthy by the load balancer but Auto Scaling does not
replace them"*.

**Bẫy số hai: health check quá nông.** Path `/` trả 200 tĩnh sẽ PASS ngay cả khi
database đã chết. Health check nên chạm vào phụ thuộc quan trọng — nhưng đừng chạm
quá sâu, vì khi database chậm thì **toàn bộ** fleet bị đánh dấu unhealthy cùng lúc
và ASG giết sạch. Thực hành chuẩn: tách `/health/live` (tôi còn sống, dùng cho ASG)
khỏi `/health/ready` (tôi sẵn sàng nhận traffic, dùng cho ELB).

**Route 53 health check — ba chi tiết ra thi:**

- Tần suất: **30 giây** (standard) hoặc **10 giây** (fast, tính thêm tiền).
- Cần **3 lần fail liên tiếp** mặc định để chuyển sang unhealthy.
- **Calculated health check** gộp nhiều health check con bằng logic AND/OR; dùng
  cho "chỉ failover khi cả web lẫn database đều hỏng".
- Health check chỉ gọi được endpoint **public**. Muốn theo dõi tài nguyên private
  thì tạo CloudWatch alarm rồi dùng **health check kiểu CloudWatch alarm**.

Thời gian phát hiện + TTL của bản ghi DNS = độ trễ thực tế của DNS failover. TTL
300 giây nghĩa là resolver vẫn trả IP cũ trong 5 phút sau khi bạn chuyển. Đề nói
"failover phải xong trong 60 giây" → phải đặt **TTL 60 hoặc thấp hơn**, và đây là
đáp án hay bị bỏ sót.

---

## 5. Stateless — tách state ra đâu

Một tier stateless là tier mà **bất kỳ instance nào cũng xử lý được bất kỳ request
nào**. Đó là điều kiện tiên quyết của mọi thứ trong file này: không stateless thì
không scale out được, không thay thế instance được, không dùng Spot được.

State nằm ở đâu trong một ứng dụng web, và chuyển đi đâu:

| State | Chỗ sai (trên instance) | Chỗ đúng |
|---|---|---|
| Session người dùng | File session trên đĩa | **ElastiCache Redis**, DynamoDB, hoặc JWT có chữ ký (không lưu server-side) |
| File người dùng upload | Thư mục local | **S3** |
| File chia sẻ giữa các instance | NFS tự dựng trên một EC2 | **EFS** (Linux), **FSx for Windows** (Windows/SMB) |
| Cache tính toán | Bộ nhớ tiến trình | ElastiCache (nếu cần chia sẻ), hoặc chấp nhận cache cục bộ nếu mất được |
| Log | `/var/log` trên máy | **CloudWatch Logs**, hoặc S3 qua Firehose |
| Cấu hình và bí mật | File `.env` trên máy | **SSM Parameter Store**, **Secrets Manager** |

### Sticky session là giải pháp tạm, không phải giải pháp

ALB có sticky session (cookie `AWSALB` do LB tạo, hoặc cookie do ứng dụng tạo). Nó
buộc một người dùng luôn về cùng một instance, nên session trên local disk vẫn chạy.

Vì sao đề thi coi đây là đáp án kém:

- Instance chết → người dùng ràng vào nó **mất session**, phải đăng nhập lại.
- Phân bố tải lệch — instance mới thêm vào không nhận được người dùng cũ.
- Scale in giết instance là giết luôn session của người dùng trên đó.

Sticky session là đáp án đúng chỉ khi đề nói rõ **"không được sửa ứng dụng"**. Nếu
đề cho phép thay đổi kiến trúc, đáp án là **đưa session ra ElastiCache hoặc DynamoDB**.

---

## 6. Decoupling — để một mảnh chết không kéo cả hệ thống

Ghép chặt (tight coupling) nghĩa là A gọi B đồng bộ và chờ. B chậm thì A chậm. B
chết thì A chết. Ghép lỏng là chèn một lớp đệm vào giữa.

| Cơ chế | Kiểu | Dùng khi |
|---|---|---|
| **SQS** | Hàng đợi, một message một consumer | Cần đệm tải, cần retry, cần xử lý bất đồng bộ. Producer không cần biết consumer là ai |
| **SNS** | Pub/sub, fan-out tới nhiều subscriber | Một sự kiện cần nhiều bên xử lý |
| **SNS + SQS (fan-out)** | Kết hợp | Nhiều bên xử lý, mỗi bên có hàng đợi riêng để đệm và retry độc lập. **Mẫu chuẩn của đề thi** |
| **EventBridge** | Event bus có routing rule, lọc theo nội dung | Kiến trúc event-driven, tích hợp SaaS, lịch chạy (`cron`) |
| **Kinesis Data Streams** | Stream có thứ tự, nhiều consumer đọc lại được | Cần **thứ tự** và **replay**. Dữ liệu giữ 24 giờ (tới 365 ngày) |
| **Step Functions** | Orchestration có state | Workflow nhiều bước, cần retry/catch từng bước, cần thấy trạng thái |

Ba tính chất mà decoupling mang lại cho tính sẵn sàng:

1. **Đệm tải (buffering).** Traffic tăng 10 lần trong 5 phút: không có hàng đợi thì
   backend sập; có hàng đợi thì message xếp hàng và backend xử lý theo tốc độ của
   nó. Đề mô tả "spike causes the backend to fail" → **SQS ở giữa**.
2. **Cô lập lỗi.** Consumer chết thì message vẫn nằm trong hàng đợi (SQS giữ tới
   **14 ngày**). Khi consumer sống lại, không mất gì.
3. **Scale độc lập.** ASG của consumer scale theo `ApproximateNumberOfMessagesVisible`
   thay vì CPU. Đây là **target tracking metric** đúng cho worker tier, và đề có ra.

### Bốn chi tiết SQS ra thi

- **Visibility timeout.** Message được lấy ra sẽ ẩn trong khoảng thời gian này. Nếu
  consumer chưa `DeleteMessage` xong trước khi hết hạn, message hiện lại và bị xử lý
  lần nữa. Đề mô tả "messages are processed twice" → visibility timeout ngắn hơn
  thời gian xử lý.
- **Dead Letter Queue.** Sau `maxReceiveCount` lần thất bại, message chuyển sang DLQ
  thay vì lặp vô hạn. Đề nhắc "poison message", "one message blocks the queue" → DLQ.
- **FIFO queue** đảm bảo thứ tự và exactly-once processing, nhưng throughput thấp hơn
  Standard (300 TPS, hoặc 3.000 với batching; high-throughput mode cao hơn nhiều).
  Chỉ chọn FIFO khi đề nói rõ cần **thứ tự** hoặc **không trùng lặp**.
- **Long polling** (`WaitTimeSeconds` tới 20 giây) giảm cả chi phí lẫn số request
  rỗng so với short polling. Gần như luôn là đáp án đúng khi đề hỏi tối ưu SQS.

Chi tiết đầy đủ ở [`06-tich-hop.md`](06-tich-hop.md).

---

## 7. Auto healing — tự sửa mà không cần người

Từ khóa trong đề: `without manual intervention`, `automatically`, `self-healing`,
`minimize downtime`.

| Lớp | Cơ chế tự sửa | Điều kiện để nó hoạt động |
|---|---|---|
| Instance đơn lẻ | **EC2 Auto Recovery** — khởi động lại instance trên host khác, giữ nguyên ID, IP, EBS | Bật mặc định trên instance dựa trên Nitro. Chỉ sửa lỗi hạ tầng của AWS, không sửa lỗi OS |
| Fleet | **Auto Scaling Group** — thay thế instance unhealthy | Phải đặt health check type ELB (xem [mục 4](#4-health-check--tầng-nào-phát-hiện-được-cái-gì)) |
| Container | ECS/EKS scheduler khởi động lại task/pod hỏng | Cần liveness/health check đúng |
| Database | RDS Multi-AZ / Aurora failover | Phải bật Multi-AZ; ứng dụng phải **retry kết nối** |
| DNS | Route 53 failover routing | Cần health check và TTL thấp |
| Toàn vùng | Không có auto healing tự động — đây là DR | Xem [13](13-khoi-phuc-tham-hoa.md) |

**Auto Recovery vs Auto Scaling — khác nhau ở đâu.** Auto Recovery giữ **cùng một
instance** (cùng instance ID, cùng private IP, cùng EBS volume) và chỉ chuyển sang
host vật lý khác. Auto Scaling **tạo instance mới hoàn toàn** từ launch template.
Đề nói "phải giữ nguyên IP và dữ liệu trên EBS" → Auto Recovery. Đề nói "ứng dụng
stateless, cần thay thế nhanh" → ASG.

**Điều kiện ngầm mà đề hay kiểm tra: ứng dụng phải chịu được failover.** RDS
Multi-AZ failover đổi CNAME; connection pool đang giữ kết nối cũ sẽ lỗi. Nếu ứng
dụng không retry, "automatic failover" vẫn dẫn tới lỗi cho người dùng. Đáp án đúng
cho câu "vì sao vẫn có lỗi sau khi bật Multi-AZ" là **implement connection retry
logic**, không phải "tăng size instance".

### Ba chi tiết ASG ra thi

- **Health check grace period.** Khoảng thời gian sau khi launch mà ASG bỏ qua health
  check. Đặt quá ngắn thì ASG giết instance đang khởi động → vòng lặp launch-kill vô
  tận. Đề mô tả "instances are terminated shortly after launching" → tăng grace period.
- **Lifecycle hook.** Tạm dừng instance ở trạng thái `Pending:Wait` hoặc
  `Terminating:Wait` để chạy việc gì đó (nạp dữ liệu, đẩy log ra ngoài trước khi
  chết). Đề nhắc "must upload logs before termination" → lifecycle hook.
- **Termination policy.** Mặc định ASG giết instance ở AZ có nhiều instance nhất,
  rồi tới instance có launch configuration cũ nhất. `OldestInstance`,
  `NewestInstance`, `ClosestToNextInstanceHour` là các lựa chọn khác. Đề nhắc
  "ensure the oldest instances are replaced first" → đổi termination policy.

---

## 8. Multi-Region — khi nào thật sự cần và cái giá

Multi-Region đắt và phức tạp. Đề thi biết điều đó, nên nó chỉ là đáp án đúng khi
có một trong bốn lý do sau **được nêu rõ trong đề**:

1. **Yêu cầu chịu được mất cả một Region** — `Region-wide outage`, `RTO of X` với
   X nhỏ và phạm vi là Region.
2. **Ràng buộc pháp lý** — dữ liệu phải tồn tại ở nhiều quốc gia.
3. **Người dùng toàn cầu cần độ trễ ghi thấp** — chú ý chữ **ghi**. Nếu chỉ cần
   **đọc** nhanh thì CloudFront hoặc read replica là đủ và rẻ hơn nhiều.
4. **Availability mục tiêu năm số 9 (99,999%)** — vượt trần thực tế của một Region.

Nếu đề không nêu lý do nào trong bốn cái trên, **multi-Region là đáp án sai** dù
nghe hợp lý. Multi-AZ giải quyết được gần hết.

### Cái giá phải trả

| Chi phí | Cụ thể |
|---|---|
| Tiền hạ tầng | Nhân đôi (hoặc gần đôi) toàn bộ compute và storage |
| Data transfer | ~$0,02/GB cho mọi byte replicate cross-Region |
| **Độ phức tạp dữ liệu** | Đây mới là cái đắt nhất. Xem bên dưới |
| Vận hành | Deploy hai nơi, test failover định kỳ, giữ cấu hình đồng bộ |
| Quota và IAM | Quota tính theo Region; phải xin tăng ở cả hai nơi |

**Vấn đề dữ liệu là vấn đề thật.** RTT cross-Region 10–200 ms khiến replication đồng
bộ bất khả thi. Mọi cơ chế cross-Region đều bất đồng bộ, dẫn tới hai hệ quả:

- **RPO > 0.** Luôn có một lượng dữ liệu đã ghi ở Region A nhưng chưa tới Region B.
- **Ghi ở hai nơi cùng lúc thì có xung đột.** DynamoDB Global Tables giải bằng
  **last writer wins** — nghĩa là một trong hai bản ghi **bị mất im lặng**. Nếu
  nghiệp vụ không chấp nhận được điều đó (số dư tài khoản, tồn kho), active-active
  không dùng được và bạn phải quay về active-passive với một writer duy nhất.

### Ba mẫu multi-Region

| Mẫu | Ghi ở đâu | Dùng khi |
|---|---|---|
| **Active-passive (DR)** | Chỉ Region chính | Phần lớn trường hợp. Xem [13](13-khoi-phuc-tham-hoa.md#3-bốn-chiến-lược-dr) |
| **Read-local, write-global** | Một Region ghi, nhiều Region đọc | Người dùng toàn cầu đọc nhiều, ghi ít. Aurora Global Database, DynamoDB Global Tables |
| **Active-active thật sự** | Mọi Region đều ghi | Chỉ khi nghiệp vụ chịu được xung đột. Route 53 latency routing hoặc Global Accelerator ở phía trước |

---

## 9. Quorum và split brain — mức khái niệm

Đề SAA không hỏi thuật toán, nhưng có hỏi hệ quả kiến trúc của chúng.

**Quorum** là số phiếu tối thiểu để một cụm phân tán ra quyết định. Với cụm N node,
quorum thường là ⌊N/2⌋+1. Với 3 node thì quorum là 2 — cụm chịu được mất 1 node.
Với 2 node thì quorum là 2 — cụm **không chịu được mất node nào**, vì mất 1 là còn
1, không đủ quorum.

**Đây chính là lý do "3 AZ" xuất hiện khắp nơi.** Một hệ thống cần quorum mà chỉ có
2 AZ thì mất một AZ là tê liệt. Aurora, etcd, ZooKeeper, Kafka, và mọi thứ dùng
consensus đều muốn số lẻ node trải trên 3 AZ.

**Split brain** là tình huống mạng bị chia đôi, hai nửa đều tưởng nửa kia đã chết,
và cả hai cùng nhận vai trò primary. Kết quả: hai bản dữ liệu phân kỳ, không hòa
giải được. Quorum ngăn split brain vì chỉ một bên có thể đạt đa số.

Ba chỗ điều này ra thi:

1. **Vì sao Aurora nhân dữ liệu 6 lần trên 3 AZ.** Aurora cần 4/6 để ghi và 3/6 để
   đọc. Cấu hình này chịu được mất **cả một AZ** (2 bản) mà vẫn ghi được, và mất
   một AZ cộng thêm một bản nữa mà vẫn đọc được.
2. **Vì sao khuyến nghị 3 AZ chứ không phải 2** cho hệ thống nghiêm túc. Ngoài lý do
   quorum, còn lý do chi phí đã nêu ở [00-nen-tang.md](00-nen-tang.md#cây-quyết-định):
   3 AZ chỉ cần dư 150% capacity, 2 AZ cần 200%.
3. **Vì sao active-active multi-Region khó.** Không có quorum nào chạy được qua RTT
   100 ms mà giữ throughput ghi. Nên các hệ thống cross-Region chọn eventual
   consistency + last writer wins thay vì consensus.

---

## Bảng số phải nhớ

| Con số | Giá trị | Vì sao ra thi |
|---|---|---|
| RDS Multi-AZ (instance) failover | **60–120 giây** | Loại đáp án khi đề nói "no downtime" |
| RDS Multi-AZ DB cluster failover | **dưới 35 giây** (điển hình ~20) | Lựa chọn khi cần nhanh hơn Multi-AZ thường |
| Aurora failover có reader | **dưới 30 giây** | Đáp án cho "minimal downtime" trên RDS family |
| Aurora không có reader | ~10 phút | Vì sao single-instance Aurora không phải HA |
| Aurora storage | **6 bản trên 3 AZ**; ghi cần 4/6, đọc cần 3/6 | Câu hỏi quorum |
| ElastiCache Redis failover | dưới ~60 giây | Cần bật "Multi-AZ with automatic failover" |
| SQS message retention | mặc định 4 ngày, tối đa **14 ngày** | Consumer chết bao lâu thì vẫn cứu được |
| SQS visibility timeout | mặc định 30 giây, tối đa 12 giờ | Bài toán "message processed twice" |
| SQS long polling | tối đa **20 giây** | Tối ưu chi phí và số request rỗng |
| Route 53 health check | 30 giây (standard) / 10 giây (fast); **3 lần fail** | Tính thời gian phát hiện |
| Route 53 TTL cho failover nhanh | **60 giây hoặc thấp hơn** | Chi tiết hay bị bỏ sót |
| ALB cross-zone | **bật mặc định**, không tính phí cross-AZ | So với NLB |
| NLB cross-zone | **tắt mặc định**, có tính phí khi bật | So với ALB |
| ASG health check mặc định | **kiểu EC2** (không phải ELB) | Bẫy số một của mục health check |
| Availability 99,99% | 52,6 phút/năm | Trần thực tế của một Region |
| Availability 99,999% | 5,26 phút/năm | Buộc phải multi-Region |
| Dư thừa capacity cho N AZ | N/(N−1) → 2 AZ:200%, 3 AZ:150% | 3 AZ rẻ hơn 2 AZ cho cùng mức chịu lỗi |

---

## Bẫy đề thi

**Bẫy 1 — read replica được coi là HA**

> *RDS MySQL là single point of failure. Cần database chịu được mất một AZ.* —
> "Create a read replica in another AZ" là bẫy. Read replica là **bất đồng bộ**,
> **không tự promote**, và có thể mất dữ liệu khi promote thủ công. Đáp án là
> **bật Multi-AZ**. Hai tính năng độc lập: Multi-AZ cho HA, read replica cho scale đọc.

**Bẫy 2 — ASG không thay thế instance bị ALB đánh dấu unhealthy**

> *ALB báo target unhealthy nhưng Auto Scaling không thay thế chúng.* — "Tăng số
> lượng instance tối đa" không giải quyết gì. Nguyên nhân: ASG dùng health check
> **kiểu EC2** mặc định, mà EC2 status check vẫn PASS khi ứng dụng treo. Đáp án:
> đổi ASG sang **health check type ELB** với grace period đủ dài.

**Bẫy 3 — Multi-AZ để giảm tải đọc**

> *Database quá tải vì report chạy nhiều query đọc.* — "Enable Multi-AZ" là bẫy:
> standby của RDS Multi-AZ (instance deployment) **hoàn toàn thụ động**, không nhận
> query. Đáp án: **read replica**, hoặc chuyển sang Aurora với reader endpoint.

**Bẫy 4 — sticky session được coi là giải pháp**

> *Người dùng bị đăng xuất khi ASG scale in.* — "Bật sticky session trên ALB" chỉ
> giấu vấn đề: instance bị giết vẫn mang theo session của người dùng ràng vào nó.
> Đáp án: **đưa session ra ElastiCache Redis hoặc DynamoDB**. Sticky session chỉ
> đúng khi đề nói rõ "không được sửa ứng dụng".

**Bẫy 5 — một NAT Gateway là đủ**

> *Kiến trúc 3 AZ, private subnet cần ra internet, phải chịu được mất một AZ.* —
> "Một NAT Gateway ở AZ-a, mọi route table trỏ về nó" rẻ hơn nhưng NAT Gateway gắn
> **một AZ**; AZ đó chết là **cả ba** private subnet mất đường ra. Đáp án: **một
> NAT Gateway mỗi AZ**, mỗi route table trỏ về NAT cùng AZ.

**Bẫy 6 — multi-Region cho một bài toán multi-AZ**

> *Ứng dụng phải chịu được mất một data center, cost-effective.* — "Deploy sang
> Region thứ hai với active-active" giải quyết vấn đề lớn hơn nhiều so với đề hỏi,
> với giá đắt hơn nhiều lần. "Một data center" là **AZ**, không phải Region. Đáp án:
> **ALB + ASG trên nhiều AZ + RDS Multi-AZ**.

**Bẫy 7 — Memcached cho cache cần HA**

> *Session store cho ứng dụng web, phải chịu được mất một node.* — "ElastiCache for
> Memcached với nhiều node" là bẫy: Memcached không có replication, mất node là mất
> phần dữ liệu trên node đó vĩnh viễn. Đáp án: **ElastiCache for Redis** với replica
> và Multi-AZ automatic failover bật.

---

## Cây quyết định

**Đề hỏi "highly available" — chạy theo thứ tự:**

1. Phạm vi lỗi mà đề yêu cầu chịu được là gì?
   - "instance failure" → ASG với min ≥ 2
   - "Availability Zone failure" / "data center failure" → Multi-AZ
   - "Region failure" → sang [13-khoi-phuc-tham-hoa.md](13-khoi-phuc-tham-hoa.md)
2. Đề có nói `no downtime` / `zero downtime` không?
   - Có → cần fault tolerance, loại mọi đáp án có failover mất phút
   - Không, chỉ `highly available` → failover 1–2 phút chấp nhận được
3. Rà [danh sách SPOF](#2-rà-single-point-of-failure) trên kiến trúc đề mô tả. Đáp
   án đúng thường là cái vá đúng SPOF lớn nhất.
4. Còn hai đáp án? → Chọn cái **ít việc vận hành hơn**, và cái **rẻ hơn** nếu ràng
   buộc đã thỏa.

**Chọn cơ chế HA cho database:**

```
Engine gì?
├── MySQL/PostgreSQL/MariaDB/Oracle/SQL Server (RDS)
│   ├── Chỉ cần HA, failover 1–2 phút chấp nhận được ──► Multi-AZ instance deployment
│   ├── Cần failover dưới 1 phút + standby đọc được ──► Multi-AZ DB cluster (MySQL/PostgreSQL)
│   └── Cần scale đọc ──────────────────────────────► + Read replica (KHÔNG thay Multi-AZ)
├── MySQL/PostgreSQL, cần hiệu năng và HA tốt hơn ──► Aurora (≥1 reader ở AZ khác)
├── Cần chịu mất Region ────────────────────────────► Aurora Global Database
├── NoSQL key-value ────────────────────────────────► DynamoDB (đã 3 AZ sẵn)
└── Cache
    ├── Cần HA, cần persistence, cần replication ───► ElastiCache Redis + Multi-AZ failover
    └── Cache đơn giản, mất được ───────────────────► ElastiCache Memcached
```

**Chọn cơ chế decoupling:**

```
Cần gì?
├── Đệm tải, retry, một message một consumer ─────► SQS
├── Một sự kiện, nhiều bên xử lý ─────────────────► SNS (+ SQS mỗi bên nếu cần đệm)
├── Routing theo nội dung, tích hợp SaaS, lịch ───► EventBridge
├── Thứ tự + đọc lại được nhiều lần ──────────────► Kinesis Data Streams
└── Workflow nhiều bước, cần thấy trạng thái ─────► Step Functions
```

---

## Nối với thực hành

| Lab | Chạm vào mục nào | Quan sát gì |
|---|---|---|
| [`labs/w03-ec2-alb-asg/`](../../learn-aws/labs/w03-ec2-alb-asg/) | Mục 2, 4, 7 | Chạy `ansible/chaos.yml` để giết instance. Xem ALB rút target khỏi rotation trước, rồi ASG launch instance mới. Thử đổi health check type EC2 ↔ ELB và so sánh hành vi |
| [`labs/w05-databases/`](../../learn-aws/labs/w05-databases/) | Mục 3 | Bật Multi-AZ rồi gọi `reboot-db-instance --force-failover`, bấm giờ. So với con số 60–120 giây |
| [`labs/w07-decoupling/`](../../learn-aws/labs/w07-decoupling/) | Mục 6 | Tắt consumer, đẩy message vào SQS, xem `ApproximateNumberOfMessagesVisible` tăng. Bật consumer lại — không mất message nào |
| [`labs/w08-dns-cdn-edge/`](../../learn-aws/labs/w08-dns-cdn-edge/) | Mục 4 (Route 53 health check) | Đo thời gian thực tế từ lúc endpoint chết tới lúc DNS trả IP mới. Thử TTL 60 và TTL 300 |
| [`labs/w11-dr-hybrid/`](../../learn-aws/labs/w11-dr-hybrid/) | Mục 8 | Replication cross-Region và độ trễ thực tế của nó |
| [`labs/w12-exam-review/`](../../learn-aws/labs/w12-exam-review/) | Toàn bộ | Rà SPOF trên kiến trúc capstone |
| [`labs-self/`](../../learn-aws/labs-self/) — lab `w03` (tự thiết kế tier web HA) | Mục 2, 3, 4, 5 | `verify.sh` có negative check: giết một instance và kiểm tra dịch vụ vẫn trả 200 |
| [`labs-self/`](../../learn-aws/labs-self/) — lab `w07` (tự thiết kế worker tier) | Mục 6, 7 | Đề bài chỉ nói "backend không được sập khi traffic tăng 10 lần" — chọn cơ chế là việc của bạn |

Bài tuần tương ứng: [`docs/aws/w03-ec2-alb-asg.md`](../aws/w03-ec2-alb-asg.md),
[`docs/aws/w07-decoupling.md`](../aws/w07-decoupling.md).

---

## Nguồn nói khác

| Chỗ | Nguồn `aws-saa-c03/` nói | Thực tế (2026-08) |
|---|---|---|
| File `H-high-availability.md` | `README.md` và `A-nen-tang-kien-truc.md` link tới file này | **Không tồn tại.** File bạn đang đọc thay thế nó |
| HA vs Fault Tolerance | `A-nen-tang-kien-truc.md` ghi "Aurora with replicas (instant)" cho fault tolerance | Aurora failover **dưới 30 giây**, không phải tức thì. Đủ để gọi là HA rất tốt, chưa phải fault tolerance đúng nghĩa. [Aurora availability](https://docs.aws.amazon.com/rds/latest/auroraextendedcontent/aurora-features-availability.html) |
| RDS Multi-AZ | Nguồn chỉ nói "failover 1–2 phút" | Có **hai loại** Multi-AZ. Instance deployment: 60–120 giây, standby không đọc được. **Multi-AZ DB cluster** (2 readable standby): **dưới 35 giây**, standby đọc được, SLA 99,95%. [Multi-AZ DB cluster](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/multi-az-db-clusters-concepts.html) |
| "Multi-AZ = high availability, Auto Scaling = fault tolerance" | `00-tong-quan-overview.md` mục Availability Keywords gợi ý cách phân loại này | Cách phân loại này gây hiểu nhầm. Auto Scaling một mình **không** cho fault tolerance — nó cho auto healing. Fault tolerance cần dư thừa **đang hoạt động** ở mọi tầng cùng lúc |
| Cross-zone load balancing | Nguồn không nhắc | Khác biệt ALB (bật mặc định, miễn phí cross-AZ) và NLB (tắt mặc định, tính phí) là chi tiết ra thi. [ELB cross-zone](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html#cross-zone-load-balancing) |

---

## Ngoài phạm vi

- **Chaos engineering và AWS Fault Injection Service** — biết nó tồn tại là đủ. [FIS](https://docs.aws.amazon.com/fis/latest/userguide/what-is.html)
- **Aurora Global Database write forwarding** — mức Professional. [Write forwarding](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-write-forwarding.html)
- **Thuật toán consensus (Raft, Paxos)** — chỉ cần hiểu hệ quả (quorum, số lẻ node).
- **Route 53 Application Recovery Controller (zonal shift, readiness check)** — mức Professional. [ARC](https://docs.aws.amazon.com/r53recovery/latest/dg/what-is-route53-recovery.html)
- **ELB Gateway Load Balancer** — dùng cho chèn appliance bảo mật, hiếm khi ra SAA.
- **Kinesis enhanced fan-out, resharding** — chi tiết vận hành, không ra SAA.

---

## Tự kiểm tra

**1.** Đề nói: *"The application must remain available with no interruption to users
during an Availability Zone failure."* Bạn đang chọn giữa RDS Multi-AZ, RDS Multi-AZ
DB cluster, và Aurora với hai instance. Chọn cái nào và vì sao hai cái kia yếu hơn?

<details><summary>Đáp án</summary>

Từ khóa quyết định là `no interruption`, không phải `highly available`.

- **RDS Multi-AZ (instance deployment)**: failover 60–120 giây. Có gián đoạn rõ rệt.
  Loại nếu đề nhấn "no interruption".
- **RDS Multi-AZ DB cluster**: failover dưới 35 giây, thường ~20 giây. Tốt hơn nhiều
  vì standby là node **nóng** (engine đang chạy, không phải crash recovery), nhưng
  vẫn có gián đoạn.
- **Aurora với hai instance** (1 writer + 1 reader ở AZ khác): failover dưới 30 giây,
  và storage đã sẵn 6 bản trên 3 AZ nên không phải chờ dữ liệu.

Trong thực tế không lựa chọn nào cho **đúng** zero downtime ở tầng database — đó là
lý do ứng dụng phải có connection retry. Nếu đề liệt kê cả ba, chọn Aurora hoặc
Multi-AZ DB cluster tùy engine đề nêu. Nếu đề chỉ có RDS Multi-AZ và read replica
thì chọn Multi-AZ.

Điểm cần nói được: **failover time và việc ứng dụng phải retry là hai thứ khác nhau**,
và không có kiến trúc RDS nào cho zero downtime tuyệt đối.
</details>

**2.** Vì sao ASG health check kiểu EC2 (mặc định) là một cái bẫy, và điều gì xảy
ra cụ thể trong hệ thống khi bạn để nguyên nó?

<details><summary>Đáp án</summary>

EC2 status check chỉ kiểm tra hai thứ: `system status` (host vật lý và mạng của AWS)
và `instance status` (OS có phản hồi không). Nó **không biết gì** về ứng dụng của bạn.

Kịch bản thật: tiến trình Java hết heap và treo. OS vẫn chạy, vẫn trả lời ping,
`instance status` vẫn PASS. Trong khi đó ALB gọi `/health` bị timeout và đánh dấu
target unhealthy.

Kết quả:
- ALB ngừng gửi traffic tới instance đó — đúng.
- ASG coi instance vẫn khỏe → **không thay thế**.
- Capacity thực tế giảm từ 4 xuống 3 nhưng `DesiredCapacity` vẫn là 4, nên ASG cũng
  **không scale bù**.
- Ba instance còn lại gánh tải của bốn. Nếu tải đủ cao, chúng cũng treo theo — đây
  là cơ chế của một dạng sập dây chuyền.

Sửa: `health_check_type = "ELB"` và `health_check_grace_period` đủ dài (thường
180–300 giây tùy thời gian khởi động ứng dụng). Đặt grace period quá ngắn tạo ra
lỗi ngược lại: ASG giết instance đang boot, launch cái mới, cái mới cũng bị giết
khi đang boot — vòng lặp vô tận.
</details>

**3.** Giải thích vì sao một kiến trúc 3 AZ chịu lỗi tốt hơn 2 AZ theo hai góc độ
khác nhau: quorum và chi phí capacity.

<details><summary>Đáp án</summary>

**Góc quorum:** hệ thống cần đa số phiếu để ra quyết định. Với dữ liệu trải trên 2
AZ, mất một AZ là còn một nửa — không bên nào có đa số, hệ thống hoặc dừng (an toàn)
hoặc phân kỳ thành split brain (nguy hiểm). Với 3 AZ, mất một AZ thì hai AZ còn lại
có 2/3, đủ quorum, hệ thống chạy tiếp và biết chắc bên kia không đang ghi. Đây là
lý do Aurora nhân dữ liệu 6 bản trên 3 AZ với ngưỡng ghi 4/6.

**Góc chi phí capacity:** để chịu được mất một AZ mà vẫn phục vụ 100% tải, với N AZ
thì mỗi AZ phải chạy 1/(N−1) tải:
- 2 AZ: mỗi AZ chạy 100% → tổng cấp phát 200%
- 3 AZ: mỗi AZ chạy 50% → tổng cấp phát 150%

Chuyển từ 2 sang 3 AZ **giảm** 25% chi phí compute cho cùng mức chịu lỗi.

Chi phí đi ngược lại: nhiều AZ hơn thì tỉ lệ traffic cross-AZ ($0,01/GB mỗi chiều)
cao hơn. Với ứng dụng web thông thường tiết kiệm compute thắng; với kiến trúc rất
chatty giữa các tier thì phải cân lại.
</details>

**4.** Một kiến trúc có ALB → ASG (3 AZ) → RDS Multi-AZ, nhưng private subnet dùng
chung một NAT Gateway ở `us-east-1a` cho cả ba AZ. AZ `us-east-1a` mất hoàn toàn.
Mô tả chuyện gì xảy ra với từng thành phần.

<details><summary>Đáp án</summary>

- **ALB**: node ở `1a` mất, Route 53 ngừng trả IP của nó. Node ở `1b` và `1c` tiếp
  tục phục vụ. Người dùng có thể gặp lỗi trong vài chục giây trong lúc DNS cập nhật.
- **ASG**: instance ở `1a` chết, health check fail, ASG launch thay thế ở `1b`/`1c`.
  Capacity phục hồi sau vài phút.
- **RDS Multi-AZ**: nếu primary ở `1a`, failover sang standby ở AZ khác trong 60–120
  giây. Ứng dụng cần retry.
- **NAT Gateway**: đây là chỗ hỏng. NAT Gateway ở `1a` biến mất. Route table của
  private subnet ở `1b` và `1c` vẫn trỏ về NAT ID đó → **mọi outbound của cả ba AZ
  chết**, kể cả từ instance hoàn toàn khỏe mạnh ở `1b` và `1c`.

Hậu quả cụ thể: instance không gọi được API bên thứ ba, không tải được package,
không gửi được webhook. Nếu ứng dụng gọi một dịch vụ ngoài trong đường xử lý request
thì **cả hệ thống sập dù chỉ mất một AZ**.

Sửa: một NAT Gateway ở mỗi AZ, và mỗi private subnet có route table riêng trỏ về NAT
cùng AZ. Chi phí tăng ~$66/tháng cho hai NAT Gateway nữa — và đây là ví dụ điển hình
của "ràng buộc HA thắng ràng buộc chi phí".
</details>

**5.** Đề nói: *"During a marketing campaign, incoming requests increase tenfold for
about 20 minutes. The processing backend cannot handle this and fails, losing
requests."* Nêu giải pháp và giải thích vì sao "tăng size instance của backend" là
đáp án kém.

<details><summary>Đáp án</summary>

Giải pháp: **chèn SQS giữa frontend và backend**, cho backend chạy trong ASG scale
theo `ApproximateNumberOfMessagesVisible` (hoặc dùng Lambda với SQS event source).

Vì sao nó đúng:
- **Không mất request.** Frontend nhận request và đẩy vào hàng đợi rất nhanh; SQS
  giữ message tới 14 ngày. Backend xử lý theo tốc độ của nó.
- **Tự điều tiết.** Hàng đợi dài ra là tín hiệu để scale; hàng đợi ngắn lại là tín
  hiệu để scale in.
- **Cô lập lỗi.** Backend chết hẳn cũng không mất request nào.

Vì sao "tăng size instance" kém:
- Phải trả tiền cho instance lớn **24/7** trong khi đỉnh chỉ 20 phút.
- Vẫn có trần. Chiến dịch lần sau tăng 20 lần thì lại sập.
- Không giải quyết việc **mất request** — nếu backend vẫn quá tải, request vẫn rơi.
- Scale up có downtime (phải restart instance).

Vì sao "chỉ thêm Auto Scaling cho backend" cũng chưa đủ: ASG mất vài phút để launch
và warm up instance mới. Trong 3–5 phút đó, đỉnh 10 lần vẫn đè lên capacity cũ và
vẫn mất request. Hàng đợi hấp thụ đúng khoảng thời gian đó. Đáp án tốt nhất thường
là **cả hai**: SQS để đệm, ASG để bắt kịp.
</details>

**6.** Phân biệt EC2 Auto Recovery và Auto Scaling replacement. Nêu một tình huống
mà Auto Recovery là đáp án đúng còn ASG thì không.

<details><summary>Đáp án</summary>

**Auto Recovery**: khi EC2 system status check fail (lỗi hạ tầng của AWS — mất điện
host, mất mạng host, lỗi phần cứng), AWS khởi động lại **chính instance đó** trên
một host vật lý khác. Giữ nguyên: instance ID, private IP, Elastic IP, mọi EBS
volume đang gắn, và metadata. Mất: nội dung instance store, mọi thứ trong RAM. Bật
mặc định trên instance dựa trên Nitro.

**ASG replacement**: terminate instance cũ và launch một instance **hoàn toàn mới**
từ launch template. Instance ID mới, private IP mới, EBS volume mới từ AMI.

Tình huống Auto Recovery đúng còn ASG sai: **một license server hoặc appliance được
cấp phép theo địa chỉ IP hoặc theo instance ID**, chạy đơn lẻ, có dữ liệu trạng thái
trên EBS volume. ASG sẽ tạo instance mới với IP mới → license không còn hợp lệ, và
dữ liệu trên EBS cũ không tự đi theo.

Giới hạn của Auto Recovery cần nói rõ: nó **chỉ** xử lý lỗi hạ tầng. Ứng dụng treo,
OS panic do lỗi cấu hình của bạn, đĩa đầy — Auto Recovery không phát hiện. Để bắt
những cái đó phải có CloudWatch alarm riêng.
</details>

**7.** Đề mô tả một hệ thống toàn cầu và bạn đang phân vân giữa multi-AZ và
multi-Region. Nêu bốn câu hỏi bạn đặt ra để quyết định, và đáp án tương ứng.

<details><summary>Đáp án</summary>

1. **"Đề có nêu rõ phải chịu được mất cả một Region không?"** Từ khóa: `Region-wide
   outage`, `regional failure`, `RTO/RPO` gắn với phạm vi Region. Không có từ khóa
   này → multi-AZ.
2. **"Có ràng buộc pháp lý buộc dữ liệu tồn tại ở nhiều quốc gia không?"** Có →
   multi-Region, không có lựa chọn khác.
3. **"Người dùng toàn cầu cần độ trễ thấp khi ĐỌC hay khi GHI?"** Chỉ đọc →
   **CloudFront** hoặc read replica cross-Region, rẻ hơn nhiều. Cần ghi ở nhiều nơi
   → multi-Region, và phải trả lời tiếp câu hỏi xung đột ghi.
4. **"Availability mục tiêu là bao nhiêu?"** 99,99% → multi-AZ đủ. 99,999% → buộc
   phải multi-Region.

Câu hỏi thứ năm nên tự hỏi nhưng đề ít khi cho dữ kiện: **"nghiệp vụ chịu được
last-writer-wins không?"** Nếu dữ liệu là số dư tài khoản hay tồn kho thì
active-active multi-Region không dùng được, phải quay về một writer duy nhất
(active-passive hoặc read-local-write-global).

Quy tắc chốt: multi-Region chỉ là đáp án khi đề **nêu rõ** một trong bốn lý do. Nếu
không, nó là đáp án "kiến trúc hoành tráng" mà người ra đề cài để bẫy.
</details>
