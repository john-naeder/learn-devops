# Gợi ý — tuần 4

> Mở từng tầng một, và chỉ mở khi đã thật sự kẹt. Mỗi tầng bạn mở sớm là một
> lần bạn đổi việc *nghĩ ra kiến trúc* lấy việc *gõ theo hướng dẫn*.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bài này có bốn khối. Làm và kiểm tra từng khối; đừng viết hết rồi apply một
lần — phân phối CDN mất 5–15 phút mỗi lần tạo lại, và bạn không muốn chờ ba
lần vì ba lỗi khác nhau.

**Khối 1 — nội dung nằm ở đâu.** Một nơi lưu trữ object, một file HTML trong
đó, và file đó dài hơn 1 KB (đọc lại yêu cầu 5 để hiểu vì sao con số này quan
trọng). Kiểm tra bằng cách tải file về từ chính máy bạn bằng credential của
`lab-builder` — bạn có quyền, nên nó phải tải được. Đó là *chưa* giải bài, chỉ
là xác nhận file có thật.

**Khối 2 — cái đứng trước.** Một dịch vụ phân phối nội dung ở biên. Nó cần
biết ba thứ: lấy nội dung ở đâu (origin), phục vụ ai và bằng giao thức nào
(viewer), và giữ bản sao bao lâu (cache). Ba thứ đó là ba nhóm cấu hình khác
nhau và người mới hay trộn lẫn.

**Khối 3 — cái khoá.** Đây là phần thật sự của bài, và nó chỉ có hai câu hỏi:

1. Nếu kho đóng hoàn toàn với internet, thì dịch vụ phân phối lấy nội dung
   bằng **danh tính nào**? Nó không phải là bạn, không phải là một người dùng
   ẩn danh. Nó là gì?
2. Cho phép danh tính đó đọc kho bằng cách nào? Có hai hướng: sửa quyền của
   *bên đọc*, hoặc sửa quyền của *bên bị đọc*. Với một dịch vụ AWS thì chỉ một
   hướng khả thi — hướng nào, và vì sao?

Nếu bạn trả lời được hai câu đó thì phần còn lại chỉ là tra cú pháp.

**Khối 4 — ba yêu cầu về vòng đời dữ liệu.** Ghi đè rồi khôi phục (yêu cầu 7),
tự dọn bản cũ (yêu cầu 8), mã hoá khi lưu (yêu cầu 9). Ba thứ này độc lập với
ba khối trên, làm sau cùng cũng được, và mỗi thứ chỉ là một khối cấu hình gắn
vào kho. Nhưng yêu cầu 7 và 8 gắn với nhau: cái thứ hai tồn tại **vì** cái thứ
nhất tạo ra rác.

Khái niệm cần tra: `origin`, `cache behavior`, `viewer protocol policy`,
`origin access control`, `bucket policy`, `Block Public Access`,
`bucket versioning`, `noncurrent version`, `lifecycle rule`,
`server-side encryption`, `Compress`, `x-cache`, `price class`.

Đọc kèm: `docs/aws/w04-s3-cloudfront.md` mục 7, 14, 15.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Cách cho thế giới đọc nội dung trong kho — bốn lựa chọn, ba sai.**

| Cách | Kho có mở ra internet không | Vấn đề với đề bài này |
|---|---|---|
| Bật static website hosting + bucket policy `Principal: "*"` | **Có** | vi phạm yêu cầu 3 ngay từ câu đầu, và endpoint website không có HTTPS |
| Presigned URL | Không | URL có hạn, phải sinh cho từng file, từng người. Không phục vụ được trang web công khai |
| Phân phối CDN + **origin access identity** (OAI) | Không | chạy được, nhưng AWS gọi nó là **cơ chế cũ**. Nó gắn với một *canonical user*, không hỗ trợ SSE-KMS, không hỗ trợ mọi region mới |
| Phân phối CDN + cơ chế kế nhiệm của OAI | Không | đây là câu trả lời của năm 2024 trở đi |

Câu hỏi giúp bạn tự chốt: cơ chế nào ký request bằng **SigV4** thay vì gắn vào
một canonical user? Tra hai từ khoá `origin access identity` và
`origin access control`, đọc bảng so sánh của AWS, rồi tự chọn.

