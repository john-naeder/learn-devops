# Đối chiếu — tuần 8

> Đọc sau khi `./verify.sh` xanh hết.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong lab | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1. Kho không lộ ra internet | **OAC** (Origin Access Control), bucket policy với `AWS:SourceArn` | [`docs/aws/w08-dns-cdn-edge.md`](../../../docs/aws/w08-dns-cdn-edge.md) §6 |
| 2. Chỉ HTTPS | **Viewer protocol policy** `redirect-to-https` | [`w08`](../../../docs/aws/w08-dns-cdn-edge.md) §9 |
| 3. Ba hành vi cache | **Cache behavior**, **path pattern**, **cache key**, **cache policy** | [`w08`](../../../docs/aws/w08-dns-cdn-edge.md) §6 · [sổ tay hiệu năng](../../../docs/notebook/12-hieu-nang.md) |
| 4. Header do biên chèn | **Response headers policy** vs **CloudFront Functions** vs **Lambda@Edge** | [`w08`](../../../docs/aws/w08-dns-cdn-edge.md) §7 |
| 5. Tên miền riêng | **Alias record**, vì sao alias miễn phí và dùng được ở apex | [`w08`](../../../docs/aws/w08-dns-cdn-edge.md) §2 · [sổ tay mạng](../../../docs/notebook/04-networking.md) |

### Ba thứ tạo nên cache key, và cái giá của mỗi thứ

Cache key mặc định của CloudFront chỉ gồm **domain + đường dẫn**. Bạn có thể
thêm ba nhóm nữa, và **mỗi lần thêm là một lần chia nhỏ tỉ lệ trúng cache**:

| Thêm vào cache key | Số bản cache nhân lên bao nhiêu | Khi nào đáng |
|---|---|---|
| Query string | bằng số tổ hợp giá trị khác nhau | khi nội dung thật sự phụ thuộc vào nó (`/nguoidung/*`) |
| Header | bằng số giá trị header khác nhau | `Accept-Encoding` để tách bản nén; `CloudFront-Viewer-Country` cho nội dung theo quốc gia |
| Cookie | thường là **vô hạn** — mỗi phiên một cookie | gần như không bao giờ. Cookie phiên trong cache key = tỉ lệ trúng 0% |

Đây là lý do sự cố trong Bối cảnh: đội frontend đổi `?v=` mỗi lần build, mà
`?v=` lại nằm trong cache key → mỗi lần build tạo ra một tập bản cache hoàn toàn
mới, tỉ lệ trúng rớt và origin ăn hết tải.

**Cache policy khác origin request policy ở chỗ nào** — câu hỏi thi kinh điển:

- **Cache policy**: cái gì đi vào **cache key**. Thêm vào đây là giảm tỉ lệ trúng.
- **Origin request policy**: cái gì được **chuyển tiếp tới origin** nhưng
  **không** vào cache key. Origin nhìn thấy nó, mà tỉ lệ trúng không đổi.

Ví dụ thực tế: bạn muốn origin ghi log `User-Agent` nhưng không muốn mỗi trình
duyệt một bản cache → cho `User-Agent` vào **origin request policy**, không cho
vào cache policy.

---

## Ba cách khác để giải bài này

### Cách A — S3 static website endpoint + bucket public, bỏ hẳn OAC

Bật "Static website hosting", để bucket public, CloudFront trỏ vào website
endpoint như một custom origin.

**Tốt hơn khi:** bạn cần các tính năng chỉ website endpoint có — **redirect
rules** khai báo được, và **index document tự động cho mọi thư mục con**
(`/blog/` → `/blog/index.html`). REST endpoint không làm được cái thứ hai, và đó
là lý do thật sự khiến nhiều đội vẫn dùng website endpoint.

