# Tuần 3 — EC2, EBS, Load Balancer và Auto Scaling

> Tuần 2 bạn đã dựng được cái mạng. Tuần này trả lời câu hỏi kế tiếp: **đặt máy
> vào đó thế nào để nó không chết, không mất dữ liệu, và không đắt vô lý.** Ba
> mảnh ghép — EC2 (compute), EBS (block storage), ELB + Auto Scaling (khả năng
> chịu lỗi và co giãn) — hợp lại thành câu trả lời mặc định của đề SAA cho mọi
> tình huống "hệ thống này phải highly available".

## Học xong bài này bạn phải trả lời được

1. `m7g.large` nghĩa là gì, và vì sao đổi sang `g` (Graviton) thường rẻ hơn ~20%?
2. Khi nào chọn Spot, khi nào Reserved Instance, khi nào Savings Plan — và vì sao
   "Dedicated Host" gần như luôn là câu trả lời sai trừ một trường hợp?
3. IMDSv2 khác IMDSv1 ở đâu, và vì sao một lỗ hổng SSRF trong ứng dụng web lại
   biến thành mất toàn bộ AWS credential nếu còn IMDSv1?
4. gp3 khác gp2 ở chỗ nào ngoài giá? Khi nào bắt buộc phải dùng io2 thay vì gp3?
5. Snapshot là incremental — vậy xoá snapshot đầu tiên thì snapshot thứ hai có
   hỏng không?
6. EBS, EFS, instance store: cùng là "ổ đĩa", đề cho tình huống nào thì chọn cái nào?
7. ALB, NLB, GWLB — từ khoá nào trong đề đủ để loại hai cái còn lại?
8. Vì sao `health_check_type = ELB` mới thật sự là self-healing, còn `EC2` thì không?

## Bản đồ khái niệm

```
                         Internet
                            │
                 ┌──────────▼──────────┐
                 │   Load Balancer     │ ALB (L7) / NLB (L4) / GWLB (L3)
                 │   trải ≥ 2 AZ       │ chỉ NLB có IP tĩnh, còn lại chỉ có DNS name
                 └──────────┬──────────┘
                 ┌──────────▼──────────┐
                 │   Target Group      │ health check + sticky session + cross-zone
                 └──────────┬──────────┘
                            │ ASG tự đăng ký / huỷ đăng ký
        ┌───────────────────▼────────────────────┐
        │       Auto Scaling Group               │
        │  min/desired/max · trải ≥ 2 AZ         │
        │  health_check_type = EC2 | ELB         │
        │  scaling policy · cooldown · warm-up   │
        │  lifecycle hook · instance refresh     │
        └───────┬────────────────────┬───────────┘
      dùng khuôn│                    │sinh ra
    ┌───────────▼────────┐   ┌───────▼────────────────────┐
    │  Launch Template   │   │  EC2 instance              │
    │  AMI · type · SG   │   │   └ instance store: mất khi│
    │  IAM role · IMDS   │   │     stop/terminate         │
    │  user data         │   └───────┬────────────────────┘
    └────────────────────┘           │ attach qua mạng
                             ┌───────▼────────┐  incremental  ┌───────────┐
                             │  EBS volume    │──────────────▶│ Snapshot  │
                             │  CHỈ 1 AZ      │               │ region-wide│
                             └────────────────┘               └───────────┘
```

Điểm quan trọng nhất của sơ đồ này: **EBS volume sống trong đúng một AZ**. Đó là
lý do mọi kiến trúc HA trên AWS đều phải nhân bản ở tầng cao hơn (ASG + nhiều AZ),
chứ không phải ở tầng đĩa.

---

## 1. EC2 với người đã quen Docker

Bạn đã quen chạy container. EC2 là tầng dưới nó — máy ảo có kernel riêng, ENI
riêng, ổ đĩa riêng:

| Bạn đã biết | AWS gọi là | Khác ở chỗ nào |
|---|---|---|
| Docker image | **AMI** (Amazon Machine Image) | AMI là ảnh của cả ổ đĩa + kernel, gắn với region; copy sang region khác phải `copy-image` |
| `docker run --cpus --memory` | **instance type** | Không chọn tuỳ ý, phải chọn trong bảng có sẵn; CPU và RAM đi kèm nhau theo tỉ lệ cố định |
| `cloud-init` / `docker entrypoint` | **user data** | Chạy đúng một lần lúc boot đầu tiên (mặc định) |
| Volume của Docker | **EBS volume** | Là thiết bị block qua mạng, không phải thư mục trên host |
| `docker service scale` | **Auto Scaling Group** | Đơn vị là máy ảo, mất 1–3 phút để sẵn sàng, không phải mili giây |
| Node label / affinity | **placement group** | Ảnh hưởng tới vị trí vật lý, không phải scheduling |

Khác biệt tư duy lớn nhất: trên Kubernetes bạn coi pod là ephemeral từ đầu. Trên
AWS bạn phải **chủ động ép mình coi EC2 instance là ephemeral** — vì AWS vẫn cho
bạn nuôi một con "pet" và mọi thứ vẫn chạy, cho tới ngày AZ đó hỏng.

## 2. Đọc tên instance type

Cấu trúc: `series` + `generation` + `options` `.` `size`.

```
m 7 g . large
│ │ │    └── size: nano/micro/small/medium/large/xlarge/2xlarge/.../metal
│ │ └────── options: g = Graviton (Arm), a = AMD, i = Intel,
│ │                  d = có instance store, n = tối ưu mạng+EBS,
│ │                  e = thêm bộ nhớ/đĩa, z = xung nhịp cao, flex = Flex instance
│ └──────── generation: đời 7 (số càng lớn càng mới, thường rẻ hơn và nhanh hơn)
└────────── series: họ instance
```

Các series cần nhớ ở mức SAA:

| Series | Nghĩa | Đề cho tình huống |
|---|---|---|
| `t` | Burstable, chạy bằng CPU credit | Máy tải thấp, lúc lên lúc xuống; dev/test; web server nhỏ |
| `m` | General purpose, tỉ lệ vCPU:RAM cân bằng (1:4) | Không có yêu cầu đặc biệt → mặc định chọn `m` |
| `c` | Compute optimized (1:2) | Batch, mã hoá, game server, HPC nhẹ |
| `r`, `x`, `z` | Memory optimized (1:8 trở lên) | In-memory database, cache lớn, SAP HANA |
| `i`, `d` | Storage optimized, có NVMe local | NoSQL cần IOPS local rất cao, data warehouse |
| `p`, `g`, `inf`, `trn` | Accelerated (GPU / chip AI) | ML training, inference, transcode |

Về `t`: nó chạy bằng **CPU credit**, hết credit thì bị hạ về baseline (`t3.micro`
là 10% CPU). Chế độ `unlimited` cho vượt baseline nhưng **tính tiền thêm** — một
nguồn hoá đơn bất ngờ kinh điển.

Về `g` (Graviton, Arm64): rẻ hơn dòng x86 tương đương, đánh đổi là binary phải build
cho `arm64` — với người dùng Docker chỉ là `--platform linux/arm64`. Đề hỏi "giảm chi
phí compute mà không đổi kiến trúc" thì Graviton là đáp án hợp lệ.

## 3. Mô hình mua — nơi Domain 4 sống

| Mô hình | Cơ chế | Giảm giá | Cam kết | Chọn khi |
|---|---|---|---|---|
| **On-Demand** | Trả theo giây/giờ | 0% | Không | Tải không đoán được, đang thử nghiệm, ngắn hạn |
| **Savings Plans** | Cam kết chi $X/giờ trong 1 hoặc 3 năm | tới ~72% | 1 hoặc 3 năm | Mặc định nên chọn khi tải ổn định. `Compute SP` linh hoạt nhất — áp cho mọi region, mọi family, cả Fargate và Lambda |
| **Reserved Instance** | Cam kết đúng một cấu hình instance | tới ~72% | 1 hoặc 3 năm | Khi cần **Capacity Reservation trong một AZ cụ thể** (zonal RI), hoặc bán lại trên Marketplace |
| **Spot** | Mua capacity thừa, AWS đòi lại bất cứ lúc nào | tới ~90% | Không | Workload **fault-tolerant, stateless, có thể ngắt**: batch, CI runner, render, data processing |
| **Dedicated Instance** | Máy ảo chạy trên phần cứng không chia sẻ với account khác | Đắt hơn | Không | Yêu cầu tuân thủ ép "không multi-tenant" |
| **Dedicated Host** | Nguyên một máy vật lý, bạn thấy socket/core | Đắt nhất | Có thể có | **Bring-Your-Own-License** tính theo socket/core (Oracle, Windows Server cũ). Đây gần như là lý do duy nhất |

Chọn nhanh trong phòng thi: "có thể bị gián đoạn / fault-tolerant / rẻ nhất" →
**Spot**. "Chạy 24/7 trong 1–3 năm" → **Savings Plans** (hoặc **RI** nếu đề nhấn
một cấu hình cố định / cần capacity reservation trong một AZ). "Licence tính theo
core vật lý, socket" → **Dedicated Host**; "compliance, không chia sẻ phần cứng"
mà không nhắc licence → **Dedicated Instance**.

Về Spot: AWS gửi **interruption notice trước 2 phút** (qua EventBridge và qua
instance metadata) và có thể gửi **rebalance recommendation** sớm hơn. Kiến trúc
đúng là bắt tín hiệu đó, checkpoint state ra S3/EFS, drain connection. ASG có
**Capacity Rebalancing** làm việc này tự động.

> Free plan của lộ trình này **không dùng được** Savings Plans và Reserved
> Instances — học lý thuyết, không lab được.

## 4. User data và Instance Metadata Service

**User data** là script chạy lúc boot lần đầu. Với Linux AMI của Amazon, nó do
`cloud-init` thực thi dưới quyền root. Bạn đã quen thứ này.

**Instance Metadata Service (IMDS)** là thứ mới. Từ bên trong instance, gọi:

```
http://169.254.169.254/latest/meta-data/
```

sẽ trả về instance-id, AZ, private IP, và — quan trọng nhất —
`iam/security-credentials/<role>` chứa **temporary credential của IAM role gắn
vào instance**. Đây chính là cơ chế làm cho instance profile hoạt động: SDK và
AWS CLI trên máy tự động lấy credential ở đó, nên bạn không bao giờ phải đặt
access key vào máy.

### Vì sao IMDSv2 bắt buộc

IMDSv1 là một GET đơn giản. Nếu ứng dụng web của bạn có lỗ hổng **SSRF** — kiểu
"nhập URL để tôi tải ảnh về" — kẻ tấn công nhập `http://169.254.169.254/...` và
web server ngoan ngoãn tải credential về đưa cho họ. Đây chính là lớp lỗ hổng
đứng sau vụ Capital One 2019.

IMDSv2 dùng **session-oriented**: phải `PUT` để lấy token trước, rồi mới `GET`
kèm token trong header.

```bash
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id
```

Ba lớp phòng thủ nằm trong thiết kế này:

- Đa số lỗ hổng SSRF chỉ khiến server phát **GET**, không phát được **PUT**.
- Header tuỳ biến `X-aws-ec2-metadata-token-ttl-seconds` khó chèn qua SSRF.
- **Hop limit** trên gói trả về mặc định là 1 (hoặc 2 nếu AMI khai báo
  `ImdsSupport: v2.0`). Hop limit 1 nghĩa là gói không đi qua được lớp NAT của
  container — tức container trên máy không tự tiện đọc được credential của host.
  Chạy container thì đặt hop limit = 2, và chỉ khi thật cần.

Cấu hình: `HttpTokens=required`, `HttpEndpoint=enabled`. Trong Terraform là block
`metadata_options`. Từ góc SAA: **"require IMDSv2" là đáp án đúng cho mọi câu hỏi
bảo vệ credential của EC2.**

## 5. Placement group

Mặc định AWS đã rải instance của bạn ra nhiều phần cứng khác nhau. Placement group
là khi bạn muốn **ép** cách rải đó. Không mất phí.