**Bên đọc hay bên bị đọc.** Một dịch vụ AWS gọi vào S3 thay mặt bạn thì bạn
không gắn identity policy vào nó được — bạn không sở hữu nó. Thứ duy nhất bạn
sở hữu là **kho**. Nên quyền phải viết ở phía kho: đó là một **resource
policy**. Tuần 1 bạn đã viết một cái rồi, khác duy nhất ở chỗ `Principal` lần
này là một dịch vụ chứ không phải một người.

**Và ngay sau đó là bẫy `confused deputy`.** Nếu resource policy của bạn nói
"dịch vụ CDN được đọc kho này", thì **mọi** phân phối CDN của **mọi** tài khoản
AWS trên thế giới đều khớp câu đó. Người khác chỉ cần tạo một phân phối trỏ
vào kho của bạn là đọc được. Cần thêm một **điều kiện** thu hẹp lại còn đúng
một phân phối. Tra khoá điều kiện `aws:SourceArn`. Tuần 1 bạn đã gặp đúng mẫu
này dưới tên `external ID` — cùng một bài toán, hai dịch vụ khác nhau.

**Yêu cầu 4 (bắt buộc HTTPS) làm ở đâu?** Hai chỗ đều hợp lý và chúng chống
lại hai thứ khác nhau:

- Ở phía CDN: một tuỳ chọn của cache behavior quyết định `http://` được phục
  vụ, bị chuyển hướng, hay bị từ chối thẳng. Đây là thứ verify.sh chấm.
- Ở phía kho: một `Deny` khi `aws:SecureTransport` là `false` — đúng cái bạn
  viết ở tuần 1. Nó bảo vệ kho kể cả khi ai đó gọi thẳng, không qua CDN.

Làm cả hai thì tốt hơn, và giải thích được vì sao "cả hai" tốt hơn "một" chính
là câu trả lời cho từ khoá **defence in depth**.

**Yêu cầu 5 và 6 (nén và cache) — đọc kỹ ràng buộc thật của dịch vụ.**
Có ba điều kiện phải đúng *cùng lúc* thì response mới có header nén:
trình duyệt phải khai là hiểu nén, phân phối phải được bật nén, và **cấu hình
cache phải chuyển tiếp header khai báo đó tới tầng quyết định**. Cái thứ ba là
chỗ hỏng thường gặp nhất: nhiều chính sách cache dựng sẵn của AWS *bỏ đi*
header `Accept-Encoding` để tăng tỉ lệ trúng cache. Tra danh sách
**managed cache policy** của AWS và đọc cột "Compression support".

**Yêu cầu 8 — quy tắc vòng đời có mấy loại.** Có ít nhất bốn thứ khác nhau một
quy tắc vòng đời làm được: chuyển bản *hiện hành* sang lớp rẻ hơn, xoá bản
hiện hành, chuyển bản *không còn hiện hành*, xoá bản không còn hiện hành. Đề
bài nói về 4 GB **bản nháp cũ** — đó là loại nào? Và có một loại thứ năm không
liên quan tới version nhưng dọn một loại rác vô hình mà gần như không ai biết:
tra `AbortIncompleteMultipartUpload`.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**Lỗi 1 — CDN trả 403 với body XML `AccessDenied`, cho một file chắc chắn có
thật.** Đây là lỗi phổ biến nhất của lab, và nó gần như luôn nằm trong resource
policy của kho. Kiểm tra theo thứ tự:

1. `Principal` có đúng là dịch vụ CDN không (`cloudfront.amazonaws.com`), hay
   bạn đang để ARN của phân phối ở đó? ARN của phân phối **không phải** một
   principal.
2. Điều kiện `aws:SourceArn` có khớp **đúng ARN của phân phối** không? Đây là
   chỗ dễ tạo vòng lặp phụ thuộc: policy cần ARN của phân phối, phân phối cần
   kho đã sẵn sàng. Terraform giải được vòng này (phân phối không phụ thuộc vào
   policy), nhưng nếu bạn viết nhầm thành phụ thuộc hai chiều thì sẽ thấy
   `Cycle: ...`.