**Tệ hơn khi:** — và đây là bài này — bucket buộc phải **public**, nên bất kỳ ai
biết tên bucket đều bỏ qua được tầng biên: bỏ qua WAF, bỏ qua giới hạn địa lý,
bỏ qua signed URL, và **bỏ qua cả hoá đơn CloudFront** (data transfer từ S3 đắt
hơn từ CloudFront). Website endpoint cũng **chỉ nói HTTP** với CloudFront, nên
chặng biên→origin không mã hoá.

**Đề thi hỏi thế nào:** `content must only be accessible through CloudFront` →
OAC. Nếu đề thêm `directory index documents for subfolders` thì mới là website
endpoint, và khi đó phải bù bảo mật bằng cách khác (ví dụ header bí mật kiểm tra
ở bucket policy).

### Cách B — Global Accelerator thay cho CloudFront

**Tốt hơn khi:** giao thức **không phải HTTP** (game UDP, MQTT, VoIP); cần **IP
tĩnh anycast** để khách hàng cho vào allowlist firewall; cần **failover giữa
Region trong vài giây**; nội dung **không cache được** nên CDN chẳng giúp gì mà
bạn vẫn muốn đi vào mạng xương sống của AWS sớm.

**Tệ hơn khi:** — bài này — nội dung là HTTP tĩnh và cache được. Global
Accelerator **không cache gì cả**: mọi request vẫn đi tới origin, chỉ là đi
nhanh hơn. Nó cũng tính **$0,025/giờ tức ~$18/tháng** dù không có lưu lượng, còn
CloudFront tính $0 khi rảnh. Hàng rào của bộ lab này chặn nó chính vì con số đó.

**Đề thi hỏi thế nào:** `static content`, `cache`, `TTL`, `invalidation` →
CloudFront. `static IP addresses`, `non-HTTP protocol`, `TCP/UDP`, `fast regional
failover` → Global Accelerator. Bẫy hay gặp: đề nói "tăng tốc cho người dùng
toàn cầu" — chưa đủ để chọn, phải đọc tiếp xem nội dung có cache được không.

### Cách C — Không dùng CDN, đặt ALB ở nhiều Region + latency routing của Route 53

**Tốt hơn khi:** nội dung **hoàn toàn động và cá nhân hoá**, tỉ lệ trúng cache
sẽ gần 0 dù có CDN; bạn cần xử lý gần người dùng chứ không chỉ phục vụ gần người
dùng (ví dụ tuân thủ chủ quyền dữ liệu); bạn cần chuyển hướng theo **quốc gia**
với logic phức tạp.

**Tệ hơn khi:** — bài này — bạn phải trả tiền ALB ở mỗi Region (~$17/tháng mỗi
cái), nhân bản dữ liệu, và **DNS không phải là cơ chế failover nhanh**: TTL và
DNS cache của trình duyệt làm thời gian chuyển hướng thực tế dài hơn TTL bạn
đặt. Với nội dung tĩnh thì đây là kiến trúc đắt gấp hàng chục lần mà chậm hơn.

**Đề thi hỏi thế nào:** khi đề vừa nói `static website` vừa nói `lowest cost`,
mọi đáp án có EC2/ALB đều sai. Mẫu đáp án đúng gần như luôn là **S3 + CloudFront
+ OAC + Route 53 alias**.

---

## Nếu đề thi hỏi

<details><summary>Câu 1. Sau khi đội frontend bắt đầu gắn `?build=<hash>` vào mọi URL asset, hoá đơn CloudFront tăng và tỉ lệ trúng cache rớt xuống 12%. Cách sửa nào TỐT NHẤT?</summary>

**A.** Tăng `default_ttl` lên 1 năm.
**B.** Cấu hình cache policy để **không** đưa query string vào cache key cho đường dẫn asset.
**C.** Chạy invalidation `/*` sau mỗi lần deploy.
**D.** Chuyển sang Global Accelerator.

**Đáp án: B.**

- **A sai** — TTL dài không giúp gì khi *mỗi URL là một khoá khác nhau*. Bạn chỉ
  giữ lâu hơn những bản cache mà không ai gọi lại.