| Loại | Đặt ở đâu | Đánh đổi | Đề cho tình huống |
|---|---|---|---|
| **Cluster** | Sát nhau, cùng một AZ, cùng segment mạng băng thông cao | Một sự cố phần cứng có thể hạ cả nhóm. Không trải AZ được | HPC, MPI, "cần latency mạng thấp nhất giữa các node", single-flow lên 10 Gbps |
| **Spread** | Mỗi instance trên một rack riêng, tối đa **7 instance chạy mỗi AZ mỗi group** | Số lượng bị chặn cứng | "Vài instance quan trọng, không được cùng chết", ví dụ 3 node quorum |
| **Partition** | Chia thành các partition, mỗi partition có bộ rack riêng, **tối đa 7 partition mỗi AZ** | Phức tạp hơn | Hadoop/HDFS, Cassandra, Kafka — hệ thống tự biết topology và tự nhân bản chéo partition |

Mẹo nhớ: **Cluster = nhanh, Spread = an toàn (ít máy), Partition = an toàn (nhiều máy)**.

## 6. EBS — các loại volume

EBS là block device qua mạng. Không phải đĩa cắm vào máy. Hệ quả: nó sống độc lập
với instance, nhưng **chỉ trong một Availability Zone**.

| Loại | Kích thước | IOPS | Throughput | Boot? | Dùng khi |
|---|---|---|---|---|---|
| **gp3** | 1 GiB – 64 TiB | baseline **3.000**, provision tới **80.000** | baseline **125 MiB/s**, tới **2.000 MiB/s** | Có | **Mặc định.** IOPS và throughput tách rời khỏi dung lượng |
| **gp2** | 1 GiB – 16 TiB | **3 IOPS mỗi GiB**, min 100, max 16.000; burst 3.000 nếu < 1 TiB | 128–250 MiB/s theo dung lượng | Có | Thế hệ cũ. Không có lý do gì chọn mới |
| **io2 Block Express** | 4 GiB – 64 TiB | tới **256.000** | tới **4.000 MiB/s** | Có | Latency dưới 500 µs, IOPS bền vững, database quan trọng nhất |
| **io1** | 4 GiB – 16 TiB | tới **64.000** | tới 1.000 MiB/s | Có | Thế hệ cũ của io2 |
| **st1** | 125 GiB – 16 TiB | tối đa 500 (I/O 1 MiB) | tối đa **500 MiB/s** | **Không** | Đọc ghi tuần tự lớn: log processing, big data, data warehouse |
| **sc1** | 125 GiB – 16 TiB | tối đa 250 | tối đa **250 MiB/s** | **Không** | Rẻ nhất. Dữ liệu lạnh, ít truy cập, throughput-oriented |

Ba điều đáng nhớ hơn cả bảng số:

**gp3 tách hiệu năng khỏi dung lượng.** Với gp2, muốn 3.000 IOPS bạn phải mua 1.000
GiB dù chỉ dùng 20 GiB. gp3 cho 3.000 IOPS baseline miễn phí ở mọi kích thước. Đề
hỏi "giảm chi phí storage mà giữ nguyên hiệu năng" → **migrate gp2 sang gp3**, làm
online bằng Elastic Volumes, không downtime.

**Độ bền khác nhau:** gp2/gp3/io1/st1/sc1 là 99,8–99,9% (AFR ≤ 0,2%), **io2 là
99,999%**. Đề nhắc "durability cao nhất cho single volume" → io2.
**HDD (st1, sc1) không boot được.**

## 7. Snapshot — bản chất incremental

Snapshot của EBS lưu trong S3 (do AWS quản lý, bạn không thấy bucket) và mang
tính **region-wide**, không bị khoá vào AZ. Đó là cách bạn chuyển dữ liệu block
sang AZ khác hay region khác.

Cơ chế incremental hay bị hiểu sai:

```
Snap A (đầy đủ)      block: [1][2][3][4]
Snap B (sau khi sửa block 2)  lưu thêm: [2']  và trỏ [1][3][4] về Snap A
Snap C (sau khi sửa block 4)  lưu thêm: [4']  và trỏ về A/B
```

Bạn chỉ **trả tiền cho phần thay đổi**. Nhưng đây là điểm mấu chốt:

> **Xoá Snap A KHÔNG làm hỏng Snap B.** Khi bạn xoá một snapshot, AWS chỉ thật sự
> xoá những block mà **không snapshot nào khác còn tham chiếu**. Mọi snapshot còn
> lại vẫn restore được đầy đủ. Mỗi snapshot luôn là một bản khôi phục hoàn chỉnh
> về mặt logic.

Vài chi tiết SAA hay hỏi:

- Restore tạo ra **volume mới**, có thể ở AZ khác, đổi được loại volume và kích
  thước (chỉ tăng). Snapshot **copy được sang region khác** — nền của backup DR.
- Snapshot của volume đã mã hoá thì **bắt buộc được mã hoá**. Muốn mã hoá một
  volume chưa mã hoá: snapshot → copy snapshot có bật encryption → restore. Không
  mã hoá tại chỗ được.
- **Data Lifecycle Manager** hoặc **AWS Backup** để tự động hoá lịch snapshot.
  Snapshot bị bỏ quên là khoản tiền âm thầm — nó không hiện trong danh sách volume.

## 8. Instance store so với EBS

Instance store là NVMe/SSD **gắn thẳng vào máy vật lý** đang chạy instance của bạn.

| | Instance store | EBS |
|---|---|---|
| Vị trí | Trên host vật lý | Qua mạng, trong AZ |
| Hiệu năng | Cao nhất (hàng triệu IOPS trên `i` series) | Tới 256.000 IOPS |
| Tồn tại sau khi **stop** instance | **KHÔNG** | Có |
| Tồn tại sau khi **terminate** | **KHÔNG** | Có, nếu `delete_on_termination = false` |
| Tồn tại sau khi host hỏng | **KHÔNG** | Có |
| Snapshot được? | Không | Có |
| Đổi kích thước? | Không, gắn với instance type | Có, online |
| Giá | Nằm trong giá instance | Tính riêng theo GB-tháng |

Từ khoá trong đề: **"ephemeral", "temporary", "scratch", "buffer", "cache", "IOPS
cao nhất có thể"** → instance store. **"persistent", "durable", "phải sống sau
reboot"** → EBS.

