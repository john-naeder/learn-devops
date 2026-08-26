# Khôi phục thảm họa — RTO/RPO, bốn chiến lược, di trú và hybrid

> **Tra nhanh:** đề cho bạn hai con số (chịu ngừng bao lâu, chịu mất bao nhiêu dữ liệu)
> hoặc một câu chữ ám chỉ hai con số đó, và bạn phải ra được đúng một trong bốn chiến
> lược DR — rồi biết dùng công cụ nào để chuyển dữ liệu và nối mạng tới nơi dự phòng.

`Domain 2 · Design Resilient Architectures (26% đề)` · `Domain 4 · Cost-Optimized (20% đề)`

DR là nửa sau của Domain 2. Nửa trước — hệ thống chạy tiếp khi mất một instance hay một
AZ — nằm ở [`11-san-sang-cao.md`](11-san-sang-cao.md). File này lo chuyện khác hẳn:
**mất cả một Region, hoặc mất cả datacenter on-prem**, và bạn phải dựng lại ở nơi khác.

Phần chi phí không phải phụ: mọi câu DR đều là câu đánh đổi tiền. Đề gần như luôn kèm
`most cost-effective` vào yêu cầu RTO/RPO, và đó chính là chỗ ba đáp án còn lại bị loại.

---

## Bản đồ

