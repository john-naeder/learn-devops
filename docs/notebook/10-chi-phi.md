# Tối ưu chi phí — giải bài toán "MOST cost-effective"

> **Tra nhanh:** bạn đang cầm một câu hỏi có chữ `cost-effective` và cần biết loại
> đáp án nào trước, rồi tính con số nào để chọn giữa hai cái còn lại.

`Domain 4 · Design Cost-Optimized Architectures (20% đề)`

20% của 65 câu là khoảng **13 câu**. Nhưng chữ `cost` còn xuất hiện trong đề của ba
miền kia dưới dạng tiêu chí phụ ("highly available **and** cost-effective"), nên
thực tế miền này chạm vào gần một phần ba bài thi.

---

## Bản đồ

| Mục | Khi nào bạn cần đọc mục này |
|---|---|
| [1. Quy trình đọc câu hỏi tiền](#1-quy-trình-bốn-bước-đọc-một-câu-hỏi-về-tiền) | Ngay khi thấy chữ `cost`. Đọc mục này trước mọi mục khác |
| [2. Mua compute thế nào](#2-mua-compute--năm-cách-trả-tiền-cho-cùng-một-cái-máy) | Đề nhắc On-Demand, Reserved, Savings Plan, Spot, Dedicated |
| [3. Spot và thiết kế chịu gián đoạn](#3-spot--rẻ-nhất-nếu-kiến-trúc-chịu-được-gián-đoạn) | Đề nhắc "fault-tolerant batch", "can be interrupted", "flexible start time" |
| [4. Storage class và lifecycle](#4-s3-storage-class-và-lifecycle--ngưỡng-hòa-vốn-thật) | Đề nhắc archive, retention, "accessed once a quarter", compliance 7 năm |
| [5. Chọn compute/db rẻ](#5-chọn-dịch-vụ-rẻ-hơn-cho-cùng-một-việc) | Đề mô tả tải rồi hỏi cách rẻ nhất chạy nó |
| [6. Data transfer](#6-data-transfer--nguồn-hóa-đơn-bất-ngờ-số-1) | Bất kỳ câu nào có nhiều tier nói chuyện với nhau, hoặc có chữ "unexpected bill" |
| [7. NAT Gateway vs Endpoint](#7-nat-gateway-vs-gateway-endpoint--bài-toán-kinh-điển) | Đề nhắc private subnet + S3/DynamoDB |
| [8. Right-sizing](#8-right-sizing--tìm-tiền-đang-nằm-không) | Đề nhắc "instances are underutilized", "CPU averages 10%" |
| [9. Công cụ quản lý chi phí](#9-công-cụ--cái-nào-trả-lời-câu-hỏi-nào) | Đề hỏi "which tool", "how to identify", "how to alert" |
| [Bảng số phải nhớ](#bảng-số-phải-nhớ) | 30 phút trước giờ thi |

---

## 1. Quy trình bốn bước đọc một câu hỏi về tiền

Đề tiền hầu như luôn có bốn đáp án: một cái rẻ nhưng vi phạm ràng buộc, một cái
đúng nhưng đắt, một cái sai kỹ thuật, và một cái đúng. Quy trình này tìm ra cái
cuối cùng trong khoảng 40 giây.

**Bước 1 — Gạch chân ràng buộc cứng, trước khi nhìn giá.**

Từ khóa ràng buộc cứng: `must`, `required`, `regulation`, `SLA`, `no data loss`,
`within N minutes`, `highly available`, `across Availability Zones`, `encrypted`.

Đáp án nào vi phạm một ràng buộc cứng thì **loại ngay, dù rẻ nhất**. Đây là cách
loại đáp án nhanh nhất và chính xác nhất. Ví dụ: đề nói "must survive an
Availability Zone failure" rồi hỏi cost-effective → mọi đáp án single-AZ chết,
kể cả S3 One Zone-IA và single-AZ RDS.

**Bước 2 — Xác định tải là loại nào.** Chỉ có bốn loại, và mỗi loại có một câu trả
lời mặc định:

| Dạng tải | Nhận ra qua | Đáp án mặc định |
|---|---|---|
| Chạy 24/7, ổn định, dài hạn | "steady state", "runs continuously", "for the next 3 years" | Reserved Instance / Savings Plan |
| Đột biến, không đoán trước | "unpredictable", "traffic spikes", "seasonal" | Auto Scaling + On-Demand cho phần đỉnh |
| Chạy ngắt quãng, chịu được gián đoạn | "batch", "can be interrupted", "flexible start and end time", "stateless workers" | Spot |
| Chạy rất thưa, vài phút mỗi ngày | "runs a few times per day", "event-driven", "unpredictable low volume" | Lambda / Fargate / serverless |

**Bước 3 — Tìm dòng tiền lớn nhất trong kiến trúc mà đề mô tả.** Thứ tự thường gặp:

1. Compute chạy không tải (instance bật 24/7 mà chỉ dùng 2 giờ/ngày)
2. **Data transfer** — đặc biệt egress ra internet và cross-AZ
3. NAT Gateway (cả giờ lẫn GB)
4. Storage sai class (dữ liệu lạnh nằm ở S3 Standard, EBS cấp phát thừa)
5. Tài nguyên mồ côi: EBS volume không attach, snapshot cũ, EIP không dùng, ALB rỗng

Đáp án đúng gần như luôn nhắm vào dòng lớn nhất, không phải dòng dễ thấy nhất.

**Bước 4 — Ưu tiên "không tốn tiền" hơn "tốn ít tiền".** AWS có một nhóm nhỏ những
thứ hoàn toàn miễn phí, và đề rất thích chúng vì chúng cho đáp án dứt khoát:

**S3/DynamoDB Gateway Endpoint**; **data transfer vào AWS**; **origin AWS →
CloudFront**; **trong cùng AZ qua private IP**; **S3 Lifecycle policy**;
**Auto Scaling, CloudFormation, IAM, VPC, Security Group** (chỉ trả cho tài nguyên
chúng tạo ra).

Nếu một đáp án dùng thứ trong danh sách này và vẫn thỏa mọi ràng buộc, nó thường là đáp án.

---

## 2. Mua compute — năm cách trả tiền cho cùng một cái máy

Cùng một `m6i.large` chạy cùng một khối lượng công việc có thể có năm mức giá khác
nhau. Khác biệt **không nằm ở cái máy**, nó nằm ở **cái bạn cam kết**.

| Cách mua | Bạn cam kết gì | Giảm giá | Bỏ giữa chừng được không |
|---|---|---|---|
| **On-Demand** | Không gì cả | 0% (giá gốc) | Có, tắt lúc nào cũng được |
| **Spot** | Không gì, nhưng chấp nhận bị thu hồi | tới **90%** | AWS bỏ bạn, không phải ngược lại |
| **Reserved Instance** | 1 hoặc 3 năm, **một cấu hình cụ thể** | tới **72%** | Không. Bán lại được trên RI Marketplace (chỉ RI Standard) |
| **Savings Plans** | 1 hoặc 3 năm, **một số tiền mỗi giờ** | tới **72%** | Không. Không bán lại được |
| **Dedicated Host / Instance** | Phần cứng riêng | Giá **cao hơn**, mua vì licensing/compliance | Host có thể mua Reserved |

### Reserved Instance — hai trục biến thể

RI có hai trục và đề thi hỏi cả hai:

**Trục 1: Standard vs Convertible**

| | Standard RI | Convertible RI |
|---|---|---|
| Giảm giá tối đa (3 năm, all upfront) | ~72% | ~66% |
| Đổi instance family (m6i → c6i) | **Không** | **Có** |
| Đổi OS, tenancy | Không | Có |
| Đổi size trong cùng family | Có (nếu là Linux, regional RI) | Có |
| Bán lại trên RI Marketplace | **Có** | Không |

Quy tắc chọn: chắc chắn về family trong 3 năm tới → Standard. Không chắc → Convertible,
hoặc tốt hơn là **Savings Plan** (linh hoạt hơn Convertible mà giảm giá tương đương).

**Trục 2: Regional vs Zonal**

| | Regional RI | Zonal RI |
|---|---|---|
| Phạm vi | Cả Region, áp cho AZ bất kỳ | Đúng một AZ |
| Instance size flexibility | **Có** (Linux/UNIX, shared tenancy) | Không |
| **Capacity reservation** | **Không** | **Có** — AWS giữ chỗ cho bạn |

Đây là bẫy ra thi: đề nói *"must be guaranteed capacity in a specific Availability
Zone"* → cần **Zonal RI** hoặc **On-Demand Capacity Reservation**, không phải
Regional RI và không phải Savings Plan. Savings Plans **không bao giờ** đảm bảo
capacity — chúng chỉ là công cụ giảm giá.

**Trục 3: thanh toán.** `No Upfront` < `Partial Upfront` < `All Upfront`, chênh
nhau 5–10 điểm phần trăm. "Maximum savings" → **3 năm, All Upfront, Standard RI**.

### Savings Plans — ba (nay là bốn) loại

Bạn cam kết chi **$X mỗi giờ** trong 1 hoặc 3 năm. Mọi usage đủ điều kiện được tính
theo giá Savings Plan cho tới khi đạt $X; phần vượt tính giá On-Demand.

| Loại | Áp cho | Linh hoạt | Giảm tối đa |
|---|---|---|---|
| **Compute Savings Plans** | EC2 + **Fargate** + **Lambda** | Đổi family, size, Region, OS, tenancy tự do | ~66% |
| **EC2 Instance Savings Plans** | Chỉ EC2, khóa vào **một family trong một Region** | Đổi size, OS, tenancy trong family đó | ~72% |
| **SageMaker AI Savings Plans** | SageMaker | Đổi family, size, Region, component | — |
| **Database Savings Plans** (mới) | Aurora, RDS, DynamoDB, ElastiCache, DocumentDB, Neptune, Keyspaces, DMS, OpenSearch | Đổi engine, family, size, AZ, Region | ~35% |

Loại thứ tư mới có và **chưa xuất hiện trong đề SAA-C03**. Biết nó tồn tại là đủ —
nếu đề chỉ liệt kê ba loại thì đề đang theo bản cũ, chọn theo ba loại.

Bốn điểm ra thi nhiều nhất về Savings Plans:

1. **Compute Savings Plans phủ cả Fargate và Lambda** — khác biệt lớn nhất so với
   RI (chỉ phủ EC2). "Kiến trúc hỗn hợp EC2 + Fargate + Lambda chạy ổn định" →
   Compute Savings Plans.
2. **Quyền lợi tính theo từng giờ, không cộng dồn.** Giờ dùng ít hơn cam kết thì mất.
3. **Không đảm bảo capacity.** Xem bẫy 1.
4. **Không hủy, không bán lại.** RI Standard bán lại được, Savings Plan thì không.

### Dedicated Host vs Dedicated Instance

Hai thứ này khác nhau ở một điểm duy nhất mà đề thi luôn xoáy: **bạn có nhìn thấy
phần cứng không**.

| | Dedicated Instance | Dedicated Host |
|---|---|---|
| Phần cứng riêng, không chia với khách khác | Có | Có |
| Nhìn thấy socket / core / host ID | **Không** | **Có** |
| BYOL license tính theo socket/core (Windows Server, SQL Server, Oracle) | **Không dùng được** | **Dùng được** |
| Kiểm soát instance nào chạy trên host nào | Không | Có |
| Tính tiền theo | Từng instance | **Cả cái host**, dù chạy 1 instance hay 20 |
| Mua Reserved được | Có (RI) | Có (Dedicated Host Reservation) |

Cây quyết định một dòng: **có giấy phép phần mềm tính theo socket/core cần mang
lên cloud → Dedicated Host. Chỉ cần "không chia hardware với ai" vì lý do tuân
thủ → Dedicated Instance** (rẻ hơn).

### Cây quyết định mua compute

```
Tải này có chạy đủ lâu và đủ đều để cam kết 1 năm không?
├── KHÔNG (dự án ngắn, thử nghiệm, tải thất thường)
│   ├── Chịu được bị thu hồi giữa chừng? ──► SPOT
│   └── Không chịu được ──────────────────► ON-DEMAND
│
└── CÓ
    ├── Cần đảm bảo có máy trong một AZ cụ thể?
    │   └── CÓ ──────────────────► ZONAL RI hoặc On-Demand Capacity Reservation
    │
    ├── Có giấy phép BYOL tính theo socket/core?
    │   └── CÓ ──────────────────► DEDICATED HOST (mua Host Reservation)
    │
    ├── Tải có cả EC2 + Fargate + Lambda, hoặc sẽ đổi family/Region?
    │   └── CÓ ──────────────────► COMPUTE SAVINGS PLANS
    │
    ├── Chắc chắn ở lại một family, một Region, muốn giảm giá tối đa?
    │   └── CÓ ──────────────────► EC2 INSTANCE SAVINGS PLANS (hoặc Standard RI)
    │
    └── Cần bán lại được nếu kế hoạch thay đổi?
        └── CÓ ──────────────────► STANDARD RI (RI Marketplace)
```

**Mẫu kiến trúc mà đề thi coi là "đúng" nhất:** đường nền 24/7 mua bằng Savings
Plan hoặc RI; phần dao động dùng On-Demand qua Auto Scaling; phần batch chịu gián
đoạn dùng Spot. Ba tầng, không phải một. Đáp án "mua RI cho toàn bộ capacity kể cả
peak" luôn sai.

---

## 3. Spot — rẻ nhất nếu kiến trúc chịu được gián đoạn

Spot bán capacity nhàn rỗi của AWS với giá giảm tới 90%. Đổi lại, AWS lấy lại máy
khi cần, với **thông báo trước 2 phút**.

### Cơ chế phải hiểu

- **Giá Spot không còn là đấu giá.** Từ 2017 giá do AWS điều chỉnh theo cung cầu,
  thay đổi mượt. Đáp án nào nói về "bid price" thì nghi ngờ ngay.
- **Interruption notice: 2 phút**, qua instance metadata
  (`/latest/meta-data/spot/instance-action`) và một sự kiện EventBridge.
- **Capacity Rebalance Recommendation** đến **sớm hơn** notice 2 phút. Bật
  `Capacity Rebalancing` trên ASG để ASG thay thế trước khi bị cắt.
- **Spot không dùng được** với Dedicated Host; không phải mọi type/AZ đều có Spot.

### Thiết kế để chịu được gián đoạn

Bốn nguyên tắc, gần như là đề bài của mọi câu hỏi Spot trong đề thi:

1. **Stateless.** State đi ra S3, DynamoDB, EFS, RDS. Điều kiện cần — workload giữ
   state trên local disk thì Spot bị loại.
2. **Chia việc nhỏ và idempotent.** Pattern chuẩn: **SQS + worker Spot**, worker xóa
   message chỉ khi xong; message chưa xóa hiện lại sau visibility timeout.
3. **Đa dạng hóa.** Nhiều instance type và nhiều AZ trong cùng ASG
   (`mixed instances policy`). AWS thu hồi theo pool; chiến lược
   `capacity-optimized` chọn pool dồi dào nhất → ít gián đoạn nhất.
4. **Trộn với On-Demand.** ASG có `On-Demand base capacity` rồi phần còn lại là Spot
   theo tỉ lệ. Đây là đáp án cho đề "cost-effective **but** must always have some
   capacity".

### Khi nào Spot chắc chắn SAI

Đề nói `must not be interrupted` / `always available` / `production database`;
workload có state cục bộ không sao chép được; job dài không checkpoint được; hoặc
đề đang hỏi `operational overhead` chứ không phải `cost` — Spot **tăng** độ phức
tạp vận hành.

---

## 4. S3 storage class và lifecycle — ngưỡng hòa vốn thật

Đây là chỗ nhiều người trả lời theo cảm tính ("dữ liệu cũ thì cho vào Glacier").
Có ba con số quyết định, và đề thi có ra cả ba.

### Bảng lựa chọn

| Class | Giá lưu ($/GB-tháng) | Phí lấy ra | Thời gian tối thiểu bị tính | Kích thước tối thiểu bị tính | Số AZ | Độ trễ lấy ra |
|---|---|---|---|---|---|---|
| **Standard** | ~0,023 | $0 | không | không | ≥3 | ms |
| **Intelligent-Tiering** | 0,023 → 0,0025 tự động | $0 | không | không (object <128 KB không được tự chuyển tier) | ≥3 | ms (trừ tier archive tùy chọn) |
| **Standard-IA** | ~0,0125 | ~$0,01/GB | **30 ngày** | **128 KB** | ≥3 | ms |
| **One Zone-IA** | ~0,01 | ~$0,01/GB | **30 ngày** | **128 KB** | **1** | ms |
| **Glacier Instant Retrieval** | ~0,004 | ~$0,03/GB | **90 ngày** | **128 KB** | ≥3 | ms |
| **Glacier Flexible Retrieval** | ~0,0036 | $0 (bulk 5–12h) → ~$0,03/GB (expedited 1–5 phút) | **90 ngày** | 40 KB metadata | ≥3 | phút đến 12 giờ |
| **Glacier Deep Archive** | ~0,00099 | ~$0,02/GB | **180 ngày** | 40 KB metadata | ≥3 | **9–48 giờ** |

Giá tham chiếu `us-east-1`, tính đến **2026-08**. Thứ hạng quan trọng hơn con số.

### Ngưỡng hòa vốn 1 — tần suất truy cập

Standard-IA rẻ hơn Standard khoảng $0,0105/GB-tháng nhưng thu $0,01/GB mỗi lần lấy ra.

```
Tiết kiệm mỗi tháng  = 0,0105 × S (GB)
Phí lấy ra mỗi tháng = 0,01 × S × N   (N = số lần đọc toàn bộ object trong tháng)

Hòa vốn khi:  0,0105 = 0,01 × N   →   N ≈ 1,05
```

**Kết luận: object được đọc nhiều hơn khoảng 1 lần/tháng thì Standard-IA ĐẮT HƠN
Standard.** Đây là con số cần nhớ, và nó giải thích vì sao đề dùng cụm
"accessed once a month or less" để gợi ý IA, còn "accessed daily" thì IA sai.

### Ngưỡng hòa vốn 2 — kích thước object

IA, One Zone-IA và Glacier Instant Retrieval tính tiền **tối thiểu 128 KB mỗi object**,
bất kể object nhỏ đến đâu.

```
Object kích thước S (KB).
Chi phí ở Standard    = S   × 0,023 / 1.048.576   $/tháng
Chi phí ở Standard-IA = 128 × 0,0125 / 1.048.576  $/tháng   (nếu S < 128)

Hòa vốn:  S × 0,023 = 128 × 0,0125   →   S ≈ 69,6 KB
```

**Kết luận: object nhỏ hơn khoảng 70 KB thì để ở Standard rẻ hơn Standard-IA.**
Đây là lý do S3 Lifecycle có bộ lọc `ObjectSizeGreaterThan` — AWS khuyến nghị đặt
ngưỡng 128 KB. Kho ảnh thumbnail 20 KB chuyển hết sang IA là **tăng** hóa đơn 4 lần.

### Ngưỡng hòa vốn 3 — phí request khi chuyển tier

Mỗi lần lifecycle chuyển một object sang Glacier Flexible Retrieval hoặc Deep Archive
tốn khoảng **$0,05 / 1.000 request** = $0,00005 mỗi object. Cộng thêm 8 KB metadata
tính giá Standard và 32 KB tính giá Glacier cho mỗi object đã archive.

```
Object S GB, chuyển Standard → Deep Archive.
Tiết kiệm mỗi tháng = S × (0,023 − 0,00099) = S × 0,02201
Deep Archive buộc tính tối thiểu 180 ngày = 6 tháng
Tổng tiết kiệm      = S × 0,132
Phí chuyển          = 0,00005

Hòa vốn:  S × 0,132 = 0,00005   →   S ≈ 0,00038 GB ≈ 390 KB
```

**Kết luận: chuyển hàng triệu object nhỏ hơn ~400 KB sang Deep Archive thì phí
request nuốt hết phần tiết kiệm** (chưa kể 40 KB metadata mỗi object, thứ càng làm
object nhỏ trở nên tệ hơn). Giải pháp thực tế: gộp object nhỏ thành archive lớn
trước khi lưu, hoặc dùng bộ lọc kích thước trong lifecycle rule.

### Intelligent-Tiering — khi nào nó thắng

Intelligent-Tiering thu một khoản **monitoring and automation** nhỏ mỗi object mỗi
tháng (~$0,0025 / 1.000 object), đổi lại tự chuyển tier và **không thu phí lấy ra**.

Chọn nó khi đề nói `access pattern is unknown` / `unpredictable` / `changing`, hoặc
`without performance impact or operational overhead`, **và** object đủ lớn (>128 KB)
và đủ ít — phí monitoring tính theo **số object**, không theo dung lượng.

**Không** chọn khi bạn đã biết chắc pattern: "logs never accessed after 90 days,
kept 7 years" → lifecycle sang Deep Archive rẻ hơn.

### Lifecycle rule — chuỗi chuẩn của đề thi

```
Ngày 0    : S3 Standard              (đang dùng nhiều)
Ngày 30   : → Standard-IA            (30 ngày là mức tối thiểu; không chuyển sớm hơn được)
Ngày 90   : → Glacier Instant hoặc Flexible Retrieval
Ngày 180+ : → Glacier Deep Archive
Ngày 2555 : Expire (xóa)             (7 năm = 2555 ngày, con số hay gặp trong đề compliance)
```

Ba luật lifecycle ra thi:

1. **Lifecycle chỉ đi xuống bậc lạnh hơn**, không "hâm nóng" ngược lại được. Muốn
   quay về Standard phải `RestoreObject` rồi copy.
2. **Object phải ở Standard tối thiểu 30 ngày** trước khi chuyển sang IA.
3. **Version cũ cần rule riêng** (`NoncurrentVersionTransition` /
   `NoncurrentVersionExpiration`), cộng `AbortIncompleteMultipartUpload` để dọn
   upload dở dang — thứ **không hiện trong console** nhưng vẫn tính tiền. Đây là
   đáp án của đề "bucket bật versioning, chi phí tăng vọt".

Chi tiết cơ chế S3 nằm ở [`02-storage.md`](02-storage.md).

---

## 5. Chọn dịch vụ rẻ hơn cho cùng một việc

### Compute

| Tải | Rẻ nhất | Vì sao |
|---|---|---|
| API gọi 100 lần/ngày | **Lambda** | Không request thì không trả tiền. EC2 nhỏ nhất vẫn ~$7,5/tháng |
| API gọi 500 lần/giây liên tục | **EC2/Fargate + Savings Plan** | Ở mức này Lambda đắt hơn máy chạy 24/7 |
| Batch chạy 4 giờ mỗi đêm | **Spot qua AWS Batch** | Chịu được gián đoạn, chỉ trả 4 giờ |
| Container chạy 24/7 quy mô nhỏ | **Fargate + Compute Savings Plan** | Không phải trả cho capacity thừa của EC2 |
| Container chạy 24/7 quy mô lớn | **ECS/EKS trên EC2 + Savings Plan** | Ở quy mô lớn, EC2 rẻ hơn Fargate tính trên mỗi vCPU |

**Điểm hòa vốn Lambda ↔ EC2:** nếu tải đủ đều để giữ một instance bận trên 50%
thời gian, EC2 rẻ hơn; nếu tải thưa hoặc đột biến mạnh, Lambda rẻ hơn.

**Graviton (ARM).** AWS quảng cáo tới **40% price-performance tốt hơn** so với
instance x86 cùng thế hệ. Điều kiện: workload phải chạy được trên ARM (phần lớn
runtime hiện đại đều chạy được; phần mềm thương mại đóng gói sẵn thì không chắc).
Đề nói "reduce cost without changing architecture" và ứng dụng là Java/Python/Go/
Node → **đổi sang Graviton** là đáp án rất hay gặp, và nó cũng là đáp án của trụ
cột Sustainability.

### Database

| Tình huống | Rẻ hơn | Vì sao |
|---|---|---|
| Tải DB thất thường, có lúc gần bằng 0 | **Aurora Serverless v2** | Scale theo ACU, không trả cho capacity thừa |
| Tải DB ổn định 24/7 | **RDS/Aurora provisioned + RI** | Serverless đắt hơn ở mức tải đều |
| Bảng key-value truy cập thưa, không đoán được | **DynamoDB On-Demand** | Trả theo request |
| Bảng key-value tải đều, đoán được | **DynamoDB Provisioned + Auto Scaling** (+ Reserved Capacity) | Rẻ hơn On-Demand đáng kể ở tải đều |
| Dữ liệu lịch sử chỉ query thỉnh thoảng | **S3 + Athena** | Không nuôi cluster; trả theo TB quét. Đừng dùng Redshift cho việc này |

Bẫy: DynamoDB On-Demand không phải lúc nào cũng rẻ hơn. Ở tải đều và cao,
Provisioned rẻ hơn nhiều lần. Đề dùng từ khóa `unpredictable` / `spiky` để gợi
On-Demand, và `steady` / `predictable` để gợi Provisioned.

### Storage

| Tình huống | Rẻ hơn |
|---|---|
| EBS gp2 đang dùng | **gp3** — rẻ hơn ~20%, IOPS/throughput cấu hình độc lập với size |
| Cần 500 GB nhưng chỉ dùng 50 GB | Thu nhỏ volume (EBS tính theo **cấp phát**, không theo dùng) |
| File share truy cập thưa | **EFS Infrequent Access** + lifecycle của EFS |
| Log ghi tuần tự, dung lượng lớn | **st1** (HDD throughput-optimized) thay vì gp3 |
| Backup cũ trên EBS snapshot | **EBS Snapshot Archive** — rẻ hơn ~75%, restore 24–72 giờ, tối thiểu 90 ngày |

---

## 6. Data transfer — nguồn hóa đơn bất ngờ số 1

Không dịch vụ nào tên là "Data Transfer" nên nó không có trang riêng trong đầu bạn.
Nhưng nó là dòng lớn nhất trên hóa đơn của phần lớn công ty vừa và lớn.

### Bảng chiều nào tốn tiền

| Từ → Đến | Giá tham chiếu `us-east-1` | Ghi chú |
|---|---|---|
| Internet → AWS (ingress) | **$0** | Mọi dịch vụ, mọi Region |
| AWS → Internet (egress) | ~$0,09/GB, **100 GB đầu mỗi tháng miễn phí** cho cả account | Bậc thang giảm dần khi khối lượng lớn |
| Trong cùng AZ, **private IP** | **$0** | Điều kiện là private IP |
| Trong cùng AZ, **public IP hoặc Elastic IP** | ~$0,01/GB mỗi chiều | Bẫy: gọi nhau qua public DNS name trong cùng VPC |
| Cross-AZ trong cùng Region | ~$0,01/GB **mỗi chiều** → $0,02/GB cho một lượt đi-về | |
| Cross-Region | ~$0,02/GB (từ `us-east-1`) | Đắt hơn cho các Region xa |
| Origin AWS → CloudFront | **$0** | Lý do CloudFront vừa nhanh vừa rẻ |
| CloudFront → Internet | ~$0,085/GB, **1 TB đầu mỗi tháng miễn phí** | Rẻ hơn egress trực tiếp |
| VPC Peering cùng AZ | **$0** | Cross-AZ qua peering vẫn tính $0,01/GB mỗi chiều |
| Transit Gateway | ~$0,02/GB xử lý + ~$0,05/giờ/attachment | Đắt hơn peering, đổi lấy khả năng transitive |
| NAT Gateway | ~$0,045/GB xử lý + ~$0,045/giờ | Cộng thêm phí egress nếu ra internet |
| Interface Endpoint (PrivateLink) | ~$0,01/giờ/AZ + ~$0,01/GB | Nhân với số AZ |
| **Gateway Endpoint** (S3, DynamoDB) | **$0** | Không giới hạn |
| Direct Connect data out | ~$0,02/GB | Rẻ hơn egress internet — một lý do dùng DX |

### Ba mẫu bài toán data transfer trong đề

**Mẫu 1 — "hóa đơn tăng vọt sau khi chuyển sang multi-AZ".** Kiến trúc chatty (app
tier gọi db tier hàng nghìn lần mỗi giây) trải trên 2 AZ có khoảng một nửa số cuộc
gọi đi cross-AZ. Đáp án không phải "bỏ multi-AZ" (vi phạm ràng buộc HA) mà là
**giảm chattiness**: thêm cache, gộp request. Chi tiết ra thi: với **ALB**,
cross-zone bật mặc định và **không tính phí cross-AZ**; với **NLB**, tắt mặc định
và **có tính phí** khi bật.

**Mẫu 2 — "phát video, hóa đơn egress khổng lồ".** Đáp án **CloudFront** — không
chỉ vì cache mà vì đoạn origin→CloudFront miễn phí và giá ra internet thấp hơn.

**Mẫu 3 — "private subnet gọi S3 rất nhiều".** Đáp án **Gateway Endpoint**, tính
toán ở mục tiếp theo.

---

## 7. NAT Gateway vs Gateway Endpoint — bài toán kinh điển

Đây là câu hỏi cost-optimization ra thi nhiều nhất. Nếu bạn chỉ nhớ được một thứ
từ file này, nhớ cái này.

### Tình huống

Instance ở private subnet cần đọc/ghi S3. Có ba đường đi:

```
(A) private subnet ──► route 0.0.0.0/0 ──► NAT Gateway ──► Internet Gateway ──► S3
(B) private subnet ──► route tới prefix list của S3 ──► Gateway Endpoint ──► S3
(C) private subnet ──► ENI của Interface Endpoint (PrivateLink) ──► S3
```

Cả ba đều chạy. Giá thì không giống nhau chút nào.

### Tính tiền cho 10 TB/tháng, kiến trúc 3 AZ

Giả định: 730 giờ/tháng, 10 TB = 10.240 GB.

| | NAT Gateway (A) | Gateway Endpoint (B) | Interface Endpoint (C) |
|---|---|---|---|
| Phí theo giờ | 3 NAT × $0,045 × 730 = **$98,55** | **$0** | 3 AZ × $0,01 × 730 = **$21,90** |
| Phí xử lý dữ liệu | 10.240 × $0,045 = **$460,80** | **$0** | 10.240 × $0,01 = **$102,40** |
| Data transfer sang S3 | $0 (cùng Region) | $0 | $0 |
| **Tổng mỗi tháng** | **~$559** | **$0** | **~$124** |

Chênh lệch giữa (A) và (B) là **$559/tháng cho đúng một dòng route table**.
Đây là lý do đề thi yêu quý bài toán này.

### Khi nào Gateway Endpoint KHÔNG dùng được

Gateway Endpoint chỉ hỗ trợ **S3 và DynamoDB**, và chỉ phục vụ traffic **xuất phát
từ chính VPC đó**. Nó không đi qua được:

- VPC peering
- Transit Gateway
- Site-to-Site VPN / Direct Connect (tức là on-premises không dùng được)
- VPC khác, Region khác

Trong những trường hợp đó phải dùng **Interface Endpoint**. Và với mọi dịch vụ
khác S3/DynamoDB (SQS, SNS, KMS, Secrets Manager, Systems Manager, ECR…), Interface
Endpoint là lựa chọn duy nhất.

### Vẫn cần NAT Gateway khi nào

Khi instance ở private subnet cần ra **internet công cộng** (chạy `yum update`,
gọi API bên thứ ba, tải package). Không endpoint nào thay được. Cách giảm chi phí
trong trường hợp này:

- **Một NAT Gateway mỗi AZ** — đắt hơn về phí giờ nhưng tránh phí cross-AZ và tránh
  SPOF. Đề coi "một NAT Gateway duy nhất" là đáp án **sai** cho câu hỏi HA.
- Môi trường dev tối ưu tiền tuyệt đối: một NAT Gateway, chấp nhận SPOF.
- **NAT Instance** rẻ hơn ở khối lượng nhỏ nhưng bạn tự lo HA, tự patch, băng thông
  giới hạn theo instance type. Chỉ đúng khi đề nhấn mạnh chi phí và khối lượng rất nhỏ.

---

## 8. Right-sizing — tìm tiền đang nằm không

Từ khóa nhận diện trong đề: `underutilized`, `CPU utilization averages 10%`,
`over-provisioned`, `instances were sized based on peak load three years ago`.

### Quy trình

1. **Đo trước, cắt sau.** CloudWatch mặc định **không** có metric RAM và dung lượng
   đĩa đã dùng — phải cài **CloudWatch agent**. Đề hay hỏi "làm sao biết instance
   thừa RAM" → CloudWatch agent, không phải metric mặc định.
2. **AWS Compute Optimizer** phân tích 14 ngày metric và đề xuất instance type cụ
   thể cho EC2, ASG, EBS volume, Lambda memory, ECS task trên Fargate, và RDS.
3. **Cắt theo bậc.** Giảm một bậc size (xl → large) là giảm 50% giá.
4. **Đổi thế hệ.** m5 → m6i/m7i thường rẻ hơn **và** nhanh hơn cùng lúc.
5. **Đổi kiến trúc.** x86 → Graviton, xem mục 5.

### Danh sách tài nguyên mồ côi — chỗ tiền nằm im

| Thứ | Vẫn tính tiền dù không dùng | Tìm bằng |
|---|---|---|
| EBS volume `available` (không attach) | Có, đầy đủ giá | Trusted Advisor, Cost Explorer theo usage type |
| EBS snapshot cũ | Có (giá thấp nhưng tích lũy) | Data Lifecycle Manager để tự xóa |
| Elastic IP không gắn instance nào | **Có**, ~$0,005/giờ | Trusted Advisor |
| **Mọi IPv4 công cộng** (kể cả đang gắn) | **Có**, ~$0,005/giờ từ 01/02/2024 | Cost Explorer, usage type `PublicIPv4:InUseAddress` |
| ALB/NLB không có target | Có, phí theo giờ | Trusted Advisor |
| RDS instance đang chạy ở môi trường dev ban đêm | Có | Instance Scheduler, hoặc `StopDBInstance` (RDS tự bật lại sau 7 ngày) |
| Multipart upload dở dang trong S3 | Có, và **không hiện trong console** | Lifecycle rule `AbortIncompleteMultipartUpload` |
| Version cũ trong bucket bật versioning | Có, đầy đủ giá | Lifecycle rule `NoncurrentVersionExpiration` |

Ba dòng cuối là câu trả lời của đề "S3 bill keeps growing but object count is stable".

---

## 9. Công cụ — cái nào trả lời câu hỏi nào

| Câu hỏi trong đề | Công cụ | Ghi chú ra thi |
|---|---|---|
| *"Tháng trước tiền đi đâu?"* / *"phân tích theo service, theo tag, theo account"* | **Cost Explorer** | Có giao diện, có API, dữ liệu tới 13 tháng quá khứ và dự báo 12 tháng tới |
| *"Cảnh báo tôi khi chi vượt $X"* / *"khi dự báo sẽ vượt"* | **AWS Budgets** | Có 4 loại: cost, usage, RI/SP utilization, RI/SP coverage. Cảnh báo được cả trên **forecast**, không chỉ trên thực tế |
| *"Instance nào đang thừa? nên đổi sang type nào?"* | **Compute Optimizer** | Khuyến nghị cụ thể, dựa trên 14 ngày metric |
| *"Kiểm tra nhanh toàn account xem có gì lãng phí"* | **Trusted Advisor** | 5 nhóm check; nhóm cost đầy đủ cần Business/Enterprise Support |
| *"Chi phí này thuộc phòng ban nào?"* | **Cost Allocation Tags** | Xem cảnh báo bên dưới |
| *"Tôi cần dữ liệu thô để tự phân tích"* | **Cost and Usage Report (CUR)** | Đổ vào S3, query bằng Athena. Chi tiết nhất, dạng dữ liệu thô |
| *"Có khoản chi bất thường nào không?"* | **Cost Anomaly Detection** | Machine learning trên pattern chi tiêu, gửi cảnh báo |
| *"Áp trần chi tiêu cho cả tổ chức"* | **Organizations + SCP** | SCP không chặn được chi tiêu trực tiếp, nhưng chặn được việc *tạo* loại tài nguyên đắt tiền |
| *"So sánh giá trước khi build"* | **AWS Pricing Calculator** | |

### Cost Allocation Tags — ba điều luôn ra thi

1. **Tag phải được kích hoạt trong Billing console** thì mới xuất hiện trong Cost
   Explorer và CUR. Gắn tag lên tài nguyên là chưa đủ.
2. **Kích hoạt không có tác dụng hồi tố** — dữ liệu chi phí trước đó không có tag.
   Đề dùng chi tiết này để loại đáp án "bật tag rồi xem chi phí quý trước".
3. Hai loại: **AWS-generated** (`aws:createdBy`) và **user-defined** (tiền tố `user:`).

Để ép tag nhất quán: **Tag Policy** trong Organizations, và IAM condition
`aws:RequestTag` chặn việc tạo tài nguyên thiếu tag.

---

## Bảng số phải nhớ

| Con số | Giá trị | Dùng để làm gì |
|---|---|---|
| Spot giảm giá tối đa | ~90% | Nhận diện đáp án Spot |
| Spot interruption notice | **2 phút** | Thiết kế xử lý gián đoạn |
| RI Standard 3 năm All Upfront | ~72% | "Maximum savings" |
| RI Convertible tối đa | ~66% | Đánh đổi linh hoạt lấy giảm giá |
| Compute Savings Plans | ~66%, phủ **EC2 + Fargate + Lambda** | Câu trả lời của kiến trúc hỗn hợp |
| EC2 Instance Savings Plans | ~72%, khóa **1 family + 1 Region** | Giảm giá tối đa mà vẫn linh hoạt về size |
| Graviton | tới 40% price-performance tốt hơn | "Reduce cost without redesign" |
| Standard-IA / One Zone-IA / GIR | tối thiểu **30 / 30 / 90 ngày**, tối thiểu **128 KB** | Loại đáp án chuyển tier quá sớm |
| Glacier Deep Archive | tối thiểu **180 ngày**, lấy ra **9–48 giờ** | Loại đáp án cần truy cập nhanh |
| Ngưỡng hòa vốn IA theo tần suất | ~**1 lần đọc/tháng** | Chọn giữa Standard và IA |
| Ngưỡng hòa vốn IA theo kích thước | ~**70 KB** | Loại đáp án chuyển thumbnail sang IA |
| Ngưỡng hòa vốn Deep Archive theo kích thước | ~**400 KB** | Bài toán hàng triệu object nhỏ |
| Egress internet | ~$0,09/GB, 100 GB đầu/tháng miễn phí | Dòng lớn nhất hóa đơn |
| Cross-AZ | $0,01/GB **mỗi chiều** | Bài toán kiến trúc chatty |
| NAT Gateway | ~$0,045/giờ + ~$0,045/GB | Bài toán kinh điển |
| Gateway Endpoint | **$0** | Đáp án của bài toán kinh điển |
| Interface Endpoint | ~$0,01/giờ/AZ + ~$0,01/GB | Khi Gateway Endpoint không dùng được |
| IPv4 công cộng | ~$0,005/giờ (~$3,6/tháng) mỗi địa chỉ, **kể cả đang dùng** | Từ 01/02/2024 |
| CloudFront free tier | 1 TB out + 10 triệu request/tháng | Vì sao CloudFront rẻ hơn egress trực tiếp |

Giá tham chiếu `us-east-1`, tính đến **2026-08**.

---

## Bẫy đề thi

**Bẫy 1 — Reserved Instance được coi là đảm bảo capacity**

> *Phải đảm bảo luôn có 10 instance trong `us-east-1a`, kể cả khi Region hết
> capacity.* — "Regional RI" và "Compute Savings Plan" đều là bẫy: chúng là **công
> cụ tính tiền**, không giữ chỗ vật lý. Đáp án: **On-Demand Capacity Reservation**
> trong `us-east-1a` (kết hợp Savings Plan để giảm giá), hoặc **Zonal RI** vốn có
> sẵn cả hai tính chất.

**Bẫy 2 — Spot cho workload không chịu được gián đoạn**

> *Xử lý ảnh người dùng upload, phải trả kết quả trong 30 giây.* — "EC2 Spot Fleet"
> là bẫy (rẻ tới 90%!). Có ràng buộc phản hồi đồng bộ với người dùng, bị thu hồi
> giữa chừng là hỏng trải nghiệm. Đáp án: **Lambda** hoặc Fargate. Spot đúng cho
> batch, không đúng cho đường đi đồng bộ của request.

**Bẫy 3 — chuyển hết mọi thứ sang Glacier**

> *5 tỉ file log, mỗi file 50 KB, giữ 7 năm, gần như không đọc lại.* — "Lifecycle
> sang Deep Archive sau 30 ngày" là bẫy: 5 tỉ object × $0,00005 phí chuyển =
> **$250.000** chỉ riêng phí request, cộng 5 tỉ × 40 KB metadata. Object 50 KB nằm
> dưới cả ngưỡng 128 KB lẫn ~400 KB. Đáp án: **gộp log thành file lớn trước**
> (Firehose gom theo giờ, hoặc S3 Batch Operations) rồi mới archive. Xem
> [ngưỡng hòa vốn 3](#ngưỡng-hòa-vốn-3--phí-request-khi-chuyển-tier).

**Bẫy 4 — One Zone-IA cho dữ liệu không tái tạo được**

> *Backup của database, truy cập hiếm. Rẻ nhất?* — "S3 One Zone-IA" là bẫy: nó chỉ
> lưu ở **một AZ**, mất AZ là mất vĩnh viễn. Đáp án đúng là **Standard-IA** hoặc
> Glacier. One Zone-IA chỉ đúng cho dữ liệu **tái tạo được** (thumbnail, cache).
> Đề luôn cài chi tiết "backup" hoặc "cannot be recreated" để loại nó.

**Bẫy 5 — hóa đơn S3 tăng dù số object không đổi**

> *Bucket bật versioning, object count ổn định, chi phí vẫn tăng đều.* — "Chuyển
> sang Intelligent-Tiering" là bẫy. "Object count" trong console chỉ đếm **current
> version**; mỗi lần ghi đè tạo thêm một version cũ vẫn tính tiền đầy đủ. Đáp án:
> lifecycle rule cho **noncurrent version** + `AbortIncompleteMultipartUpload`.

**Bẫy 6 — NAT Gateway cho traffic tới S3**

> *Private subnet ghi 20 TB log lên S3 mỗi tháng.* — "Nén log" và "Interface
> Endpoint" đều giảm được nhưng không phải đáp án lớn nhất. **S3 Gateway Endpoint**
> miễn phí hoàn toàn: 20 TB qua NAT = 20.480 × $0,045 ≈ **$922/tháng**, xóa sạch
> bằng một dòng route.

**Bẫy 7 — Savings Plan cho tải chỉ chạy giờ hành chính**

> *Môi trường dev chạy 8 tiếng/ngày, 5 ngày/tuần.* — "3-year Savings Plan giảm 66%"
> là bẫy. 8×5 = 40/168 giờ = **24% thời gian**; tắt máy tiết kiệm 76% mà không cam
> kết gì, còn Savings Plan cam kết theo **giờ** nên bạn mất quyền lợi của mọi giờ
> máy tắt. Đáp án: **Instance Scheduler / EventBridge tắt ngoài giờ** + On-Demand.
> Tắt máy luôn thắng khi tỉ lệ sử dụng dưới ~35%.

---

## Cây quyết định

**Đề hỏi "MOST cost-effective" — chạy theo thứ tự này:**

1. Có ràng buộc cứng nào không (HA, compliance, latency, RTO/RPO)? → Loại mọi đáp
   án vi phạm, kể cả rẻ nhất.
2. Có đáp án nào dùng thứ **miễn phí** mà vẫn thỏa ràng buộc không? (Gateway Endpoint,
   CloudFront, lifecycle, tắt máy ngoài giờ) → Nếu có, gần như chắc chắn là nó.
3. Tải thuộc dạng nào? → Áp bảng bốn dạng ở [mục 1](#1-quy-trình-bốn-bước-đọc-một-câu-hỏi-về-tiền).
4. Dòng tiền lớn nhất trong kiến trúc là gì? → Chọn đáp án nhắm vào nó.
5. Còn hai đáp án ngang nhau? → Chọn cái **ít việc vận hành hơn**. Đề thi coi công
   sức vận hành là chi phí thật.

**Chọn storage class cho object:**

```
Truy cập bao lâu một lần?
├── Nhiều lần/ngày ─────────────────────► S3 Standard
├── Không biết / thay đổi ──────────────► Intelligent-Tiering  (nếu object > 128 KB)
├── ~1 lần/tháng hoặc thưa hơn
│   ├── Object < 70 KB ─────────────────► giữ ở Standard (IA đắt hơn)
│   ├── Tái tạo được nếu mất ───────────► One Zone-IA
│   └── Không tái tạo được ─────────────► Standard-IA
├── ~1 lần/quý, cần lấy ra tức thì ─────► Glacier Instant Retrieval
├── ~1–2 lần/năm, chờ được vài giờ ─────► Glacier Flexible Retrieval
└── Gần như không bao giờ, chờ được 1 ngày ► Glacier Deep Archive
                                            (kiểm tra object > ~400 KB trước)
```

**Chọn cách nối private subnet ra ngoài:**

```
Đích đến là gì?
├── S3 hoặc DynamoDB, từ chính VPC này ──► GATEWAY ENDPOINT  ($0)
├── Dịch vụ AWS khác, hoặc từ on-prem/VPC khác ──► INTERFACE ENDPOINT
├── Internet công cộng
│   ├── Cần HA ──────────────────────────► NAT Gateway MỖI AZ
│   ├── Dev, tối ưu tiền tuyệt đối ──────► 1 NAT Gateway (chấp nhận SPOF + phí cross-AZ)
│   └── Khối lượng rất nhỏ, chấp nhận tự vận hành ──► NAT Instance
└── Chỉ cần nhận traffic vào, không cần ra ──► không cần gì cả
```

---

## Nối với thực hành

| Lab | Chạm vào mục nào | Quan sát gì |
|---|---|---|
| [`labs/w02-vpc-networking/`](../../learn-aws/labs/w02-vpc-networking/) | Mục 7 (NAT vs Endpoint) | Biến `enable_nat = false` trong Terraform có comment ghi giá. Bật lên và xem Cost Explorer sau 24 giờ |
| [`labs/w03-ec2-alb-asg/`](../../learn-aws/labs/w03-ec2-alb-asg/) | Mục 2 (mua compute), mục 8 (right-sizing) | ASG scale in/out — đây chính là cơ chế "không trả cho capacity thừa" |
| [`labs/w04-s3-cloudfront/`](../../learn-aws/labs/w04-s3-cloudfront/) | Mục 4 (storage class), mục 6 (data transfer) | Bật lifecycle rule, chờ và xem object đổi storage class. Xem `X-Cache` header để biết request nào không chạm S3 |
| [`labs/w05-databases/`](../../learn-aws/labs/w05-databases/) | Mục 5 (chọn DB rẻ) | So sánh giá RDS provisioned với Aurora Serverless v2 ở cùng tải |
| [`labs/w10-observability-iac/`](../../learn-aws/labs/w10-observability-iac/) | Mục 8, mục 9 | CloudWatch agent để có metric RAM — thứ mà right-sizing cần |
| [`labs/w12-exam-review/`](../../learn-aws/labs/w12-exam-review/) | Toàn bộ | Rà lại toàn account tìm tài nguyên mồ côi trước khi đóng |
| [`labs-self/`](../../learn-aws/labs-self/) — lab `w04` (tự thiết kế lifecycle) | Mục 4 | Bạn tự tính ngưỡng hòa vốn cho bộ dữ liệu đề bài đưa ra |
| [`labs-self/`](../../learn-aws/labs-self/) — lab `w02` (private subnet ra ngoài) | Mục 7 | Đề bài chỉ nói "instance phải đọc được S3 mà không qua internet" — chọn cơ chế là việc của bạn, và verify.sh chấm cả chi phí |

Kế hoạch chi tiêu và bảng bẫy tiền cho account học tập:
[`aws-saa-plan.md` mục 2](../../learn-aws/aws-saa-plan.md).

---

## Nguồn nói khác

| Chỗ | Nguồn `aws-saa-c03/` nói | Thực tế (2026-08) |
|---|---|---|
| File `G-toi-uu-chi-phi.md` | `README.md` và `A-nen-tang-kien-truc.md` đều link tới file này | **Không tồn tại.** File bạn đang đọc thay thế nó |
| Số loại Savings Plans | Nguồn (và phần lớn tài liệu ôn thi) nói **ba** loại | AWS hiện có **bốn**: thêm **Database Savings Plans** (Aurora, RDS, DynamoDB, ElastiCache, DocumentDB, Neptune, Keyspaces, DMS, OpenSearch — tới ~35%). Chưa vào đề SAA-C03. [Savings Plans types](https://docs.aws.amazon.com/savingsplans/latest/userguide/plan-types.html) |
| Spot | Một số tài liệu ôn thi vẫn dạy "bid price" | Từ 2017 giá Spot do AWS điều chỉnh theo cung cầu, **không còn đấu giá**. [Spot pricing](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-spot-instances.html) |
| Địa chỉ IPv4 công cộng | Tài liệu cũ nói chỉ EIP **không gắn** mới tính tiền | Từ **01/02/2024**, **mọi** địa chỉ IPv4 công cộng đều tính ~$0,005/giờ, kể cả đang gắn vào instance đang chạy. Đây là thay đổi giá quan trọng nhất gần đây và đã bắt đầu xuất hiện trong đề |
| Ngưỡng chọn storage class | Nguồn chỉ nói "dữ liệu ít truy cập thì dùng IA" | Có ba ngưỡng định lượng: ~1 lần đọc/tháng, ~70 KB, ~400 KB. Xem [mục 4](#4-s3-storage-class-và-lifecycle--ngưỡng-hòa-vốn-thật). [Glacier storage classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/glacier-storage-classes.html) |
| Intelligent-Tiering | Nguồn ghi "tự động tối ưu, luôn nên dùng" | Có phí monitoring tính **theo số object**; object <128 KB không được auto-tier và luôn tính giá Frequent Access. Với hàng chục triệu object nhỏ thì Intelligent-Tiering **đắt hơn**. [How S3 Intelligent-Tiering works](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intelligent-tiering-overview.html) |

---

## Ngoài phạm vi

- **AWS Cost Categories, Billing Conductor** — dành cho reseller và tổ chức lớn. [Cost Categories](https://docs.aws.amazon.com/cost-management/latest/userguide/manage-cost-categories.html)
- **CUR schema chi tiết, query Athena** — kỹ năng FinOps, không phải kiến thức SAA. [CUR](https://docs.aws.amazon.com/cur/latest/userguide/what-is-cur.html)
- **Enterprise Discount Program, Private Pricing Agreement** — hợp đồng thương mại.
- **Bậc thang giá egress ở khối lượng petabyte** — đề không hỏi con số bậc thang.
- **Spot Fleet và EC2 Fleet** — đề SAA chỉ hỏi ASG mixed instances policy. [EC2 Fleet](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-fleet.html)

---

## Tự kiểm tra

**1.** Một công ty chạy 100 instance `m6i.large` 24/7 ổn định, và thêm 50–200
instance nữa vào giờ cao điểm mỗi ngày (khoảng 4 tiếng). Họ cũng chạy một job phân
tích 6 tiếng mỗi đêm, chia được thành hàng nghìn task nhỏ độc lập. Thiết kế cách
mua compute và giải thích từng phần.

<details><summary>Đáp án</summary>

Ba tầng:

1. **100 instance nền → Savings Plan hoặc Reserved Instance 1–3 năm.** Đây là phần
   chắc chắn chạy, cam kết được. Nếu chắc chắn ở lại family `m6i` trong Region này
   → EC2 Instance Savings Plans (~72%). Nếu có thể sẽ chuyển sang Fargate/Lambda
   hoặc đổi family → Compute Savings Plans (~66%).
2. **50–200 instance giờ cao điểm → On-Demand qua Auto Scaling.** 4 tiếng trên 24 là
   17% thời gian; cam kết cho phần này là lỗ. Dùng target tracking hoặc scheduled
   scaling nếu giờ cao điểm cố định.
3. **Job phân tích ban đêm → Spot** qua ASG mixed instances hoặc AWS Batch. Job chia
   nhỏ, độc lập, chạy ban đêm không ảnh hưởng người dùng → đúng hồ sơ của Spot.
   Bật Capacity Rebalancing và đa dạng hóa instance type.

Sai lầm điển hình bị loại: mua RI cho toàn bộ 300 instance (trả tiền cho capacity
chỉ dùng 17% thời gian), hoặc dùng On-Demand cho cả 100 instance nền (bỏ qua 66–72%
giảm giá miễn phí về mặt rủi ro).
</details>

**2.** Kho ảnh có 200 triệu thumbnail, mỗi cái 15 KB, được đọc khoảng 3 lần mỗi
tháng. Ai đó đề xuất lifecycle chuyển hết sang S3 Standard-IA sau 30 ngày để tiết
kiệm. Tính xem đề xuất này đúng hay sai.

<details><summary>Đáp án</summary>

**Sai ở cả hai chiều.**

Chiều kích thước: object 15 KB nằm dưới ngưỡng tính tiền tối thiểu 128 KB của IA.
Mỗi object bị tính như 128 KB.
- Ở Standard: 15 KB × $0,023/GB = tương đương $0,00000033/object/tháng
- Ở Standard-IA: 128 KB × $0,0125/GB = tương đương $0,00000153/object/tháng

Tức là **đắt hơn khoảng 4,6 lần**. Với 200 triệu object: Standard ~$66/tháng,
Standard-IA ~$306/tháng. Chuyển sang IA làm hóa đơn tăng gần $240/tháng.

Chiều tần suất: 3 lần đọc/tháng đã vượt ngưỡng hòa vốn ~1 lần/tháng. Phí lấy ra
$0,01/GB × 3 lần còn cộng thêm nữa.

Việc cần làm thay vào đó: giữ nguyên Standard, và nếu muốn giảm chi phí thì tấn
công phía **request cost và data transfer** — đặt CloudFront trước bucket. Với
thumbnail đọc 3 lần/tháng, cache hit sẽ cắt cả phí GET lẫn phí egress.
</details>

**3.** Giải thích vì sao "kiến trúc 3 AZ có thể rẻ hơn kiến trúc 2 AZ cho cùng mức
chịu lỗi", nhưng cũng có một dòng chi phí đi ngược lại. Cả hai dòng là gì?

<details><summary>Đáp án</summary>

**Rẻ hơn ở phần compute.** Để chịu được mất một AZ mà vẫn phục vụ 100% tải, với N
AZ mỗi AZ cần chạy 1/(N−1) tải, tổng capacity phải cấp phát là N/(N−1):
- 2 AZ → 200% (mỗi AZ chạy 100%)
- 3 AZ → 150% (mỗi AZ chạy 50%)
- 4 AZ → 133%

Chuyển từ 2 sang 3 AZ cắt được 25% tiền máy.

**Đắt hơn ở phần data transfer.** Traffic cross-AZ tốn $0,01/GB **mỗi chiều**. Trải
trên nhiều AZ hơn nghĩa là tỉ lệ cuộc gọi phải đi cross-AZ cao hơn (với 2 AZ và
phân phối đều, 50% cuộc gọi đi cross-AZ; với 3 AZ là 67%).

Cân nhắc thực tế: với ứng dụng web bình thường, tiết kiệm compute thắng. Với kiến
trúc chatty giữa các tier (hàng nghìn RPC nhỏ mỗi giây), phí cross-AZ có thể vượt
tiền máy — lúc đó giải pháp là giảm chattiness (cache, gộp request), không phải
giảm số AZ.
</details>

**4.** Đề nói: *"Instances in a private subnet download 5 TB of data from S3 each
month. The company wants to reduce cost. The instances also need to reach a
third-party payment API on the internet."* Thiết kế và tính tiền tiết kiệm được.

<details><summary>Đáp án</summary>

Cần **cả hai**:

1. **S3 Gateway Endpoint** cho traffic S3 — thêm một route tới prefix list của S3
   trong route table của private subnet. Chi phí: **$0**.
2. **Giữ NAT Gateway** cho traffic tới payment API. Không thay được, vì đó là
   internet công cộng.

Tiết kiệm: 5 TB = 5.120 GB × $0,045/GB phí xử lý NAT = **~$230/tháng**. Phí theo
giờ của NAT Gateway vẫn còn vì vẫn cần nó cho payment API.

Bẫy trong câu này: nếu bạn chỉ đọc nửa đầu, bạn sẽ chọn "bỏ NAT Gateway hoàn toàn"
và mất điểm. Đề SAA thường xuyên cài một yêu cầu thứ hai ở câu cuối để kiểm tra
bạn có đọc hết không.

Bonus: sau khi có Gateway Endpoint, nên thêm **endpoint policy** giới hạn chỉ truy
cập được bucket của mình — vừa bảo mật vừa không tốn thêm đồng nào. Đây là điểm
Domain 1 nằm trong câu hỏi Domain 4.
</details>

**5.** Vì sao Savings Plans "không đảm bảo capacity" lại là một chi tiết quan trọng,
và trong tình huống nào nó biến một đáp án nghe rất hợp lý thành sai?

<details><summary>Đáp án</summary>

Savings Plans là một **cơ chế tính tiền**: AWS áp giá ưu đãi cho usage đủ điều kiện
tới mức cam kết $/giờ. Nó không đặt trước phần cứng nào cả.

Tình huống làm đáp án sai: đề mô tả một sự kiện có thể đoán trước (Black Friday,
phát hành sản phẩm, sự kiện thể thao) cần chắc chắn có N instance trong một AZ cụ
thể. Nếu Region hết capacity đúng lúc đó — chuyện có thật, đặc biệt với instance
type phổ biến — thì Savings Plan không cứu bạn, bạn vẫn nhận
`InsufficientInstanceCapacity`.

Đáp án đúng là **On-Demand Capacity Reservation** (đặt trước capacity, trả tiền dù
có dùng hay không, hủy lúc nào cũng được) hoặc **Zonal RI** (vừa giữ chỗ vừa giảm
giá, nhưng cam kết 1–3 năm). Hai thứ này kết hợp được với Savings Plan: Capacity
Reservation giữ chỗ, Savings Plan giảm giá cho phần usage đó.

Cùng logic áp dụng cho Regional RI: nó cũng **không** giữ chỗ. Chỉ Zonal RI mới giữ.
</details>

**6.** Bạn được giao rà soát một account và cắt giảm chi phí. Liệt kê năm chỗ bạn
kiểm tra đầu tiên, theo thứ tự khả năng tìm ra tiền, và nói rõ dùng công cụ nào.

<details><summary>Đáp án</summary>

1. **Tài nguyên đang chạy mà không ai dùng** — môi trường dev/test bật 24/7, RDS
   không có kết nối, ALB không có target. Công cụ: **Cost Explorer** nhóm theo
   service + tag `Environment`, và **Trusted Advisor** (Idle Load Balancers, Low
   Utilization EC2). Đây thường là khoản lớn nhất và dễ cắt nhất.
2. **Tài nguyên mồ côi** — EBS volume `available`, snapshot cũ, IPv4 công cộng
   không gắn (và cả đang gắn, từ 2024). Công cụ: **Trusted Advisor**, hoặc query
   trực tiếp `describe-volumes --filters Name=status,Values=available`.
3. **Data transfer** — nhóm Cost Explorer theo **usage type** để tách các dòng
   `DataTransfer-Out-Bytes`, `DataTransfer-Regional-Bytes`, `NatGateway-Bytes`.
   Nếu `NatGateway-Bytes` lớn, kiểm tra ngay xem có Gateway Endpoint chưa.
4. **Right-sizing** — **Compute Optimizer** cho danh sách khuyến nghị cụ thể. Kiểm
   tra cả EBS volume (gp2 → gp3 là món hời không cần suy nghĩ).
5. **Cam kết chưa mua** — Cost Explorer có báo cáo **Savings Plans coverage** và
   **RI coverage**. Nếu coverage thấp mà usage ổn định thì đang trả giá On-Demand
   cho thứ đáng lẽ được giảm 66%.

Sau khi cắt xong, đặt **AWS Budgets** với cảnh báo trên forecast và bật **Cost
Anomaly Detection** để không phải làm lại việc này sau sáu tháng.
</details>

**7.** Đề nói: *"The company stores 500 TB of data that must be retained for 10
years for regulatory compliance. Data is never accessed except during an audit,
which happens once every two years and requires access within 48 hours. The data
must be protected from deletion, including by administrators."* Chọn giải pháp và
giải thích từng ràng buộc dẫn tới quyết định nào.

<details><summary>Đáp án</summary>

**S3 Glacier Deep Archive + S3 Object Lock ở chế độ Compliance mode**, với retention
period 10 năm.

Ánh xạ từng ràng buộc:
- `never accessed except once every two years` → tần suất thấp nhất có thể → tier
  lạnh nhất.
- `access within 48 hours` → Deep Archive lấy ra trong **9–48 giờ** (standard
  retrieval ~12 giờ, bulk ~48 giờ). Vừa khít. Nếu đề nói "within 12 hours" thì
  Deep Archive vẫn được với standard retrieval; nếu nói "within 1 hour" thì phải
  lên Glacier Flexible Retrieval hoặc Instant Retrieval.
- `10 years` > 180 ngày tối thiểu → không dính phí xóa sớm.
- `protected from deletion, including by administrators` → đây là từ khóa của
  **Object Lock Compliance mode**: trong chế độ này **không ai** xóa được, kể cả
  root account, cho tới hết retention. (Governance mode thì user có quyền
  `s3:BypassGovernanceRetention` xóa được — không thỏa "including by administrators".)

Kiểm tra ngưỡng kích thước: 500 TB là dữ liệu compliance, thường là file lớn. Nếu
đề nói đó là 500 TB gồm hàng tỉ file nhỏ thì phải gộp trước, xem
[ngưỡng hòa vốn 3](#ngưỡng-hòa-vốn-3--phí-request-khi-chuyển-tier).

Chi phí xấp xỉ: 500 TB × 1.024 × $0,00099 ≈ **$507/tháng**. Ở S3 Standard con số
đó là ~$11.780/tháng.
</details>