Nhớ: **stop rồi start một instance có instance store là mất sạch dữ liệu trên đó**,
vì start sẽ đưa instance lên một host vật lý khác.

## 9. EBS Multi-Attach — ở mức khái niệm

Chỉ `io1` và `io2` hỗ trợ. Cho phép gắn **một volume vào tối đa 16 instance Nitro
trong cùng một AZ**, tất cả đều có quyền đọc-ghi đầy đủ.

Cái bẫy: **ext4, XFS, NTFS đều KHÔNG dùng được với Multi-Attach** — chúng không có
cơ chế phối hợp lock giữa các host, ghi đồng thời là hỏng dữ liệu. Phải dùng
**cluster-aware file system** (GFS2, OCFS2) hoặc ứng dụng tự lo I/O fencing.

Ở mức SAA chỉ cần nhận ra: "nhiều instance cần chia sẻ file system" → gần như luôn
là **EFS**. Multi-Attach chỉ đúng khi đề nói rõ về clustered application đã có sẵn
cơ chế quản lý concurrent write.

## 10. EBS so với EFS so với instance store so với S3

Bảng này ra thi. Học thuộc.

| | **Instance store** | **EBS** | **EFS** | **S3** |
|---|---|---|---|---|
| Kiểu | Block | Block | File (NFSv4) | Object |
| Bắc cầu | Đĩa cắm vào máy | SAN/iSCSI | NFS server | HTTP API |
| Gắn vào bao nhiêu máy | 1 | 1 (16 nếu Multi-Attach io1/io2, cùng AZ) | **Hàng nghìn, đồng thời** | Không "gắn", gọi API |
| Phạm vi | 1 host | **1 AZ** | **Multi-AZ trong 1 region** (hoặc One Zone) | Region, ≥ 3 AZ |
| Tự lớn lên? | Không | Không (phải `modify-volume`) | **Có, tự động** | Có, vô hạn |
| Latency | Thấp nhất | Rất thấp | Thấp (Standard, SSD) | Cao hơn |
| Hệ điều hành | Linux/Windows | Linux/Windows | **Chỉ Linux** (Windows dùng FSx) | Không liên quan |
| Giá | Trong giá instance | Theo GB **provision** | Theo GB **dùng thật**, đắt hơn EBS/GB | Rẻ nhất/GB |
| Đề cho tình huống | Scratch, cache, IOPS cực cao | Root volume, database một node | **Nhiều EC2 cùng đọc ghi một thư mục**: CMS, shared upload, home directory | Static asset, backup, data lake, log |

EFS có thêm hai trục cần biết ở mức SAA:

- **Storage class:** EFS Standard (SSD, low latency) → **EFS Infrequent Access**
  (truy cập vài lần mỗi quý) → **EFS Archive** (vài lần mỗi năm). Chuyển tầng bằng
  **lifecycle management**, giống hệt ý tưởng của S3 lifecycle.
- **Resilience:** file system **Regional** (dữ liệu trải nhiều AZ) so với
  **One Zone** (rẻ hơn, mất AZ là mất). Không đổi được sau khi tạo.

Nếu đề nhắc **Windows** và **SMB** → **FSx for Windows File Server**. Nhắc **HPC,
Lustre, tính toán song song trên dữ liệu ở S3** → **FSx for Lustre**. Nhận diện
use case là đủ ở mức SAA.

## 11. Ba loại Elastic Load Balancer

| | **ALB** | **NLB** | **GWLB** |
|---|---|---|---|
| Tầng OSI | **7** (HTTP) | **4** (TCP/UDP) | **3** (IP) |
| Giao thức listener | HTTP, HTTPS, gRPC | TCP, UDP, TLS | GENEVE (port 6081) |
| Định tuyến theo | Path, host header, HTTP header, query string, method, source IP | IP + port | Không định tuyến — chuyển hướng gói |
| Target type | Instance, IP, **Lambda**, ALB-in-NLB | Instance, IP, **ALB** | Instance, IP |
| IP tĩnh / Elastic IP | Không (chỉ DNS name) | **Có, một EIP mỗi AZ** | Không |
| TLS termination | Có | Có | Không |
| Hiệu năng | Cao | **Cực cao, latency thấp nhất**, hàng triệu req/s | — |
| Cross-zone mặc định | **Bật** | **Bật** (theo tài liệu features hiện tại) | Bật |

Cách chọn trong phòng thi — tìm từ khoá:

- "route theo `/api/*`", "host-based routing", "microservice", "container",
  "WebSocket", "xác thực người dùng qua Cognito/OIDC" → **ALB**.
- "cần **IP tĩnh**", "cần **UDP**", "MQTT / gaming / SIP", "latency cực thấp",
  "hàng triệu request mỗi giây", "giữ nguyên **source IP** của client" → **NLB**.
- "chèn **firewall / IDS / IPS của bên thứ ba**", "traffic inspection appliance"
  → **GWLB**.

Ba chi tiết hay ra thi:

- **ALB luôn ghi đè source IP** — ứng dụng phải đọc `X-Forwarded-For`. NLB **giữ
  nguyên source IP** ở mức TCP, đó là một lý do chọn NLB.
- **ALB hỗ trợ Lambda làm target** — đề hỏi "gọi Lambda qua HTTP mà không dùng API
  Gateway" thì ALB là đáp án hợp lệ.
- Mọi ELB cần subnet ở **ít nhất 2 AZ**, và phải là public subnet nếu internet-facing.

## 12. Target group, health check, sticky session, cross-zone

**Target group** là danh sách đích + cách kiểm tra sức khoẻ của chúng. ASG tự đăng
ký và huỷ đăng ký instance — bạn không bao giờ sửa danh sách bằng tay.

**Health check** — các tham số ra thi:

| Tham số | Nghĩa | Mặc định của ALB |
|---|---|---|
| `path` | URL để gọi | `/` |
| `interval` | Bao lâu gọi một lần | 30 giây |
| `timeout` | Chờ bao lâu thì coi là fail | 5 giây |
| `healthy_threshold` | Bao nhiêu lần pass liên tiếp thì thành healthy | 5 |
| `unhealthy_threshold` | Bao nhiêu lần fail liên tiếp thì thành unhealthy | 2 |
| `matcher` | HTTP code coi là healthy | `200` |