- **C sai** — invalidation làm điều ngược lại: **xoá** bản cache, tức là ép Miss.
  Nó cũng tính tiền sau 1000 đường dẫn/tháng. Và nó không sửa nguyên nhân.
- **D sai** — Global Accelerator không cache gì cả, tỉ lệ trúng sẽ là 0%.

Câu hỏi tiếp theo bạn phải tự trả lời được: nếu bỏ `?build=` ra khỏi cache key
thì đội frontend phá cache trình duyệt bằng cách nào? Đáp án: **đổi tên file**
(`app.8f2a1.js`), tức là đổi *đường dẫn* chứ không đổi *query string*. Đường dẫn
luôn nằm trong cache key.

</details>

<details><summary>Câu 2. Một khách hàng báo nhìn thấy tên người dùng khác trên trang cá nhân hoá. Trang được phục vụ qua CloudFront. Nguyên nhân nào ĐÚNG NHẤT?</summary>

**A.** Lỗi trong mã ứng dụng ở origin.
**B.** Cache key không bao gồm thành phần phân biệt người dùng, nên một bản cache được dùng chung.
**C.** TTL quá ngắn.
**D.** Thiếu chứng chỉ TLS.

**Đáp án: B.** Đây chính là thí nghiệm bạn vừa chạy ở mục 3 của `verify.sh`.

- **A sai** — có thể, nhưng đề nói rõ trang đi qua CloudFront và triệu chứng là
  *nội dung của người khác*, dấu hiệu kinh điển của cache dùng chung.
- **C sai** — TTL ngắn làm cache **ít** hiệu quả hơn, không làm lẫn nội dung.
- **D sai** — TLS bảo vệ đường truyền, không liên quan tới việc ai thấy gì.

Bài học kèm theo: với nội dung cá nhân hoá, an toàn nhất là **không cache ở
biên** trừ khi bạn chắc chắn cache key đủ phân biệt. Một lỗi cache key không phải
lỗi hiệu năng — nó là **lỗ hổng rò rỉ dữ liệu**.

</details>

<details><summary>Câu 3. Website chạy ở `example.com` (gốc tên miền) và cần trỏ vào một CloudFront distribution. Bản ghi DNS nào?</summary>

**A.** Bản ghi CNAME trỏ tới `d111111abcdef8.cloudfront.net`.
**B.** Bản ghi A với địa chỉ IP của edge location gần nhất.
**C.** Bản ghi Alias kiểu A trỏ tới distribution.
**D.** Bản ghi NS uỷ quyền cho CloudFront.

**Đáp án: C.**

- **A sai** — chuẩn DNS (RFC 1034) không cho phép CNAME tồn tại cùng chỗ với các
  bản ghi khác, mà gốc tên miền **bắt buộc** có SOA và NS. Nên CNAME ở apex là
  bất hợp lệ. Ở `www.example.com` thì CNAME hợp lệ, nhưng vẫn bị tính phí truy vấn.
- **B sai** — IP của edge location thay đổi liên tục, và bạn không được cho một
  IP cố định nào.
- **D sai** — NS là uỷ quyền cả một vùng DNS, không phải cách trỏ một bản ghi.

Ba điều phải nhớ về Alias: (1) đặt được ở **apex**; (2) truy vấn **miễn phí**;
(3) Route 53 tự biết trạng thái của đích và bỏ đích chết ra khỏi câu trả lời.

</details>

<details><summary>Câu 4. Cần chèn header HSTS vào mọi phản hồi của một distribution. Giải pháp nào có chi phí vận hành thấp nhất?</summary>

**A.** Lambda@Edge trên sự kiện `origin-response`.
**B.** CloudFront Function trên sự kiện `viewer-response`.
**C.** Response headers policy.
**D.** Sửa metadata của từng object trong S3.

