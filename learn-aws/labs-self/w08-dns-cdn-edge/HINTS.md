# Gợi ý — tuần 8

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bài này chỉ có **một** kho lưu trữ và **một** điểm biên. Mọi sự khác biệt nằm ở
chỗ bạn khai *ba luật khác nhau cho ba mẫu đường dẫn*. Nếu bạn đang định tạo ba
distribution hoặc ba bucket thì dừng lại — bạn đang đi sai hướng.

Thứ tự làm:

1. **Kho lưu trữ + ba file.** Đưa `tinh/thu.txt`, `nguoidung/thu.txt`,
   `api/thu.txt` lên. Kho **private hoàn toàn**, chặn public đủ 4 công tắc.
   Kiểm tra bằng `aws s3 ls`. Chưa động gì tới biên.

2. **Điểm biên trỏ vào kho.** Đây là bước khó nhất và cũng nhiều người kẹt nhất.
   Câu hỏi cần trả lời: *kho đang private, vậy tầng biên lấy file bằng danh tính
   nào?* Có hai cơ chế trong lịch sử AWS làm việc này — một cái cũ đã ngừng
   khuyến nghị, một cái mới. Tra cả hai, hiểu vì sao cái mới ra đời, rồi dùng
   cái mới. Sau bước này, `https://<biên>/tinh/thu.txt` phải trả 200.

3. **Ba luật cache.** Mỗi luật gắn với một *mẫu đường dẫn*. Khái niệm cần tra:
   **cache behavior** và **path pattern**. Thứ tự các behavior có ý nghĩa —
   cái khớp trước thắng, và luôn có một behavior mặc định ở cuối.

4. **Cache key.** Đây là trái tim của bài. Câu hỏi: *hai request như thế nào thì
   biên coi là "cùng một thứ"?* Tra khái niệm **cache policy** và ba thành phần
   nó điều khiển. Đọc kỹ chỗ nói về query string: có bốn chế độ, và bài này cần
   hai chế độ khác nhau ở hai đường dẫn khác nhau.

5. **Header bảo mật.** Có ít nhất hai cách làm ở tầng biên. Một cách khai báo,
   một cách viết code. Với một header cố định như thế này, cách nào ít việc hơn?

Mẹo tiết kiệm thời gian: mỗi lần `terraform apply` sửa distribution mất 5–10
phút. Viết cả ba behavior một lượt rồi apply một lần, đừng apply ba lần.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Cho việc chèn header (yêu cầu 4)** — ba ứng viên:

| | Chạy ở đâu | Làm được gì | Giá |
|---|---|---|---|
| **Response headers policy** | cấu hình thuần, không chạy code | thêm/sửa/xoá header cố định, CORS, HSTS | miễn phí |
| **CloudFront Functions** | edge location, JS, < 1 ms | sửa header và URL, không gọi mạng, không đọc thân | $0,10/triệu |
| **Lambda@Edge** | regional edge cache, Node/Python | mọi thứ, gọi được mạng, đọc được thân | $0,60/triệu + thời gian chạy |

Câu hỏi để tự chọn: header này có phụ thuộc vào request không? Có cần đọc gì từ
bên ngoài không? Nếu câu trả lời là "không" cho cả hai thì ứng viên nào đang là
lựa chọn quá tay?

**Cho việc bảo vệ kho (yêu cầu 1)** — hai ứng viên:

- **OAI** (Origin Access Identity) — cơ chế cũ, chỉ hỗ trợ S3 REST endpoint,
  không hỗ trợ SSE-KMS, không hỗ trợ mọi region.
- **OAC** (Origin Access Control) — cơ chế hiện tại, ký request bằng SigV4, hỗ
  trợ KMS, hỗ trợ cả origin không phải S3.

AWS khuyến nghị OAC cho mọi thiết kế mới. Đề thi vẫn hỏi cả hai, nhưng khi hỏi
"nên dùng gì" thì đáp án là OAC.

