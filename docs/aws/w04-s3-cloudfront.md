# Tuần 4 — S3 và các tầng lưu trữ

> Tuần 3 bạn học block storage (EBS) và file storage (EFS). Tuần này là mảnh còn
> lại: **object storage**. S3 không phải "ổ đĩa trên mây" — nó là một cái key-value
> store khổng lồ nói HTTP, và mọi thứ khó chịu lẫn mọi thứ mạnh mẽ của nó đều bắt
> nguồn từ chỗ đó. Bài này trả lời: chọn storage class nào, khoá bucket lại bằng
> cách nào, và **tiền thật sự đi đâu** (gợi ý: không phải phí lưu trữ).

## Học xong bài này bạn phải trả lời được

1. S3 khác EBS và EFS ở chỗ nào về mặt mô hình, không phải về mặt giá?
2. Vì sao `s3://bucket/a/b/c.txt` **không** có thư mục `a/` và `b/`, và điều đó ảnh
   hưởng gì tới hiệu năng và tới `aws s3 rm --recursive`?
3. Đề cho một tình huống lưu trữ: bạn dùng ba tiêu chí nào để chọn storage class?
4. Bucket policy, ACL, Block Public Access, IAM policy — cái nào thắng cái nào?
5. SSE-S3 và SSE-KMS đều "mã hoá phía server", vậy đề chọn cái nào khi nào?
6. Versioning bật rồi, bạn `delete-object`. Chuyện gì thật sự xảy ra, và vì sao
   bucket "trống" mà vẫn không xoá được?
7. Ba điều kiện bắt buộc để bật Cross-Region Replication là gì?
8. Tại sao một bucket 1 GB có thể tốn nhiều tiền hơn một bucket 1 TB?

## Bản đồ khái niệm

```
                          Người dùng cuối
                                │ HTTPS
                    ┌───────────▼────────────┐
                    │      CloudFront        │ cache ở edge · cache behavior + TTL
                    └───────────┬────────────┘ 1 TB egress/tháng always free
                                │ OAC — ký SigV4 bằng service principal
                                │ cloudfront.amazonaws.com + AWS:SourceArn
        ┌───────────────────────▼──────────────────────────┐
        │                  S3 BUCKET                       │
        │  Block Public Access: 4/4 BẬT                    │
        │  Ai được vào: IAM policy ⋃ bucket policy          │
        │               ACL (cũ, nên tắt) ∩ BPA             │
        │               explicit DENY thắng tất cả          │
        │                                                  │
        │  object = key + data + metadata + storage class   │
        │  KHÔNG có thư mục — chỉ có prefix                 │
        │  versioning: [v3 current][v2][v1]                 │
        │  encryption: SSE-S3 · SSE-KMS · SSE-C · CSE       │
        └───┬───────────────┬───────────────┬──────────────┘
            │ lifecycle     │ replication   │ event notification
            ▼               ▼               ▼
  Standard → IA →      CRR (region khác)  Lambda / SQS / SNS / EventBridge
  Glacier IR →         SRR (cùng region)
  Glacier Flexible → Deep Archive
```

---

## 1. Object storage khác block và file ở chỗ nào

| | **Block** (EBS) | **File** (EFS) | **Object** (S3) |
|---|---|---|---|
| Đơn vị | Block cố định kích thước | File trong cây thư mục | Object bất biến + metadata |
| Giao thức | SCSI/NVMe qua mạng nội bộ | NFSv4 | **HTTP REST API** |
| Sửa một phần | Được, ghi đè block | Được, `seek` + `write` | **Không.** Phải PUT lại cả object |
| Cấu trúc | Không có, OS lo | Cây thư mục thật | **Phẳng.** Chỉ là key-value |
| Metadata | Không | inode: quyền, mtime | **Tuỳ ý, bạn tự đặt** |
| Ai gắn được | 1 instance | Nhiều instance | Ai có quyền IAM, từ bất cứ đâu |
| Giới hạn dung lượng | 64 TiB / volume | Petabyte | **Không giới hạn** |

Hệ quả thực tế của "object là bất biến":

- **Không append được.** Thêm một dòng vào log 1 GB nghĩa là tải về, sửa, PUT lại
  1 GB. Đó là lý do log không ghi thẳng vào S3 kiểu append — ghi thành nhiều object
  nhỏ, hoặc dùng Firehose gom lại rồi mới ghi.
- **Không mount làm root filesystem.** `mountpoint-for-s3` và `s3fs` giả lập POSIX
  rất kém. Cần POSIX thật → EFS.
- **Ghi đè là tạo object mới** — gốc rễ của versioning và của mọi hoá đơn bất ngờ.

Bắc cầu: S3 giống **Docker registry** hơn là giống volume. Bạn `push` và `pull`
object nguyên vẹn, không sửa tại chỗ.

## 2. Bucket, key, prefix — và sự thật rằng không có thư mục

Một object được định danh bởi **bucket + key** (+ version ID nếu bật versioning).

```
s3://my-logs/app/2026/08/17/access.log
   └─bucket─┘└──────── key ────────────┘
```

Toàn bộ `app/2026/08/17/access.log` là **một chuỗi ký tự**. Dấu `/` không có ý
nghĩa đặc biệt với S3 — nó chỉ là một byte trong key. Console vẽ ra "thư mục" bằng
cách gọi `ListObjectsV2` với `delimiter=/` rồi nhóm kết quả lại. Đó là ảo giác của
giao diện, không phải cấu trúc dữ liệu.

Hệ quả bạn phải nhớ:

- **Không có "đổi tên thư mục".** `aws s3 mv s3://b/a/ s3://b/z/ --recursive` thật ra
  là COPY rồi DELETE từng object. Một triệu object = hai triệu request, trả tiền đủ.
- **Không có "thư mục rỗng".** Console cho tạo, nhưng nó chỉ tạo một object 0 byte
  có key kết thúc bằng `/`.