**Đáp án: C.** Cấu hình thuần, không code, không tiền, không phiên bản để quản lý.

- **A sai** — đúng về kỹ thuật nhưng đắt nhất và nặng nhất: có runtime, có cold
  start, có phiên bản phải replicate ra edge, và tính tiền theo GB-giây.
- **B sai** — nhẹ hơn Lambda@Edge nhiều, nhưng vẫn là code phải viết, test và
  triển khai để làm một việc mà cấu hình làm được.
- **D sai** — S3 không trả về được header `Strict-Transport-Security` từ
  metadata, và kể cả làm được thì cũng không mở rộng nổi.

Thứ tự lựa chọn nên thuộc lòng: **cấu hình → CloudFront Functions → Lambda@Edge**.
Chỉ leo lên bậc sau khi bậc trước không làm được.

</details>

<details><summary>Câu 5. Nội dung phải chỉ phục vụ cho người dùng đã đăng nhập, hết hạn sau 10 phút, và mỗi người một đường dẫn riêng. Chọn gì?</summary>

**A.** Bucket policy chặn theo IP.
**B.** CloudFront signed URL.
**C.** CloudFront signed cookie.
**D.** WAF rate limiting.

**Đáp án: B** — vì đề nói **mỗi người một đường dẫn riêng**, tức là cấp quyền cho
**từng file một**.

- **C gần đúng nhưng sai ngữ cảnh** — signed cookie dùng khi cần cấp quyền cho
  **nhiều file cùng lúc** (ví dụ toàn bộ một khoá học video) mà không muốn đổi URL.
  Đây là cặp đôi đề thi hay đảo: *một file, đổi được URL* → signed URL;
  *nhiều file, không đổi URL* → signed cookie.
- **A sai** — IP của người dùng di động thay đổi liên tục, và IP không phải danh tính.
- **D sai** — rate limiting chống lạm dụng, không phải cơ chế phân quyền.

</details>

---

## Chỗ dễ hiểu sai

**"x-cache: Hit nghĩa là mọi người trên thế giới đều Hit."**
Không. CloudFront có hàng trăm edge location, mỗi cái có bản cache riêng, và
phía sau còn một tầng **regional edge cache**. Một object mới cần được yêu cầu ở
mỗi POP một lần trước khi POP đó có bản sao. Tỉ lệ trúng cache thật của bạn phụ
thuộc vào **độ phân tán địa lý của người dùng** chia cho **số object**. Lab này
chạy từ một máy nên bạn luôn nói chuyện với cùng một POP — đó là lý do `Hit` xuất
hiện dễ dàng, và đó không phải bức tranh production.

**"TTL = 0 nghĩa là CloudFront không đụng vào."**
Không hẳn. Với TTL = 0, CloudFront vẫn **hợp nhất các request giống hệt nhau
đang chạy song song** (request collapsing) — 1000 request đồng thời cho cùng một
URL vẫn chỉ tạo ra một request tới origin. Đó là một tính năng bảo vệ origin mà
bạn nhận được miễn phí, kể cả khi không cache.

**"Invalidation là cách cập nhật nội dung."**
Trong production, invalidation là **giải pháp chữa cháy**, không phải quy trình
deploy. Nó chậm (vài phút để lan ra toàn cầu), có giá sau 1000 đường dẫn/tháng,
và có hạn mức đồng thời. Quy trình deploy đúng là **versioned URL**: file mới có
tên mới, nên không cần xoá gì cả, và rollback chỉ là trỏ lại tên cũ.

**"Bucket đã private thì an toàn rồi."**
Bạn vừa chặn được đường vào thẳng bucket. Nhưng địa chỉ `*.cloudfront.net` của
bạn vẫn công khai với cả thế giới. Nếu nội dung cần giới hạn, tầng biên phải có
thêm: signed URL/cookie, giới hạn địa lý, hoặc WAF. "Origin private" chỉ giải
quyết được một nửa câu hỏi.