Thời gian phát hiện hỏng = `interval × unhealthy_threshold`. Lab tuần 3 đặt
`interval = 10`, `threshold = 2` → phát hiện sau khoảng 20 giây, đủ ngắn để bạn
ngồi xem trong một buổi lab.

**Deregistration delay** (connection draining), mặc định **300 giây**: khi gỡ một
target ra, ELB ngừng gửi request mới nhưng vẫn cho các request đang chạy hoàn tất.
Đề hỏi "làm sao rút máy ra khỏi ELB mà không cắt request đang xử lý" → đây.

**Sticky session** (session affinity): ALB đặt cookie để một client luôn về cùng
một target — `lb_cookie` (ALB tự sinh cookie `AWSALB`) hoặc `app_cookie` (bám theo
cookie của ứng dụng). NLB cũng có sticky nhưng theo **source IP**.

Đánh đổi: sticky làm tải lệch và phá nguyên tắc stateless. Đề nhắc "một máy quá tải
trong khi máy khác rảnh" thì sticky là nghi phạm. Kiến trúc đúng là **đưa session
ra ngoài** — ElastiCache hoặc DynamoDB — rồi tắt sticky.

**Cross-zone load balancing**: ELB có node ở mỗi AZ. Không bật cross-zone thì node
ở AZ-A chỉ gửi cho target ở AZ-A. Nếu AZ-A có 2 máy và AZ-B có 8 máy, mỗi máy ở
AZ-A nhận gấp 4 lần tải. Bật cross-zone thì mọi node gửi cho mọi target.

Với ALB nó bật sẵn và **miễn phí**. Với NLB nó cũng đã bật theo tài liệu features
hiện tại, nhưng lưu ý **traffic cross-AZ có thể bị tính phí data transfer** — đây
là điểm khác biệt kinh điển giữa ALB và NLB trong đề tối ưu chi phí.

## 13. Auto Scaling Group

ASG là thứ biến "vài cái máy" thành "một hệ thống tự chữa lành".

**Launch template** là khuôn: AMI, instance type, security group, IAM instance
profile, user data, EBS mapping, metadata options. Nó **có version** — đó là lý do
nó thay thế Launch Configuration cũ (bất biến, không version, không hỗ trợ IMDSv2
hay mixed instance policy). Đề nhắc Launch Configuration thì đáp án đúng thường là
"chuyển sang launch template".

**Ba con số:** `min` / `desired` / `max`. ASG luôn kéo số instance đang chạy về
`desired`, và không bao giờ vượt ra ngoài `[min, max]`.

### Scaling policy

| Loại | Cách hoạt động | Chọn khi |
|---|---|---|
| **Target tracking** | "Giữ `ASGAverageCPUUtilization` ở 50%", AWS tự tạo alarm và tự tính số máy | **Mặc định.** Đề hỏi "đơn giản nhất / ít thao tác vận hành nhất" |
| **Step scaling** | Ngưỡng theo bậc: CPU 60–70% thêm 1 máy, > 70% thêm 3 máy | Cần kiểm soát chi tiết theo mức độ vượt ngưỡng |
| **Simple scaling** | Một alarm, một hành động, rồi chờ hết cooldown | Thế hệ cũ. AWS khuyến nghị **không dùng** |
| **Scheduled** | Đặt `desired` theo lịch (cron) | **Biết trước** tải: giờ hành chính, sự kiện, chạy batch cuối tháng |
| **Predictive** | ML học chu kỳ tải trong lịch sử rồi **scale trước** khi tải đến | Tải có chu kỳ rõ (ngày/tuần) và **thời gian khởi động máy lâu** |

Predictive giải vấn đề target tracking không giải được: máy mất 5 phút để sẵn sàng
thì phản ứng sau khi CPU đã tăng là quá muộn. Thực tế bật predictive **cùng với**
target tracking — predictive lo phần dự báo, target tracking lo phần bất ngờ.

### Cooldown và warm-up — hai thứ hay bị lẫn

| | **Cooldown** | **Instance warm-up** |
|---|---|---|
| Áp cho | **Simple scaling policy** | **Target tracking và step scaling** |
| Mặc định | **300 giây** | Kế thừa từ health check grace period nếu không đặt |
| Nghĩa | Sau một hành động scaling, ASG tạm dừng mọi hành động tiếp theo | Máy mới không được tính vào metric tổng hợp cho tới khi ấm |
| Vì sao cần | Tránh scale chồng lên nhau trước khi thấy hiệu quả | Máy đang boot có CPU cao/thấp bất thường, làm lệch số liệu |

Điểm mấu chốt: **target tracking và step scaling có thể scale out ngay lập tức,
không chờ cooldown.** Chúng dựa vào warm-up chứ không dựa vào cooldown. Và ASG
**không bao giờ chờ cooldown khi thay một máy bị unhealthy** — self-healing luôn
được ưu tiên.

### Health check type — bẫy kinh điển

| | Kiểm tra cái gì | Nginx chết nhưng máy còn sống |
|---|---|---|
| **`EC2`** (mặc định) | EC2 status check: máy có boot được không, network có thông không | ASG **không làm gì**. Người dùng gặp 502 mãi mãi |
| **`ELB`** | Health check của target group: **ứng dụng có trả lời không** | ASG đánh dấu unhealthy và **thay máy** |

Đây là câu hỏi ra thi và cũng là điểm mấu chốt của lab tuần 3. Mặc định của ASG là
`EC2`, và mặc định đó **không đủ**. Bất kỳ ASG nào đứng sau ELB đều nên đặt
`health_check_type = ELB`.

Đi kèm là **health check grace period** (mặc định 300 giây): khoảng thời gian sau
khi máy khởi động mà ASG bỏ qua kết quả health check. Đặt quá ngắn thì ASG sẽ giết
máy trước khi user data kịp cài xong nginx — và bạn được một vòng lặp launch/kill
vô tận, đốt tiền mà không có gì chạy.