- **Prefix là đơn vị của hiệu năng.** S3 cho **ít nhất 3.500 PUT/COPY/POST/DELETE**
  và **5.500 GET/HEAD mỗi giây trên mỗi prefix đã được phân vùng**, và không giới
  hạn số prefix. Cần nhiều throughput hơn thì **rải key ra nhiều prefix**. Vượt
  ngưỡng trong lúc S3 đang tự phân vùng lại thì bạn nhận **HTTP 503 SlowDown** —
  xử lý bằng exponential backoff (SDK làm sẵn).
- **Tên bucket là global** trong namespace mặc định: duy nhất trên mọi account, mọi
  region trong một partition. Không đổi được tên lẫn region sau khi tạo.

> Ngày xưa có lời khuyên "đặt hash ngẫu nhiên ở đầu key để tăng hiệu năng". Từ khi
> S3 tự phân vùng theo prefix (2018), lời khuyên đó **không còn đúng** — hãy đặt key
> theo ngữ nghĩa, và chỉ rải prefix khi thật sự chạm trần.

## 3. Storage class — bảng phải thuộc

| Storage class | Durability | Availability (thiết kế) | Số AZ | Thời gian lưu tối thiểu | Kích thước tính tiền tối thiểu | Lấy ra mất bao lâu | Phí lấy ra |
|---|---|---|---|---|---|---|---|
| **S3 Standard** | 11 số 9 | 99,99% | ≥ 3 | — | — | Tức thì | Không |
| **S3 Intelligent-Tiering** | 11 số 9 | 99,9% | ≥ 3 | — | — | Tức thì (2 tầng lạnh cần restore) | **Không**, nhưng có phí monitoring/object |
| **S3 Standard-IA** | 11 số 9 | 99,9% | ≥ 3 | **30 ngày** | **128 KB** | Tức thì | **Có** |
| **S3 One Zone-IA** | 11 số 9 | **99,5%** | **1** | **30 ngày** | **128 KB** | Tức thì | **Có** |
| **S3 Glacier Instant Retrieval** | 11 số 9 | 99,9% | ≥ 3 | **90 ngày** | **128 KB** | **Tức thì** | Có |
| **S3 Glacier Flexible Retrieval** | 11 số 9 | 99,99% (sau khi restore) | ≥ 3 | **90 ngày** | — | **Phải restore trước** | Có |
| **S3 Glacier Deep Archive** | 11 số 9 | 99,99% (sau khi restore) | ≥ 3 | **180 ngày** | — | **Phải restore trước** | Có |

"11 số 9" = 99,999999999% — **mọi** storage class đều như nhau về durability. Cái
khác nhau là **availability** và **số AZ**. One Zone-IA vẫn 11 số 9, nhưng nếu cả
AZ đó biến mất thì dữ liệu biến mất theo. Đây là chỗ đề thi hay đánh lừa.

### Thời gian restore của hai lớp Glacier lạnh

| Storage class | Expedited | Standard | Bulk |
|---|---|---|---|
| **Glacier Flexible Retrieval** | **1–5 phút** | **3–5 giờ** | **5–12 giờ** (miễn phí) |
| **Glacier Deep Archive** | Không có | **trong 12 giờ** | **trong 48 giờ** |

### Ba câu hỏi để chọn lớp

1. **Bao lâu truy cập một lần?** Nhiều lần/tháng → Standard. Một lần/tháng → IA.
   Một lần/quý → Glacier IR. Một lần/năm → Glacier Flexible. Ít hơn nữa → Deep Archive.
2. **Chờ được bao lâu khi cần lấy ra?** Phải tức thì → Standard, IA, Glacier IR.
   Chờ được vài giờ → Glacier Flexible. Chờ được nửa ngày → Deep Archive.
3. **Mất AZ có tạo lại được không?** Tạo lại được (thumbnail, transcode, bản sao
   thứ hai) → **One Zone-IA** rẻ hơn. Không tạo lại được → không bao giờ One Zone.

Nếu đề nói **"không biết access pattern"** hoặc **"pattern thay đổi"** → luôn là
**Intelligent-Tiering**. Nó tự chuyển tầng và **không có phí lấy ra**, đổi lại là
một khoản phí monitoring nhỏ mỗi object. Object **dưới 128 KB không được monitor**
và luôn nằm ở tầng Frequent Access — nên Intelligent-Tiering vô nghĩa với bucket
toàn file nhỏ.

## 4. Lifecycle policy

Lifecycle rule là cách bạn tự động hoá cả ba tiêu chí trên. Một rule gồm bộ lọc
(prefix, tag, kích thước) và các hành động:

| Hành động | Nghĩa |
|---|---|
| `Transition` | Chuyển **current version** sang class khác sau N ngày |
| `NoncurrentVersionTransition` | Chuyển **version cũ** sang class khác |
| `Expiration` | Xoá current version (bật versioning thì = đặt **delete marker**) |
| `NoncurrentVersionExpiration` | **Xoá hẳn** version cũ sau N ngày |
| `AbortIncompleteMultipartUpload` | Dọn phần upload dở dang |
| `ExpiredObjectDeleteMarker` | Dọn delete marker mồ côi |

Hai luật chuyển tầng cần nhớ:

- Lifecycle chỉ chuyển **xuôi theo chiều lạnh dần**:
  `Standard → Standard-IA / One Zone-IA → Glacier IR → Glacier Flexible → Deep Archive`.
  Muốn đi ngược lên phải **restore rồi copy**, không có transition ngược.
- Chuyển vào một class có thời gian lưu tối thiểu rồi xoá sớm thì **vẫn bị tính đủ**.
  Đưa object sang Glacier rồi xoá sau 10 ngày → trả tiền đủ 90 ngày.

Ba thứ tốn tiền âm thầm mà lifecycle rule dọn hộ: **version cũ** (không có
`NoncurrentVersionExpiration` thì mỗi lần ghi đè là thêm một bản lưu vĩnh viễn),
**multipart upload dở dang** (part đã tải **không hiện trong danh sách object**
nhưng **vẫn tính tiền** — rất nhiều người không bao giờ phát hiện ra), và **delete
marker mồ côi**.

## 5. Versioning, delete marker, MFA Delete