3. `Resource` có `/*` ở cuối không? `arn:aws:s3:::kho` và `arn:aws:s3:::kho/*`
   là hai thứ khác nhau: cái đầu là *cái kho*, cái sau là *các object trong
   kho*. `s3:GetObject` cần cái sau.
4. Bạn có gắn cơ chế truy cập origin vào **đúng origin** trong phân phối chưa?
   Tạo ra nó mà quên tham chiếu là lỗi im lặng hoàn toàn.

**Lỗi 2 — CDN trả 403 nhưng body là chữ `Access Denied` ngắn gọn, không phải
XML.** Khác lỗi 1: đây là phân phối từ chối *bạn*, không phải kho từ chối phân
phối. Hay gặp khi bạn đặt price class hẹp rồi test từ một nơi ngoài vùng phủ,
hoặc khi có geo restriction.

**Lỗi 3 — CDN trả 200 nhưng nội dung là XML `ListBucketResult`, hoặc trả 404
cho `/`.** Bạn đang trỏ origin vào endpoint website (`s3-website-...`) thay vì
endpoint REST (`....s3.us-east-1.amazonaws.com`), hoặc bạn quên khai
`default_root_object`. Hai endpoint này hành xử khác nhau về thư mục mặc định,
và **chỉ endpoint REST mới dùng được với cơ chế khoá origin**.

**Lỗi 4 — không bao giờ thấy header nén.** Ba nguyên nhân, theo thứ tự khả
năng: file nhỏ hơn 1 KB; `content_type` của object là `binary/octet-stream`
(mặc định của S3 khi bạn không khai) nên CDN không coi là nén được; hoặc chính
sách cache đang loại bỏ `Accept-Encoding`. Kiểm tra nguyên nhân thứ hai trước —
nó là nguyên nhân thật của phần lớn trường hợp:

```bash
aws s3api head-object --bucket "$(terraform output -raw bucket_name)" \
  --key index.html --profile lab-builder --query ContentType
```

**Lỗi 5 — sửa nội dung, apply lại, nhưng CDN vẫn trả bản cũ.** Đúng như thiết
kế: bản sao ở biên còn hạn. Hai cách xử lý, và đề thi hỏi bạn chọn cách nào:
xoá bản sao ở biên (tốn tiền sau 1.000 đường dẫn đầu mỗi tháng), hay đổi tên
file mỗi lần deploy (miễn phí, và là thứ mọi công cụ build hiện đại làm). Trong
lúc debug thì dùng cách thứ nhất; trong production thì gần như luôn là cách
thứ hai.

**Lỗi 6 — Terraform không upload lại file khi bạn sửa nội dung.** Terraform so
sánh bằng metadata chứ không đọc file. Cú pháp lạ duy nhất bạn cần trong cả
lab này:

```hcl
etag = filemd5("${path.module}/trang/index.html")
```

**Lỗi 7 — `terraform destroy` báo `BucketNotEmpty`.** Bucket có versioning
không rỗng chỉ vì bạn xoá file. Xem mục Dọn dẹp của README. Phòng bệnh:
`force_destroy = true` ngay từ đầu — trong lab thì nên, trong production thì
tuyệt đối không.

**Lỗi 8 — apply mất 15 phút rồi báo lỗi ở phút thứ 14.** Bình thường. Phân
phối CDN triển khai ra hàng trăm điểm biên và Terraform chờ tới khi xong. Đọc
kỹ plan trước khi gõ `yes`, vì mỗi lần sai là 15 phút.

**Resource Terraform cần tra:** `aws_s3_bucket`,
`aws_s3_bucket_public_access_block`, `aws_s3_bucket_versioning`,
`aws_s3_bucket_server_side_encryption_configuration`,
`aws_s3_bucket_lifecycle_configuration`, `aws_s3_object`,
`aws_s3_bucket_policy`, `aws_cloudfront_distribution`,
`aws_cloudfront_origin_access_control`,
`data.aws_cloudfront_cache_policy`, `data.aws_iam_policy_document`.

**Docs:**
- Hạn chế truy cập origin S3: <https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html>
- Nén ở CloudFront (điều kiện thật, có bảng): <https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/ServingCompressedFiles.html>
- Managed cache policy: <https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html>
- Lifecycle với versioning: <https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-configuration-examples.html>

</details>