### Lifecycle hook

Chèn một bước **trước khi** instance vào `InService`, hoặc **trước khi** nó bị
terminate. Instance rơi vào `Pending:Wait` / `Terminating:Wait` cho tới khi bạn gọi
`complete-lifecycle-action` hoặc hết timeout. Dùng để nạp cache / warm up trước khi
nhận traffic, và — use case hay ra thi nhất — **đẩy log ra ngoài, drain connection,
chụp bản ghi debug trước khi máy chết**, vì máy do ASG terminate là mất sạch.

### Instance refresh

Cần đổi AMI cho toàn bộ ASG? `start-instance-refresh` thay từng phần theo
`MinHealthyPercentage` — rolling update ở mức ASG, chính là `kubectl rollout restart`.

## 14. Vì sao ASG + ALB + multi-AZ là câu trả lời mặc định

Ghép lại, chúng trám những lỗ hổng khác nhau:

| Lỗ hổng | Ai vá |
|---|---|
| Một process chết | ASG với `health_check_type = ELB` phát hiện, thay máy |
| Một instance / host vật lý chết | ASG giữ `desired`, sinh máy mới |
| **Cả một AZ chết** | ASG + ALB cùng trải nhiều AZ, traffic dồn về AZ còn lại |
| Tải tăng đột biến | Scaling policy |
| Deploy phiên bản mới | Instance refresh |

Không có mảnh nào thay được mảnh nào. Nhiều AZ mà không có ASG thì mất AZ là mất
nửa capacity vĩnh viễn. ASG một AZ thì mất AZ là mất tất cả. Có ASG và nhiều AZ mà
health check để `EC2` thì ứng dụng chết nhưng máy sống, không ai thay.

Vì thế khi đề SAA có chữ **"highly available"** và một lựa chọn là *ASG trải ít nhất
2 AZ đứng sau ALB*, gần như chắc chắn đó là đáp án. Các lựa chọn còn lại thường sai
vì: chỉ một AZ, dùng Elastic IP thay load balancer, hoặc scale bằng cách đổi sang
instance to hơn (**vertical scaling — luôn là bẫy**: cần downtime và có trần).

---

## Bảng quyết định

| Tình huống trong đề | Chọn | Không chọn, vì |
|---|---|---|
| Batch job chạy đêm, ngắt được | **Spot** | On-Demand: đắt gấp 10 mà không cần |
| Web server chạy 24/7 ba năm | **Compute Savings Plan** | Spot: bị ngắt là mất người dùng |
| Licence Oracle tính theo core vật lý | **Dedicated Host** | Dedicated Instance: không thấy socket/core |
| Cần IOPS cao mà dung lượng nhỏ | **gp3** | gp2: phải mua dung lượng thừa để có IOPS |
| Database quan trọng, độ bền cao nhất | **io2** | gp3: 99,9% so với 99,999% |
| Log tuần tự, dung lượng lớn, rẻ | **st1** (lạnh hơn: **sc1**) | gp3: đắt hơn cho throughput workload |
| Nhiều EC2 cùng đọc ghi một thư mục | **EFS** | EBS Multi-Attach: cần cluster-aware FS |
| Dữ liệu tạm, IOPS cực cao | **Instance store** | EBS: chậm hơn, ở đây không cần bền |
| Chuyển volume sang AZ khác | **Snapshot rồi restore** | Không attach chéo AZ được |
| Route `/api/*` sang target group khác | **ALB** | NLB: không đọc được HTTP |
| Cần IP tĩnh để whitelist ở firewall khách hàng | **NLB + Elastic IP** | ALB: chỉ có DNS name, IP đổi liên tục |
| Chèn firewall của bên thứ ba vào luồng | **GWLB** | ALB/NLB: không phải công việc của chúng |
| Tự co giãn, ít thao tác nhất | **Target tracking** | Step: phải tự tính ngưỡng |
| Biết trước 8h sáng tải tăng | **Scheduled** (hoặc Predictive) | Target tracking: phản ứng sau khi đã chậm |
| Đẩy log ra trước khi ASG giết máy | **Lifecycle hook (terminating)** | user data: chỉ chạy lúc sinh ra |
| ASG không thay máy khi app chết | Đổi `health_check_type` sang **ELB** | Giữ `EC2`: chỉ thấy máy sống |
| 3 node quorum không được cùng chết | **Spread placement group** | Cluster: cùng rack, cùng chết |
| MPI cluster cần latency thấp nhất | **Cluster placement group** | Spread: rải ra là chậm đi |

## Số phải thuộc

| Con số | Giá trị |
|---|---|
| gp3 baseline IOPS / throughput | **3.000 IOPS / 125 MiB/s** (miễn phí, mọi kích thước) |
| gp3 max IOPS / throughput | 80.000 / 2.000 MiB/s |
| gp2 IOPS | **3 IOPS mỗi GiB**, min 100, max 16.000, burst 3.000 nếu < 1 TiB |
| io2 Block Express max | 256.000 IOPS / 4.000 MiB/s |
| Độ bền EBS | gp2/gp3/io1/st1/sc1: **99,8–99,9%**; **io2: 99,999%** |
| st1 / sc1 min size | **125 GiB**, và **không boot được** |
| EBS Multi-Attach | **16 instance Nitro, cùng 1 AZ**, chỉ io1/io2 |
| Spread placement group | **7 instance chạy / AZ / group** |
| Partition placement group | **7 partition / AZ** |
| Spot interruption notice | **2 phút** |
| ASG default cooldown | **300 giây** |
| Health check grace period mặc định | **300 giây** |
| Deregistration delay mặc định | **300 giây** |
| IMDS endpoint | **169.254.169.254** (IPv6: `fd00:ec2::254`) |
| IMDSv2 hop limit mặc định | 1 (hoặc 2 nếu AMI khai `ImdsSupport: v2.0`) |
| ELB cần tối thiểu | **2 AZ** |

## Bẫy kinh điển

**"EBS được nhân bản qua nhiều AZ."** Sai. EBS nhân bản trong **một AZ**. Muốn qua
AZ khác phải snapshot. Đây là lý do multi-AZ phải làm ở tầng ASG.