Bật versioning ở mức bucket. **Bật rồi thì không tắt được**, chỉ **suspend** được —
và suspend không xoá version cũ, chỉ ngừng tạo version mới.

Khi bạn `DeleteObject` trên bucket có versioning:

```
Trước:   key=index.html  → [v3 current] [v2] [v1]
DELETE:  key=index.html  → [delete marker ← current] [v3] [v2] [v1]
                            ↑ 0 byte, không có data
```

- Object "biến mất" khỏi `ListObjects`, GET trả về **404**.
- **Không có gì bị xoá.** v1, v2, v3 vẫn còn nguyên và **vẫn tính tiền**.
- Khôi phục = **xoá delete marker** (`DeleteObject` kèm `versionId` của marker),
  không phải "undelete".
- Xoá thật = `DeleteObject` kèm `versionId` của từng version.

Đây là lý do bucket "đã xoá hết file" vẫn báo *"bucket not empty"* khi bạn xoá
bucket, và là lý do Terraform cần `force_destroy = true`.

**MFA Delete** yêu cầu thiết bị MFA để (a) xoá vĩnh viễn một version và (b)
tắt/suspend versioning. Ba chi tiết ra thi: chỉ **root user của account sở hữu
bucket** bật/tắt được, chỉ bật được qua **CLI/API** (không có trong console), và
cần versioning bật trước.

Đây là đáp án cho *"chống xoá dữ liệu do nhầm lẫn hoặc do tài khoản bị chiếm quyền"*.
Nếu đề nói về **tuân thủ pháp lý, WORM, không ai được xoá kể cả root** thì đáp án
là **S3 Object Lock** (Governance mode / Compliance mode), không phải MFA Delete.

## 6. Consistency model

Từ 12/2020, S3 cho **strong read-after-write consistency** với PUT và DELETE object
ở **mọi region**, không tốn thêm tiền, không cần bật gì: ghi mới rồi LIST ngay thì
thấy; ghi đè rồi GET ngay thì nhận dữ liệu mới; xoá rồi GET ngay thì 404. Đọc ACL,
object tag và metadata (HEAD) cũng strongly consistent.

Hai ngoại lệ phải nhớ:

- **Cấu hình ở mức bucket vẫn eventually consistent.** Xoá bucket rồi list bucket
  ngay có thể vẫn thấy nó. AWS khuyến nghị chờ **15 phút** sau khi bật versioning
  lần đầu trước khi ghi.
- **Không có object locking cho concurrent writer.** Hai PUT đồng thời vào cùng
  một key thì cái có timestamp muộn hơn thắng — **last writer wins**. Cần khoá thì
  phải tự xây ở tầng ứng dụng (ví dụ conditional write bằng DynamoDB).

> Mọi tài liệu nói "S3 là eventually consistent, phải chờ vài giây" đều viết trước
> 12/2020. Đề SAA-C03 hỏi thì đáp án là **strong read-after-write**.

## 7. Bảo mật S3 — bốn cơ chế và thứ tự đánh giá

| Cơ chế | Loại | Gắn vào | Dùng khi |
|---|---|---|---|
| **IAM policy** | Identity-based | User, group, role | Cấp quyền cho **principal trong account của bạn** |
| **Bucket policy** | Resource-based | Bucket | Cấp quyền **cross-account**, cho **service principal** (CloudFront, CloudTrail), hoặc theo điều kiện (IP, VPCE, TLS) |
| **ACL** | Cơ chế cũ, có trước IAM | Bucket và **từng object** | Gần như không còn dùng. Object Ownership mặc định là `Bucket owner enforced` → **ACL bị tắt** |
| **Block Public Access** | Chốt chặn | Bucket **và** account | **Luôn bật cả 4**. Nó **ghi đè** mọi policy/ACL cố mở public |

### Thứ tự đánh giá

```
1. Có explicit DENY ở BẤT KỲ đâu (SCP, bucket policy, IAM policy)?  → TỪ CHỐI
2. Block Public Access có chặn request ẩn danh này không?           → TỪ CHỐI
3. Có ALLOW ở identity policy HOẶC resource policy không?           → CHO PHÉP
4. Không có gì cả                                                    → TỪ CHỐI (mặc định deny)
```

Ba điều đáng nhớ:

- **Explicit Deny luôn thắng.** Kể cả Allow dành cho CloudFront, kể cả
  `AdministratorAccess`. Đây là bài tập "hai yêu cầu bảo mật mâu thuẫn" trong lab.
- **Với principal trong cùng account**, chỉ cần **một trong hai** (identity policy
  hoặc bucket policy) cho phép là đủ — chúng hợp nhất (union).
- **Với cross-account**, cần **cả hai**: bucket policy của bên sở hữu phải cho
  phép, và IAM policy bên account gọi cũng phải cho phép.

### Confused deputy — bẫy security hay ra thi

Bucket policy cho phép service principal `cloudfront.amazonaws.com` đọc bucket mà
**không kèm điều kiện** nghĩa là **bất kỳ distribution CloudFront nào của bất kỳ ai**
cũng đọc được bucket của bạn. Phải khoá lại bằng điều kiện:

```json
"Condition": {
  "StringEquals": { "AWS:SourceArn": "arn:aws:cloudfront::111122223333:distribution/E1XXXXX" }
}
```

Mẫu này (`aws:SourceArn` / `aws:SourceAccount`) áp dụng cho **mọi** resource policy
cấp quyền cho service principal, không riêng CloudFront.

## 8. Mã hoá

**At rest** — bốn lựa chọn:

| | Ai giữ khoá | Ai xoay khoá | Audit trail | Đề chọn khi |
|---|---|---|---|---|
| **SSE-S3** (`AES256`) | AWS | AWS | Không riêng | **Mặc định** (S3 mã hoá mọi object mới bằng SSE-S3 từ 01/2023). Đủ cho hầu hết yêu cầu |
| **SSE-KMS** | Bạn, qua KMS | Bạn (auto rotation) | **Có, CloudTrail ghi từng lần dùng khoá** | Đề nhắc **"kiểm soát khoá"**, **"audit ai giải mã"**, **"xoay khoá theo chính sách"** |
| **SSE-C** | **Bạn**, gửi kèm mỗi request | Bạn | Không | Đề nhắc **"AWS không được giữ khoá"** nhưng vẫn muốn S3 mã hoá hộ. Bắt buộc HTTPS |
| **Client-side (CSE)** | Bạn, mã hoá trước khi gửi | Bạn | Không | Đề nhắc **"dữ liệu phải mã hoá trước khi rời khỏi mạng của tôi"** |

Cái bẫy của SSE-KMS: mỗi lần GET/PUT là một lần gọi `kms:Decrypt`/`GenerateDataKey`,
và KMS có **quota request**. Bucket lưu lượng rất cao dùng SSE-KMS có thể bị
`ThrottlingException`. Cách chữa là **S3 Bucket Keys** — S3 dùng một khoá trung
gian ở mức bucket, giảm số lần gọi KMS tới ~99%. Đề hỏi "giảm chi phí KMS cho S3"
→ Bucket Keys.

**In transit:** ép HTTPS bằng bucket policy với `"aws:SecureTransport": "false"` →
Deny. Đây là mẫu policy chuẩn, nên biết viết.

## 9. Presigned URL

Một URL có chữ ký, cho phép người **không có tài khoản AWS** thực hiện đúng một
thao tác (GET hoặc PUT) trên đúng một object, trong đúng một khoảng thời gian.

```bash
aws s3 presign s3://my-bucket/report.pdf --expires-in 3600
```

Ba điểm ra thi: URL **kế thừa quyền của người tạo ra nó** (đừng bao giờ ký bằng
credential admin); hạn tối đa **7 ngày** khi ký bằng IAM user credential, ngắn hơn
nhiều nếu ký bằng temporary credential từ STS; và nó là đáp án cho *"cho khách tải
file riêng tư mà không mở bucket public"* lẫn *"cho người dùng upload thẳng lên S3
không qua server của tôi"*.

Phân biệt với **CloudFront signed URL / signed cookie** (tuần 8): presigned URL trỏ
thẳng vào S3, không qua CDN. Signed URL của CloudFront bảo vệ nội dung **đã nằm sau
CDN**, có giới hạn theo IP và thời gian. Đề nhắc "phân phối video có trả phí qua
CDN" → CloudFront signed URL/cookie.

## 10. Multipart upload và Transfer Acceleration

**Multipart upload** chia object thành nhiều part rồi tải song song.
| Thông số | Giá trị |
|---|---|
| Kích thước object tối đa | **48,8 TiB** |
| Số part tối đa | **10.000** |
| Kích thước mỗi part | **5 MiB – 5 GiB** (part cuối không có giới hạn dưới) |
| PUT một lần tối đa | **5 GiB** |
| AWS khuyến nghị dùng multipart từ | **100 MB** |

Lợi ích: tải song song, **retry từng part** thay vì cả file, bắt đầu được khi chưa
biết tổng kích thước. `aws s3 cp` tự dùng multipart. Cái giá: part dở dang **tính
tiền vô hình** — luôn kèm rule `AbortIncompleteMultipartUpload`.

**S3 Transfer Acceleration** định tuyến upload qua **CloudFront edge location gần
người gửi nhất** rồi đi tiếp bằng đường backbone của AWS tới bucket. Bật ở mức
bucket, dùng endpoint riêng `bucket.s3-accelerate.amazonaws.com`.

Đề chọn Transfer Acceleration khi: **người dùng ở xa region của bucket** và cần
**upload nhanh hơn qua internet công cộng**. Không chọn khi nguồn và bucket cùng
region — lúc đó nó chỉ làm tốn thêm tiền. Có công cụ so sánh tốc độ trước khi bật.

Nhớ phân biệt ba thứ hay bị lẫn:

| Cần gì | Dùng gì |
|---|---|
| Upload nhanh từ xa | **Transfer Acceleration** |
| Download nhanh, lặp lại nhiều lần | **CloudFront** (cache) |
| Chuyển hàng chục TB trở lên, đường mạng không đủ | **Snowball** (tuần 11) |

## 11. Replication — CRR và SRR

**Cross-Region Replication** (khác region) và **Same-Region Replication** (cùng
region) dùng chung một cơ chế, khác nhau ở đích.

Ba điều kiện bắt buộc, đều ra thi:

1. **Cả hai bucket phải bật versioning.**
2. Cần một **IAM role** để S3 assume khi ghi vào bucket đích.
3. **Chỉ object tạo SAU khi bật rule mới được nhân bản.** Object cũ cần
   **S3 Batch Replication**.

Replication **không** nhân bản: object đã ở Glacier/Deep Archive, object mã hoá
SSE-C, delete marker (trừ khi bật `DeleteMarkerReplication`), và **xoá theo version
ID cụ thể** — cố ý, để một lần xoá độc hại không lan sang bản sao.

Use case theo đề:

| Đề nói | Chọn |
|---|---|
| DR, tuân thủ "dữ liệu phải ở 2 region" | **CRR** |
| Giảm latency cho người dùng ở châu lục khác | **CRR** (hoặc CloudFront nếu chỉ đọc) |
| Gom log từ nhiều bucket về một chỗ, cùng region | **SRR** |
| Nhân bản sang account khác để cách ly quyền | SRR/CRR **cross-account** |
| Cần replicate trong thời gian cam kết (15 phút, có SLA) | **S3 Replication Time Control (RTC)** — mất phí thêm |

## 12. S3 Event Notification

Bucket phát sự kiện (`s3:ObjectCreated:*`, `s3:ObjectRemoved:*`,
`s3:LifecycleExpiration:*`, ...) tới **Lambda** (xử lý ngay: resize ảnh, transcode,
quét virus), **SQS** (buffer, xử lý batch, chịu tải đột biến), **SNS** (fanout), hoặc
**EventBridge** (bật ở mức bucket, cho mọi loại sự kiện, filter phong phú, routing
tới hơn 20 đích — đề nhắc "nhiều đích", "lọc phức tạp", "replay sự kiện" → EventBridge).

