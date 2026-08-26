# Storage

> **Tra nhanh:** chọn S3 / EBS / EFS / FSx nào, lớp lưu trữ nào, và tiền chảy đi
> đâu khi bạn chọn sai.

`Domain 1 · Design Secure Architectures (30% đề)` · `Domain 2 · Design Resilient Architectures (26%)` · `Domain 3 · Design High-Performing Architectures (24%)` · `Domain 4 · Design Cost-Optimized Architectures (20%)`

Tuần 4 ([`../aws/w04-s3-cloudfront.md`](../aws/w04-s3-cloudfront.md)) dạy đủ để làm
lab; file này đi sâu hơn: cơ chế, ngưỡng hoà vốn, và những chỗ nguồn ôn thi đã lỗi thời.
Phần compute đi kèm ở [`01-compute.md`](01-compute.md).

## Bản đồ

| Mục | Đọc khi bạn cần |
|---|---|
| [Consistency model](#1-consistency-model--mục-bị-dạy-sai-nhiều-nhất) | Đề nói "sau khi ghi phải đọc ngay được" |
| [Prefix và giới hạn request](#2-bucket-key-prefix-và-trần-request-thật) | "S3 trả 503 Slow Down", "tối ưu hiệu năng S3" |
| [Storage class](#3-storage-class--bảng-và-ngưỡng-hoà-vốn) | Chọn lớp, tính ngưỡng hoà vốn, phí truy hồi |
| [Lifecycle](#4-lifecycle--những-quy-tắc-ngầm) | Tự động hạ tầng lưu trữ, dọn version cũ, dọn upload dở |
| [Versioning](#5-versioning-delete-marker-mfa-delete) | Chống xoá nhầm, "bucket not empty" |
| [Replication](#6-replication-crr-và-srr) | DR đa region, gom log, compliance |
| [Mã hoá](#7-mã-hoá-s3) | SSE-S3 / SSE-KMS / SSE-C / DSSE, bucket key, KMS throttle |
| [Kiểm soát truy cập](#8-kiểm-soát-truy-cập) | BPA, bucket policy, access point, presigned URL |
| [Hiệu năng truyền](#9-multipart-transfer-acceleration-byte-range) | Upload/download file lớn, người dùng ở xa |
| [Object Lock và các tính năng còn lại](#10-object-lock-s3-select-event-notification-requester-pays) | WORM, compliance, sự kiện, ai trả tiền |
| [EBS](#11-ebs--chọn-loại-volume) | Chọn gp3/io2/st1/sc1, IOPS, throughput, resize nóng |
| [EBS snapshot](#12-ebs-snapshot--incremental-archive-fsr) | Backup, DR, chi phí snapshot |
| [Instance store](#13-instance-store) | "ephemeral", "IOPS cao nhất" |
| [EFS](#14-efs) | Nhiều EC2 cùng đọc ghi một thư mục |
| [FSx](#15-fsx--bốn-biến-thể) | Windows/SMB, HPC/Lustre, NetApp, ZFS |
| [Storage Gateway và AWS Backup](#16-storage-gateway-và-aws-backup) | Hybrid, backup tập trung, tuân thủ |
| [Bảng số phải nhớ](#bảng-số-phải-nhớ) · [Bẫy đề thi](#bẫy-đề-thi) | Ôn trước giờ thi |

---

## 1. Consistency model — mục bị dạy sai nhiều nhất

**Từ tháng 12/2020, S3 cho strong read-after-write consistency ở mọi region, cho mọi
request, không tốn thêm tiền, không phải bật gì.** Cụ thể:

- `PUT` một key mới rồi `GET` ngay → nhận được dữ liệu.
- `PUT` đè lên key đã có rồi `GET` ngay → nhận dữ liệu **mới**.
- `DELETE` rồi `GET` ngay → **404**.
- **`LIST` cũng strongly consistent.** Ghi xong list ngay là thấy.
- Đọc ACL, object tag, và `HEAD` metadata cũng strongly consistent.

Đây là chỗ **gần như mọi bộ đề luyện SAA cũ và bản thân `aws-saa-c03/` đều sai**. Câu
"S3 là eventually consistent, phải chờ vài giây, phải retry" viết trước 12/2020. Nếu
đề SAA-C03 hỏi, đáp án là **strong read-after-write**, và đáp án "thêm retry với
exponential backoff để chờ dữ liệu xuất hiện" là bẫy.

Ba ngoại lệ vẫn còn, và chúng mới là thứ đáng nhớ:

- **Cấu hình ở mức bucket vẫn eventually consistent.** Xoá bucket rồi `ListBuckets`
  ngay có thể vẫn thấy; đổi bucket policy hay lifecycle rule cần thời gian lan truyền.
  AWS khuyến nghị **chờ 15 phút** sau khi bật versioning lần đầu trước khi ghi.
- **Không có locking cho concurrent writer.** Hai `PUT` đồng thời vào cùng một key →
  **last writer wins**. Cần khoá thì xây ở tầng ứng dụng, hoặc dùng **conditional
  write** (`If-None-Match: *` để chỉ ghi khi key chưa tồn tại).
- **Replication vẫn bất đồng bộ.** Strong consistency chỉ áp trong một bucket; bucket
  đích của CRR có thể chưa thấy object vừa ghi — RTC cũng chỉ là SLA 15 phút.

---

## 2. Bucket, key, prefix, và trần request thật

**Không có thư mục trong S3.** `logs/2026/08/a.txt` là một key duy nhất; `/` chỉ là ký
tự, console vẽ thư mục bằng `ListObjectsV2` với `delimiter=/`. **Prefix không phải thư
mục, mà là đơn vị phân vùng**: S3 tự chia bucket thành partition theo tiền tố key, và
mỗi partition chịu được:

- **3.500 request/giây** cho `PUT`, `COPY`, `POST`, `DELETE`
- **5.500 request/giây** cho `GET`, `HEAD`
- **Không giới hạn số prefix.** 10 prefix song song → 55.000 GET/giây.

Cơ chế đáng nhớ: khi tải tăng đều, **S3 tự tách partition**. Trong lúc tách, bạn nhận
**HTTP 503 Slow Down** — đây là tín hiệu "đang mở rộng", không phải lỗi vĩnh viễn. Cách
đúng là retry với exponential backoff và tăng tải dần, không nhảy thẳng lên đỉnh.

> **Lời khuyên "băm ngẫu nhiên tiền tố key để tăng hiệu năng" đã lỗi thời.** AWS bỏ nó
> từ 2018. Bạn được phép đặt tên key theo thứ tự logic (ngày tháng, ID tăng dần). Nếu
> đề đưa đáp án "thêm hash 4 ký tự vào đầu key để tránh hotspot", đó là bẫy tài liệu cũ.
> Cách đúng khi cần vượt trần: **chia dữ liệu ra nhiều prefix có ý nghĩa** và đọc song song.

Vài con số về kích thước, và ở đây nguồn ôn thi cũng đã lỗi thời:

| | Giá trị |
|---|---|
| Object tối đa | **50 TB** (chính xác 48,8 TiB = 10.000 part × 5 GiB) |
| Upload bằng một `PUT` | **5 GB** |
| Upload qua console | 160 GB |
| Số bucket mỗi account | **10.000** mặc định, xin tăng tới **1 triệu** |
| Số object mỗi bucket | Không giới hạn |
| Metadata do người dùng đặt | 2 KB |

Con số "5 TB" mà mọi cheat sheet dạy là trần cũ. Cơ chế đằng sau con số mới rất dễ
nhớ: **10.000 part, mỗi part tối đa 5 GiB**.

---

## 3. Storage class — bảng và ngưỡng hoà vốn

| Storage class | Availability (thiết kế) | Số AZ | Lưu tối thiểu | Kích thước tính tiền tối thiểu | Lấy ra | Phí lấy ra |
|---|---|---|---|---|---|---|
| **S3 Standard** | 99,99% | ≥ 3 | — | — | Tức thì | Không |
| **S3 Intelligent-Tiering** | 99,9% | ≥ 3 | — | — | Tức thì (2 tầng archive cần restore) | **Không**, nhưng có phí monitoring/object |
| **S3 Express One Zone** | 99,95% | **1** | — | — | **Một chữ số ms** | Không (giá request thấp hơn 50%) |
| **S3 Standard-IA** | 99,9% | ≥ 3 | **30 ngày** | **128 KB** | Tức thì | **Có** |
| **S3 One Zone-IA** | **99,5%** | **1** | **30 ngày** | **128 KB** | Tức thì | **Có** |
| **S3 Glacier Instant Retrieval** | 99,9% | ≥ 3 | **90 ngày** | **128 KB** | **Tức thì** | Có |
| **S3 Glacier Flexible Retrieval** | 99,99% (sau restore) | ≥ 3 | **90 ngày** | +40 KB metadata | **Phải restore** | Có |
| **S3 Glacier Deep Archive** | 99,99% (sau restore) | ≥ 3 | **180 ngày** | +40 KB metadata | **Phải restore** | Có |

**Mọi lớp đều 11 số 9 durability (99,999999999%).** Khác nhau nằm ở **availability** và
**số AZ**. One Zone-IA vẫn 11 số 9, nhưng nếu AZ đó biến mất thì dữ liệu biến mất theo —
11 số 9 nói về xác suất mất bit, không nói về việc mất cả một data center. Đây là chỗ
đề thi đánh lừa thường xuyên nhất.

### Thời gian restore

| | Expedited | Standard | Bulk |
|---|---|---|---|
| **Glacier Flexible Retrieval** | **1–5 phút** | **3–5 giờ** | **5–12 giờ** (miễn phí) |
| **Glacier Deep Archive** | Không có | **trong 12 giờ** | **trong 48 giờ** |

Restore tạo một **bản sao tạm** ở S3 Standard trong số ngày bạn chỉ định — object gốc
vẫn ở Glacier và bạn trả tiền cho **cả hai**. Muốn đưa hẳn về lớp nóng thì `COPY` đè
lên chính nó sau khi restore.

### Ngưỡng hoà vốn — phần cheat sheet không bao giờ dạy

Giá us-east-1, tháng 08/2026, dùng để **lập luận** chứ không phải để nhớ tuyệt đối
(kiểm tra lại trang pricing trước khi tin):

| Lớp | Lưu ($/GB-tháng) | Lấy ra ($/GB) |
|---|---|---|
| Standard | ~0,023 | 0 |
| Standard-IA | ~0,0125 | ~0,01 |
| One Zone-IA | ~0,010 | ~0,01 |
| Glacier Instant Retrieval | ~0,004 | ~0,03 |
| Glacier Flexible Retrieval | ~0,0036 | ~0,01 (Standard tier) |
| Glacier Deep Archive | ~0,00099 | ~0,02 |

Cách tính hoà vốn Standard so với Standard-IA cho 1 GB trong một tháng:

```
Standard      = 0,023
Standard-IA   = 0,0125 + 0,01 × (số GB được đọc trong tháng)
hoà vốn khi     0,0125 + 0,01 × x = 0,023   →   x ≈ 1,05
```

Nghĩa là: **đọc hết object đó nhiều hơn khoảng một lần mỗi tháng thì Standard-IA đắt
hơn Standard.** Đây là lý do "infrequent" trong đề luôn có nghĩa cụ thể — *dưới một
lần mỗi tháng*, không phải "cảm giác ít dùng".

Ba ngưỡng nữa nên nhớ dạng ý niệm: **object dưới 128 KB không nên vào IA hay Glacier
IR** (bị tính đủ 128 KB — file 20 KB tốn gấp 6 lần dung lượng thật); **Glacier Flexible
và Deep Archive tính thêm 40 KB metadata mỗi object** (32 KB ở giá Glacier + 8 KB ở giá
Standard), nên một triệu file nhỏ có thể tốn hơn cả dữ liệu; và **xoá sớm vẫn trả đủ** —
vào Glacier rồi xoá sau 10 ngày là trả tiền đủ 90 ngày.

### Intelligent-Tiering — khi nào nó thắng

Ba tầng tự động, không cần cấu hình, **không có phí truy hồi**:

| Tầng | Chuyển vào khi | Truy cập |
|---|---|---|
| Frequent Access | Mặc định khi upload | Tức thì |
| Infrequent Access | **30 ngày** không truy cập | Tức thì |
| Archive Instant Access | **90 ngày** không truy cập | Tức thì |
| *Archive Access* (tuỳ chọn) | ≥ 90 ngày, **phải bật** | Phải restore |
| *Deep Archive Access* (tuỳ chọn) | ≥ 180 ngày, **phải bật** | Phải restore |

Đổi lại là **phí monitoring theo từng object** (~$0,0025 mỗi 1.000 object/tháng). Hai
kết luận thực dụng: **object dưới 128 KB không được monitor** và luôn ở tầng Frequent
Access, nên bucket toàn file nhỏ chỉ tốn thêm tiền; và đề nói **"không biết access
pattern"** → luôn là Intelligent-Tiering, còn đề nói **"biết chắc 30 ngày nóng rồi
lạnh"** → **lifecycle rule rẻ hơn** vì không mất phí monitoring.

**S3 Express One Zone** là lớp mới, nằm trong **directory bucket** (kiểu bucket khác,
tên khác, không hỗ trợ mọi tính năng của general purpose bucket). Nó cho độ trễ một
chữ số mili giây và giá request thấp hơn 50%, đổi lại giá lưu trữ cao hơn nhiều và chỉ
một AZ. Ở mức SAA chỉ cần nhận ra từ khoá **"single-digit millisecond", "hàng trăm
nghìn request/giây", "chấp nhận một AZ"**.

---

## 4. Lifecycle — những quy tắc ngầm

Một rule gồm **bộ lọc** (prefix, tag, kích thước) và các **hành động**:

| Hành động | Nghĩa |
|---|---|
| `Transition` | Chuyển **current version** sang class khác sau N ngày |
| `NoncurrentVersionTransition` | Chuyển **version cũ** sang class khác |
| `Expiration` | Xoá current version (bucket có versioning → **đặt delete marker**) |
| `NoncurrentVersionExpiration` | **Xoá hẳn** version cũ sau N ngày |
| `AbortIncompleteMultipartUpload` | Dọn part upload dở dang |
| `ExpiredObjectDeleteMarker` | Dọn delete marker mồ côi |

Sáu quy tắc ngầm, mỗi cái đều từng làm ai đó mất tiền:

**Một — lifecycle chỉ đi một chiều, theo thứ tự lạnh dần:**
`Standard → Standard-IA / One Zone-IA → Glacier IR → Glacier Flexible → Deep Archive`.
Không có transition ngược. Muốn đi lên phải **restore rồi copy**.

**Hai — 30 ngày tối thiểu ở Standard trước khi sang IA.** Rule đặt `days: 10` sang
Standard-IA sẽ không chạy.

**Ba — từ tháng 09/2024, mặc định lifecycle KHÔNG chuyển object dưới 128 KB sang bất kỳ
lớp nào.** Trước đó nó vẫn chuyển được sang Glacier Flexible và Deep Archive. Lý do
AWS đổi: mỗi transition tính một request, nên với file nhỏ **phí chuyển vượt tiền tiết
kiệm**. Muốn ép chuyển thì thêm bộ lọc `ObjectSizeGreaterThan`/`ObjectSizeLessThan`.
Cấu hình tạo trước 09/2024 giữ hành vi cũ **cho tới khi bạn sửa nó** — sửa một rule là
cả configuration đổi sang hành vi mới. Đây là chi tiết chưa cheat sheet nào cập nhật.

**Bốn — chuyển vào lớp có thời gian lưu tối thiểu rồi xoá sớm thì vẫn bị tính đủ.**
Lifecycle đưa object sang Glacier ngày 1 rồi expire ngày 30 → bạn trả tiền 90 ngày.

**Năm — tiền được tính ngay khi rule thoả, dù việc chuyển là bất đồng bộ.** Với Glacier
và Deep Archive, cả 40 KB metadata lẫn đồng hồ thời gian lưu tối thiểu bắt đầu chạy
ngay lúc đó. Ngoại lệ: chuyển sang Intelligent-Tiering thì tính tiền sau khi chuyển xong.

**Sáu — ba khoản tiền âm thầm mà lifecycle dọn hộ:** **version cũ** (không có
`NoncurrentVersionExpiration` thì mỗi lần ghi đè là thêm một bản lưu vĩnh viễn);
**multipart upload dở dang** — part đã tải lên **không hiện trong `ListObjects`** nhưng
**vẫn tính tiền**, nên đặt `AbortIncompleteMultipartUpload` 7 ngày cho **mọi** bucket;
và **delete marker mồ côi** còn lại sau khi mọi version đã bị xoá.

---

## 5. Versioning, delete marker, MFA Delete

Bật ở mức bucket. **Bật rồi không tắt được**, chỉ **suspend** — và suspend không xoá
version cũ, chỉ ngừng tạo version mới (version mới sẽ có ID là `null`).

```
Trước:   key=index.html  → [v3 current] [v2] [v1]
DELETE:  key=index.html  → [delete marker ← current] [v3] [v2] [v1]
                            ↑ 0 byte, không chứa dữ liệu
```

- Object biến mất khỏi `ListObjects`, `GET` trả **404**.
- **Không có gì bị xoá.** v1, v2, v3 còn nguyên và **vẫn tính tiền**.
- Khôi phục = **xoá delete marker** (`DeleteObject` kèm `versionId` của marker).
- Xoá thật = `DeleteObject` kèm `versionId` của từng version.

Đây là lý do bucket "đã xoá hết file" vẫn báo *bucket not empty*, và là lý do Terraform
cần `force_destroy = true`.

**MFA Delete** yêu cầu thiết bị MFA để (a) xoá vĩnh viễn một version và (b) suspend
versioning. Ba chi tiết ra thi: chỉ **root user của account sở hữu bucket** bật/tắt
được, chỉ bật được qua **CLI/API** (không có trong console), và cần versioning bật trước.

Phân biệt với Object Lock: MFA Delete chống **xoá do nhầm lẫn hoặc do tài khoản bị
chiếm quyền**. Đề nói **tuân thủ pháp lý, WORM, không ai được xoá kể cả root** →
**Object Lock**, không phải MFA Delete.

---

## 6. Replication CRR và SRR

**Điều kiện bắt buộc:** versioning bật ở **cả hai** bucket, và một IAM role cho S3
đọc nguồn ghi đích. Thiếu một trong hai thì replication không cấu hình được.

| | **CRR** (khác region) | **SRR** (cùng region) |
|---|---|---|
| Dùng cho | DR, giảm latency cho người dùng ở xa, tuân thủ về vị trí dữ liệu | Gom log nhiều bucket về một chỗ, đồng bộ prod → test, đổi quyền sở hữu account |

Những gì **không** được nhân bản — danh sách này ra thi: **object đã có trước khi bật
rule** (phải chạy **S3 Batch Replication** riêng); **object được nhân bản từ bucket
khác** (replication không tự nối chuỗi `A → B → C`); **object mã hoá SSE-C**; **thao
tác xoá kèm `versionId` cụ thể** (cố ý, để kẻ tấn công xoá ở nguồn không xoá được ở
đích); và **delete marker** (mặc định tắt, bật `DeleteMarkerReplication` nếu muốn).

Ba tính năng ra thi: **Replication Time Control (RTC)** — SLA nhân bản **99,99% object
trong 15 phút**, kèm metric CloudWatch, có tính thêm tiền, là đáp án cho "RPO xác định
được"; **đổi storage class ở đích** để bản DR rẻ hơn; **owner override** khi nhân bản
cross-account.

---

## 7. Mã hoá S3

**Từ 05/01/2023, mọi object mới đều được mã hoá at-rest bằng SSE-S3 theo mặc định.**
Câu hỏi "làm sao đảm bảo dữ liệu S3 được mã hoá at-rest" ngày nay có đáp án "nó đã được
mã hoá rồi"; câu hỏi thật sự là **ai giữ khoá và ai audit được**.

| | **SSE-S3** | **SSE-KMS** | **DSSE-KMS** | **SSE-C** | **Client-side** |
|---|---|---|---|---|---|
| Ai giữ khoá | AWS, hoàn toàn | **Bạn**, qua KMS | Bạn, qua KMS | **Bạn**, gửi kèm mỗi request | Bạn, ngoài AWS |
| Header | `AES256` | `aws:kms` | `aws:kms:dsse` | `aws:kms` + khoá | — |
| Audit từng lần dùng khoá | Không | **Có** (CloudTrail) | Có | Không | Không |
| Xoay khoá, chính sách khoá, thu hồi | Không | **Có** | Có | Bạn tự lo | Bạn tự lo |
| Chi phí thêm | **0** | Phí KMS request + key/tháng | Gấp đôi phí KMS | 0 | 0 |
| Ràng buộc | — | **Bị KMS throttle** | Không dùng được S3 Bucket Key | **Bắt buộc HTTPS**, AWS không lưu khoá | Bạn tự quản lý mất khoá |

**KMS throttle là bẫy hiệu năng ra thi.** Mỗi `GET` hay `PUT` với SSE-KMS sinh một lệnh
gọi `Decrypt`/`GenerateDataKey` tới KMS, và KMS có quota request theo region. Workload
đọc hàng nghìn object mỗi giây sẽ bị `ThrottlingException`. Hai cách chữa:

- **S3 Bucket Key** — S3 xin một khoá cấp bucket từ KMS rồi tự sinh data key cho từng
  object trong một khoảng thời gian. **Giảm tới 99% số request tới KMS**, và giảm chi
  phí tương ứng. Bật bằng một tick, không đổi gì phía client. **Không dùng được với
  DSSE-KMS.**
- Xin tăng quota KMS.

Bắt buộc mã hoá bằng bucket policy — chỗ này hay ra thi ở dạng "viết policy":

```json
{
  "Effect": "Deny",
  "Principal": "*",
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::my-bucket/*",
  "Condition": {
    "StringNotEquals": { "s3:x-amz-server-side-encryption": "aws:kms" }
  }
}
```

Ép TLS thì dùng `"Bool": {"aws:SecureTransport": "false"}` với `Effect: Deny` — đây là
cách duy nhất bắt buộc mã hoá **in transit**, vì S3 chấp nhận cả HTTP.

**SSE-C:** bạn gửi khoá trong header mỗi request; AWS dùng nó để mã hoá rồi **vứt khoá
đi**, chỉ giữ HMAC để kiểm tra lần sau. Mất khoá là mất dữ liệu vĩnh viễn. Bắt buộc
HTTPS. Chọn khi đề nói **"khoá không được rời khỏi tổ chức của khách hàng"** nhưng vẫn
muốn AWS làm việc mã hoá.

---

## 8. Kiểm soát truy cập

| Cơ chế | Loại | Gắn vào | Dùng khi |
|---|---|---|---|
| **IAM policy** | Identity-based | User, group, role | Cấp quyền cho principal **trong account của bạn** |
| **Bucket policy** | Resource-based | Bucket | **Cross-account**, service principal (CloudFront, CloudTrail), điều kiện theo IP/VPCE/TLS |
| **ACL** | Cơ chế trước IAM | Bucket và **từng object** | Gần như không còn dùng — mặc định của bucket mới là `Bucket owner enforced`, **ACL bị tắt** |
| **Block Public Access** | Chốt chặn | Bucket **và** account | **Bật mặc định cho bucket mới.** Nó **ghi đè** mọi policy/ACL cố mở public |

Bốn cờ của Block Public Access chia làm hai cặp: hai cờ chặn *việc tạo ra* cấu hình
public (`BlockPublicAcls`, `BlockPublicPolicy`), hai cờ *vô hiệu hoá* cấu hình public
đã có (`IgnorePublicAcls`, `RestrictPublicBuckets`). Bật cả bốn ở mức **account** là
đáp án cho "ngăn bất kỳ ai vô tình mở public bucket trong toàn tổ chức".

Muốn phục vụ nội dung public thì **không** tắt BPA — đặt **CloudFront + Origin Access
Control (OAC)** trước bucket, và bucket policy chỉ cho service principal của CloudFront
đọc, kèm điều kiện `AWS:SourceArn` là ARN của distribution.

**S3 Access Point** — mỗi access point là một hostname riêng với policy riêng, trỏ vào
cùng một bucket. Giải quyết bài toán một bucket dùng chung cho nhiều đội mà bucket
policy phình lên tới trần 20 KB. Access point còn khoá được vào một VPC
(`NetworkOrigin: VPC`) — cách sạch nhất để nói "chỉ truy cập từ trong VPC này".

**Presigned URL** — bạn ký một URL bằng credential của mình, người nhận dùng mà không
cần tài khoản AWS. Hai điều phải nhớ. **URL mang đúng quyền của người ký**: ký bằng
role không có `s3:GetObject` thì URL vô dụng; ký bằng admin là phát ra quyền admin trên
object đó cho bất kỳ ai cầm URL. **Hạn dùng** tối đa **7 ngày** khi ký bằng credential
của IAM user với SigV4; ký bằng **credential tạm** (role, STS, instance profile) thì
URL **chết cùng credential**, dù bạn đặt `--expires-in` dài hơn — URL ký trên EC2 bằng
instance profile thường chỉ sống ~6 giờ.

Presigned URL dùng được cả cho `PUT` — đó là cách đúng để người dùng upload thẳng vào
S3 mà không đi qua server của bạn.

---

## 9. Multipart, Transfer Acceleration, byte-range

| Kỹ thuật | Giải quyết vấn đề | Con số |
|---|---|---|
| **Multipart upload** | File lớn, mạng chập chờn, muốn upload song song | Khuyến nghị từ **100 MB**, **bắt buộc trên 5 GB**. 10.000 part, mỗi part **5 MiB – 5 GiB** (part cuối được nhỏ hơn) |
| **Byte-range fetch** | Tải song song, hoặc chỉ cần một phần file | Gửi header `Range:`. Dùng để đọc header của file lớn mà không tải cả file |
| **Transfer Acceleration** | Người dùng ở **xa** region của bucket | Đi vào **edge location** của CloudFront rồi qua đường trục AWS. Endpoint riêng `bucket.s3-accelerate.amazonaws.com`. **Tính thêm tiền**, và chỉ đáng dùng khi khoảng cách địa lý lớn |

Multipart còn một tác dụng ít ai nhắc: **retry từng part**. Đứt mạng ở part 900/1000
thì chỉ tải lại part đó. Đổi lại là rủi ro để lại part mồ côi tính tiền — xem
`AbortIncompleteMultipartUpload` ở mục lifecycle. Với Transfer Acceleration, AWS có
công cụ **Speed Comparison** để đo trước; client và bucket cùng region thì câu trả lời
gần như luôn là "không nhanh hơn, mà đắt hơn".

---

## 10. Object Lock, S3 Select, Event Notification, Requester Pays

### Object Lock — WORM

**Phải bật lúc tạo bucket** (bật sau cần mở ticket với AWS Support), và cần versioning.

| Mode | Ai vượt qua được | Dùng cho |
|---|---|---|
| **Governance** | Người có quyền `s3:BypassGovernanceRetention` | Chống xoá nhầm, vẫn có đường thoát |
| **Compliance** | **Không ai, kể cả root account** | SEC 17a-4, FINRA, quy định pháp lý thật sự |

Hai cách khoá, dùng độc lập hoặc chồng nhau: **Retention period** (khoá tới một ngày
cụ thể) và **Legal hold** (khoá vô thời hạn tới khi ai đó có quyền gỡ). Object Lock áp
cho **từng version**, không phải cả bucket. Từ khoá đề: **"WORM", "immutable", "không
được xoá kể cả admin", "regulatory"** → Compliance; **"chống xoá nhầm nhưng admin vẫn
sửa được"** → Governance.

### S3 Select và các cách truy vấn

**S3 Select** chạy `SELECT ... WHERE` trên **một object** CSV/JSON/Parquet và chỉ trả
phần khớp — giảm dữ liệu truyền và CPU phía client. Giới hạn: một object, SQL rất hẹp.
Đề nói **"truy vấn nhiều file, join, group by"** → **Athena**; đề nói **"lấy vài dòng
từ một file log lớn"** → S3 Select.

### Event Notification

Nguồn sự kiện: object created / removed / restored, replication, lifecycle, và
`ReducedRedundancyLostObject`. Đích:

| Đích | Khi nào |
|---|---|
| **SQS** | Cần đệm, cần retry, cần nhiều consumer đọc theo tốc độ của mình |
| **SNS** | Fan-out tới nhiều subscriber |
| **Lambda** | Xử lý ngay, không cần hạ tầng |
| **EventBridge** | Cần lọc phức tạp, cần archive/replay, cần gửi tới nhiều đích và cross-account |

Cấu hình gốc của S3 chỉ cho **một đích cho mỗi loại sự kiện chồng lấn** — đó là lý do
EventBridge tồn tại như lựa chọn thứ tư, và là câu trả lời cho *"nhiều hệ thống cùng
phản ứng với một sự kiện S3"*. Quyền: với SQS/SNS phải sửa **resource policy của
queue/topic** cho service principal `s3.amazonaws.com`; với Lambda thêm
`lambda:InvokeFunction`. Thiếu bước này là nguyên nhân số một của "notification không chạy".

### Requester Pays

Bật lên thì **người gọi trả phí request và egress**, chủ bucket chỉ trả tiền lưu trữ.
Người gọi phải gửi header `x-amz-request-payer: requester`, và **không cho phép truy
cập ẩn danh** — mọi request phải được ký. Đề nói **"chia sẻ dataset lớn cho cộng đồng
mà không muốn trả phí egress"** → Requester Pays.

---

## 11. EBS — chọn loại volume

| Loại | Kích thước | IOPS | Throughput | Boot | Ghi chú |
|---|---|---|---|---|---|
| **gp3** | 1 GiB – 64 TiB | baseline **3.000** (miễn phí), tới **80.000** ở tỉ lệ 500 IOPS/GiB | baseline **125 MiB/s**, tới **2.000 MiB/s** (0,25 MiB/s mỗi IOPS) | Có | **Mặc định.** Không có burst — giữ nguyên hiệu năng vô thời hạn |
| **gp2** | 1 GiB – 16 TiB | **3 IOPS/GiB**, min 100, max 16.000 (đạt ở 5.334 GiB) | 128–250 MiB/s theo dung lượng | Có | Burst 3.000 IOPS nếu < 1 TiB, bằng credit. Thế hệ cũ |
| **io2 Block Express** | 4 GiB – 64 TiB | tới **256.000** ở tỉ lệ **1.000 IOPS/GiB** (đạt ở 256 GiB) | tới **4.000 MiB/s** | Có | Latency trung bình **dưới 500 µs**. Độ bền **99,999%** |
| **io1** | 4 GiB – 16 TiB | tới **64.000** ở tỉ lệ 50 IOPS/GiB | tới 1.000 MiB/s | Có | Thế hệ cũ, độ bền 99,8–99,9% |
| **st1** | 125 GiB – 16 TiB | — (tối ưu cho I/O 1 MiB) | baseline **40 MiB/s mỗi TiB**, burst 250 MiB/s mỗi TiB, trần **500 MiB/s** | **Không** | Đọc ghi tuần tự lớn: log, EMR, ETL, data warehouse |
| **sc1** | 125 GiB – 16 TiB | — | baseline **12 MiB/s mỗi TiB**, burst 80 MiB/s mỗi TiB, trần **250 MiB/s** | **Không** | Rẻ nhất. Dữ liệu lạnh, truy cập hiếm |

Năm điều quan trọng hơn cả bảng:

**Một — gp3 tách hiệu năng khỏi dung lượng.** Với gp2, muốn 3.000 IOPS bạn phải mua
1.000 GiB dù chỉ dùng 20 GiB. gp3 cho 3.000 IOPS baseline miễn phí ở **mọi** kích
thước, và giá mỗi GiB còn thấp hơn gp2 **20%**. Đề hỏi "giảm chi phí storage mà giữ
nguyên hiệu năng" → **migrate gp2 sang gp3**, làm online, không downtime.

**Hai — "io2" và "io2 Block Express" không còn là hai thứ khác nhau.** Từ **30/04/2025,
mọi volume io2, cũ lẫn mới, đều là io2 Block Express.** Bảng nào còn ghi io2 = 64.000
IOPS còn io2 Block Express = 256.000 IOPS là bảng đã lỗi thời.

**Ba — độ bền khác nhau giữa các loại.** gp2/gp3/io1/st1/sc1 là **99,8–99,9%** (AFR ≤
0,2%); **io2 là 99,999%** (AFR ≤ 0,001%). Đề nhắc "durability cao nhất cho một volume
đơn" → io2.

**Bốn — HDD (st1, sc1) không boot được**, và chúng tính hiệu năng bằng **throughput
credit** giống gp2 chứ không phải IOPS. Đưa workload random I/O nhỏ vào st1 là cách
nhanh nhất để có một hệ thống chậm không hiểu vì sao.

**Năm — Elastic Volumes cho phép sửa nóng.** Đổi loại volume, **tăng** kích thước, đổi
IOPS/throughput ngay khi instance đang chạy. Không **giảm** được kích thước. Sau khi
tăng vẫn phải `growpart` + `resize2fs`/`xfs_growfs` trong OS thì mới thấy chỗ mới.

**Multi-Attach** chỉ có ở io1/io2: một volume gắn vào tối đa **16 instance Nitro trong
cùng một AZ**, tất cả đọc-ghi đầy đủ. Cái bẫy: **ext4, XFS, NTFS đều không dùng được** —
chúng không phối hợp lock giữa các host, ghi đồng thời là hỏng dữ liệu. Phải là
cluster-aware file system (GFS2, OCFS2) hoặc ứng dụng tự lo I/O fencing. Ở mức SAA:
"nhiều instance cùng đọc ghi một thư mục" gần như luôn là **EFS**.

**Mã hoá:** bật là mã hoá cả dữ liệu at-rest, dữ liệu đang đi giữa instance và volume,
mọi snapshot, và mọi volume tạo từ snapshot đó. Ảnh hưởng hiệu năng không đáng kể.
**Không mã hoá tại chỗ được** — muốn mã hoá volume chưa mã hoá: snapshot → copy
snapshot có bật encryption → tạo volume mới từ snapshot đã mã hoá. Bật
**EBS encryption by default** ở mức account+region để không phải nhớ nữa.

---

## 12. EBS snapshot — incremental, archive, FSR

Snapshot lưu trong S3 do AWS quản lý (bạn không thấy bucket) và có phạm vi **region**,
không khoá vào AZ. Đó là cách chuyển dữ liệu block sang AZ khác hay region khác.

```
Snap A (đầu)                  lưu: [1][2][3][4]
Snap B (sau khi sửa block 2)  lưu thêm: [2']  trỏ [1][3][4] về A
Snap C (sau khi sửa block 4)  lưu thêm: [4']  trỏ về A/B
```

> **Xoá Snap A KHÔNG làm hỏng Snap B.** Khi xoá một snapshot, AWS chỉ thật sự xoá
> những block **không snapshot nào khác còn tham chiếu**. Mọi snapshot còn lại vẫn
> restore được đầy đủ. Mỗi snapshot luôn là một bản khôi phục hoàn chỉnh về mặt logic.

| Tính năng | Cơ chế | Con số |
|---|---|---|
| **Snapshot Archive** | Chuyển sang tầng lưu trữ lạnh | Rẻ hơn ~75%; **lưu tối thiểu 90 ngày**; restore mất **24–72 giờ**; snapshot archive được lưu **dạng đầy đủ**, không còn incremental |
| **Fast Snapshot Restore (FSR)** | Nạp trước block để volume mới không bị chậm lần đọc đầu | Tính tiền theo **snapshot × AZ × giờ**, khá đắt. Có cơ chế **credit**: mỗi volume tạo ra tiêu 1 credit, bucket credit nạp lại theo `MIN(10, 1024 ÷ snapshot_GiB)` mỗi giờ |
| **Recycle Bin** | Giữ snapshot/AMI đã xoá trong một khoảng thời gian | Chống xoá nhầm ở tầng hạ tầng |
| **Data Lifecycle Manager (DLM)** | Tự động tạo, copy cross-region, và xoá snapshot theo lịch | Miễn phí, chỉ trả tiền snapshot |

Ba chi tiết SAA hay hỏi: restore tạo **volume mới**, có thể ở **AZ khác**, đổi loại
volume và **tăng** kích thước (không giảm), và snapshot **copy được sang region khác** —
nền của DR bằng backup; snapshot của volume đã mã hoá thì **bắt buộc được mã hoá** và
không gỡ được; snapshot bị bỏ quên **không hiện trong danh sách volume** nên là khoản
tiền âm thầm, cùng lớp với snapshot mồ côi sau khi deregister AMI (xem
[`01-compute.md`](01-compute.md#6-ami-và-vòng-đời-của-nó)).

---

## 13. Instance store

NVMe/SSD gắn thẳng vào host vật lý đang chạy instance. Hiệu năng cao nhất trong mọi
lựa chọn (hàng triệu IOPS trên `i` series), giá đã nằm trong giá instance.

Mất dữ liệu khi **stop**, **hibernate**, **terminate**, hoặc **host hỏng**; chỉ sống
sót qua **reboot**. Không snapshot được, không đổi kích thước được. Từ khoá đề:
**"ephemeral", "temporary", "scratch", "buffer", "cache", "IOPS cao nhất có thể"** →
instance store; **"persistent", "durable", "phải sống sót"** → EBS.

Ứng dụng đúng đắn duy nhất trong kiến trúc thật là dữ liệu **tái tạo được**: cache cục
bộ, thư mục Spark shuffle, replica của cụm tự nhân bản (Cassandra, Elasticsearch) — nơi
mất một node là cụm tự dựng lại.

---

## 14. EFS

NFSv4 do AWS quản lý, tự lớn tự co, **hàng nghìn instance mount đồng thời**. Linux only
(Windows dùng FSx for Windows).

**Mount target là một ENI trong mỗi AZ.** Đây là chi tiết bị bỏ qua nhiều nhất và là
gốc của mọi lỗi "mount treo": bạn tạo **một mount target cho mỗi AZ** có client, mỗi
mount target có **security group riêng**, và security group đó phải cho phép **TCP
2049** từ security group của instance. Client trong AZ nào thì nói chuyện với mount
target của AZ đó — nên thiếu mount target ở một AZ nghĩa là instance ở AZ đó không
mount được (hoặc phải trả phí cross-AZ).

| Trục cấu hình | Lựa chọn | Chọn thế nào |
|---|---|---|
| **File system type** | **Regional** (≥ 3 AZ) hoặc **One Zone** (1 AZ, rẻ hơn ~47%) | One Zone cho dev/test và dữ liệu tái tạo được |
| **Performance mode** | **General Purpose** (mặc định) hoặc **Max I/O** | **Luôn chọn General Purpose.** Max I/O đánh đổi latency mỗi thao tác lấy throughput tổng, và AWS đã khuyến nghị không dùng |
| **Throughput mode** | **Elastic** (mặc định), **Provisioned**, **Bursting** | Elastic khi tải thất thường hoặc chưa biết đỉnh; Provisioned khi biết đỉnh và dùng đều (> 5% capacity trung bình); Bursting là mô hình cũ theo credit |
| **Storage class** | Standard, Infrequent Access, Archive | Kèm **lifecycle management** tự chuyển sau N ngày không truy cập |

Con số hiệu năng (Regional, General Purpose):

| Throughput mode | Read IOPS tối đa | Write IOPS tối đa | Read throughput | Latency đọc / ghi |
|---|---|---|---|---|
| **Elastic** | 900.000 – 2.500.000 | 500.000 | **20–60 GiB/s** | ~1 ms / ~2,7 ms |
| **Provisioned** | 55.000 | 25.000 | 3–10 GiB/s | ~1 ms / ~2,7 ms |
| **Bursting** | 35.000 | 7.000 | 3–5 GiB/s | ~1 ms / ~2,7 ms |

Bursting tính theo credit: baseline **50 MiB/s mỗi TiB** dữ liệu ở lớp Standard, burst
lên 100 MiB/s. File system nhỏ mà tải nặng thì cạn credit rồi chậm hẳn — triệu chứng
"EFS chậm dần theo thời gian" gần như luôn là hết burst credit. Cách chữa: chuyển sang
**Elastic**.

Bảo mật: mã hoá at-rest bằng KMS (bật **lúc tạo**), in-transit bằng TLS (`-o tls` của
`efs-utils`), phân quyền bằng security group + IAM policy của file system + **EFS Access
Point** (ép POSIX uid/gid và thư mục gốc cho mỗi ứng dụng).

---

## 15. FSx — bốn biến thể

| Biến thể | Protocol | Khi nào chọn |
|---|---|---|
| **FSx for Windows File Server** | **SMB** | Ứng dụng Windows cần file share, tích hợp **Active Directory**, ACL của NTFS, DFS Namespace. Đây là câu trả lời cho "EFS nhưng cho Windows" |
| **FSx for Lustre** | **Lustre** (POSIX) | HPC, ML training, xử lý video, phân tích dữ liệu lớn — cần **hàng trăm GB/s** và độ trễ sub-millisecond. Liên kết được với bucket S3 và **lazy-load** dữ liệu khi đọc lần đầu |
| **FSx for NetApp ONTAP** | **NFS, SMB, iSCSI cùng lúc** | Đang chạy NetApp on-prem và muốn giữ nguyên snapshot, clone, dedup, compression. Cũng là lựa chọn khi cần **một file system phục vụ cả Linux lẫn Windows** |
| **FSx for OpenZFS** | **NFS** | Di chuyển từ ZFS on-prem; cần snapshot/clone tức thì và độ trễ rất thấp cho workload NFS |

Chi tiết Lustre hay ra thi là hai kiểu deployment. **Scratch** không nhân bản, cho dữ
liệu tạm trong lúc tính toán — mất node là mất dữ liệu, nhưng rẻ và nhanh nhất.
**Persistent** nhân bản trong một AZ và tự chữa lành. Throughput tỉ lệ với dung lượng:
chọn 125/250/500/1.000 MB/s mỗi TiB (Persistent 2). Liên kết S3 là điểm bán hàng: gắn
bucket vào file system, file được lazy-load khi đọc lần đầu, kết quả ghi ngược lại S3 —
đề nói **"chạy HPC trên dữ liệu đang nằm ở S3"** → FSx for Lustre.

---

## 16. Storage Gateway và AWS Backup

**Storage Gateway** chạy như VM tại chỗ (VMware, Hyper-V, KVM), như EC2, hoặc như thiết
bị phần cứng, giữ **cache cục bộ** cho dữ liệu hay dùng và đẩy phần còn lại lên AWS.

| Loại | Giao thức phía on-prem | Dữ liệu nằm ở | Khi nào chọn |
|---|---|---|---|
| **Amazon S3 File Gateway** | NFS, SMB | **S3** (object đọc thẳng được từ S3) | Ứng dụng cũ chỉ biết file share nhưng bạn muốn dữ liệu thành object trong data lake; backup, archive |
| **Amazon FSx File Gateway** | SMB | **FSx for Windows File Server** | File share Windows nhiều người dùng tương tác, cần độ trễ thấp tại chi nhánh |
| **Volume Gateway** | **iSCSI** (block) | S3, snapshot dạng **EBS snapshot** | **Cached volumes** — dữ liệu chính ở AWS, chỉ cache nóng tại chỗ (khi muốn giảm storage on-prem). **Stored volumes** — dữ liệu chính ở on-prem, backup bất đồng bộ lên AWS (khi cần latency thấp cho toàn bộ dataset) |
| **Tape Gateway** | **iSCSI VTL** | S3, Glacier, Deep Archive | Đang dùng phần mềm backup ghi băng (Veeam, NetBackup, Commvault) và muốn bỏ băng vật lý mà không đổi phần mềm |

Nguồn ôn thi thường chỉ liệt kê **ba** loại — thiếu **Amazon FSx File Gateway**.

**AWS Backup** là mặt phẳng điều khiển backup tập trung cho nhiều dịch vụ: EBS, EC2,
RDS, Aurora, DynamoDB, EFS, FSx, Storage Gateway volume, S3, và cả tài nguyên VMware.
Nó giải quyết bài toán mà DLM không giải được: **một chính sách cho nhiều loại tài
nguyên, nhiều account, nhiều region.**

Ba thứ ra thi: **backup plan** = lịch + thời gian giữ + vault đích + quy tắc copy
cross-region/cross-account, và gán tài nguyên vào plan bằng **tag** nên tài nguyên mới
tạo tự động được backup; **Backup Vault Lock** — WORM cho vault, ở chế độ **compliance**
thì sau cooling-off **không ai xoá được backup, kể cả root**, đây là đáp án cho "chống
ransomware xoá cả backup"; và **cold storage** cho backup EBS chỉ áp dụng với lịch
**hàng tháng trở lên**, tối thiểu **90 ngày**, lưu **dạng đầy đủ** chứ không incremental.

---

## Bảng số phải nhớ

| Con số | Giá trị |
|---|---|
| S3 request rate mỗi prefix | **3.500 ghi / 5.500 đọc mỗi giây**, không giới hạn số prefix |
| S3 object tối đa | **50 TB**; một `PUT` tối đa **5 GB** |
| Multipart | khuyến nghị > **100 MB**, bắt buộc > **5 GB**; **10.000 part**, mỗi part **5 MiB–5 GiB** |
| Durability mọi storage class | **11 số 9** |
| Lưu tối thiểu | IA & One Zone-IA **30 ngày** · Glacier IR & Flexible **90 ngày** · Deep Archive **180 ngày** |
| Kích thước tính tiền tối thiểu | **128 KB** cho IA, One Zone-IA, Glacier IR |
| Glacier Flexible / Deep Archive metadata | **+40 KB mỗi object** |
| Lifecycle không chuyển object nhỏ hơn | **128 KB** (mặc định từ 09/2024) |
| Intelligent-Tiering chuyển tầng | **30 ngày** → IA · **90 ngày** → Archive Instant Access |
| Glacier Flexible restore | Expedited **1–5 phút** · Standard **3–5 giờ** · Bulk **5–12 giờ** |
| Deep Archive restore | Standard **12 giờ** · Bulk **48 giờ** |
| Replication Time Control | **99,99% trong 15 phút** |
| Presigned URL | tối đa **7 ngày** (IAM user); hết hạn theo credential nếu ký bằng role |
| S3 Bucket Key | giảm tới **99%** số request tới KMS |
| gp3 | baseline **3.000 IOPS / 125 MiB/s** miễn phí; tối đa **80.000 / 2.000 MiB/s** |
| gp2 | **3 IOPS/GiB**, min 100, max 16.000; burst 3.000 nếu < 1 TiB |
| io2 Block Express | tối đa **256.000 IOPS / 4.000 MiB/s**, tỉ lệ **1.000 IOPS/GiB**, latency < **500 µs** |
| st1 / sc1 | baseline **40 / 12 MiB/s mỗi TiB**, trần **500 / 250 MiB/s**; min **125 GiB**; **không boot được** |
| Độ bền EBS | gp2/gp3/io1/st1/sc1 **99,8–99,9%**; **io2 99,999%** |
| EBS Multi-Attach | **16 instance Nitro, cùng 1 AZ**, chỉ io1/io2 |
| EBS Snapshot Archive | rẻ hơn ~75%, tối thiểu **90 ngày**, restore **24–72 giờ** |
| EFS mount target | **một ENI mỗi AZ**, mở **TCP 2049** |
| EFS bursting baseline | **50 MiB/s mỗi TiB** |
| EFS Elastic | tới **60 GiB/s** đọc, **2,5 triệu** read IOPS |

---

## Bẫy đề thi

**"S3 là eventually consistent, phải retry hoặc chờ vài giây."**
Sai từ 12/2020. Strong read-after-write cho mọi request, **kể cả LIST**, ở mọi region,
miễn phí. Chỉ **cấu hình mức bucket** còn eventually consistent. Đáp án "thêm retry
với exponential backoff để chờ object xuất hiện" là bẫy nguồn cũ.
→ [S3 consistency](https://aws.amazon.com/s3/consistency/)

**"Băm ngẫu nhiên tiền tố key để tăng hiệu năng S3."**
Lỗi thời từ 2018. S3 tự phân vùng theo tải. Đặt tên key theo thứ tự logic thoải mái;
cách vượt trần đúng là **nhiều prefix có ý nghĩa + đọc song song**.

**"One Zone-IA kém bền hơn nên đừng dùng cho dữ liệu quan trọng."**
Nửa đúng nửa sai, và cách nói sai làm bạn chọn nhầm. Nó **cũng 11 số 9 durability**;
cái thấp hơn là **availability (99,5%)** và số AZ (**1**). Tiêu chí đúng để chọn:
**mất cả AZ thì có tạo lại dữ liệu được không.**

**"Versioning bảo vệ khỏi xoá, nên không cần gì nữa."**
Versioning không chặn được người có quyền xoá version cụ thể. Chống xoá thật sự cần
**MFA Delete** (chống chiếm quyền) hoặc **Object Lock Compliance** (chống cả root).
Và versioning làm **tăng tiền** nếu không có `NoncurrentVersionExpiration`.

**"Bật replication là mọi thứ trong bucket được nhân bản."**
Chỉ object **tạo sau** khi bật rule. Object cũ cần **S3 Batch Replication** chạy riêng.
Delete marker mặc định **không** nhân bản. Object mã hoá SSE-C **không** nhân bản.

**"Chọn SSE-KMS cho mọi bucket vì bảo mật hơn."**
Đúng về audit và kiểm soát khoá, nhưng nó thêm một lệnh gọi KMS cho **mỗi** object
operation, và bạn sẽ gặp `ThrottlingException` ở tải cao. Bật **S3 Bucket Key** là câu
trả lời (giảm 99% request tới KMS) — và nhớ rằng **DSSE-KMS không dùng được Bucket Key**.

**"io2 Block Express là loại volume riêng, khác io2."**
Từ **30/04/2025 mọi volume io2 đều là Block Express.** Bảng nào còn chia io2 = 64.000
IOPS và io2 Block Express = 256.000 IOPS là bảng cũ.
→ [provisioned-iops](https://docs.aws.amazon.com/ebs/latest/userguide/provisioned-iops.html)

**"Lifecycle rule sẽ chuyển hết object sang Glacier."**
Từ **09/2024**, mặc định **object dưới 128 KB không được chuyển sang bất kỳ lớp nào**,
vì phí transition vượt tiền tiết kiệm. Muốn ép thì phải thêm bộ lọc kích thước.

**"EBS được nhân bản qua nhiều AZ."**
Sai. EBS nhân bản **trong một AZ**. Muốn sang AZ khác phải snapshot rồi restore. Đây
là lý do multi-AZ phải làm ở tầng ASG chứ không phải tầng volume.

**"Gắn EFS xong là mount được."**
Thiếu **mount target ở đúng AZ** hoặc thiếu rule **TCP 2049** trong security group của
mount target là mount treo im lặng. Đây là lỗi vận hành phổ biến nhất của EFS.

**"Presigned URL sống đúng bằng thời gian tôi đặt."**
Chỉ khi ký bằng credential của IAM user (tối đa 7 ngày). Ký bằng **role hay instance
profile** thì URL chết cùng session — thường là ~6 giờ trên EC2, dù bạn đặt 7 ngày.

---

## Cây quyết định

**Bước 1 — dữ liệu được truy cập thế nào?** API HTTP, không cần POSIX → **S3**. Một
máy cần block device → **EBS**. Nhiều máy Linux cùng đọc ghi một thư mục → **EFS**.
Nhiều máy Windows → **FSx for Windows**. Throughput hàng trăm GB/s cho HPC → **FSx for
Lustre**. Dữ liệu tạm, tái tạo được, cần IOPS cao nhất → **instance store**.

**Bước 2 — trong S3, chọn lớp theo tần suất và độ trễ chấp nhận được.** Nhiều lần mỗi
tháng → Standard. Không biết pattern → Intelligent-Tiering. Dưới một lần mỗi tháng,
cần tức thì → Standard-IA (One Zone-IA nếu tái tạo được). Một lần mỗi quý, cần tức thì
→ Glacier Instant Retrieval. Một lần mỗi năm, chờ được vài giờ → Glacier Flexible.
Ít hơn nữa → Deep Archive. Cần một chữ số mili giây → S3 Express One Zone.

**Bước 3 — trong EBS, chọn loại theo hình dạng I/O.** Mặc định **gp3**. Cần hơn 80.000
IOPS, latency sub-millisecond, hoặc độ bền 99,999% → **io2**. Cần Multi-Attach →
io1/io2. Đọc ghi tuần tự dung lượng lớn → **st1**. Dữ liệu lạnh, rẻ nhất → **sc1**.
Không bao giờ chọn gp2 cho volume mới.

**Bước 4 — hybrid và backup.** On-prem cần file share nhưng dữ liệu phải thành object →
**S3 File Gateway**. Cần block qua iSCSI → **Volume Gateway** (cached nếu muốn giảm
storage tại chỗ, stored nếu cần toàn bộ dataset ở local). Đang ghi băng → **Tape
Gateway**. Cần một chính sách backup cho nhiều dịch vụ và account → **AWS Backup**
(kèm **Vault Lock** nếu đề nhắc ransomware hay tuân thủ).

---

## Nối với thực hành

Lab có lời giải: [`../../learn-aws/labs/w04-s3-cloudfront/`](../../learn-aws/labs/w04-s3-cloudfront/)
và [`../../learn-aws/labs/w03-ec2-alb-asg/`](../../learn-aws/labs/w03-ec2-alb-asg/) (phần EBS).

| Mục trong file này | Lab chạm vào đâu |
|---|---|
| [Block Public Access và OAC](#8-kiểm-soát-truy-cập) | `labs/w04-s3-cloudfront` — bucket giữ BPA bật cả 4 cờ, CloudFront + OAC là đường duy nhất vào. Thử `curl` thẳng vào endpoint S3 để thấy `403` |
| [Versioning và delete marker](#5-versioning-delete-marker-mfa-delete) | `labs/w04-s3-cloudfront` — xoá object, `list-object-versions` để thấy delete marker; xoá marker để khôi phục; hiểu vì sao cần `force_destroy` |
| [Lifecycle](#4-lifecycle--những-quy-tắc-ngầm) | `labs/w04-s3-cloudfront` — đặt rule và đọc lại bằng `get-bucket-lifecycle-configuration`. Chú ý mặc định 128 KB |
| [Mã hoá và bucket policy](#7-mã-hoá-s3) | `labs/w04-s3-cloudfront` — thêm statement `Deny` khi thiếu `s3:x-amz-server-side-encryption`, rồi thử `PutObject` không kèm header |
| [Presigned URL](#8-kiểm-soát-truy-cập) | `labs/w04-s3-cloudfront` — `aws s3 presign` từ máy bạn và từ EC2 dùng instance profile; so sánh thời điểm hết hạn thật |
| [EBS và snapshot](#12-ebs-snapshot--incremental-archive-fsr) | `labs/w03-ec2-alb-asg` — snapshot, xoá volume, restore ở AZ khác; `find-orphans.sh` quét volume và snapshot mồ côi |

Lab tự viết (đề bài, không lời giải) ở `learn-aws/labs-self/w04-*/` và
`learn-aws/labs-self/w03-*/`, chấm bằng `verify.sh` trên hạ tầng thật.

---

## Nguồn nói khác

Những chỗ `aws-saa-c03/02-storage-services.md` và các bộ đề luyện phổ biến đang dạy sai
hoặc đã lỗi thời. Kiểm tra lại tháng 08/2026.

| Nguồn nói | Thực tế | Docs |
|---|---|---|
| Không có mục consistency; các đề luyện dạy "eventually consistent" | **Strong read-after-write từ 12/2020**, kể cả LIST | [S3 consistency](https://aws.amazon.com/s3/consistency/) |
| Max object size **5 TB** | **50 TB** (48,8 TiB = 10.000 part × 5 GiB) | [UsingObjects](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingObjects.html) |
| "Prefix example: `bucket/folder1/`" — hiểu prefix là thư mục | Prefix là **đơn vị phân vùng do S3 tự chia**, không phải thư mục. Vượt trần thì gặp **503 Slow Down** trong lúc S3 tách partition | [optimizing-performance-design-patterns](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance-design-patterns.html) |
| "Minimum 30 days in S3 Standard before transitioning to IA" (chỉ nêu một quy tắc) | Còn quy tắc **09/2024: mặc định không chuyển object dưới 128 KB sang bất kỳ lớp nào** | [lifecycle-transition-general-considerations](https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html) |
| Bảng storage class thiếu **S3 Express One Zone**, thiếu cột "kích thước tính tiền tối thiểu" và "40 KB metadata" | Cả ba đều là yếu tố quyết định chi phí thật | [storage-class-intro](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html) |
| "SSE-S3: default encryption" (nói mơ hồ) | **Từ 05/01/2023 mọi object mới được mã hoá SSE-S3 tự động**, không cần bật | [S3 encrypts new objects by default](https://aws.amazon.com/blogs/aws/amazon-s3-encrypts-new-objects-by-default/) |
| Không nhắc **S3 Bucket Key** và **DSSE-KMS** | Bucket Key giảm **99%** request KMS — là đáp án cho câu hỏi KMS throttle | [bucket-key](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html) |
| "ACLs: legacy, not recommended" | Mạnh hơn thế: bucket mới mặc định **`Bucket owner enforced` → ACL bị vô hiệu hoá hoàn toàn** | [S3 features](https://aws.amazon.com/s3/features/) |
| **io2** 64.000 IOPS và **io2 Block Express** 256.000 IOPS là hai dòng khác nhau | Từ **30/04/2025 mọi io2 đều là Block Express**. Tỉ lệ là **1.000 IOPS/GiB** | [provisioned-iops](https://docs.aws.amazon.com/ebs/latest/userguide/provisioned-iops.html) |
| gp3 "3.000–16.000 IOPS, 125–1.000 MB/s" | **3.000–80.000 IOPS, 125–2.000 MiB/s** | [general-purpose](https://docs.aws.amazon.com/ebs/latest/userguide/general-purpose.html) |
| st1 "500 IOPS / 500 MB/s", sc1 "250 / 250" | HDD tính bằng **throughput credit**: st1 baseline **40 MiB/s mỗi TiB** (trần 500), sc1 baseline **12 MiB/s mỗi TiB** (trần 250) | [hdd-vols](https://docs.aws.amazon.com/ebs/latest/userguide/hdd-vols.html) |
| Storage Gateway có **3 loại** | Có **4**: thiếu **Amazon FSx File Gateway** | [Storage Gateway FAQ](https://aws.amazon.com/storagegateway/faqs/) |
| EFS "Max I/O cho big data" | AWS khuyến nghị **luôn dùng General Purpose**; Max I/O có latency mỗi thao tác cao hơn. Elastic throughput mới là câu trả lời cho throughput | [EFS performance](https://docs.aws.amazon.com/efs/latest/ug/performance.html) |
| Không nhắc **mount target là một ENI mỗi AZ** | Đây là gốc của mọi lỗi "mount EFS treo" | [EFS performance](https://docs.aws.amazon.com/efs/latest/ug/performance.html) |
| Snow Family: Snowcone 8–14 TB, Snowball Edge 80/42 TB, Snowmobile 100 PB | **Toàn bộ Snow Family đóng cửa với khách hàng mới từ 07/11/2025**; Snowmobile đã ngừng; các model 80 TB/42 TB đã ngừng từ 11/2024. Thay bằng **DataSync** hoặc **AWS Data Transfer Terminal** | [Snowball Edge availability change](https://docs.aws.amazon.com/snowball/latest/developer-guide/snowball-edge-availability-change.html) |
| Số bucket mỗi account (thường dạy 100) | **10.000** mặc định, xin tăng tới **1 triệu** | [create-bucket-overview](https://docs.aws.amazon.com/AmazonS3/latest/userguide/create-bucket-overview.html) |

---

## Ngoài phạm vi

- **Snow Family** và **DataSync** chi tiết — thuộc `10-chi-phi.md` và phần migration; và Snow đã đóng với khách mới. [Docs](https://docs.aws.amazon.com/snowball/latest/developer-guide/snowball-edge-availability-change.html)
- **S3 on Outposts**, **S3 Vectors**, **S3 Tables**, **S3 Metadata** — ngoài đề SAA-C03. [Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/S3onOutposts.html)
- **S3 Object Lambda** — đã chuyển sang maintenance từ 07/11/2025. [Docs](https://aws.amazon.com/about-aws/whats-new/2025/10/aws-service-availability/)
- **Multi-Region Access Point** và **S3 Storage Lens** nâng cao — biết tên là đủ. [Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiRegionAccessPoints.html)
- **CloudFront**, **OAC** chi tiết, **signed URL/cookie** — thuộc `04-networking.md`.
- **Amazon Glacier** dịch vụ độc lập (vault, archive) — đã chuyển maintenance 07/11/2025; đề SAA chỉ hỏi các **storage class** Glacier trong S3. [Docs](https://aws.amazon.com/about-aws/whats-new/2025/10/aws-service-availability/)

---

## Tự kiểm tra

<details>
<summary>1. Đội bạn lưu 200 TB ảnh gốc, mỗi ảnh khoảng 40 KB, truy cập khoảng một lần mỗi quý. Vì sao "chuyển hết sang Glacier Instant Retrieval bằng lifecycle" có thể làm hoá đơn tăng chứ không giảm?</summary>

Ba cơ chế cộng dồn, và cả ba đều nằm ở kích thước object chứ không ở tần suất truy cập:

- **Kích thước tính tiền tối thiểu của Glacier IR là 128 KB.** Ảnh 40 KB bị tính như
  128 KB — bạn trả gấp **3,2 lần** dung lượng thật.
- **Mỗi transition tính một request.** 200 TB ảnh 40 KB là khoảng **5 tỉ object**, tức
  5 tỉ request transition. Con số này một mình đã có thể vượt tiền tiết kiệm cả năm.
- **Từ 09/2024, lifecycle mặc định KHÔNG chuyển object dưới 128 KB** — nên rule bạn
  viết có thể đơn giản là không chạy, và bạn ngồi chờ một khoản tiết kiệm không tới.

Kiến trúc đúng: **gộp file nhỏ lại** trước khi archive (tar/zip theo lô, hoặc định dạng
cột như Parquet), rồi mới hạ tầng lưu trữ. Đây là bài học chung: **S3 phạt file nhỏ**,
ở mọi lớp lạnh.
</details>

<details>
<summary>2. Ứng dụng của bạn ghi 4.000 object mỗi giây vào <code>s3://bucket/events/</code> và bắt đầu nhận HTTP 503. Vì sao đáp án "thêm hash ngẫu nhiên vào đầu key" là bẫy, và bạn làm gì?</summary>

503 Slow Down ở đây nghĩa là bạn vượt **3.500 ghi/giây trên một partitioned prefix**.
S3 **đang tự tách partition** để phục vụ tải mới — đây là trạng thái tạm thời, không
phải lỗi cấu hình.

"Thêm hash ngẫu nhiên" là lời khuyên AWS **đã rút lại từ 2018**. Nó từng đúng khi S3
phân vùng theo tiền tố cố định; nay S3 tự phân vùng theo tải, và hash chỉ làm key khó
đọc, phá thứ tự liệt kê, làm hỏng lifecycle rule theo prefix.

Việc cần làm, theo thứ tự:
1. **Retry với exponential backoff** — SDK của AWS làm sẵn. Đây là cách xử lý đúng cho
   503 trong lúc S3 mở rộng.
2. **Tăng tải dần** thay vì nhảy thẳng lên đỉnh, để S3 kịp tách partition.
3. Nếu cần bền vững hơn 3.500/giây: **chia ra nhiều prefix có ý nghĩa** —
   `events/2026-08-21/shard-00/`… — mỗi prefix là một partition riêng, và bạn vẫn đọc
   được theo ngày.
</details>

<details>
<summary>3. Một bucket dùng SSE-KMS phục vụ 10.000 GET mỗi giây. Ứng dụng bắt đầu nhận <code>ThrottlingException</code>. Chuyện gì xảy ra, và vì sao "chuyển sang SSE-S3" không phải câu trả lời tốt nhất?</summary>

Mỗi `GET` object mã hoá SSE-KMS sinh **một lệnh gọi `Decrypt` tới KMS**. KMS có quota
request theo region (hàng chục nghìn/giây tuỳ region), và 10.000 GET/giây có thể chạm
trần — đặc biệt khi có workload khác trong account cùng dùng KMS.

Chuyển sang SSE-S3 làm hết throttle, nhưng bạn **mất toàn bộ thứ khiến bạn chọn KMS**:
audit từng lần dùng khoá trong CloudTrail, key policy riêng, xoay khoá, và khả năng
thu hồi quyền giải mã tức thì bằng cách sửa key policy. Nếu bucket dùng KMS vì lý do
tuân thủ, đây là bước lùi.

Câu trả lời đúng là **bật S3 Bucket Key**: S3 lấy một khoá cấp bucket từ KMS rồi tự
sinh data key cho từng object trong một khoảng thời gian, **giảm tới 99% số request tới
KMS** và giảm chi phí KMS tương ứng. Không đổi gì phía client, không mất tính năng.
Lưu ý duy nhất: **DSSE-KMS không dùng được Bucket Key**.
</details>

<details>
<summary>4. Bạn bật CRR từ bucket prod (us-east-1) sang bucket DR (eu-west-1). Một tuần sau, đội compliance báo bucket DR thiếu 80% dữ liệu và các file bị xoá ở prod vẫn còn ở DR. Giải thích cả hai hiện tượng.</summary>

**Thiếu 80% dữ liệu:** replication chỉ áp cho object **tạo sau** khi rule được bật.
Toàn bộ dữ liệu có trước đó không bao giờ được nhân bản tự động. Cách chữa là chạy
**S3 Batch Replication** — một job riêng, quét bucket nguồn và đẩy object cũ sang đích.

**File xoá ở prod vẫn còn ở DR:** đây là **hành vi cố ý và đúng đắn**. Mặc định
`DeleteMarkerReplication` **tắt**, và thao tác xoá kèm `versionId` cụ thể **không bao
giờ** được nhân bản. Thiết kế này để kẻ tấn công (hoặc một script sai) xoá dữ liệu ở
nguồn thì bản DR vẫn còn — đúng mục đích của DR.

Nếu compliance thật sự muốn bucket DR là gương y hệt prod thì bật
`DeleteMarkerReplication`, nhưng phải hiểu rằng bạn vừa đánh đổi khả năng chống xoá
nhầm để lấy tính "y hệt". Thường thì lựa chọn đúng là **giữ nguyên** và giải thích cho
compliance rằng DR không phải mirror, DR là bản sao chống mất mát.
</details>

<details>
<summary>5. EC2 ở AZ <code>ap-southeast-1a</code> mount EFS thành công. EC2 ở <code>ap-southeast-1b</code> thì lệnh <code>mount</code> treo rồi timeout. Cả hai cùng security group, cùng subnet route table. Vì sao?</summary>

Vì EFS không phải "một endpoint cho cả region". Client nói chuyện với **mount target
của AZ mình**, và mỗi mount target là **một ENI đặt trong một subnet của AZ đó**. Hai
nguyên nhân, cả hai đều khớp triệu chứng:

- **Không có mount target trong `ap-southeast-1b`.** Bạn tạo file system rồi chỉ tạo
  mount target ở AZ đầu tiên. Máy ở AZ khác không có ai để nói chuyện.
- **Security group của mount target không cho TCP 2049 từ security group của instance.**
  Chú ý đây là SG của **mount target**, không phải SG của instance — đó là lý do "cả
  hai cùng security group" không giải thích được gì. Và vì NFS không trả lỗi khi bị
  drop, triệu chứng là **treo rồi timeout**, không phải "connection refused".

Cách chữa: tạo mount target cho **mọi AZ có client**, và cho SG của mount target một
inbound rule TCP 2049 tham chiếu SG của instance. Lợi ích phụ: mount trong cùng AZ
tránh được phí truyền dữ liệu cross-AZ.
</details>

<details>
<summary>6. Đề yêu cầu: "log kiểm toán phải giữ 7 năm, không ai được sửa hoặc xoá, kể cả quản trị viên có quyền cao nhất." Bạn chọn gì, và vì sao ba lựa chọn gần đúng kia đều sai?</summary>

Đáp án: **S3 Object Lock ở chế độ Compliance**, retention 7 năm, trên bucket đã bật
versioning và bật Object Lock **ngay lúc tạo**.

Ba lựa chọn gần đúng và lý do chúng sai:

- **Versioning + MFA Delete** — chống xoá do nhầm lẫn hoặc do tài khoản bị chiếm quyền,
  nhưng **root user có MFA vẫn xoá được**. Đề nói rõ "kể cả quản trị viên cao nhất".
- **Object Lock ở chế độ Governance** — người có quyền `s3:BypassGovernanceRetention`
  vượt qua được. Đó chính là "quản trị viên có quyền cao nhất" mà đề loại trừ.
- **Bucket policy `Deny s3:DeleteObject`** — policy do người viết ra thì người có quyền
  sửa policy cũng xoá được nó. Đây không phải cơ chế bất biến, nó chỉ là một lớp rào.

Chi tiết dễ trượt: **Object Lock phải bật lúc tạo bucket** (bật sau cần ticket với AWS
Support), và nó áp cho **từng version**, không phải cả bucket. Nếu đề nói về backup của
nhiều dịch vụ chứ không riêng S3, câu trả lời tương đương là **AWS Backup Vault Lock**
ở chế độ compliance.
</details>