**"Xoá snapshot cũ nhất sẽ hỏng các snapshot sau."** Sai. AWS chỉ xoá block không
còn ai tham chiếu. Mọi snapshot còn lại vẫn restore đầy đủ.

**"Stop instance thì instance store vẫn còn."** Sai, mất sạch. Start sẽ đưa
instance sang host vật lý khác.

**"Multi-AZ nghĩa là HA, cứ chọn nhiều AZ là xong."** Chưa đủ. Nhiều AZ mà không
có ASG thì mất AZ là mất capacity vĩnh viễn, không ai sinh máy bù.

**"ASG mặc định đã tự chữa lành khi ứng dụng chết."** Sai. Mặc định là
`health_check_type = EC2`, chỉ thấy máy sống hay chết. Ứng dụng treo mà máy còn
ping được thì ASG không làm gì.

**"NLB đọc được HTTP header."** Không. NLB ở layer 4. Muốn route theo path/host
phải dùng ALB (hoặc đặt ALB làm target của NLB).

**"ALB có IP tĩnh."** Không, chỉ có DNS name và IP sau nó đổi liên tục. Cần IP tĩnh
→ NLB. Đây cũng là lý do security group của instance phải **tham chiếu security
group của ALB** chứ không viết CIDR.

**"Bật sticky session để cân bằng tải tốt hơn."** Ngược lại — sticky làm tải lệch.
Nó là workaround cho ứng dụng stateful, không phải tính năng hiệu năng.

**"Scale up (máy to hơn) cũng là scale."** Trong ngôn ngữ SAA, "highly available"
và "elastic" luôn nghĩa là **scale out** (nhiều máy). Vertical scaling cần downtime
và có trần cứng — hầu như luôn là đáp án sai.

**"IMDSv1 vẫn ổn, có SG chặn rồi."** Security group không cứu được bạn: request
tới `169.254.169.254` phát ra **từ chính instance**, không đi qua SG.

**"Cooldown áp cho mọi scaling policy."** Không — target tracking và step scaling
dùng **warm-up** và scale out được ngay, không chờ cooldown.

## Nối với lab

[`../../learn-aws/labs/w03-ec2-alb-asg/`](../../learn-aws/labs/w03-ec2-alb-asg/)

Lab dựng đúng sơ đồ đầu bài: launch template → ASG (min 1 / desired 2 / max 3,
trải 2 AZ) → target group → ALB. Bạn sẽ thấy tận mắt:

| Khái niệm trong bài | Quan sát gì khi chạy lab |
|---|---|
| **`health_check_type = ELB`** | `ansible-playbook chaos.yml` phá `/health` nhưng **để nginx và máy vẫn sống**. EC2 status check vẫn xanh. Chỉ health check của ELB phát hiện. Đây là toàn bộ lý do lab tồn tại |
| **Thời gian phát hiện hỏng** | `interval 10s × threshold 2` ≈ 20 giây. Ghi lại mốc thời gian từ `healthy` → `unhealthy` → terminate → máy mới `InService` |
| **SG tham chiếu SG** | `referenced_security_group_id` thay vì `cidr_ipv4` — vì IP của ALB đổi liên tục, không viết CIDR được |
| **user data so với Ansible** | user data lo bootstrap cho máy sinh ra lúc 3 giờ sáng; Ansible lo thay đổi sau đó. `serial: 1` là rolling update thủ công |
| **Cross-zone** | Refresh trang liên tục, thấy instance ID đổi luân phiên giữa 2 AZ |
| **Snapshot + `delete_on_termination`** | Snapshot, xoá volume, restore lại. Để `delete_on_termination = false` là volume sống mãi và tính tiền mãi — `find-orphans.sh` quét đúng thứ này |
| **IMDSv2** | Launch template đặt `http_tokens = required`; gọi metadata không kèm token để thấy 401 |

Đây là buổi **tốn tiền nhất cả khoá** (~$0,053/giờ, chủ yếu do ALB). Đặt hẹn giờ
3 tiếng ngay khi `terraform apply` xong.

## Tự kiểm tra

<details>
<summary>1. Một ASG có 2 máy trải 2 AZ đứng sau ALB. Bạn `kill -9` nginx trên một máy. ASG không làm gì. Vì sao?</summary>

`health_check_type` đang là `EC2` (mặc định). EC2 status check chỉ kiểm tra máy có
boot được và network có thông không — cả hai vẫn đúng khi nginx chết. Đổi sang
`ELB` thì ASG mới dùng kết quả health check của target group, tức là mới biết
**ứng dụng** đã chết. Trong lúc đó ALB vẫn hoạt động đúng: nó ngừng gửi traffic
tới máy hỏng, nhưng nó không có quyền thay máy — đó là việc của ASG.
</details>

<details>
<summary>2. Vì sao gp3 rẻ hơn gp2 cho cùng một khối lượng công việc, dù giá mỗi GB chỉ thấp hơn 20%?</summary>

Vì gp2 buộc IOPS đi kèm dung lượng (3 IOPS/GiB). Cần 3.000 IOPS với gp2 nghĩa là
phải mua 1.000 GiB, dù dữ liệu chỉ 20 GiB. gp3 cho 3.000 IOPS baseline miễn phí ở
mọi kích thước, nên bạn mua 20 GiB là đủ. Tiết kiệm thật đến từ chỗ không phải mua
dung lượng thừa, không phải từ giá mỗi GB.
</details>

<details>
<summary>3. Ứng dụng của bạn có lỗ hổng SSRF. Vì sao IMDSv2 cứu được bạn, còn security group thì không?</summary>

Request tới `169.254.169.254` phát ra từ chính bên trong instance — nó là link-local
address, không rời khỏi máy, không đi qua security group hay NACL. IMDSv2 chặn ở
tầng khác: bắt buộc `PUT` để lấy token trước, kèm header tuỳ biến. Phần lớn SSRF
chỉ khiến server phát `GET` với URL do kẻ tấn công kiểm soát, không phát được
`PUT` kèm header — nên chuỗi tấn công đứt ngay bước đầu.
</details>