Chi tiết ra thi: event notification là **at-least-once**, cùng một sự kiện có thể
đến hai lần nên consumer phải **idempotent**. Bucket bật versioning thì `ObjectCreated`
bắn cho mỗi version, không phải mỗi key.

## 13. Requester Pays

Bật `RequesterPays` thì **người gọi trả phí request và phí data transfer**, chủ
bucket chỉ trả phí lưu trữ. Requester phải là **principal AWS đã xác thực** (không có
truy cập ẩn danh) và phải gửi header `x-amz-request-payer: requester`. Use case: chia
sẻ dataset lớn (dữ liệu khoa học, ảnh vệ tinh) mà không trả phí egress cho hàng nghìn
người tải. Đề nhắc *"chia sẻ dữ liệu ra ngoài mà không chịu chi phí truyền tải"* → đây.

## 14. CloudFront ở mức đủ cho lab

Phần sâu để [tuần 8](w08-dns-cdn-edge.md). Ở đây chỉ bốn khái niệm.

**OAC (Origin Access Control)** thay thế **OAI (Origin Access Identity)** cũ. Mục
đích giống nhau: chỉ CloudFront được đọc bucket, người dùng gọi thẳng URL S3 thì
nhận **403**. OAC hơn OAI ở ba điểm: hỗ trợ **SSE-KMS**, hỗ trợ **mọi region**, và
hỗ trợ **mọi HTTP method** (kể cả PUT/DELETE). Tài liệu nào còn dạy OAI là tài liệu cũ.

Với OAC, bucket policy cấp quyền cho service principal `cloudfront.amazonaws.com`
kèm điều kiện `AWS:SourceArn` — chính là mẫu chống confused deputy ở mục 7.

Kiến trúc chuẩn cho web tĩnh:

```
Người dùng → CloudFront (HTTPS, cache) → OAC → S3 bucket ĐÓNG HOÀN TOÀN
                                                Block Public Access: 4/4 bật
                                                static website hosting: TẮT
```

Cách sai phổ biến là bật **S3 static website hosting** rồi mở bucket public: vừa hở,
vừa **không có HTTPS** (endpoint website của S3 chỉ nói HTTP), vừa không có cache.

**Cache behavior** là quy tắc "path pattern nào thì xử lý thế nào": default behavior
cache mọi thứ 24 giờ, thêm một behavior cho `/api/*` với TTL = 0 và forward hết
header/cookie/query string. Behavior khớp theo thứ tự, cụ thể nhất trước.

**TTL** quyết định bao lâu edge giữ bản sao:

| Nguồn | Ai kiểm soát |
|---|---|
| `Cache-Control: max-age` / `Expires` trên object | **Origin** — cách đúng |
| Minimum / Default / Maximum TTL trong cache policy | CloudFront, ghi đè hoặc chặn hai đầu |

**Invalidation** xoá bản cache trước hạn. `1.000 path/tháng miễn phí`, sau đó tính
tiền mỗi path *(kiểm tra lại trang pricing trước khi tin)*.

Nhưng invalidation gần như luôn là **cách sai**:

| Cách | Chi phí | Dùng khi |
|---|---|---|
| Invalidation | Trả tiền mỗi path sau hạn mức | Sửa gấp, ít file |
| **Tên file có hash** (`app.a3f9c2.js`) | **Miễn phí** | **Mặc định nên dùng** |

URL mới thì không có cache cũ để mà xoá. Đề hỏi *"cập nhật nội dung CDN với chi phí
thấp nhất"* → versioned filename, không phải invalidation.

## 15. Tiền đi đâu — bảng quan trọng nhất của Domain 4

Ai cũng nhìn vào giá lưu trữ. Giá lưu trữ hầu như không bao giờ là vấn đề.

| Khoản | Bản chất | Vì sao nguy hiểm |
|---|---|---|
| **Data transfer OUT ra internet** | Tính theo GB đi ra | **Kẻ giết ví số 1.** Đặt CloudFront phía trước là cách giảm chính (CloudFront có 1 TB/tháng always free) |
| **Data transfer OUT sang region khác** | Tính theo GB | CRR nhân đôi chi phí này với mọi object |
| **Phí request** | Tính theo **số** GET/PUT/LIST | Một triệu file 1 KB đắt hơn nhiều so với một file 1 GB, dù cùng dung lượng |
| **Phí lấy ra (retrieval)** của IA/Glacier | Theo GB lấy ra | Đưa dữ liệu **còn nóng** vào IA rồi đọc liên tục thì **đắt hơn Standard** |
| **Thời gian lưu tối thiểu** | 30/90/180 ngày | Xoá sớm vẫn trả đủ |
| **Kích thước tính tiền tối thiểu 128 KB** | IA và Glacier IR | File 4 KB trong Standard-IA bị tính như 128 KB — **gấp 32 lần** |
| **Version cũ + multipart dở dang** | Lưu trữ vô hình | Không hiện trong danh sách object |

Hai hệ quả kiến trúc: (1) **đừng đưa file nhỏ vào IA/Glacier** — gom lại (tar,
parquet) rồi mới hạ tầng, vì bucket toàn file 4 KB thì lifecycle sang Standard-IA
làm hoá đơn **tăng**; (2) **đặt CloudFront trước bucket phục vụ nội dung công khai**
— không phải vì tốc độ mà vì phí egress, và đây là đáp án cho *"giảm chi phí phục vụ
nội dung tĩnh"*.

*Con số giá cụ thể thay đổi theo thời gian — kiểm tra lại trang pricing chính thức
trước khi tin.*

---

## Bảng quyết định