| Mục | Khi nào bạn cần đọc mục này |
|---|---|
| [1. RTO và RPO](#1-rto-và-rpo--hai-con-số-và-cách-đọc-chúng-ra-từ-đề) | Đề không cho số mà cho câu chữ, bạn phải dịch ra số |
| [2. Ba khái niệm không được lẫn](#2-ha-fault-tolerance-dr--ba-thứ-mua-bằng-ba-loại-tiền) | Đề dùng `resilient`, `available`, `recover` và bạn phân vân |
| [3. Bốn chiến lược DR](#3-bốn-chiến-lược-dr--cơ-chế-chi-phí-dấu-hiệu-nhận-biết) | Câu hỏi DR kinh điển: chọn một trong bốn |
| [4. Ngân sách RTO](#4-ngân-sách-rto--rto-không-phải-một-con-số-mà-là-một-phép-cộng) | Đề cho RTO 30 phút và bạn phải kiểm tra chiến lược có kịp không |
| [5. Backup: cơ chế thật](#5-backup--cơ-chế-thật-của-từng-loại) | Snapshot, AWS Backup, Vault Lock, cross-account |
| [6. Replication cho dữ liệu sống](#6-replication-cross-region-cho-dữ-liệu-đang-sống) | Cần RPO tính bằng giây chứ không phải giờ |
| [7. Failover bằng Route 53](#7-failover--route-53-và-thời-gian-thật-của-nó) | Đề hỏi "chuyển traffic sang region phụ bằng cách nào" |
| [8. 7R của migration](#8-7r--bảy-cách-đưa-một-ứng-dụng-lên-cloud) | Đề mô tả một dự án di trú và hỏi chiến lược nào |
| [9. Công cụ migration](#9-công-cụ-migration--khi-nào-chọn-cái-nào) | DMS, SCT, MGN, DRS, DataSync — bốn chữ viết tắt dễ lẫn |
| [10. Chuyển X TB trong Y ngày](#10-chuyển-x-tb-trong-y-ngày--tính-thật-đừng-đoán) | Đề cho dung lượng và băng thông. Đó là một bài toán, không phải một quy tắc |
| [11. Hybrid: DX vs VPN](#11-hybrid--direct-connect-vpn-và-dùng-cả-hai) | Đề nhắc on-premises, dedicated connection, consistent latency |
| [Bảng số phải nhớ](#bảng-số-phải-nhớ) | 30 phút trước giờ thi |

Liên quan: [sẵn sàng cao](11-san-sang-cao.md), [chi phí](10-chi-phi.md),
[storage](02-storage.md), [database](03-database.md), [networking](04-networking.md),
[tuần 11](../aws/w11-dr-hybrid.md).

---

## 1. RTO và RPO — hai con số và cách đọc chúng ra từ đề

Hai định nghĩa chính xác, không phải cách nói nôm na:

- **RPO — Recovery Point Objective.** Lượng dữ liệu tối đa được phép mất, **đo bằng
  thời gian**, tính từ thời điểm sự cố ngược về **điểm khôi phục gần nhất còn dùng được**.
  RPO 1 giờ nghĩa là: nếu sự cố xảy ra lúc 14:00, bạn chấp nhận quay hệ thống về trạng
  thái lúc 13:00 và mất mọi giao dịch trong khoảng đó.
- **RTO — Recovery Time Objective.** Thời gian tối đa từ **lúc sự cố xảy ra** tới lúc
  dịch vụ **phục vụ được người dùng thật**. Không phải "tới lúc EC2 chạy". Không phải
  "tới lúc database restore xong". Tới lúc người dùng gõ URL và nhận được trang.

```
                     sự cố
   ────┬──────────────┼──────────────────────────┬────▶ thời gian
       │              │                          │
  điểm khôi phục      │                    dịch vụ chạy lại
  gần nhất còn dùng   │
       │◀──── RPO ───▶│◀────────── RTO ─────────▶│
       │              │
  dữ liệu trong khoảng này MẤT       khoảng này KHÔNG PHỤC VỤ ĐƯỢC
```

**Hai con số này độc lập nhau và mua bằng hai loại chi tiêu khác nhau.**

| | RPO | RTO |
|---|---|---|
| Rút ngắn bằng cách | Sao chép dữ liệu **thường xuyên hơn** hoặc **liên tục** | Giữ sẵn hạ tầng **đã dựng** ở nơi dự phòng, tự động hoá thao tác chuyển |
| Tiền chảy vào đâu | Băng thông cross-Region, phí replication, độ phức tạp | Tài nguyên **nhàn rỗi** ở region phụ |
| Ràng buộc vật lý chặn ở đâu | Tốc độ ánh sáng: replication đồng bộ cross-Region làm mọi write chậm thêm hàng chục ms | Thời gian boot, thời gian restore, TTL của DNS |
| Ai quyết định | Nghiệp vụ (mất một giờ đơn hàng có chấp nhận được không) | Nghiệp vụ (ngừng bán hàng một giờ mất bao nhiêu tiền) |

Đề thi rất hay cho **một con số chặt và một con số lỏng** — đó là chỗ phân biệt hai
đáp án gần giống nhau. Ví dụ *"RPO 5 phút nhưng RTO 4 giờ chấp nhận được"*: bạn cần
replication liên tục (Aurora Global Database, DynamoDB Global Tables) nhưng **không**
cần giữ EC2 chạy sẵn — Pilot Light là đáp án, Warm Standby là đáp án đắt hơn mức cần.

### Dịch câu chữ trong đề ra con số

Phần lớn câu hỏi DR **không cho số**. Chúng mô tả nghiệp vụ và để bạn suy ra. Bảng này
là công cụ dịch:

| Câu trong đề | Nói về RTO hay RPO | Suy ra |
|---|---|---|
| *"cannot afford to lose any data"*, *"zero data loss"* | RPO | RPO ≈ 0 → replication đồng bộ hoặc multi-Region strong consistency. Trong phạm vi một Region: RDS Multi-AZ, Aurora |
| *"can tolerate losing up to X minutes of data"* | RPO | RPO = X, cho thẳng |
| *"the last nightly backup is acceptable"* | RPO | RPO = 24 giờ → Backup & Restore |
| *"must be back online within X minutes"* | RTO | RTO = X, cho thẳng |
| *"minimal downtime"*, *"as quickly as possible"* | RTO | RTO chặt, nhưng vẫn > 0 → Warm Standby |
| *"no downtime"*, *"users must not notice"* | RTO | RTO ≈ 0 → Multi-Site Active/Active |
| *"cannot afford idle resources"*, *"minimize cost"* | ràng buộc tiền | Loại Warm Standby và Active/Active nếu RTO cho phép |
| *"must survive a Region-wide outage"* | phạm vi | Bắt buộc multi-Region. Multi-AZ không đủ |
| *"an entire Availability Zone fails"* | phạm vi | **Không phải DR.** Đây là HA — xem [file 11](11-san-sang-cao.md) |
| *"regulatory requirement to retain backups for N years"* | tuân thủ | S3 Object Lock hoặc AWS Backup Vault Lock, không phải chiến lược DR |

**Bẫy phạm vi lớn nhất trong toàn bộ chủ đề này:** đề mô tả mất một AZ mà bạn chọn kiến
trúc multi-Region. Đáp án đó đúng về mặt kỹ thuật (multi-Region cũng chịu được mất AZ)
nhưng đắt gấp nhiều lần mức cần thiết, và đề SAA luôn phạt lỗi này. Đọc kỹ xem đề nói
**Availability Zone** hay **Region**.

### Điểm hoà vốn — vì sao không phải lúc nào cũng chọn RTO thấp nhất

Chi phí phòng ngừa tăng khi RTO giảm; chi phí thiệt hại tăng khi RTO tăng. Tổng hai
đường đó có một đáy, và đáy đó là RTO hợp lý — không phải RTO nhỏ nhất kỹ thuật cho phép.
Đây là lập luận sau mọi câu *"most cost-effective solution that meets the requirement"*:
**đáp án đúng là đáp án rẻ nhất vẫn đạt yêu cầu**. Đề nói RTO 4 giờ mà bạn chọn Warm
Standby là sai — không phải vì nó không chạy, mà vì Pilot Light đạt yêu cầu và rẻ hơn.

---

## 2. HA, fault tolerance, DR — ba thứ mua bằng ba loại tiền

[File 11](11-san-sang-cao.md#1-ha-vs-fault-tolerance-vs-dr--ba-từ-đề-thi-dùng-khác-nhau)
đã so ba khái niệm này theo góc "hứa gì". Ở đây góc khác: **ba thứ đó là ba khoản chi
riêng biệt, và một khoản không thay được khoản kia.**

| | Chống loại hỏng nào | Cơ chế | Bạn trả tiền cho | Có thay thế nhau không |
|---|---|---|---|---|
| **High availability** | Mất một instance, một AZ | Dư thừa trong cùng Region + failover tự động | Bản sao thứ hai **trong Region** | Không thay được DR: cả Region hỏng thì cả hai bản sao cùng hỏng |
| **Fault tolerance** | Mất một thành phần bất kỳ, không ai nhận ra | Dư thừa **đang phục vụ**, N+M | Công suất thừa chạy 24/7 | Không thay được backup: bug xoá dữ liệu thì mọi bản sao cùng mất |
| **Disaster recovery** | Mất cả Region, mất cả datacenter | Dữ liệu và/hoặc hạ tầng ở **nơi khác** | Lưu trữ + băng thông cross-Region + hạ tầng nhàn rỗi | Không thay được HA: DR chỉ dùng khi đã chấp nhận downtime |
| **Backup** | Xoá nhầm, mã độc, bug ghi sai dữ liệu, tài khoản bị chiếm | Bản sao **bất biến, tách rời theo thời gian** | Lưu trữ | Không thay được replication, và replication không thay được nó |

Câu phải nói được thành lời:

> **Replication chống mất hạ tầng. Backup chống mất dữ liệu.** Chúng khác nhau ở chỗ
> replication **sao chép cả sai lầm của bạn** — bạn `DELETE FROM orders` ở region chính
> thì trong một giây region phụ cũng không còn bảng orders. Backup có độ trễ theo thời
> gian, và chính độ trễ đó là thứ cứu bạn.

Bẫy đi kèm: đề mô tả *"a developer accidentally deleted a table"* hoặc *"ransomware
encrypted the files"* và đưa Cross-Region Replication làm đáp án. Sai. Đáp án là
**versioning + MFA Delete**, **PITR**, hoặc **AWS Backup với Vault Lock**.

---

## 3. Bốn chiến lược DR — cơ chế, chi phí, dấu hiệu nhận biết

| | Backup & Restore | Pilot Light | Warm Standby | Multi-Site Active/Active |
|---|---|---|---|---|
| **RTO** | Giờ đến ngày | Chục phút | Phút | Gần 0 |
| **RPO** | Giờ (theo chu kỳ backup) | Phút (replication liên tục) | Giây | Gần 0 |
| **Chi phí tương đối** | 1× (chỉ lưu trữ) | ~2–5% hạ tầng chính | ~25–50% hạ tầng chính | ~100–200% |
| **Ở region phụ có gì** | Chỉ backup nằm im | Dữ liệu **đang được sao chép** + AMI + IaC. Compute **tắt** | Bản sao **thu nhỏ đang chạy** (ví dụ 1 instance thay vì 10) | Bản sao **đầy đủ đang phục vụ traffic thật** |
| **Thao tác khi sự cố** | Dựng hạ tầng từ IaC → restore dữ liệu → đổi DNS | Promote replica → scale ASG từ 0 lên → đổi DNS | Scale out → đổi DNS (hoặc chỉ đổi trọng số) | Health check tự loại region hỏng. Không ai bấm nút |
| **Điểm gãy hay gặp** | Kịch bản restore chưa từng diễn tập | Thiếu quota / thiếu capacity ở region phụ đúng lúc cần | Thời gian scale out bị đánh giá thấp | Xung đột ghi giữa hai region |

### Cơ chế từng chiến lược, ở mức đủ để trả lời "vì sao"

**Backup & Restore.** Ở region phụ **không có gì đang chạy**. Bạn giữ: snapshot EBS/RDS
đã copy sang, object S3 đã replicate, và **template IaC**. Khi sự cố: `terraform apply`
hoặc deploy CloudFormation stack ở region phụ, restore snapshot, trỏ DNS sang.

Điều quyết định RTO ở đây **không phải AWS mà là bạn**: nếu hạ tầng chưa từng được mô
tả bằng mã, "dựng lại" là một dự án hai tuần chứ không phải một lệnh. Đây là lý do thật
sự khiến IaC là một phần của câu chuyện DR chứ không phải một sở thích kỹ thuật. Chi phí
gần như chỉ là tiền lưu trữ snapshot cộng một lần data transfer cross-Region khi copy.

**Pilot Light.** Ẩn dụ gốc là ngọn lửa mồi của bếp ga: nó nhỏ xíu, luôn cháy, và đủ để
bật cả bếp trong một giây. Ở region phụ bạn giữ **đúng phần không thể dựng nhanh**:

- **Database replica đang chạy và đang nhận replication** (RDS cross-Region read replica,
  Aurora Global Database secondary, DynamoDB Global Tables replica). Đây là phần đắt nhất
  của Pilot Light và cũng là phần duy nhất bắt buộc phải "sáng".
- **AMI đã copy sang**, launch template đã tạo, ASG đã tạo với `desired_capacity = 0`.
- **VPC, subnet, security group, IAM role, KMS key** đã dựng sẵn — chúng miễn phí hoặc
  gần miễn phí khi không có traffic.

Khi sự cố: promote replica thành writer, đổi `desired_capacity` từ 0 lên N, chờ instance
boot và đăng ký vào target group, đổi DNS. Tổng thời gian thực tế: **10–45 phút**.

Bẫy cụ thể: **service quota ở region phụ**. Account mới ở một Region thường có quota
mặc định thấp (ví dụ 5 Elastic IP, một giới hạn vCPU on-demand khiêm tốn). Bật ASG lên
50 instance ở Region chưa bao giờ dùng là công thức chắc chắn để nhận
`InsufficientInstanceCapacity` hoặc lỗi quota đúng lúc tệ nhất. Xin tăng quota **trước**,
và diễn tập ít nhất một lần.

**Warm Standby.** Toàn bộ kiến trúc đã chạy ở region phụ, chỉ **nhỏ hơn**: ASG chạy
min=1 thay vì min=6, RDS instance dùng size nhỏ hơn, ElastiCache một node thay vì ba.
Nó **phục vụ được ngay** với công suất thấp — khác biệt căn bản so với Pilot Light, nơi
compute bằng 0 và bạn phải chờ boot.

Khi sự cố: scale out lên full size rồi đổi DNS. Thứ tự này quan trọng — đổi DNS trước
khi scale xong là tự tay đẩy 100% traffic vào 1/6 công suất và sập ngay.

Một biến thể hay ra thi: chạy Warm Standby với **trọng số Route 53 nhỏ** (ví dụ 5%
traffic đi Region phụ) thay vì để nó nhàn rỗi hoàn toàn. Nó giải quyết vấn đề lớn nhất
của Warm Standby — bạn biết chắc Region phụ **thực sự hoạt động**, vì nó đang phục vụ
người dùng thật mỗi ngày. Đường code chưa bao giờ chạy là đường code hỏng.

**Multi-Site Active/Active.** Hai (hoặc nhiều) Region cùng phục vụ traffic thật, Route 53
latency-based hoặc geoproximity routing chia người dùng, health check tự loại Region hỏng.
RTO ≈ thời gian health check phát hiện + TTL DNS.

Vấn đề duy nhất nhưng rất lớn: **tầng dữ liệu**. Bạn phải trả lời được "hai region cùng
ghi một bản ghi thì ai thắng":

- **DynamoDB Global Tables (MREC)** — last writer wins theo timestamp ở mức **item**,
  không phải mức attribute. Chấp nhận được với giỏ hàng, session, log. Không chấp nhận
  được với số dư tài khoản hay tồn kho.
- **DynamoDB Global Tables MRSC** (multi-Region strong consistency) — ghi đồng bộ sang
  ít nhất một Region khác trước khi trả về, RPO 0, đọc strongly consistent từ mọi Region
  active. Đổi lại là độ trễ ghi cao hơn và ràng buộc về số Region.
- **Aurora Global Database** — chỉ **một writer**. Region phụ chỉ đọc. Nên "active/active"
  với Aurora thực chất là "đọc ở mọi nơi, ghi ở một nơi".

Đây là lý do đề thi hay gợi ý Multi-Site cho kiến trúc **serverless** (API Gateway +
Lambda + DynamoDB Global Tables): không có traffic thì không có hoá đơn, nên "Region phụ
đang chạy đầy đủ" gần như miễn phí. Cùng kiến trúc đó bằng EC2 thì bạn trả gấp đôi 24/7.

### Dấu hiệu nhận biết trong đề

| Cụm từ trong đề | Chiến lược | Vì sao |
|---|---|---|
| *"lowest cost"*, *"downtime of several hours is acceptable"*, *"data rarely changes"* | **Backup & Restore** | RTO lỏng + ràng buộc tiền chặt |
| *"restore within 30 minutes"* + *"do not want to pay for idle compute"* | **Pilot Light** | Đây là câu định nghĩa Pilot Light: dữ liệu sáng, compute tắt |
| *"minimal downtime"*, *"a scaled-down version running"*, *"willing to accept higher cost"* | **Warm Standby** | Từ khoá "scaled-down" gần như luôn là Warm Standby |
| *"no downtime"*, *"serve users from the nearest Region"*, *"RTO and RPO near zero"* | **Multi-Site Active/Active** | Nhắc "nearest Region" nghĩa là cả hai đang phục vụ |
| *"a copy of the data must exist in another Region but nothing else"* | **Backup & Restore** | Chỉ dữ liệu, không hạ tầng |
| *"promote the read replica"* xuất hiện trong đáp án | **Pilot Light** | Có replica đang chạy nhưng chưa phải writer |

Bốn chiến lược này là một **thang liên tục**, không phải bốn hộp rời. Nhiều kiến trúc
thật dùng chiến lược khác nhau cho tầng khác nhau: database ở mức Warm Standby (vì
replication rẻ), compute ở mức Pilot Light (vì instance đắt). Đề SAA thường buộc bạn
chọn một tên gọi, nhưng biết điều này giúp loại đáp án.

---

## 4. Ngân sách RTO — RTO không phải một con số mà là một phép cộng

Đây là mục mà tài liệu ôn thi thông thường bỏ qua, và cũng là mục giúp bạn kiểm tra
nhanh một đáp án có khả thi không.

```
RTO thực tế = phát hiện + quyết định + dựng hạ tầng + khôi phục dữ liệu
              + hâm nóng + chuyển traffic + xác minh
```

| Bước | Mất bao lâu (điển hình) | Rút ngắn bằng cách |
|---|---|---|
| **Phát hiện** sự cố | 1–5 phút với CloudWatch alarm; 10–30 phút nếu chờ người dùng báo | Alarm + Route 53 health check + composite alarm |
| **Quyết định** failover | 0 nếu tự động; **5–60 phút** nếu cần người phê duyệt | Tự động hoá, nhưng cân nhắc rủi ro failover nhầm |
| **Dựng hạ tầng** | 0 (Warm Standby) → 5–15 phút (Pilot Light: bật ASG) → 30 phút–nhiều giờ (Backup & Restore: chạy IaC) | Giữ sẵn hạ tầng = trả tiền |
| **Khôi phục dữ liệu** | 0 (đã replicate) → phút đến **giờ** (restore snapshot lớn) | Replication thay cho restore |
| **Hâm nóng** | EBS restore từ snapshot đọc lazy-load từ S3, lần đọc đầu chậm rõ rệt; cache trống; JIT chưa warm | Fast Snapshot Restore; giữ cache ấm; pre-scale |
| **Chuyển traffic** | TTL DNS + interval × threshold của health check (xem [mục 7](#7-failover--route-53-và-thời-gian-thật-của-nó)) | TTL 60s, health check nhanh, hoặc Global Accelerator |
| **Xác minh** | 2–10 phút | Smoke test tự động |

Dùng ngân sách này để loại đáp án: đề nói **RTO 15 phút**, đáp án là "restore a 2 TB RDS
snapshot in the DR Region and update DNS". Tính thử: restore snapshot RDS 2 TB thường
mất hàng chục phút đến vài giờ, cộng thời gian hâm nóng. Không kịp. Đáp án đúng phải có
dữ liệu **đã sẵn ở đó** — tức là replica đang chạy.

Hai chi tiết cơ chế đáng nhớ vì đề có hỏi:

- **EBS volume tạo từ snapshot là lazy-load.** Block chỉ được kéo từ S3 về **lần đầu
  được đọc**, nên I/O sau restore chậm hẳn cho tới khi volume "ấm". **Fast Snapshot
  Restore (FSR)** bỏ giai đoạn này nhưng tính tiền theo **snapshot × AZ × giờ**, khá đắt.
- **Restore PITR của DynamoDB tạo ra một bảng MỚI**, không ghi đè bảng cũ — RTO phải cộng
  thời gian trỏ ứng dụng sang tên mới. `RestoreDBInstanceToPointInTime` của RDS cũng vậy:
  instance mới, endpoint mới.

---

## 5. Backup — cơ chế thật của từng loại

### Snapshot EBS: incremental nhưng không phải theo cách bạn nghĩ

Snapshot EBS là **incremental ở tầng block**: snapshot thứ hai chỉ lưu block đã đổi. Nhưng
mỗi snapshot vẫn là một **điểm khôi phục hoàn chỉnh** — xoá snapshot giữa chuỗi không làm
hỏng snapshot sau, vì AWS giữ lại block nào còn được tham chiếu. Không có chuỗi full +
differential như công cụ backup truyền thống.

Hệ quả ra thi:

- Snapshot là **Regional** (lưu trong S3 do AWS quản lý) dù volume gốc chỉ ở một AZ. Đây
  là cách duy nhất đưa dữ liệu EBS ra khỏi một AZ.
- **Copy sang Region khác là hành động riêng**, không tự động, và bản copy đầu tiên ở
  Region đích là **full** chứ không incremental.
- Snapshot của volume **mã hoá** phải được **re-encrypt bằng KMS key của Region đích** khi
  copy, vì KMS key là tài nguyên regional. Quên tạo key ở đích thì kịch bản DR gãy đúng
  ở bước này — bẫy hay ra.
- **Recycle Bin** cho snapshot và AMI: snapshot bị xoá vào thùng rác thay vì biến mất.
  Đáp án cho *"protect against accidental snapshot deletion"*.

### Backup của các dịch vụ chính

| Dịch vụ | Cơ chế | Con số | Bẫy |
|---|---|---|---|
| **EBS** | Snapshot incremental → S3 do AWS quản lý | Không giới hạn thực tế về số snapshot | Copy cross-Region cần KMS key ở đích |
| **RDS — automated backup** | Snapshot hằng ngày + transaction log mỗi 5 phút → cho phép **PITR** | Retention **0–35 ngày**; 0 nghĩa là **tắt** | **Xoá DB instance là mất toàn bộ automated backup** (trừ khi tạo final snapshot) |
| **RDS — manual snapshot** | Bạn tự bấm, giữ tới khi tự xoá | Không hết hạn | Không cho PITR, chỉ khôi phục về đúng thời điểm snapshot |
| **RDS — cross-Region automated backup replication** | AWS tự copy snapshot **và transaction log** sang Region khác, cho PITR ở Region đó | RPO thực tế **5–30 phút** | Không phải mọi engine/Region đều hỗ trợ — kiểm tra trước khi thiết kế |
| **Aurora** | Backup **liên tục** lên S3, PITR trong retention window, không ảnh hưởng hiệu năng | Retention 1–35 ngày | 6 bản dữ liệu trên 3 AZ là **chống lỗi**, không phải backup. Xoá bảng vẫn xoá cả 6 bản |
| **Aurora Backtrack** | "Tua ngược" cluster về thời điểm trước đó **tại chỗ**, không tạo instance mới | Chỉ Aurora **MySQL**; cửa sổ tối đa 72 giờ | Phải bật **trước**; không bật được sau khi lỡ tay |
| **DynamoDB — PITR** | Khôi phục về bất kỳ giây nào trong 35 ngày | **35 ngày**, cố định | Restore ra **bảng mới**; không ghi đè |
| **DynamoDB — on-demand backup** | Snapshot đầy đủ, không ảnh hưởng hiệu năng và không tốn capacity | Giữ tới khi xoá | |
| **S3** | Versioning + Replication + Object Lock + Lifecycle | Replication chỉ áp cho object tạo **sau** khi bật rule | Object cũ cần **S3 Batch Replication** |
| **EFS / FSx** | Qua **AWS Backup** (EFS cũng có automatic backup bật mặc định khi tạo qua console) | | |
| **Instance store** | **Không có backup**. Dữ liệu mất khi stop/terminate/lỗi phần cứng | | Đề đưa instance store làm nơi lưu dữ liệu cần bền = đáp án sai |

### AWS Backup — vì sao nó là đáp án của rất nhiều câu

AWS Backup là **mặt phẳng điều khiển tập trung** cho backup của nhiều dịch vụ. Đề chọn
nó khi câu hỏi có mùi "nhiều dịch vụ", "nhiều account", "chính sách tập trung", "chứng
minh tuân thủ". Bốn khái niệm phải phân biệt:

- **Backup plan** — lịch (cron), backup window, lifecycle (chuyển sang cold storage sau
  N ngày, xoá sau M ngày), và **copy rule** sang Region/account khác.
- **Resource assignment** — chọn tài nguyên **theo tag** hoặc theo ARN. Chọn theo tag là
  cách duy nhất mở rộng được: tài nguyên mới gắn đúng tag là tự động được bảo vệ.
- **Backup vault** — nơi chứa recovery point, có **KMS key riêng** và **resource policy**
  riêng. Đây là ranh giới quyền truy cập.
- **Vault Lock** — WORM (write once, read many) cho vault:
  - **Governance mode**: người có quyền đặc biệt vẫn xoá được lock. Dùng để chống lỡ tay.
  - **Compliance mode**: sau **cooling-off period** (grace time, tối thiểu **72 giờ / 3
    ngày**), lock trở thành **bất biến vĩnh viễn** — không ai xoá được, kể cả root
    account, kể cả AWS Support. Đây là đáp án cho *"regulatory requirement"* và cho
    *"protect backups from a compromised administrator account"*.

Ba năng lực nữa hay ra thi:

- **Cross-Region copy và cross-account copy** cấu hình ngay trong backup plan. Cross-account
  cần vault ở account đích có resource policy cho phép. **Không restore trực tiếp từ
  account A sang account B** — phải copy sang B rồi mới restore trong B.
- **Backup policy ở tầng Organizations**: viết chính sách ở management account, gắn vào OU,
  member account tự thực thi. Đây là đáp án cho *"enforce a backup policy across all
  accounts"* — kết hợp với SCP để member account không tắt được.
- **Restore testing plan**: AWS Backup tự restore thử theo lịch, đo thời gian restore,
  chạy validation qua EventBridge → Lambda, rồi xoá tài nguyên test. Đây là cách duy nhất
  bạn biết RTO **thật** thay vì RTO trên giấy.

**Cách ly account là lớp bảo vệ mạnh nhất.** Backup nằm cùng account với hệ thống chính
thì một credential bị lộ xoá được cả hai. Kiến trúc chuẩn: một account riêng chứa backup
vault, không ai có quyền ghi thường xuyên vào đó, cộng Vault Lock compliance mode.

---

## 6. Replication cross-Region cho dữ liệu đang sống

Khi RPO đo bằng giây chứ không phải giờ, backup theo lịch không đủ. Bảng này là bảng
chọn cơ chế:

| Cơ chế | RPO điển hình | RTO điển hình | Ghi được ở Region phụ | Khi nào chọn |
|---|---|---|---|---|
| **Aurora Global Database** | **Dưới 1 giây** (thường; đo bằng metric `AuroraGlobalDBReplicationLag`) | **Dưới 1 phút** khi promote | Không — chỉ đọc | Aurora MySQL/PostgreSQL, cần DR cross-Region tốt nhất |
| **Aurora Global Database — managed planned switchover** | **0** | Vài phút | Sau switchover thì có | Chuyển Region có kế hoạch (bảo trì, đổi Region chính) |
| **RDS cross-Region read replica** | Giây đến phút (bất đồng bộ, phụ thuộc tải và khoảng cách) | Phút (promote thủ công) | Sau promote | RDS thường (không Aurora), Pilot Light |
| **RDS cross-Region automated backup replication** | **5–30 phút** | Giờ (phải restore) | Sau restore | Rẻ hơn read replica, RPO lỏng hơn |
| **DynamoDB Global Tables (MREC)** | **~1 giây** | Gần 0 (đã active) | **Có** — active/active | Multi-Site, ứng dụng chịu được last-writer-wins |
| **DynamoDB Global Tables (MRSC)** | **0** | Gần 0 | Có, strongly consistent | Khi last-writer-wins không chấp nhận được |
| **S3 Cross-Region Replication** | Phút (không cam kết) | — | Có (two-way replication nếu bật) | Object storage |
| **S3 Replication Time Control (RTC)** | **99,99% object trong 15 phút**, có SLA 99,9% | — | | Khi có ràng buộc hợp đồng về thời gian replicate |
| **AWS Elastic Disaster Recovery (DRS)** | **Dưới một giây** (block-level liên tục) | **5–20 phút** | Sau khi launch | DR cho **server** (on-prem hoặc EC2), không phải cho một dịch vụ managed cụ thể |
| **ElastiCache Global Datastore** | Dưới 1 giây | Dưới 1 phút | Không — chỉ đọc | Cache cần sống sót qua mất Region |

Bốn điều rút ra:

1. **Aurora Global Database có tới 5 Region phụ**, replication ở tầng **storage** chứ
   không phải tầng log của engine — đó là lý do lag dưới một giây ngay cả khi tải nặng
   và gần như không tốn CPU của writer. Phân biệt với read replica thường: read replica
   dùng binlog/WAL, tốn tài nguyên của primary và lag tăng theo tải.
2. **Promote (unplanned failover) khác switchover (planned).** Promote trong sự cố cho
   RPO khác 0 bằng đúng lượng lag tại thời điểm đó, và **cắt đứt vĩnh viễn** cluster đó
   khỏi global database. Switchover có kế hoạch cho RPO 0 vì AWS chờ replication đuổi kịp.
3. **S3 replication có ba điều kiện ra thi nguyên văn:** cả hai bucket bật **versioning**;
   cần một **IAM role** cho S3 assume; chỉ object tạo **sau** khi bật rule được sao chép
   (object cũ cần S3 Batch Replication). Thêm điều kiện thứ tư ít ai nhớ: object mã hoá
   bằng **SSE-KMS** cần rule cho phép và key ở Region đích.
4. **AWS DRS là đáp án cho "DR cho server", MGN là đáp án cho "di trú server".** Chúng
   dùng cùng công nghệ replication block-level nhưng khác mục đích và khác cách tính tiền
   — xem [mục 9](#9-công-cụ-migration--khi-nào-chọn-cái-nào).

---

## 7. Failover — Route 53 và thời gian thật của nó

### Ba loại health check

| Loại | Kiểm tra gì | Dùng khi |
|---|---|---|
| **Endpoint health check** | Route 53 gọi HTTP/HTTPS/TCP tới IP hoặc domain **public**, từ nhiều vị trí trên thế giới | Endpoint có thể truy cập từ internet |
| **Calculated health check** | Kết hợp kết quả của nhiều health check con bằng logic "ít nhất N trong M khoẻ" | Một dịch vụ khoẻ chỉ khi nhiều thành phần cùng khoẻ |
| **CloudWatch alarm health check** | Theo dõi trạng thái một CloudWatch alarm | **Tài nguyên private** không gọi được từ internet (đây là cách duy nhất), hoặc điều kiện phức tạp như "độ dài hàng đợi" |

Bẫy hay ra: đề mô tả một ứng dụng trong **private subnet** và hỏi làm sao Route 53 biết
nó hỏng. Endpoint health check **không tới được**. Đáp án là CloudWatch alarm health check.

### Công thức thời gian failover — con số đề thi kiểm được

```
Thời gian failover ≈ TTL của bản ghi + (request interval × failure threshold)
```

| Tham số | Giá trị hợp lệ | Mặc định |
|---|---|---|
| Request interval | **30 giây** (standard) hoặc **10 giây** (fast, tính phí thêm) | 30 giây |
| Failure threshold | **1–10** lần quan sát liên tiếp | **3** |
| TTL bản ghi | Bạn đặt | 300 giây nếu không đổi |

Ví dụ tính được trong phòng thi:

- Mặc định hoàn toàn: `300 + (30 × 3)` = **390 giây ≈ 6,5 phút**.
- Tinh chỉnh: TTL 60 + interval 10 + threshold 3 = `60 + 30` = **90 giây**.
- Đề nói RTO 60 giây và đáp án là "Route 53 failover routing với TTL 60" → **không kịp**,
  vì riêng TTL đã ăn hết ngân sách. Cần Global Accelerator.

Ba chi tiết cơ chế đi kèm:

- **Failover routing policy** cần chính xác một bản ghi `PRIMARY` và một bản ghi
  `SECONDARY`. Bản ghi primary **bắt buộc** gắn health check, nếu không Route 53 luôn coi
  nó khoẻ và không bao giờ failover. Đây là lỗi cấu hình kinh điển.
- **Alias record trỏ tới ALB/CloudFront/S3 với `Evaluate Target Health = true`** không cần
  health check riêng — Route 53 tự biết trạng thái của target. Với ALB, "khoẻ" nghĩa là
  có ít nhất một target khoẻ.
- **TTL chỉ là gợi ý.** Một số resolver, và rất nhiều thư viện HTTP trong ứng dụng (JVM
  cache DNS vĩnh viễn nếu không cấu hình `networkaddress.cache.ttl`), phớt lờ TTL. Nghĩa
  là thời gian failover thật luôn ≥ công thức trên.

### Khi DNS không đủ nhanh: Global Accelerator

Global Accelerator cho bạn **hai IP anycast tĩnh**. Client luôn nối tới cùng hai IP đó;
việc chuyển traffic sang Region khác xảy ra **trong mạng của AWS**, không đụng tới DNS —
nên **không có TTL nào phải chờ**. Thời gian chuyển tính bằng khoảng chục giây.

Chọn giữa hai thứ:

| | Route 53 failover | Global Accelerator |
|---|---|---|
| Cơ chế chuyển | Đổi câu trả lời DNS | Đổi đường đi trong mạng AWS, IP không đổi |
| Thời gian | TTL + interval × threshold (phút) | **~30 giây**, không phụ thuộc client |
| Client cache DNS phá hỏng được không | **Có** | Không |
| Chi phí | Rẻ (per query + per health check) | Phí cố định theo giờ + phí data transfer |
| Ra thi khi | DR thông thường, RTO tính bằng phút | Đề nhấn `static IP addresses`, `non-HTTP protocol`, `fastest failover`, `gaming`, `IoT` |

---

## 8. 7R — bảy cách đưa một ứng dụng lên cloud

| Chữ R | Nghĩa | Ví dụ cụ thể | Câu trong đề dẫn tới nó |
|---|---|---|---|
| **Rehost** | Bê nguyên, không sửa gì. "Lift and shift" | VM VMware → EC2 bằng AWS MGN | *"fastest"*, *"without modifying the application"*, *"datacenter lease expires in 3 months"* |
| **Replatform** | Sửa nhẹ để dùng dịch vụ managed. "Lift, tinker and shift" | MySQL tự quản trên VM → RDS; Tomcat trên VM → Elastic Beanstalk | *"reduce operational overhead"* + *"minimal code changes"* |
| **Repurchase** | Bỏ hẳn, mua sản phẩm khác | CRM tự viết → Salesforce; email server → Workmail | *"move to a SaaS solution"*, *"replace with a commercial product"* |
| **Refactor / Re-architect** | Viết lại kiến trúc để tận dụng cloud | Monolith → microservice trên Fargate; batch job → Lambda + Step Functions | *"take full advantage of cloud-native features"*, *"long-term agility"*, *"willing to invest"* |
| **Retire** | Tắt, không di trú | Ứng dụng nội bộ không ai đăng nhập 6 tháng | *"discovered that the application is no longer used"* |
| **Retain** | Giữ nguyên tại chỗ, xem lại sau | Hệ thống mainframe, phần cứng đặc thù, ràng buộc pháp lý | *"cannot be moved due to compliance"*, *"recently upgraded hardware"* |
| **Relocate** | Chuyển nguyên tầng hạ tầng, không đụng OS hay ứng dụng | Cụm VMware on-prem → VMware Cloud on AWS; container → EKS mà không đổi image | *"hundreds of VMs"* + *"keep using the same tooling"* + *"no downtime for conversion"* |

Ba ranh giới hay bị lẫn:

- **Rehost vs Replatform.** Rehost: không đổi **bất cứ thứ gì** trong ứng dụng, kể cả
  chuỗi kết nối database. Replatform: ứng dụng vẫn thế nhưng **thứ nó nói chuyện cùng**
  đổi sang dịch vụ managed. Câu thử: *"có phải sửa file cấu hình không?"* Không → Rehost.
- **Replatform vs Refactor.** Replatform không đụng vào **kiến trúc**; Refactor thì đụng.
  Đổi từ MySQL tự quản sang RDS MySQL là Replatform. Đổi từ MySQL sang DynamoDB, phải
  viết lại tầng truy cập dữ liệu, là Refactor.
- **Retire vs Retain.** Retire là **bỏ hẳn**. Retain là **giữ lại on-prem**, ứng dụng vẫn
  chạy. Đề dùng "no longer used" cho Retire và "cannot be moved" cho Retain.

Về tần suất ra thi: **Rehost** và **Replatform** chiếm phần lớn. Đề rất hay dựng thế
lưỡng nan "thời hạn gấp" (→ Rehost) đối lại "giảm gánh vận hành" (→ Replatform), và
manh mối quyết định luôn nằm ở một mệnh đề về **thời gian** hoặc **ngân sách kỹ thuật**.

---

## 9. Công cụ migration — khi nào chọn cái nào

| Công cụ | Di chuyển cái gì | Cơ chế | Chọn khi đề nói |
|---|---|---|---|
| **DMS** (Database Migration Service) | **Dữ liệu** trong database | Replication instance đọc từ source, ghi vào target. **Full load** rồi **CDC** (change data capture) chạy tiếp | *"migrate a database with minimal downtime"*, *"source must stay online during migration"* |
| **SCT** (Schema Conversion Tool) | **Schema, view, stored procedure, function** | Phân tích và chuyển đổi cú pháp; sinh báo cáo phần nào phải sửa tay | Chỉ khi **đổi engine** (Oracle → PostgreSQL, SQL Server → MySQL) |
| **AWS MGN** (Application Migration Service) | **Cả server** — OS, ứng dụng, dữ liệu | Agent replicate block-level liên tục vào staging area, rồi convert và launch trên EC2 | *"lift and shift"*, *"rehost"*, *"migrate servers without modification"* |
| **AWS DRS** (Elastic Disaster Recovery) | Cả server, nhưng để **DR** chứ không phải để chuyển nhà | Cùng công nghệ với MGN; giữ replication chạy **mãi mãi** với staging area chi phí thấp | *"disaster recovery for on-premises servers"*, *"RPO of seconds for physical servers"* |
| **DataSync** | **File** giữa storage này và storage kia | Agent (hoặc chạy trực tiếp cloud-to-cloud), có lịch, verify toàn vẹn, throttle băng thông | *"one-time or scheduled transfer"*, *"NFS/SMB to S3/EFS/FSx"*, *"millions of files"* |
| **Storage Gateway** | **Không di chuyển** — nó cho on-prem truy cập storage trên cloud | Appliance tại chỗ nói NFS/SMB/iSCSI, cache cục bộ, dữ liệu thật nằm ở AWS | *"applications must keep using the existing protocol"*, *"low-latency access to recently used data"* |
| **Snow Family** | Dữ liệu, bằng **thiết bị vật lý gửi qua đường bưu điện** | Chép dữ liệu vào thiết bị, gửi về AWS | *"limited bandwidth"*, *"remote location"*, *"would take months over the network"* |
| **Transfer Family** | File từ đối tác qua **SFTP/FTPS/FTP** | Endpoint managed, backend là S3 hoặc EFS | *"partners upload via SFTP"*, *"legacy FTP workflow"* |
| **Application Discovery Service** | Không di chuyển gì — **khảo sát** trước | Agentless (qua vCenter) hoặc agent-based; vẽ ra phụ thuộc giữa server | *"first step"*, *"understand dependencies before migrating"* |
| **Migration Hub** | Không di chuyển gì — **theo dõi** | Bảng điều khiển gom tiến độ từ DMS, MGN, đối tác | *"single dashboard to track migration progress"* |

Bốn cặp hay nhầm, mỗi cặp là một câu hỏi thi:

1. **DMS vs SCT.** DMS chuyển **dữ liệu**, SCT chuyển **schema**. Cùng engine (MySQL
   on-prem → RDS MySQL): chỉ cần **DMS**. Khác engine (Oracle → Aurora PostgreSQL): cần
   **cả hai**, SCT chạy trước.
2. **MGN vs DRS.** Cùng công nghệ, khác ý định. MGN: replicate → cutover → **xong, tắt
   replication**. DRS: replicate → **giữ mãi** để sẵn sàng failover bất cứ lúc nào. Đề
   nói "migrate" → MGN; đề nói "disaster recovery" → DRS.
3. **DataSync vs Storage Gateway.** DataSync **chuyển dữ liệu đi rồi thôi**; Storage
   Gateway **giữ nguyên lối truy cập tại chỗ** trong khi dữ liệu sống trên cloud. Câu
   thử: *"sau khi xong, on-prem còn cần đọc dữ liệu này không?"* Không → DataSync.
   Có → Storage Gateway.
4. **DataSync vs S3 Transfer Acceleration.** DataSync là công cụ đồng bộ file có agent,
   dùng cho on-prem ↔ AWS. Transfer Acceleration là tính năng của S3 đẩy upload qua
   edge location, dùng khi **người dùng ở xa Region** upload vào S3 qua internet. Đề nói
   "global users uploading large files to a single bucket" → Transfer Acceleration.

---

## 10. Chuyển X TB trong Y ngày — tính thật, đừng đoán

Quy tắc "trên 10 TB thì dùng Snowball" là quy tắc sai, vì nó bỏ qua băng thông và thời
hạn. Đề thi cho bạn **dung lượng** và **băng thông** chính là để bạn làm phép tính.

### Công thức

```
Thời gian (giây) = Dung lượng (bit) ÷ (Băng thông khả dụng (bit/s) × hiệu suất)

Dạng dùng được trong phòng thi (dung lượng TB, băng thông Mbps):

    Số ngày ≈  Dung lượng(TB) × 8.000.000  ÷  ( Băng thông(Mbps) × η )  ÷  86.400

Rút gọn với η = 0,7:

    Số ngày ≈  Dung lượng(TB) × 132  ÷  Băng thông(Mbps)
```

Ba điều về hệ số η (hiệu suất thực tế):

- η gộp overhead TCP/IP, độ trễ, retransmit, và việc đường truyền **đang phục vụ việc
  khác**. Đề nói *"a dedicated link used only for the migration"* → η ≈ 0,8. Đề nói
  *"the existing internet connection also serves 500 employees"* → η ≈ 0,3–0,5.
- Đơn vị là chỗ bẫy: băng thông tính bằng **bit/s**, dung lượng tính bằng **byte**. Sai
  hệ số 8 là lỗi phổ biến nhất khi làm nhanh.

### Bảng tra nhanh (η = 0,7)

| Dung lượng | 100 Mbps | 500 Mbps | 1 Gbps | 10 Gbps |
|---|---|---|---|---|
| 10 TB | ~13 ngày | ~2,6 ngày | ~1,3 ngày | ~3,2 giờ |
| 50 TB | ~66 ngày | ~13 ngày | ~6,6 ngày | ~16 giờ |
| 100 TB | ~132 ngày | ~26 ngày | ~13 ngày | ~1,3 ngày |
| 500 TB | ~1,8 năm | ~132 ngày | ~66 ngày | ~6,6 ngày |
| 1 PB | ~3,6 năm | ~264 ngày | ~132 ngày | ~13 ngày |

### Đối thủ: thời gian của đường vật lý

Snowball không phải "tức thì". Ngân sách thời gian thật của một thiết bị:

```
đặt hàng và giao      3–7 ngày
chép dữ liệu          thiết bị 210 TB nhận tới ~1,5 GB/s — thường LAN của bạn mới là nút thắt
gửi trả AWS           2–5 ngày
AWS nhập vào S3       1–2 ngày
──────────────────────────────────────
tổng cố định          khoảng 7–14 ngày, gần như không phụ thuộc dung lượng
```

**Quy tắc quyết định thật:**

> Tính số ngày qua đường truyền. So với **khoảng 7–14 ngày** cố định của Snow Family.
> Đường truyền nhanh hơn → đi mạng (DataSync). Chậm hơn đáng kể → đi thiết bị.
> Nếu hai con số gần nhau, chọn đường truyền, vì nó không có rủi ro logistics và bạn
> có thể bắt đầu ngay.

Hai ví dụ đủ để nhận ra dạng bài:

- *"20 TB over a 500 Mbps connection, must finish within 2 weeks."* Tính: `20 × 132 ÷ 500`
  ≈ **5,3 ngày**. Kịp thoải mái → **DataSync**. Chọn Snowball ở đây là sai vì nó chậm hơn.
- *"600 TB from a remote site with a 100 Mbps link, must finish this quarter."* Tính:
  `600 × 132 ÷ 100` ≈ **792 ngày**. Không khả thi → **Snowball Edge**, nhiều thiết bị
  song song. Đây là dạng bài mà từ khoá `remote location` + `limited bandwidth` xuất hiện.

Một chiều nữa đáng biết: **data transfer vào AWS miễn phí**, nên đi mạng không tốn phí
ingress — cái đắt là đường truyền phải thuê. Chiều **ra khỏi** AWS thì ngược lại, và đó
là lý do "kéo 500 TB từ S3 về on-prem" là câu hỏi chi phí chứ không phải câu hỏi thời gian.

---

## 11. Hybrid — Direct Connect, VPN, và dùng cả hai

| | Site-to-Site VPN | Direct Connect |
|---|---|---|
| Đi qua đâu | **Internet công cộng**, đường hầm IPsec | **Cáp riêng** tới một Direct Connect location |
| Băng thông | **1,25 Gbps mỗi tunnel** (standard). Có loại large bandwidth tới 5 Gbps | Dedicated: **1 / 10 / 100 / 400 Gbps**. Hosted: **50 Mbps → 25 Gbps** |
| Độ trễ | Thay đổi theo internet | **Ổn định, đoán trước được** — đây là từ khoá nhận diện |
| Thời gian dựng | **Vài phút** | **Vài tuần đến vài tháng** (kéo cáp, làm việc với partner) |
| Mã hoá | **Có sẵn**, IPsec | **Không mã hoá mặc định**. Cần MACsec (chỉ một số port) hoặc chạy VPN **bên trong** DX |
| Chi phí | ~$0,05/giờ mỗi kết nối + data transfer out | Phí port theo giờ + **data transfer out rẻ hơn đáng kể** so với qua internet |
| Số tunnel | Luôn **2 tunnel** tới 2 endpoint khác nhau ở AWS, để AWS bảo trì không làm đứt | Một kết nối là một điểm hỏng — cần thiết kế dư thừa |
| Ra thi khi đề nói | *"quickly"*, *"temporary"*, *"backup connection"*, *"encrypted"* | *"consistent latency"*, *"dedicated bandwidth"*, *"large sustained data transfer"*, *"private connection"* |

Ba điều về băng thông VPN mà đề có hỏi:

- **1,25 Gbps là trần của một tunnel, và một luồng TCP đơn không vượt qua được nó** —
  ECMP băm theo 5-tuple, nên một kết nối duy nhất luôn nằm trên một tunnel.
- Muốn vượt trần: gắn VPN vào **Transit Gateway**, bật **dynamic routing (BGP)** và
  **ECMP**, rồi tạo nhiều VPN connection. Băng thông cộng dồn. Virtual Private Gateway
  **không** hỗ trợ ECMP kiểu này — đây là một trong những lý do thật để chọn TGW.
- Đề nói *"we need more than 1.25 Gbps over VPN"* → đáp án là TGW + ECMP + nhiều tunnel,
  hoặc chuyển sang Direct Connect.

### Mẫu kiến trúc kinh điển: DX chính, VPN dự phòng

Đây là câu trả lời "đúng nhất" cho gần như mọi câu hỏi hybrid có nhắc tới độ tin cậy:

```
        on-premises router
          │            │
   Direct Connect    Site-to-Site VPN (qua internet)
   (đường chính)      (đường dự phòng)
          │            │
          └─────┬──────┘
                │  BGP quảng bá cùng prefix
                │  DX được ưu tiên nhờ AS_PATH ngắn hơn / local preference cao hơn
                ▼
        Virtual Private Gateway hoặc Transit Gateway
```

Vì sao nó đúng: DX cho băng thông và độ trễ ổn định nhưng **một kết nối DX là một điểm
hỏng** (một cáp, một router, một location). VPN chạy qua internet nên nó **hỏng theo cách
khác** — đó chính là định nghĩa của dự phòng tốt. Chuyển đổi **tự động qua BGP**: cả hai
quảng bá cùng prefix, AWS ưu tiên DX; DX chết thì BGP hội tụ trong khoảng chục giây đến
dưới một phút.

Thang dư thừa AWS gọi tên trong Resiliency Toolkit, biết để đọc đáp án: **high
resiliency** = 2 kết nối ở **2 Direct Connect location khác nhau**; **maximum resiliency**
= 2 kết nối ở mỗi location, 2 location, 2 thiết bị on-prem. Bẫy: hai kết nối DX cắm vào
**cùng một router ở cùng một location** không phải dư thừa — vẫn là một điểm hỏng, chỉ
đắt gấp đôi.

### Direct Connect Gateway — nó giải bài toán nào

Vấn đề: một **private VIF** chỉ gắn được vào **một** Virtual Private Gateway, tức một
VPC trong **một** Region. Có 5 VPC ở 3 Region thì cần 5 VIF — không mở rộng được. Direct
Connect Gateway là một đối tượng **global** đứng giữa:

```
   on-prem ──DX──▶ private VIF ──▶ ┌──────────────────────┐ ──▶ VGW (VPC ở us-east-1)
                                   │ Direct Connect       │ ──▶ VGW (VPC ở eu-west-1)
                                   │ Gateway (global)     │ ──▶ TGW (nhiều VPC ở ap-southeast-1)
                                   └──────────────────────┘
```

Ba điều phải nhớ:

- **Một DX Gateway cho phép một kết nối DX tới VPC ở nhiều Region khác nhau** — câu trả
  lời cho *"connect on-premises to VPCs in multiple Regions over a single Direct Connect
  connection"*.
- **DX Gateway không cho các VPC gắn vào nó nói chuyện với nhau.** Nó chỉ nối on-prem ↔
  VPC; VPC ↔ VPC cần **peering** hoặc **Transit Gateway**. Bẫy rất hay ra.
- Nhiều VPC trong **cùng một Region**: **transit VIF** → DX Gateway → **Transit Gateway**.

Ba loại VIF, phân biệt bằng một câu:

| VIF | Tới đâu | Dùng khi |
|---|---|---|
| **Private VIF** | VPC (qua VGW hoặc DX Gateway), địa chỉ private | Truy cập tài nguyên trong VPC |
| **Public VIF** | Endpoint **public** của AWS (S3, DynamoDB, API công khai) qua DX thay vì internet | Cần băng thông ổn định tới S3 mà không đi internet |
| **Transit VIF** | Direct Connect Gateway → **Transit Gateway** | Nhiều VPC, kiến trúc hub-and-spoke |

---

## Bảng số phải nhớ

| Con số | Giá trị | Vì sao ra thi |
|---|---|---|
| RDS automated backup retention | **0–35 ngày** (0 = tắt) | Đề hỏi giữ backup được bao lâu |
| Aurora / DynamoDB PITR window | **35 ngày** | Cùng con số, dễ nhớ chung |
| Aurora Backtrack | tối đa **72 giờ**, chỉ Aurora **MySQL** | Đáp án cho "undo nhanh mà không restore" |
| Aurora Global Database | tối đa **5 Region phụ**, lag **dưới 1 giây**, RTO **dưới 1 phút** | Câu DR cross-Region cho Aurora |
| DynamoDB Global Tables (MREC) | replication **~1 giây**, **last writer wins** ở mức item | Câu active/active |
| S3 Replication Time Control | **99,99% object trong 15 phút**, SLA **99,9%** | Con số duy nhất S3 replication cam kết |
| RDS cross-Region automated backup | RPO thực tế **5–30 phút** | Phân biệt với read replica |
| AWS DRS | RPO **dưới một giây**, RTO **5–20 phút** | Câu DR cho server on-prem |
| AWS Backup Vault Lock compliance | cooling-off tối thiểu **72 giờ (3 ngày)**, sau đó **bất biến vĩnh viễn** | Câu tuân thủ / chống admin bị chiếm quyền |
| Route 53 health check | interval **30s** (hoặc **10s** fast), threshold **1–10**, mặc định **3** | Tính thời gian failover |
| Công thức failover DNS | `TTL + interval × threshold` | Kiểm tra đáp án có đạt RTO không |
| Global Accelerator failover | **~30 giây**, không phụ thuộc TTL | Khi DNS quá chậm |
| Site-to-Site VPN | **1,25 Gbps mỗi tunnel** (standard), luôn **2 tunnel** | Câu băng thông hybrid |
| Direct Connect dedicated | **1 / 10 / 100 / 400 Gbps** | Phân biệt với hosted |
| Direct Connect hosted | **50 Mbps → 25 Gbps** | Đề nói "50 Mbps" là đang nói hosted |
| Snowball Edge Storage Optimized | **210 TB**, tới **~1,5 GB/s** | Dung lượng hiện hành |
| Công thức băng thông | `ngày ≈ TB × 132 ÷ Mbps` (η = 0,7) | Bài toán mạng-hay-thiết-bị |
| Vòng đời Snow Family | khoảng **7–14 ngày** cố định | Mốc so sánh với đường truyền |

---

## Bẫy đề thi

**1. "Chống mất dữ liệu" bị trả lời bằng replication.**
Đề: *"A developer accidentally deleted production data. How can this be prevented in the
future?"* Đáp án sai hấp dẫn: **S3 Cross-Region Replication** hoặc **Multi-AZ**. Đáp án
đúng: **versioning + MFA Delete**, **PITR**, hoặc **AWS Backup với Vault Lock**.
Vì sao: replication sao chép lệnh xoá. Multi-AZ sao chép lệnh xoá. Chỉ backup có **độ trễ
theo thời gian**, và độ trễ đó là thứ duy nhất cứu bạn khỏi chính mình.

**2. RDS read replica bị nhầm là cơ chế backup.**
Đề: *"protect the database against corruption"*. Đáp án sai hấp dẫn: **cross-Region read
replica**. Đáp án đúng: **automated backup + PITR**. Vì sao: read replica sao chép mọi
thay đổi, kể cả `UPDATE` sai. Replica hữu ích cho DR **hạ tầng**, vô dụng cho DR **dữ liệu**.

**3. Xoá DB instance rồi mới nhớ ra backup.**
Đề: *"the team deleted the RDS instance; can they recover?"* Đáp án sai hấp dẫn: *"yes,
from automated backups"*. Đáp án đúng: chỉ nếu có **final snapshot** hoặc **manual
snapshot**. Vì sao: **automated backup bị xoá cùng instance**; manual snapshot thì không.
Đây là một trong những khác biệt cụ thể nhất mà đề thích hỏi.

**4. Đáp án DR không đạt nổi RTO đề yêu cầu.**
Đề: RTO **15 phút**. Đáp án sai hấp dẫn: *"restore the 2 TB snapshot in the DR Region and
update Route 53"*. Đáp án đúng: giữ replica đang chạy (Pilot Light hoặc Warm Standby).
Vì sao: cộng ngân sách ở [mục 4](#4-ngân-sách-rto--rto-không-phải-một-con-số-mà-là-một-phép-cộng)
— riêng restore đã vượt 15 phút, chưa kể hâm nóng và DNS.

**5. Chọn chiến lược DR đắt hơn mức đề yêu cầu.**
Đề: RTO 4 giờ, RPO 1 giờ, *"most cost-effective"*. Đáp án sai hấp dẫn: **Warm Standby**
(nó chắc chắn đạt yêu cầu). Đáp án đúng: **Pilot Light**, hoặc thậm chí **Backup &
Restore** nếu hạ tầng có IaC. Vì sao: câu hỏi có hai ràng buộc, và đáp án phải đạt **cả
hai**. Vượt yêu cầu về RTO trong khi thua về chi phí là thua.

**6. Quên rằng snapshot mã hoá cần KMS key ở Region đích.**
Đề: *"the cross-Region snapshot copy fails"*. Đáp án sai hấp dẫn: *"increase the IAM
permissions on the source account"*. Đáp án đúng: chỉ định **KMS key của Region đích**
cho thao tác copy. Vì sao: KMS key là tài nguyên **regional**; snapshot mã hoá phải được
re-encrypt bằng key của Region đích. Kịch bản DR không diễn tập thường gãy đúng ở đây.

**7. "Trên 10 TB thì Snowball" áp dụng máy móc.**
Đề: *"20 TB over a dedicated 1 Gbps link, must complete within one week"*. Đáp án sai hấp
dẫn: **Snowball Edge**. Đáp án đúng: **DataSync**. Vì sao: `20 × 132 ÷ 1000` ≈ **2,6 ngày**
qua mạng, so với 7–14 ngày cho vòng đời Snowball. Đường truyền thắng.

**8. Direct Connect được coi là mã hoá.**
Đề: *"data in transit must be encrypted"* + đã có Direct Connect. Đáp án sai hấp dẫn:
*"Direct Connect is a private connection, no further action needed"*. Đáp án đúng: chạy
**Site-to-Site VPN bên trong DX**, hoặc dùng **MACsec** nếu port hỗ trợ. Vì sao: "private"
không đồng nghĩa với "encrypted". DX là cáp riêng, không phải đường hầm mã hoá.

**9. Direct Connect Gateway bị tưởng là nối VPC với VPC.**
Đề: *"VPCs attached to the Direct Connect gateway must communicate with each other"*.
Đáp án sai hấp dẫn: *"already possible via the DX gateway"*. Đáp án đúng: cần **Transit
Gateway** hoặc **VPC peering**. Vì sao: DX Gateway chỉ định tuyến on-prem ↔ VPC, nó không
phải router giữa các VPC.

---

## Cây quyết định

**Chọn chiến lược DR** — đọc RTO trước, chi phí sau:

```
Đề có nhắc mất cả Region / DR / RTO / RPO không?
├── Không → đây là bài HA, sang 11-san-sang-cao.md
└── Có
    ├── RTO ≈ 0, "no downtime", "serve from nearest Region" ─► Multi-Site Active/Active
    ├── RTO phút, "scaled-down version running" ────────────► Warm Standby
    ├── RTO chục phút, "không trả tiền cho compute nhàn rỗi" ► Pilot Light
    └── RTO giờ–ngày, "lowest cost", "nightly backup is fine" ► Backup & Restore
```

**Chọn cơ chế dữ liệu cho Region phụ:**

```
Aurora ──────────► Aurora Global Database (RPO <1s, RTO <1 phút)
RDS thường ──────► RPO giây–phút: cross-Region read replica
                   RPO 5–30 phút: cross-Region automated backup replication (rẻ hơn)
DynamoDB ────────► Ghi ở 2 nơi: Global Tables (MREC, hoặc MRSC nếu không chịu được LWW)
                   Chỉ cần DR:  PITR + AWS Backup copy cross-Region
S3 ──────────────► CRR (+ RTC nếu có cam kết 15 phút)
EBS ─────────────► Snapshot + copy cross-Region (nhớ KMS key ở đích)
Server on-prem ──► AWS Elastic Disaster Recovery (DRS)
```

**Chọn công cụ chuyển dữ liệu** — tính `ngày ≈ TB × 132 ÷ Mbps` trước, rồi:

```
< ~7 ngày   ─► File (NFS/SMB): DataSync · Database đang chạy: DMS (+SCT nếu đổi engine)
               Cả server: MGN
> ~14 ngày, "remote location", "no reliable connectivity" ─► Snowball Edge
"on-prem vẫn phải truy cập sau khi xong" ─► Storage Gateway (File/Volume/Tape)
```

**Chọn kết nối hybrid:**

```
Nhanh, rẻ, tạm thời, mã hoá sẵn ─────────► Site-to-Site VPN
Độ trễ ổn định, băng thông lớn, lâu dài ─► Direct Connect
Tin cậy cao với chi phí hợp lý ──────────► DX chính + VPN dự phòng qua BGP
Nhiều VPC ở nhiều Region qua một DX ─────► Direct Connect Gateway
Nhiều VPC trong một Region + on-prem ────► Transit VIF → DX Gateway → TGW
Cần >1,25 Gbps qua VPN ──────────────────► TGW + BGP + ECMP nhiều tunnel
```

---

## Nối với thực hành

| Lab | Chạm vào mục nào | Quan sát gì |
|---|---|---|
| [`labs/w11-dr-hybrid/`](../../learn-aws/labs/w11-dr-hybrid/) | Mục 3, 5, 6 | Lab này **cố ý không có `terraform/`** — DX, TGW và VPN không lab được với ngân sách hợp lý. Phần lab được nằm ở snippet cuối README: tạo AWS Backup plan với copy rule cross-Region, và bật S3 CRR. Chạy rồi kiểm `aws backup list-recovery-points-by-backup-vault --profile learn` ở Region đích |
| [`labs-self/w11-dr-hybrid/`](../../learn-aws/labs-self/w11-dr-hybrid/) | Mục 3, 5, 7 | Bản tự viết, mới có `providers.tf` và `versions.tf`. Bài tập đáng giá nhất: tự viết một backup plan chọn tài nguyên **theo tag**, đặt lifecycle, rồi tạo một EC2 mới có tag đó và kiểm tra nó được bảo vệ mà bạn không phải sửa plan |
| [`labs/w04-s3-cloudfront/`](../../learn-aws/labs/w04-s3-cloudfront/) | Mục 5, 6 | Bật versioning rồi bật replication sang bucket khác Region. Upload một object **trước** khi bật rule và một object **sau** — chỉ object sau được replicate. Đây là điều kiện thứ ba của S3 replication xảy ra trước mắt bạn |
| [`labs/w05-databases/`](../../learn-aws/labs/w05-databases/) | Mục 5, 6 | Đặt `backup_retention_period = 0` rồi thử `restore-db-instance-to-point-in-time` — nó sẽ từ chối. Đặt lại 7 ngày và thử lại. Đó là ý nghĩa thật của con số 0–35 |
| [`labs/w08-dns-cdn-edge/`](../../learn-aws/labs/w08-dns-cdn-edge/) | Mục 7 | Tạo failover routing policy với health check, tắt endpoint primary, bấm giờ tới lúc `dig` trả IP secondary. Đối chiếu với `TTL + interval × threshold`. Chạy lại với TTL 60 và fast interval |
| [`labs-self/w08-dns-cdn-edge/`](../../learn-aws/labs-self/w08-dns-cdn-edge/) | Mục 7 | Tự dựng health check. Thử tạo failover record **không** gắn health check vào primary và quan sát nó không bao giờ failover |
| [`labs/w10-observability-iac/`](../../learn-aws/labs/w10-observability-iac/) | Mục 3, 4 | Backup & Restore chỉ đáng tin khi có IaC. Chạy `terraform destroy` rồi `terraform apply` và **bấm giờ** — đó là phần "dựng hạ tầng" trong ngân sách RTO của chính bạn |
| [`labs/w12-exam-review/`](../../learn-aws/labs/w12-exam-review/) | Toàn bộ | Với kiến trúc capstone, viết ra RTO/RPO mục tiêu rồi chỉ ra thành phần nào chưa đạt |

Bài tuần tương ứng: [`docs/aws/w11-dr-hybrid.md`](../aws/w11-dr-hybrid.md).
Tuần đó dạy để **làm được**; file này dạy để **giải thích được vì sao**.

---

## Nguồn nói khác

| Chỗ | Nguồn `aws-saa-c03/` nói | Thực tế (kiểm tra 2026-08) |
|---|---|---|
| File `J-disaster-recovery.md` | `README.md` liệt kê nó trong "Phần 3: Giải Quyết Bài Toán Cụ Thể" và lịch học tuần 5 | **Không tồn tại.** Cùng số phận với F, G, H, I, N, O. Toàn bộ nội dung DR trong file bạn đang đọc là viết mới, không phải mở rộng nguồn |
| Snowball Edge Storage Optimized | `10-migration-transfer.md` ghi **80 TB** | Model 80 TB đã **ngừng từ 12/11/2024**. Model hiện hành là **210 TB NVMe, tới ~1,5 GB/s**. Compute Optimized hiện hành là **104 vCPU / 28 TB NVMe** ([AWS Snow device updates](https://aws.amazon.com/blogs/storage/aws-snow-device-updates/)) |
| Snowcone | Nguồn ghi "8–14 TB, portable" như lựa chọn còn dùng được | **Đã ngừng cung cấp.** Vẫn phải thuộc vì đề SAA-C03 còn hỏi, nhưng đừng thiết kế thật bằng nó |
| Snowball nói chung | Nguồn coi Snow Family là lựa chọn mặc định cho "limited bandwidth + large data" | Từ **07/11/2025** Snowball Edge **không nhận khách hàng mới**. Hướng AWS khuyến nghị: **DataSync** qua mạng, **AWS Data Transfer Terminal** cho chuyển vật lý. Đề thi vẫn hỏi theo mô hình cũ ([Snowball Edge doc history](https://docs.aws.amazon.com/snowball/latest/developer-guide/doc-history.html)) |
| Ngưỡng chọn Snowball | Nguồn chỉ nói `"Limited bandwidth" + "large data" = Snow Family` | Không có ngưỡng dung lượng cố định nào đúng. Phải **tính**: `ngày ≈ TB × 132 ÷ Mbps` rồi so với vòng đời 7–14 ngày của thiết bị. 20 TB trên đường 1 Gbps đi mạng nhanh hơn Snowball |
| DR keywords | `README.md` ghi `"Disaster recovery" → S3 Cross-Region Replication, Aurora Global Database` | Đúng một nửa và nguy hiểm ở nửa còn lại: S3 CRR **không** chống xoá nhầm hay mã độc, vì nó sao chép cả thao tác xoá. Với dạng câu đó, đáp án là versioning / Object Lock / Vault Lock |
| MGN | `10-migration-transfer.md` mô tả MGN là "lift-and-shift migration (formerly CloudEndure)" và dừng ở đó | Thiếu **AWS Elastic Disaster Recovery (DRS)** — cùng gốc CloudEndure, cùng công nghệ replication, nhưng dùng cho **DR** chứ không phải di trú, RPO dưới một giây, RTO 5–20 phút ([DRS concepts](https://docs.aws.amazon.com/drs/latest/userguide/CloudEndure-Concepts.html)) |
| RDS backup | Nguồn không phân biệt automated backup với manual snapshot khi xoá instance | **Xoá instance là mất automated backup**; manual snapshot sống sót. Đây là chi tiết ra thi thường xuyên |
| Aurora Global Database | Nguồn nhắc tên trong danh sách "nên biết" nhưng không có con số | RPO **dưới 1 giây**, RTO **dưới 1 phút**, tối đa **5 Region phụ**, và **managed planned switchover** cho RPO **0** ([Aurora global database DR](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-disaster-recovery.html)) |
| DynamoDB Global Tables | Nguồn mô tả như active-active không kèm cảnh báo | Mặc định là **MREC**: last-writer-wins ở **mức item**, transaction **không** xuyên Region. Có chế độ **MRSC** cho ghi đồng bộ khi last-writer-wins không chấp nhận được ([Global tables design](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-global-table-design.html)) |

---

## Ngoài phạm vi

- **Route 53 Application Recovery Controller** (readiness check, routing control, zonal shift) — mức Professional. [ARC](https://docs.aws.amazon.com/r53recovery/latest/dg/what-is-route53-recovery.html)
- **Aurora Global Database write forwarding** — cho phép secondary nhận write rồi chuyển về primary; mức Professional. [Write forwarding](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database-write-forwarding.html)
- **AWS Backup Audit Manager** và framework tuân thủ chi tiết — biết nó tồn tại là đủ. [Audit Manager](https://docs.aws.amazon.com/aws-backup/latest/devguide/aws-backup-audit-manager.html)
- **DMS Schema Conversion không dùng SCT desktop** (DMS Fleet Advisor, DMS Serverless) — chi tiết vận hành. [DMS](https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html)
- **MACsec trên Direct Connect** — chỉ cần biết nó là cách mã hoá DX ở tầng 2. [MACsec](https://docs.aws.amazon.com/directconnect/latest/UserGuide/direct-connect-mac-sec-getting-started.html)
- **BGP tuning chi tiết** (AS_PATH prepending, communities, BFD) — mức chuyên networking. [DX routing policies](https://docs.aws.amazon.com/directconnect/latest/UserGuide/routing-and-bgp.html)
- **VMware Cloud on AWS** — chỉ cần nhận ra nó là đáp án của "Relocate".
- **AWS Data Transfer Terminal** — dịch vụ thay thế cho Snow ở chuyển vật lý, chưa vào đề SAA-C03. [Data Transfer Terminal](https://aws.amazon.com/datatransferterminal/)

---

## Tự kiểm tra

**1.** Đề nói: *"The company can tolerate up to 5 minutes of data loss but can accept up
to 4 hours of downtime, and wants the most cost-effective solution."* Chọn chiến lược DR
nào, và giải thích vì sao ba chiến lược còn lại đều sai.

<details><summary>Đáp án</summary>

RPO 5 phút là **chặt**; RTO 4 giờ là **lỏng**. Hai con số này độc lập, và đây chính là
dạng bài kiểm tra bạn có hiểu điều đó không.

RPO 5 phút loại **Backup & Restore**: snapshot theo lịch hằng ngày hoặc thậm chí mỗi giờ
đều không đạt. Bạn cần **replication liên tục** — cross-Region read replica, Aurora Global
Database, hoặc DynamoDB Global Tables.

RTO 4 giờ nghĩa là bạn **không cần** compute chạy sẵn. Bật ASG từ 0 lên và chờ boot mất
chục phút, thừa sức trong 4 giờ. Nên **Warm Standby** (trả tiền cho instance thu nhỏ
chạy 24/7) và **Multi-Site** (trả tiền cho bản sao đầy đủ) đều **vượt yêu cầu và đắt hơn**
— chúng đạt yêu cầu nhưng thua ở ràng buộc thứ ba, `most cost-effective`.

Đáp án: **Pilot Light** — replica database đang chạy và đang nhận replication (đạt RPO),
compute tắt hoàn toàn (đạt chi phí), bật lên khi cần (đạt RTO).

Điều cần nói được: khi đề có ba ràng buộc (RPO, RTO, chi phí), đáp án đúng là đáp án
**vừa đủ** cho cả ba, không phải đáp án tốt nhất cho hai cái đầu.
</details>

**2.** Đề yêu cầu RTO 15 phút cho một hệ thống dùng RDS PostgreSQL 3 TB. Bạn có bốn đáp
án: (a) restore snapshot ở Region phụ khi có sự cố, (b) cross-Region read replica đang
chạy, (c) Multi-AZ ở Region chính, (d) tăng tần suất snapshot lên mỗi giờ. Chọn và tính
ngân sách RTO để chứng minh.

<details><summary>Đáp án</summary>

Đáp án **(b) cross-Region read replica**.

Ngân sách RTO cho (b): phát hiện 2–5 phút + **promote replica 2–5 phút** + đổi DNS
`TTL 60 + 30 = 90 giây` + xác minh vài phút ≈ **8–15 phút**. Vừa đủ, và siết thêm được
bằng fast interval health check.

Vì sao ba cái kia sai:

- **(a)** Restore snapshot RDS 3 TB mất hàng chục phút đến vài giờ, cộng thời gian volume
  hâm nóng (lazy-load từ S3), chưa kể phải copy snapshot sang Region phụ trước.
- **(c)** Multi-AZ chống mất **một AZ trong cùng Region**. Mất Region thì primary và
  standby cùng mất. Sai về **phạm vi**, không phải về thời gian.
- **(d)** Tăng tần suất snapshot cải thiện **RPO**, không cải thiện **RTO**. Đề hỏi RTO.

Điểm cần nói được: RTO là một **phép cộng nhiều bước**, và bước đắt nhất luôn là bước
đưa dữ liệu về trạng thái dùng được. Cách duy nhất bỏ bước đó là **để dữ liệu sẵn ở đó**.
</details>

**3.** Công ty cần chuyển 80 TB dữ liệu nghiên cứu từ một trạm quan trắc lên S3. Đường
truyền của trạm là 200 Mbps và cũng phục vụ công việc hằng ngày. Deadline là 45 ngày.
Tính và quyết định.

<details><summary>Đáp án</summary>

Tính với η lạc quan (0,7), tức là giả định đường truyền dành hết cho việc này:

`80 × 132 ÷ 200` ≈ **53 ngày**. Đã vượt deadline 45 ngày.

Nhưng đề nói đường truyền **cũng phục vụ công việc hằng ngày**, nên η thực tế khoảng
0,3–0,4. Tính lại bằng công thức gốc với η = 0,35:

`80 TB × 8.000.000 ÷ (200 × 0,35) ÷ 86.400` ≈ **106 ngày**. Không khả thi, và trong suốt
106 ngày đó công việc hằng ngày của trạm bị bóp nghẹt.

So với Snowball Edge: một thiết bị 210 TB thừa sức chứa 80 TB, vòng đời khoảng **7–14
ngày** kể cả giao nhận. Kịp deadline với biên rất rộng.

Quyết định: **Snowball Edge Storage Optimized**, một thiết bị.

Hai điều nên nói thêm để cho thấy hiểu đủ sâu:
- Từ khoá `remote location` trong đề gần như luôn kèm ý "băng thông kém và đắt" — nó là
  tín hiệu Snow Family, nhưng vẫn nên tính để chắc.
- Ngoài đời (2026) Snowball Edge không nhận khách hàng mới nữa; phương án thay thế là
  DataSync qua đường truyền tốt hơn, hoặc AWS Data Transfer Terminal. Nhưng **trong phòng
  thi SAA-C03, Snow Family vẫn là đáp án đúng** cho dạng bài này.
</details>

**4.** Giải thích vì sao "Direct Connect chính + Site-to-Site VPN dự phòng" là kiến trúc
tốt hơn "hai đường Direct Connect", trong khi hai DX rõ ràng cho băng thông cao hơn. Nêu
trường hợp mà kết luận đảo ngược.

<details><summary>Đáp án</summary>

Lập luận chính là **tính độc lập của lỗi**, không phải băng thông.

Hai đường DX — nhất là khi cùng qua một Direct Connect location hoặc một nhà cung cấp
cáp — có thể hỏng **cùng lúc và cùng nguyên nhân**: sự cố ở location đó, một lỗi cấu hình
chung, một nhà thầu đào trúng bó cáp. Đó là **lỗi tương quan**, và dư thừa chống lỗi
tương quan kém hơn nhiều so với con số "2 đường" gợi ý.

VPN chạy qua **internet công cộng** — hạ tầng hoàn toàn khác cáp riêng của DX, nên nó
hỏng theo cách khác. Nó cũng **dựng được trong vài phút**, còn DX thứ hai mất hàng tuần
và nhân đôi phí port lẫn phí cross-connect trong khi VPN tốn ~$0,05/giờ.

Chuyển đổi tự động qua BGP: cả hai quảng bá cùng prefix, DX được ưu tiên (AS_PATH ngắn
hơn hoặc local preference cao hơn), DX chết thì BGP hội tụ trong khoảng chục giây.

**Trường hợp đảo ngược:** khi băng thông ở chế độ suy giảm cũng phải đảm bảo. Nếu bạn
đang chạy 8 Gbps qua DX và VPN chỉ cho 1,25 Gbps mỗi tunnel, thì "dự phòng" đó thực chất
là "sập với thêm bước". Khi đó phải chọn **maximum resiliency**: hai kết nối DX ở **hai
Direct Connect location khác nhau**, mỗi bên một thiết bị on-prem riêng. Ràng buộc tuân
thủ cấm dữ liệu đi qua internet cũng dẫn tới cùng kết luận.
</details>

**5.** Đề mô tả: *"Migrate an on-premises Oracle database to AWS. The application team
does not want to keep paying Oracle licenses. Downtime during business hours is not
acceptable."* Nêu công cụ, chiến lược R, và thứ tự các bước.

<details><summary>Đáp án</summary>

**Chiến lược R: Replatform** (hoặc Refactor tuỳ mức thay đổi ở tầng ứng dụng). Bỏ license
Oracle nghĩa là **đổi engine** — sang Aurora PostgreSQL hoặc RDS PostgreSQL — chứ không
phải bê Oracle lên EC2 (đó sẽ là Rehost và vẫn phải trả license).

**Công cụ: SCT + DMS**, đúng thứ tự đó.

Các bước:

1. **SCT** chuyển schema Oracle sang cú pháp PostgreSQL và sinh **assessment report**
   liệt kê phần không tự chuyển được — PL/SQL package, trigger phức tạp, kiểu dữ liệu
   đặc thù Oracle. Phần đó phải viết tay.
2. Áp schema đã chuyển lên target Aurora PostgreSQL.
3. **DMS full load**: copy dữ liệu hiện có trong khi nguồn **vẫn đang phục vụ**.
4. **DMS CDC**: DMS đọc redo log của Oracle và áp thay đổi liên tục, lag về vài giây.
5. **Cutover** ngoài giờ: dừng ghi vào nguồn, chờ CDC lag về 0, đổi chuỗi kết nối, bật lại.

Vì sao downtime chỉ còn vài phút: full load — phần dài nhất — chạy **song song với hệ
thống đang phục vụ**. Chỉ bước cutover mới cần dừng, và nó chỉ tốn thời gian đổi cấu hình.

Điều cần nói được: **DMS không chuyển schema, SCT không chuyển dữ liệu.** Nhầm hai cái
này là câu hỏi thi trực tiếp. Và **CDC là lý do duy nhất khiến "minimal downtime" khả thi**.
</details>

**6.** Bạn cấu hình Route 53 failover routing với TTL mặc định và health check mặc định.
Đề yêu cầu RTO 3 phút. Tính xem có đạt không, và nêu ba cách rút ngắn kèm đánh đổi.

<details><summary>Đáp án</summary>

Tính với mặc định: `TTL 300 + (interval 30 × threshold 3)` = **390 giây ≈ 6,5 phút**.
Riêng phần DNS đã vượt RTO 3 phút, chưa tính thời gian phát hiện ban đầu, promote database,
hay ứng dụng khởi động. **Không đạt.**

Ba cách rút ngắn:

1. **TTL xuống 60 giây** → `60 + 90 = 150 giây`. Đánh đổi: nhiều truy vấn DNS hơn, hoá
   đơn Route 53 tăng theo số query. Với bản ghi có failover, đây là mức TTL đúng.
2. **Fast interval 10 giây** → `60 + (10 × 3) = 90 giây`. Đánh đổi: phí health check cao
   hơn, và endpoint nhận gấp ba lượng request kiểm tra — Route 53 kiểm từ khoảng một tá
   vị trí, nên endpoint nhận cỡ 60–70 request/phút chỉ riêng cho health check.
3. **Threshold xuống 1–2** → `60 + (10 × 2) = 80 giây`. Đánh đổi **nguy hiểm nhất**: một
   lần chậm thoáng qua cũng kích hoạt failover, và failover nhầm sang Region phụ đang
   chạy công suất thu nhỏ có thể tệ hơn sự cố gốc.

Cách thứ tư, khác bản chất: **bỏ DNS khỏi đường quyết định** bằng **Global Accelerator**.
Client giữ nguyên hai IP anycast tĩnh, việc chuyển xảy ra trong mạng AWS, khoảng **30
giây**, và **client cache DNS không phá được**. Đánh đổi là phí cố định theo giờ cộng phí
data transfer.

Điểm cần nói được: **TTL chỉ là gợi ý**. Resolver và thư viện HTTP trong ứng dụng có thể
cache lâu hơn — JVM mặc định cache DNS vĩnh viễn nếu không chỉnh `networkaddress.cache.ttl`.
Nên thời gian failover thật luôn **≥** con số tính được, và với RTO rất chặt thì kiến trúc
dựa vào DNS là kiến trúc sai.
</details>