<details>
<summary>4. Đề: "Ứng dụng cần IP tĩnh để khách hàng whitelist trên firewall của họ, và xử lý cả TCP lẫn UDP." Chọn gì?</summary>

**NLB**, gán Elastic IP cho mỗi AZ. ALB bị loại vì hai lý do: chỉ có DNS name (IP
đổi liên tục) và chỉ hiểu HTTP/HTTPS/gRPC, không có UDP. Nếu đề đồng thời cần
routing theo path, kiến trúc đúng là **NLB đứng trước, ALB làm target của NLB** —
NLB giữ IP tĩnh, ALB lo routing layer 7.
</details>

<details>
<summary>5. Bạn có 3 node etcd. Đặt vào cluster placement group hay spread placement group?</summary>

**Spread.** Cluster nhồi các máy sát nhau trong cùng một AZ để tối ưu latency —
đúng cho HPC, sai chết người cho quorum, vì một sự cố rack có thể hạ cả ba node
cùng lúc và mất quorum. Spread đảm bảo mỗi instance nằm trên một rack riêng biệt
(tối đa 7 máy chạy mỗi AZ mỗi group), đúng với mục tiêu "vài máy quan trọng không
được cùng chết".
</details>

<details>
<summary>6. Bạn snapshot volume vào thứ Hai, thứ Ba, thứ Tư. Xoá snapshot thứ Hai. Snapshot thứ Tư còn restore được không?</summary>

Có, đầy đủ. Snapshot incremental chỉ tiết kiệm ở tầng lưu trữ, không tạo ràng buộc
ở tầng logic. Khi xoá một snapshot, AWS chỉ thật sự xoá những block mà **không
snapshot nào khác còn tham chiếu**; block nào vẫn cần cho thứ Ba hay thứ Tư thì
được giữ lại. Mọi snapshot luôn là một bản khôi phục hoàn chỉnh.
</details>

<details>
<summary>7. Một máy trong ASG nhận gấp bốn lần request so với máy khác dù cấu hình y hệt. Hai nguyên nhân khả dĩ nhất?</summary>

(a) **Sticky session** đang bật và client phân bố không đều — tệ nhất là một NAT
của khách hàng lớn bám dính đúng máy đó. (b) **Cross-zone** đang tắt và số target
giữa các AZ lệch nhau, nên node ELB ở AZ ít máy dồn tải lên chúng. Sửa (a) đúng
cách là đưa session ra ElastiCache/DynamoDB rồi tắt sticky.
</details>

<details>
<summary>8. Đề: "Xử lý ảnh, mỗi job 10 phút, chạy lại được nếu lỗi, chi phí thấp nhất." Chọn mô hình mua nào và cần thiết kế thêm gì?</summary>

**Spot** — giảm tới 90%, và "chạy lại được nếu lỗi" chính là điều kiện cần. Thiết
kế thêm: nghe **Spot interruption notice (2 phút)** và **rebalance recommendation**
qua EventBridge hoặc instance metadata, checkpoint kết quả dở dang ra S3, và đẩy
job về lại SQS để máy khác nhặt. Bật **Capacity Rebalancing** trên ASG để AWS chủ
động thay máy sắp bị thu hồi.
</details>

<details>
<summary>9. Vì sao đặt health check grace period quá ngắn lại tốn tiền hơn là để mặc định?</summary>

user data cần thời gian để `dnf install nginx` và khởi động dịch vụ. Grace period
ngắn hơn thời gian đó thì ASG gọi health check khi ứng dụng chưa sẵn sàng, thấy
fail, terminate, sinh máy mới, lặp lại y hệt. Bạn được vòng lặp launch/kill vô tận:
trả tiền cho hàng chục instance-hour mà không phút nào phục vụ được request.
</details>

## Ngoài phạm vi

- **EC2 Fleet / Spot Fleet chi tiết, allocation strategy** — biết ASG có mixed
  instances policy là đủ. [Tài liệu](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-fleet.html)
- **Nitro Enclaves, bare metal, EC2 hibernate, EBS io2 latency tuning** — chuyên sâu.
- **Elastic Fabric Adapter (EFA), enhanced networking chi tiết** — chỉ cần biết
  cluster placement group phục vụ HPC. [Tài liệu](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html)
- **ALB advanced request routing, Lambda@Edge, mTLS trên ALB** — tuần 8 chạm tới
  phần edge; phần còn lại ngoài phạm vi.
- **Warm pool của ASG** — biết nó tồn tại để rút ngắn thời gian scale out là đủ.
  [Tài liệu](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-warm-pools.html)
- **FSx for Lustre / NetApp ONTAP / OpenZFS chi tiết** — chỉ cần nhận diện use case.

## Nguồn

- [Amazon EBS volume types](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volume-types.html)
- [General Purpose SSD volumes (gp2, gp3)](https://docs.aws.amazon.com/ebs/latest/userguide/general-purpose.html)
- [Amazon EBS Multi-Attach](https://docs.aws.amazon.com/ebs/latest/userguide/ebs-volumes-multi.html)
- [Placement groups for your Amazon EC2 instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html)
- [Placement strategies for your placement groups](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-strategies.html)
- [Amazon EC2 instance type naming conventions](https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html)
- [Configure instance metadata options for new instances (IMDSv2)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-IMDS-new-instances.html)
- [EC2 instance rebalance recommendations](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/rebalance-recommendations.html)
- [Choosing a purchasing option for Amazon EC2](https://docs.aws.amazon.com/decision-guides/latest/decision-guides/ec2-purchasing-options-aws-how-to-choose.html)
- [Scaling cooldowns for Amazon EC2 Auto Scaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scaling-cooldowns.html)
- [Set the default instance warmup for an Auto Scaling group](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-default-instance-warmup.html)
- [Amazon EC2 Auto Scaling lifecycle hooks](https://docs.aws.amazon.com/autoscaling/ec2/userguide/lifecycle-hooks.html)
- [Elastic Load Balancing features](https://aws.amazon.com/elasticloadbalancing/features/)
- [Features of Amazon EFS](https://docs.aws.amazon.com/efs/latest/ug/features.html)
- [Amazon EFS FAQs](https://aws.amazon.com/efs/faq/)
