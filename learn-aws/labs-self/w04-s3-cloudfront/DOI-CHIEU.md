# Đối chiếu — tuần 4

> Đọc sau khi `./verify.sh` xanh, kể cả bốn check phủ định.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong đề | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1 — một địa chỉ HTTPS, người đọc ở khắp thế giới | CDN, edge location, origin, TTL | [CloudFront ở mức đủ cho lab](../../../docs/aws/w04-s3-cloudfront.md#14-cloudfront-ở-mức-đủ-cho-lab) |
| 2 — qua cửa hàng thì được, vào thẳng kho thì 403 | **Origin Access Control**, resource policy có `Principal` là dịch vụ | [Bảo mật S3](../../../docs/aws/w04-s3-cloudfront.md#7-bảo-mật-s3--bốn-cơ-chế-và-thứ-tự-đánh-giá) · [Kiểm soát truy cập](../../../docs/notebook/02-storage.md#8-kiểm-soát-truy-cập) |
| 2 (điều kiện `aws:SourceArn`) | **confused deputy** | [Confused deputy](../../../docs/aws/w04-s3-cloudfront.md#confused-deputy--bẫy-security-hay-ra-thi) · [Luồng đánh giá quyền](../../../docs/notebook/05-security.md#2-luồng-đánh-giá-quyền--sáu-cửa-một-request-phải-qua) |
| 3 — bốn khoá chặn public | Block Public Access, và vì sao nó đứng **trên** cả bucket policy | [Thứ tự đánh giá](../../../docs/aws/w04-s3-cloudfront.md#thứ-tự-đánh-giá) |
| 4 — http:// bị chuyển hướng | viewer protocol policy; `aws:SecureTransport` | [Kiểm soát truy cập](../../../docs/notebook/02-storage.md#8-kiểm-soát-truy-cập) |
| 5 — nén trước khi truyền | CDN compression; cache policy phải chuyển tiếp `Accept-Encoding` | [CloudFront](../../../docs/aws/w04-s3-cloudfront.md#14-cloudfront-ở-mức-đủ-cho-lab) |
| 6 — trúng cache ở biên | cache hit ratio, TTL, `x-cache` | như trên |
| 7 — khôi phục bản cũ | versioning, **delete marker**, `null` version | [Versioning](../../../docs/aws/w04-s3-cloudfront.md#5-versioning-delete-marker-mfa-delete) · [sổ tay](../../../docs/notebook/02-storage.md#5-versioning-delete-marker-mfa-delete) |
| 8 — rác tự dọn | lifecycle rule trên **noncurrent version**; `AbortIncompleteMultipartUpload` | [Lifecycle](../../../docs/aws/w04-s3-cloudfront.md#4-lifecycle-policy) · [Những quy tắc ngầm](../../../docs/notebook/02-storage.md#4-lifecycle--những-quy-tắc-ngầm) |
| 9 — mã hoá khi lưu | SSE-S3 vs SSE-KMS vs SSE-C | [Mã hoá](../../../docs/aws/w04-s3-cloudfront.md#8-mã-hoá) · [sổ tay](../../../docs/notebook/02-storage.md#7-mã-hoá-s3) |
| price class, 1 TB miễn phí | Domain 4: tiền của CDN đi đâu | [Tiền đi đâu](../../../docs/aws/w04-s3-cloudfront.md#15-tiền-đi-đâu--bảng-quan-trọng-nhất-của-domain-4) · [Ngưỡng hoà vốn](../../../docs/notebook/10-chi-phi.md#4-s3-storage-class-và-lifecycle--ngưỡng-hòa-vốn-thật) |

### Ba dòng bạn viết ra, và ba lỗ hổng chúng bịt

Đây là phần đáng nhớ nhất của lab, vì nó là ba tầng khác nhau của cùng một câu
hỏi "ai được đọc kho này":

```
Block Public Access (4/4)     -> chặn ở tầng TÀI KHOẢN + BUCKET
                                 kể cả khi bạn lỡ viết một policy public,
                                 AWS bỏ qua policy đó. Đây là lưới an toàn
                                 chống chính bạn.

Principal = cloudfront...     -> ai được vào. Không phải người, mà là DỊCH VỤ.
                                 Đây là chỗ 90% người học dừng lại — và dừng
                                 ở đây là để lại một cửa sau.

Condition aws:SourceArn = ARN -> dịch vụ đó, NHƯNG chỉ khi nó đang hành động
  của phân phối CỦA BẠN          thay mặt đúng phân phối của bạn.
```

Bỏ dòng thứ ba đi thì bất kỳ ai trên thế giới cũng có thể tạo một phân phối
CloudFront trỏ vào kho của bạn — và CloudFront, một cách hoàn toàn đúng luật,
sẽ ký request bằng chính principal mà policy của bạn đã cho phép. Bạn không bị
hack; bạn bị **mượn tay**. Tên của lỗ hổng là **confused deputy**, và tuần 1
bạn đã gặp nó dưới tên `external ID`.

---

## Ba cách khác để giải bài này

### Cách A — S3 static website hosting, bucket policy `Principal: "*"`, không CDN

Bật tính năng phục vụ web sẵn có của kho, mở bucket policy cho tất cả, đưa
endpoint `http://<bucket>.s3-website-us-east-1.amazonaws.com` cho người đọc.

- **Tốt hơn khi:** không có gì tốt hơn trong bài này. Nó tốt hơn duy nhất ở chỗ
  *ít dòng cấu hình hơn* và không phải chờ 15 phút triển khai — nên nó là đáp
  án đúng cho một bản demo nội bộ sống 30 phút.
- **Tệ hơn ở chỗ:** vi phạm cả ba yêu cầu bảo mật cùng lúc. Endpoint website
  **không có HTTPS** — nó chỉ nói HTTP, nên yêu cầu 4 không thể đạt bằng bất kỳ
  cách nào. Kho public thì liệt kê được nếu bạn lỡ cho `s3:ListBucket`. Và
  không có edge cache, nên người đọc ở Brazil vẫn phải đi hết một vòng tới
  `us-east-1`.
- **Đề thi hỏi thế nào:** thấy *"bucket must not be publicly accessible"*,
  *"serve over HTTPS"*, *"custom domain"*, *"low latency worldwide"* → loại
  ngay đáp án static website hosting. Thấy *"simplest possible"*, *"internal
  test"* → nó có thể là đáp án. Một mẹo đọc đề: nếu câu hỏi nhắc tới **HTTPS**
  thì S3 static website hosting **luôn** là đáp án sai, vì nó không hỗ trợ.

### Cách B — presigned URL sinh từ một backend

Kho đóng kín. Một dịch vụ nhỏ (Lambda, hoặc server ứng dụng) xác thực người
dùng rồi ký một URL có hạn cho từng object.

- **Tốt hơn khi:** nội dung **không công khai**. Hoá đơn của từng khách hàng,
  video khoá học đã trả tiền, file xuất báo cáo. Presigned URL mang theo danh
  tính của người ký và hết hạn — đó là hai thứ CDN + OAC không cho bạn.
  Nó cũng là cách cho phép **upload** trực tiếp vào kho mà không cho ai quyền
  gì lâu dài (`presigned PUT`) — mẫu này ra thi rất nhiều.
- **Tệ hơn ở chỗ:** không có cache ở biên, nên mỗi lượt tải đều đi tới region
  gốc và tính tiền data transfer đắt hơn. Mỗi file cần một lần ký, nên một
  trang web 60 file tĩnh là 60 URL. Và URL đã ký thì **chuyển tay được**: ai
  cầm được link đều tải được cho tới lúc hết hạn.
- **Đề thi hỏi thế nào:** thấy *"temporary access"*, *"without granting IAM
  permissions"*, *"users upload directly to S3"*, *"expires after N minutes"*
  → presigned URL. Thấy *"publicly available content"*, *"reduce latency for
  global users"* → CDN.

### Cách C — CDN + signed URL / signed cookie (nội dung riêng tư qua CDN)

Vẫn là phân phối CDN trước kho đã khoá, nhưng thêm một tầng: chỉ request mang
chữ ký hợp lệ mới được edge phục vụ.

- **Tốt hơn khi:** bạn cần **cả hai** — cache ở biên *và* kiểm soát ai xem.
  Đây là kiến trúc thật của mọi nền tảng video trả tiền. Signed **cookie** khi
  người dùng cần xem nhiều file (một khoá học 200 bài giảng); signed **URL**
  khi chỉ một file, hoặc khi client không giữ được cookie (ứng dụng di động).
- **Tệ hơn ở chỗ:** phải quản lý một cặp khoá ký và một key group, phải có chỗ
  chạy code để ký, và mọi lỗi cấu hình đều biểu hiện thành 403 giống hệt lỗi
  OAC — rất khó chẩn đoán. Với nội dung công khai như tài liệu kỹ thuật thì đây
  là độ phức tạp không đổi lấy gì.
- **Đề thi hỏi thế nào:** thấy *"restrict access to premium content"*,
  *"only paying subscribers"*, kèm *"CloudFront"* → signed URL/cookie. Thấy
  *"multiple files"*, *"entire section of the site"* → signed **cookie**, không
  phải signed URL. Đây là chỗ phân biệt duy nhất giữa hai đáp án và đề thi biết.

### Bảng quyết định rút ra

| Đề nói | Chọn |
|---|---|
| "nội dung tĩnh công khai, người dùng toàn cầu, HTTPS" | **CloudFront + S3 + OAC** |
| "bucket không được public, nhưng CloudFront phải đọc được" | **OAC** (OAI là bản cũ, chọn khi đề nhắc legacy) |
| "chặn mọi phân phối CloudFront của tài khoản khác" | điều kiện **`aws:SourceArn`** trong bucket policy |
| "quyền truy cập tạm thời, hết hạn sau N phút" | **presigned URL** |
| "người dùng upload thẳng lên S3, không cấp IAM" | **presigned PUT** |
| "chỉ thuê bao trả tiền xem được, qua CDN" | **signed URL / signed cookie** |
| "nhiều file, cả một khu vực của trang" | signed **cookie** |
| "upload file lớn từ nơi rất xa region" | **Transfer Acceleration** (không phải CloudFront) |
| "giảm chi phí lưu trữ bản cũ" | **lifecycle** trên noncurrent version |
| "khôi phục file đã xoá nhầm" | **versioning** + xoá delete marker |
| "không ai được xoá vĩnh viễn trong N năm" | **Object Lock** (compliance mode) |

---

## Nếu đề thi hỏi

<details><summary>Câu 1 — Công ty phục vụ nội dung tĩnh cho người dùng toàn cầu. Chính sách bảo mật cấm mọi S3 bucket public. Nội dung phải qua HTTPS và có độ trễ thấp. Giải pháp nào TỐT NHẤT?</summary>

**A.** Bật S3 static website hosting, thêm bucket policy cho phép `Principal: "*"`.
**B.** CloudFront với Origin Access Control, bucket giữ Block Public Access bật 4/4, bucket policy cho phép `cloudfront.amazonaws.com` với điều kiện `aws:SourceArn`.
**C.** Đặt một ALB trước bucket và bật TLS trên listener.
**D.** Sinh presigned URL cho từng object và nhúng vào trang HTML.

**Đáp án: B.**

- **A sai hai lần**: bucket thành public (vi phạm chính sách), và endpoint
  static website **không nói HTTPS**. Bất cứ khi nào đề nhắc HTTPS mà đáp án là
  static website hosting, đó là đáp án sai.
- **C sai vì một sự thật kỹ thuật**: ALB **không** nhận S3 làm target. Target
  của ALB là instance, IP, hoặc Lambda. Đây là kiểu đáp án nghe hợp lý với
  người chưa từng thử.
- **D chạy được nhưng tệ**: không cache ở biên, phải sinh URL cho từng file,
  URL hết hạn nên trang tĩnh sẽ vỡ sau vài giờ.
- **B đúng**: đây chính là thứ bạn vừa dựng, và mệnh đề `aws:SourceArn` là
  phần mà đề thi dùng để phân biệt người hiểu với người thuộc lòng.

</details>

<details><summary>Câu 2 — Bucket policy cho phép `Principal: {"Service": "cloudfront.amazonaws.com"}` với `s3:GetObject`, không có Condition nào. Rủi ro là gì?</summary>

**A.** Không có rủi ro, chỉ CloudFront đọc được và CloudFront là dịch vụ của AWS.
**B.** Bất kỳ ai cũng có thể tạo một CloudFront distribution trỏ vào bucket này và đọc được nội dung.
**C.** CloudFront sẽ không đọc được vì thiếu `s3:ListBucket`.
**D.** Bucket bị AWS đánh dấu là public và Block Public Access sẽ chặn CloudFront.

**Đáp án: B.**

- **A là bẫy chính**: "dịch vụ của AWS" không có nghĩa là "dịch vụ đang hành
  động thay mặt bạn". Principal là *dịch vụ*, không phải *tài khoản của bạn*.
- **C sai**: `s3:GetObject` là đủ để tải một object đã biết key. `ListBucket`
  chỉ cần để liệt kê — và bạn **không** muốn cấp nó.
- **D sai**: policy có `Principal` là một Service, không phải `"*"`, nên
  `get-bucket-policy-status` trả `IsPublic: false` và BPA không can thiệp. Đây
  chính là lý do lỗ hổng này **im lặng**: mọi công cụ kiểm tra "bucket có public
  không" đều báo xanh.
- **B đúng**: đây là **confused deputy**. Thiếu `aws:SourceArn` (hoặc
  `aws:SourceAccount`), request từ phân phối của người lạ vẫn khớp policy.
  Cùng một mẫu với `external ID` của tuần 1, với `aws:SourceArn` của SNS/SQS,
  và với mọi lần một dịch vụ AWS gọi hộ bạn.

</details>

<details><summary>Câu 3 — Bucket bật versioning chứa 500 GB. Người dùng "đã xoá" 400 GB tháng trước nhưng hoá đơn không giảm. Vì sao, và sửa thế nào?</summary>

**A.** S3 tính tiền theo dung lượng đỉnh trong tháng; hoá đơn sẽ giảm ở chu kỳ sau.
**B.** Xoá trong bucket có versioning chỉ tạo delete marker; các version cũ vẫn tồn tại và vẫn tính tiền. Thêm lifecycle rule `NoncurrentVersionExpiration`.
**C.** Cần bật Intelligent-Tiering để S3 tự xoá dữ liệu không dùng.
**D.** Cần chạy `aws s3 rm --recursive` lại vì lần đầu thất bại im lặng.

**Đáp án: B.**

- **A sai**: S3 tính theo GB-tháng thực dùng, không theo đỉnh.
- **C sai và đây là hiểu nhầm nguy hiểm**: Intelligent-Tiering **chuyển tầng**
  theo tần suất truy cập, nó **không bao giờ xoá** gì cả. Không lớp lưu trữ nào
  tự xoá dữ liệu.
- **D sai**: lệnh đó đã thành công — nó tạo delete marker, đúng như thiết kế.
- **B đúng**: đây đúng là 4 GB bản nháp của đội tài chính trong đề bài, phóng
  to lên 400 GB. Điểm phải nhớ: **xoá một object trong bucket có versioning
  không làm bucket nhỏ đi**, nó chỉ làm object *biến mất khỏi tầm nhìn*. Và
  `NoncurrentVersionExpiration` là quy tắc khác hẳn với `Expiration` — quy tắc
  thứ hai không đụng tới version cũ.

</details>

<details><summary>Câu 4 — Đội deploy trang tĩnh nhiều lần mỗi ngày. Sau mỗi lần deploy, người dùng vẫn thấy bản cũ trong nhiều giờ. Cách nào TỐT NHẤT về lâu dài?</summary>

**A.** Tạo CloudFront invalidation `/*` sau mỗi lần deploy.
**B.** Đặt TTL của cache behavior về 0.
**C.** Thêm hash nội dung vào tên file (`app.9f2c1a.js`) và tham chiếu tên mới trong HTML, HTML thì để TTL ngắn.
**D.** Tắt cache của CloudFront và bật cache ở trình duyệt.

**Đáp án: C.**

- **A chạy được nhưng không phải "tốt nhất"**: 1.000 đường dẫn đầu mỗi tháng
  miễn phí, sau đó $0,005/đường dẫn — và `/*` tính là **một** đường dẫn nên tiền
  không phải vấn đề lớn. Vấn đề thật là invalidation mất vài phút để lan ra mọi
  edge, và trong lúc đó người dùng thấy trạng thái lẫn lộn giữa hai phiên bản.
- **B huỷ toàn bộ lợi ích của CDN**: mọi request đi về origin, độ trễ về như cũ,
  hoá đơn S3 request tăng vọt.
- **D là B nói bằng chữ khác**, cộng thêm việc cache trình duyệt không kiểm
  soát được.
- **C đúng**: file có nội dung khác thì có **URL khác**, nên không có gì để làm
  mất hiệu lực cả. Đặt TTL rất dài cho asset có hash, TTL ngắn (hoặc
  `no-cache`) cho file HTML điều phối. Đây là cách mọi công cụ build hiện đại
  làm, và cũng là đáp án chuẩn của đề thi cho cụm từ *"without invalidation
  costs"* hoặc *"immediately visible"*.

</details>

<details><summary>Câu 5 — Yêu cầu: dữ liệu mã hoá khi lưu, phải kiểm toán được AI đã dùng khoá nào để giải mã, và phải xoay khoá hằng năm. Chọn cơ chế nào?</summary>

**A.** SSE-S3 (AES256).
**B.** SSE-KMS với customer managed key.
**C.** SSE-C, client tự gửi khoá theo mỗi request.
**D.** Client-side encryption với khoá tự quản lý.

**Đáp án: B.**

- **A sai ở đúng một chỗ**: SSE-S3 mã hoá thật, miễn phí, nhưng **không để lại
  dấu vết CloudTrail cho từng lần dùng khoá** và bạn không kiểm soát vòng đời
  khoá. Khi đề nhắc *audit* hoặc *rotation*, SSE-S3 bị loại.
- **C sai**: SSE-C bắt client gửi khoá kèm **mỗi** request; AWS không lưu khoá
  nên cũng không kiểm toán được, và mất khoá là mất dữ liệu vĩnh viễn.
- **D quá sức yêu cầu**: mã hoá phía client là đáp án khi đề nói *"AWS must
  never have access to the plaintext or the keys"*.
- **B đúng**: customer managed KMS key cho bạn key policy riêng, log
  `kms:Decrypt` trong CloudTrail kèm danh tính người gọi, và rotation tự động
  hằng năm. Cái giá: $1/tháng mỗi khoá cộng phí request — chính là lý do lab
  này cấm tạo KMS key. Nhớ thêm **S3 Bucket Keys** giảm tới 99% số lần gọi KMS,
  đề thi hỏi nó trong câu về chi phí KMS.

</details>

<details><summary>Câu 6 — Người dùng ở Singapore upload file 5 GB lên bucket ở us-east-1, rất chậm. Giải pháp nào?</summary>

**A.** Đặt CloudFront trước bucket.
**B.** Bật S3 Transfer Acceleration.
**C.** Tạo bucket thứ hai ở ap-southeast-1 và bật cross-region replication.
**D.** Dùng multipart upload với 100 phần song song.

**Đáp án: B**, và **D** là bổ trợ chứ không thay thế.

- **A sai chiều**: CloudFront tăng tốc **đọc**, không tăng tốc ghi vào origin.
  (Có tính năng upload qua CloudFront, nhưng nó không phải câu trả lời chuẩn
  cho tình huống này và bị giới hạn kích thước.)
- **C giải sai bài toán**: replication chạy **sau khi** file đã lên tới bucket
  gốc, nên nó không làm lần upload đầu tiên nhanh hơn chút nào. Nó còn nhân đôi
  tiền lưu trữ — và trong bộ lab này thì boundary sẽ chặn vì region thứ hai.
- **D là kỹ thuật đúng nhưng không đủ**: multipart giúp tận dụng băng thông và
  cho phép thử lại từng phần, nhưng gói tin vẫn phải đi hết đường công cộng từ
  Singapore tới Virginia.
- **B đúng**: Transfer Acceleration đưa dữ liệu vào **edge gần nhất** rồi đi
  tiếp bằng đường xương sống của AWS. Giá $0,04/GB thêm vào, nên đề thi thường
  đặt nó cạnh câu hỏi "có đáng không". Cặp *upload xa + chậm* → Transfer
  Acceleration; cặp *download xa + chậm* → CloudFront. Nhớ cặp đôi này.

</details>

---

## Chỗ dễ hiểu sai

**"Block Public Access bật rồi thì bucket an toàn."** Nó chặn *public*, không
chặn *sai*. Một bucket policy cho phép `"AWS": "*"` với một điều kiện lỏng lẻo,
hay cho phép một account ID gõ nhầm, vẫn qua được BPA vì nó không phải public
theo định nghĩa của AWS. BPA là lưới chống lỗi ngu, không phải kiểm soát truy
cập.

**"403 nghĩa là đã khoá đúng."** Lab của bạn có hai loại 403 hoàn toàn khác
nhau và chúng trông y hệt: 403 vì kho từ chối *bạn* (đúng), và 403 vì kho từ
chối *CloudFront* (sai, và trang của bạn chết). Khi debug, luôn hỏi **ai** bị
từ chối trước khi hỏi **vì sao**.

**"Cache hit ratio cao là tốt."** Đúng cho nội dung tĩnh. Nhưng CDN cache theo
**cache key**, và nếu bạn đưa quá nhiều thứ vào cache key (mọi header, mọi
query string, mọi cookie) thì mỗi người dùng có một key riêng và tỉ lệ trúng về
gần 0 — cache trở thành một tầng chuyển tiếp tốn tiền. Ngược lại, đưa **quá
ít** vào cache key thì bạn có thể phục vụ nội dung của người này cho người
khác. Cache key là một quyết định bảo mật, không chỉ là quyết định hiệu năng.

**"Versioning là backup."** Không. Versioning bảo vệ khỏi *ghi đè* và *xoá
nhầm* trong cùng một bucket. Nó không bảo vệ khỏi việc bucket bị xoá, khỏi
account bị chiếm, hay khỏi một lifecycle rule viết sai xoá sạch version cũ. Khi
đề thi nói *"ransomware"*, *"malicious insider"*, *"regulatory retention"* thì
đáp án là **Object Lock**, **MFA Delete**, hoặc replication sang một account
khác — không phải versioning một mình.

**Trong production, cái bạn vừa dựng còn thiếu bốn thứ:** tên miền riêng với
chứng chỉ ACM (và ACM cho CloudFront **bắt buộc** nằm ở `us-east-1`, bất kể
bucket ở đâu — một bẫy region ra thi thường xuyên), security header qua
CloudFront Functions, access log để điều tra sự cố, và một quy trình deploy
dùng tên file có hash thay vì invalidation. Lab bỏ cả bốn vì chúng cần một tên
miền phải sở hữu hoặc thêm chi phí — nhưng thiếu chúng thì đây chưa phải kiến
trúc production.