Có một ứng viên thứ ba mà nhiều người chọn nhầm: **S3 static website endpoint**.
Nó chạy được, nhưng nó buộc bucket phải public, tức là **phá yêu cầu 1**. Nếu
bạn thấy mình đang bật "Static website hosting" thì dừng lại.

**Cho tên miền (yêu cầu 5)** — Alias hay CNAME? Hai câu hỏi quyết định:
1. Bạn muốn đặt bản ghi ở `example.com` hay ở `www.example.com`? Chuẩn DNS cấm
   một trong hai loại bản ghi tồn tại ở gốc tên miền cùng với SOA/NS.
2. Route 53 tính $0,40/triệu truy vấn. Loại nào không bị tính?

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**403 với thân XML `<Code>AccessDenied</Code>` khi gọi qua biên.**
CloudFront tới được kho nhưng kho từ chối. Bucket policy phải cho phép principal
service `cloudfront.amazonaws.com` gọi `s3:GetObject`, **kèm điều kiện**
`AWS:SourceArn` bằng ARN của distribution. Thiếu điều kiện đó thì mọi
distribution của mọi khách hàng AWS đều đọc được kho của bạn.
Vòng phụ thuộc: bucket policy cần ARN distribution, distribution cần bucket.
Terraform tự gỡ được nếu bạn tham chiếu đúng chiều — bucket policy tham chiếu
`aws_cloudfront_distribution.x.arn`, còn distribution tham chiếu
`aws_s3_bucket.y.bucket_regional_domain_name`.

**Sửa cache policy xong mà `verify.sh` vẫn báo sai.**
Bản cache cũ vẫn còn sống tới hết TTL. Hai cách: chạy invalidation `/*`, hoặc
đợi. `verify.sh` dùng query string ngẫu nhiên mới mỗi lần chạy nên phần
`/nguoidung/*` và `/tinh/*` thường tự sạch — nhưng nếu bạn vừa đổi *chính sách*
thì phải invalidate.

**`x-cache` luôn là `Miss` ở mọi đường dẫn.**
Ba nguyên nhân hay gặp: (a) bạn gắn nhầm cache policy `CachingDisabled` cho
behavior mặc định; (b) origin trả về header `Cache-Control: no-cache` và bạn
chưa ghi đè; (c) TTL bằng 0. Kiểm tra bằng `curl -I` xem origin trả gì.

**`x-cache` là `Hit` ở `/api/*` dù đã đặt TTL = 0.**
`min_ttl`, `default_ttl`, `max_ttl` phải cùng bằng 0 — chỉ đặt `default_ttl = 0`
là chưa đủ khi origin gửi `Cache-Control: max-age=...`. Cách sạch hơn là dùng
managed cache policy `CachingDisabled` của AWS.

**Managed policy ID.** Bạn không cần nhớ chúng — Terraform có data source tra
theo tên. Đây là cú pháp lạ duy nhất đáng trích:

```hcl
data "aws_cloudfront_cache_policy" "khong_cache" { name = "Managed-CachingDisabled" }
```

**ACM cho tên miền riêng.** Chứng chỉ dùng cho CloudFront **bắt buộc** nằm ở
`us-east-1`, bất kể distribution phục vụ ở đâu. Đây là câu hỏi thi rất hay gặp.
Bộ lab này đã cố định `us-east-1` nên bạn không gặp vấn đề — nhưng phải biết là
có, vì đề sẽ hỏi.

**Tài liệu cần tra:**
- `aws_cloudfront_distribution` — `ordered_cache_behavior`, `default_cache_behavior`,
  `viewer_protocol_policy`
- `aws_cloudfront_origin_access_control`
- `aws_cloudfront_response_headers_policy`
- `aws_cloudfront_cache_policy` (hoặc data source cho managed policy)
- [Understanding the cache key](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/understanding-the-cache-key.html)
- [Restricting access to an S3 origin (OAC)](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)

</details>