| Tình huống trong đề | Chọn | Không chọn, vì |
|---|---|---|
| Không biết access pattern, hoặc pattern thay đổi | **Intelligent-Tiering** | Standard-IA: đọc nhiều là dính phí retrieval |
| Backup, cần lấy lại trong vài giờ, giữ 1 năm | **Glacier Flexible Retrieval** | Glacier IR: đắt hơn mà không cần tức thì |
| Log tuân thủ, giữ 7 năm, gần như không đọc | **Glacier Deep Archive** | Mọi lớp khác đều đắt hơn |
| Ảnh thumbnail, tạo lại được, ít đọc | **One Zone-IA** | Standard-IA: trả tiền cho 3 AZ mà không cần |
| Dữ liệu y tế, ít đọc, mất là chết | **Standard-IA** | One Zone-IA: mất AZ là mất dữ liệu |
| Cần audit ai giải mã object nào | **SSE-KMS** | SSE-S3: không có CloudTrail cho từng lần dùng khoá |
| "AWS không được giữ khoá của tôi" | **SSE-C** hoặc **client-side** | SSE-S3/KMS: AWS giữ khoá |
| Bucket SSE-KMS bị throttle, chi phí KMS cao | **S3 Bucket Keys** | Đổi sang SSE-S3: mất tính năng audit |
| Cho khách tải file riêng tư, không có tài khoản AWS | **Presigned URL** | Mở bucket public: hở toàn bộ |
| Cho người dùng upload thẳng, không qua server | **Presigned PUT/POST** | Proxy qua EC2: tốn băng thông và compute |
| Người dùng toàn cầu upload file lớn | **Transfer Acceleration** | CloudFront: tối ưu cho đọc, không phải ghi |
| Người dùng toàn cầu **tải** nội dung tĩnh | **CloudFront + OAC** | Transfer Acceleration: sai chiều |
| Chống xoá nhầm | **Versioning** (+ MFA Delete) | Chỉ backup: mất thời gian khôi phục |
| Tuân thủ WORM, không ai được xoá kể cả root | **S3 Object Lock (Compliance)** | MFA Delete: root vẫn xoá được |
| Nhân bản sang region khác cho DR | **CRR** | Backup thủ công: RPO tệ |
| Gom log nhiều bucket cùng region về một chỗ | **SRR** | CRR: trả phí cross-region vô ích |
| Chia sẻ dataset lớn, không chịu phí egress | **Requester Pays** | Bucket public: bạn trả tiền cho cả thế giới |
| Resize ảnh ngay khi upload | **Event Notification → Lambda** | Polling: chậm và tốn LIST request |
| Nhiều consumer, lọc phức tạp, cần replay | **EventBridge** | SNS/SQS trực tiếp: filter hạn chế |
| Cập nhật nội dung CDN, chi phí thấp nhất | **Tên file có hash** | Invalidation: trả tiền mỗi path |

## Số phải thuộc

| Con số | Giá trị |
|---|---|
| Durability mọi storage class | **99,999999999%** (11 số 9) |
| Availability S3 Standard | **99,99%** (thiết kế) |
| Min duration | Standard-IA / One Zone-IA: **30 ngày**; Glacier IR / Flexible: **90 ngày**; Deep Archive: **180 ngày** |
| Min billable object size | **128 KB** cho IA và Glacier IR |
| Ngưỡng monitor của Intelligent-Tiering | Object **< 128 KB** không được monitor |
| Glacier Flexible restore | Expedited **1–5 phút** · Standard **3–5 giờ** · Bulk **5–12 giờ** |
| Deep Archive restore | Standard **trong 12 giờ** · Bulk **trong 48 giờ** |
| Request rate mỗi prefix | **3.500** PUT/COPY/POST/DELETE · **5.500** GET/HEAD mỗi giây |
| Object tối đa | **48,8 TiB** · PUT một lần tối đa **5 GiB** |
| Multipart | **10.000 part**, mỗi part **5 MiB – 5 GiB**, khuyến nghị dùng từ **100 MB** |
| Presigned URL hạn tối đa | **7 ngày** (ký bằng IAM user credential) |
| CloudFront invalidation miễn phí | **1.000 path/tháng** |
| Bucket policy tối đa | **20 KB** |
| Consistency | **Strong read-after-write**, mọi region, mọi PUT/DELETE |

## Bẫy kinh điển

**"Glacier là một dịch vụ riêng."** Không, chúng là **storage class của S3**. Object
vẫn nằm trong bucket, vẫn dùng S3 API. (Có dịch vụ Amazon S3 Glacier độc lập kiểu
vault từ thời xưa, nhưng SAA-C03 hỏi về storage class.)

**"One Zone-IA kém bền hơn."** Sai. Durability vẫn 11 số 9. Cái kém là
**availability (99,5%)** và **khả năng chịu mất AZ**. Đọc kỹ đề: "durable" và
"available" là hai từ khác nhau.

**"Chuyển sang Standard-IA thì luôn rẻ hơn."** Không, nếu bạn còn đọc thường xuyên
(phí retrieval), hoặc file nhỏ hơn 128 KB (bị tính tròn lên), hoặc xoá trước 30 ngày.

**"Xoá object là xoá thật."** Với versioning bật thì không — chỉ thêm delete marker.
Đây là lý do bucket "trống" vẫn không xoá được và vẫn tính tiền.

**"Tắt versioning để dọn version cũ."** Tắt không được, chỉ suspend. Và suspend
không xoá gì cả. Phải dùng `NoncurrentVersionExpiration` hoặc xoá từng version.

**"S3 là eventually consistent."** Không còn đúng từ 12/2020. Strong read-after-write
cho object; chỉ **cấu hình mức bucket** mới eventual.

**"Block Public Access chặn cả CloudFront."** Không. BPA chỉ chặn **truy cập ẩn danh
/ public**. CloudFront qua OAC là request **đã ký SigV4** bằng service principal —
đó là truy cập có xác thực, đi qua bucket policy bình thường.

**"Bucket policy cho phép `cloudfront.amazonaws.com` là đủ an toàn."** Không, thiếu
`AWS:SourceArn` thì mọi distribution của mọi người đều đọc được — confused deputy.

**"CRR nhân bản luôn cả dữ liệu cũ."** Không, chỉ object tạo **sau** khi bật rule.
Dữ liệu cũ cần **S3 Batch Replication**.

**"MFA Delete chống được mọi kiểu xoá."** Nó chống xoá version và chống tắt
versioning, do root thao tác. Yêu cầu WORM thật sự (kể cả root cũng không xoá được)
là **Object Lock Compliance mode**.

**"Invalidation là cách chuẩn để cập nhật CDN."** Là cách đắt. Cách chuẩn là đổi
tên file (hash) — URL mới không có cache cũ.

**"Bucket 1 GB thì rẻ."** Nếu là 1 triệu file 1 KB được đọc liên tục, phí request
và phí egress sẽ vượt xa phí lưu trữ của một bucket 1 TB nằm im.

## Nối với lab

[`../../learn-aws/labs/w04-s3-cloudfront/`](../../learn-aws/labs/w04-s3-cloudfront/)

Lab tuần 4 gần như **$0** và **đáng giữ lại** — capstone tuần 6 sẽ nối API vào
chính distribution này.

| Khái niệm trong bài | Quan sát gì khi chạy lab |
|---|---|
| **OAC + bucket đóng hoàn toàn** | `verify.sh` mục 2 phải trả **403** khi gọi thẳng URL S3. Block Public Access bật 4/4, static website hosting tắt |
| **Confused deputy** | Đọc điều kiện `AWS:SourceArn` trong bucket policy. Thử bỏ nó đi và tự giải thích lỗ hổng |
| **Delete marker** | `ansible-playbook site.yml --tags versioning`: ghi đè 3 lần, xoá, thấy file biến mất mà 4 version vẫn còn và vẫn tính tiền. Khôi phục = xoá delete marker |
| **Lifecycle dọn tiền** | `noncurrent_version_expiration` và `abort_incomplete_multipart_upload` — hai bẫy tiền được cài sẵn trong code |
| **Presigned URL** | `--tags presigned`: tạo URL, đợi hết hạn, gọi lại để thấy lỗi |
| **Explicit Deny thắng tất cả** | `enable_ip_restriction=true` làm **website hỏng**, vì CloudFront gọi từ IP edge chứ không phải IP của bạn. Đây là xung đột policy thật |
| **Điều kiện của CRR** | `enable_crr=true` → kiểm chứng file được nhân bản → **tắt ngay**. Object cũ **không** được nhân bản |
| **Invalidation vs versioned filename** | `--tags deploy` chạy invalidation. Xem header `x-cache` đổi giữa `Miss from cloudfront` và `Hit from cloudfront` |
| **Dọn dẹp** | Bucket có versioning không xoá được nếu chưa xoá hết version — lý do `force_destroy = true`. Và **đừng quên bucket ở region thứ hai** |

## Tự kiểm tra

<details>
<summary>1. Bạn xoá hết file trong console, bucket hiện trống, nhưng xoá bucket báo "not empty". Vì sao?</summary>

Versioning đang bật. `DeleteObject` không xoá gì cả — nó đặt một **delete marker**
(object 0 byte) lên trên cùng, khiến object biến mất khỏi `ListObjects`. Mọi version
cũ vẫn còn, vẫn chiếm chỗ, vẫn tính tiền. Muốn xoá bucket phải xoá **từng version
và từng delete marker** theo `versionId`, hoặc dùng lifecycle rule, hoặc
`force_destroy = true` trong Terraform.
</details>

<details>
<summary>2. Bucket chứa 10 triệu ảnh thumbnail, mỗi ảnh 8 KB, đọc vài lần mỗi tháng. Lifecycle sang Standard-IA có tiết kiệm không?</summary>

**Không, sẽ đắt hơn.** Standard-IA có kích thước tính tiền tối thiểu **128 KB**:
file 8 KB bị tính như 128 KB, tức **gấp 16 lần** dung lượng thật. Cộng thêm phí
retrieval mỗi lần đọc. Cách đúng: giữ Standard, hoặc gom nhiều thumbnail vào một
object lớn hơn trước khi hạ tầng. Nếu thumbnail tạo lại được từ ảnh gốc thì
**One Zone-IA** đáng cân nhắc — nhưng vẫn dính ngưỡng 128 KB.
</details>

<details>
<summary>3. Đề: "Dữ liệu phải mã hoá, phải audit được ai đã giải mã object nào, và khoá phải xoay hằng năm." Chọn gì?</summary>

**SSE-KMS với customer managed key**. Ba yêu cầu ánh xạ đúng ba tính năng: mã hoá
phía server, **CloudTrail ghi lại từng lần gọi `kms:Decrypt`** kèm principal, và
**automatic key rotation** hằng năm. SSE-S3 mã hoá được nhưng không cho audit theo
khoá và bạn không kiểm soát vòng đời khoá. Nếu bucket có lưu lượng cao thì bật thêm
**S3 Bucket Keys** để không bị KMS throttle.
</details>

<details>
<summary>4. Website chạy qua CloudFront + OAC. Bạn thêm bucket policy Deny cho mọi IP trừ IP văn phòng. Website hỏng. Vì sao, và sửa ở đâu?</summary>

CloudFront gọi origin từ **IP của edge location**, không phải IP của bạn. Điều kiện
Deny theo `aws:SourceIp` khớp và **explicit Deny thắng mọi Allow**, kể cả Allow dành
cho `cloudfront.amazonaws.com`. Giới hạn IP cho người dùng cuối **không thuộc về
bucket policy** — nó thuộc tầng edge: **AWS WAF** gắn vào CloudFront distribution
với IP set rule, hoặc CloudFront geo/signed URL. Bucket chỉ nên biết một điều: chỉ
CloudFront distribution này được đọc.
</details>

<details>
<summary>5. Bạn bật CRR sang region khác. Nửa giờ sau bucket đích vẫn trống dù bucket nguồn có 500 GB. Vì sao?</summary>

Replication **chỉ áp dụng cho object được tạo sau khi rule có hiệu lực**. 500 GB
kia là dữ liệu cũ, nó sẽ không bao giờ tự sang. Cần chạy **S3 Batch Replication**
cho dữ liệu hiện có. Kiểm tra thêm: cả hai bucket đã bật versioning chưa, IAM role
đã có quyền `s3:ReplicateObject` trên bucket đích chưa.
</details>

<details>
<summary>6. Vì sao đặt CloudFront trước một bucket public giúp giảm hoá đơn, dù CloudFront cũng tính tiền?</summary>

Vì phí **data transfer out từ S3 ra internet** đắt hơn phí egress của CloudFront, và
quan trọng hơn: CloudFront **cache ở edge**, nên phần lớn request không bao giờ chạm
tới S3 — bạn tiết kiệm cả phí egress **lẫn** phí GET request. Trong lộ trình này còn
có yếu tố thứ ba: CloudFront có **1 TB egress + 10 triệu request mỗi tháng always
free**, S3 thì không.
</details>

<details>
<summary>7. Ứng dụng ghi 10.000 file/giây vào `s3://logs/2026-08-17/`. Bạn nhận HTTP 503 SlowDown. Sửa thế nào?</summary>

Trần là **3.500 PUT/COPY/POST/DELETE mỗi giây trên mỗi prefix**. Toàn bộ ghi đang dồn
vào một prefix duy nhất. Cách sửa là **rải ra nhiều prefix** — ví dụ thêm một tầng
phân mảnh `logs/2026-08-17/<shard>/...` với 8–16 shard, hoặc đảo thứ tự khoá để
phần biến thiên nhanh nằm gần đầu. Không giới hạn số prefix, nên throughput mở rộng
tuyến tính. Đồng thời bật exponential backoff (SDK đã có sẵn) vì S3 cần thời gian
để tự phân vùng lại.
</details>

<details>
<summary>8. Đề: "Người dùng ở Úc upload video 5 GB lên bucket tại us-east-1, quá chậm." Chọn gì? Còn nếu là tải xuống?</summary>

Upload → **S3 Transfer Acceleration**: request đi vào edge location gần nhất ở Úc
rồi chạy trên backbone của AWS về us-east-1, tránh đường internet công cộng. Kết
hợp với **multipart upload** để tải song song nhiều part và retry được từng part.

Tải xuống → **CloudFront**. Transfer Acceleration tối ưu chiều ghi; CloudFront cache
nội dung ở edge nên lần tải thứ hai trở đi không chạm tới origin.
</details>

<details>
<summary>9. Vì sao S3 Event Notification bắt buộc consumer phải idempotent?</summary>

Vì nó là **at-least-once**: cùng một sự kiện có thể được gửi hai lần. Nếu Lambda
của bạn "tăng bộ đếm" hoặc "cộng tiền" thì lần gửi trùng sẽ làm sai dữ liệu. Thiết
kế đúng là đặt khoá idempotency từ `bucket + key + versionId + eventName` rồi bỏ
qua bản trùng. Chi tiết đi kèm: bucket có versioning thì sự kiện bắn cho **mỗi
version**, không phải mỗi key.
</details>

<details>
<summary>10. Bạn cho phép người dùng upload trực tiếp lên S3 bằng presigned PUT. Rủi ro lớn nhất là gì?</summary>

Presigned URL kế thừa **toàn bộ quyền của principal đã ký nó**. Nếu backend ký bằng
credential admin thì URL đó cũng mạnh tương ứng trong phạm vi thao tác đã ký — và
nếu bạn ký cẩu thả (key do client tự đặt), người dùng có thể **ghi đè object của
người khác**. Cách làm đúng: ký bằng một role tối thiểu quyền, **server tự sinh key**
(thêm prefix theo user ID), đặt hạn ngắn, và dùng **presigned POST** với policy giới
hạn `content-length-range` cùng `Content-Type` để chặn upload file khổng lồ hoặc sai
loại.
</details>

## Ngoài phạm vi

- **S3 Object Lambda, S3 Select, S3 Storage Lens chi tiết** — biết chúng tồn tại
  là đủ. [Tài liệu](https://docs.aws.amazon.com/AmazonS3/latest/userguide/transforming-objects.html)
- **S3 Express One Zone và directory bucket** — mới, chưa vào SAA-C03. Nhận diện
  "single-digit millisecond, một AZ" là đủ.
- **S3 Tables, S3 Vectors** — ngoài phạm vi hoàn toàn.
- **S3 Access Points và Multi-Region Access Points** — biết access point tồn tại để
  quản lý quyền cho dataset dùng chung.
- **CloudFront Functions, Lambda@Edge, signed URL/cookie, WAF** — [tuần 8](w08-dns-cdn-edge.md).
- **FSx (Windows / Lustre / ONTAP / OpenZFS) chi tiết** — chỉ cần nhận diện use case,
  đã nói ở [tuần 3](w03-ec2-alb-asg.md).
- **AWS Backup, Snowball, DataSync, Storage Gateway** — [tuần 11](w11-dr-hybrid.md).

## Nguồn

- [Understanding and managing Amazon S3 storage classes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html)
- [What is Amazon S3? — data consistency model, buckets, keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)
- [Understanding archive retrieval options](https://docs.aws.amazon.com/AmazonS3/latest/userguide/restoring-objects-retrieval-options.html)
- [Amazon S3 multipart upload limits](https://docs.aws.amazon.com/AmazonS3/latest/userguide/qfacts.html)
- [Performance design patterns for Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/optimizing-performance-design-patterns.html)
- [Managing the lifecycle of objects](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [Retaining multiple versions of objects with S3 Versioning](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
- [Configuring MFA delete](https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiFactorAuthenticationDelete.html)
- [Blocking public access to your Amazon S3 storage](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
- [Protecting data with encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingEncryption.html)
- [Reducing the cost of SSE-KMS with Amazon S3 Bucket Keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html)
- [Replicating objects within and across Regions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [Amazon S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html)
- [Using Requester Pays buckets](https://docs.aws.amazon.com/AmazonS3/latest/userguide/RequesterPaysBuckets.html)
- [Configuring Transfer Acceleration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/transfer-acceleration.html)
- [Restricting access to an Amazon S3 origin (OAC)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
