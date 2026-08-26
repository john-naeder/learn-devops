# Tuần 8 — DNS, CDN và tầng biên

`Domain 3 · Performance`

| | |
|---|---|
| **Chi phí mặc định** | **~$0,00** — CloudFront + S3 trong hạn mức miễn phí |
| **Nếu bật Route 53** | **~$1/tháng** (zone $0,50 + health check $0,50) → xoá sau 2 ngày ≈ **$0,05** |
| **Dọn dẹp** | `terraform destroy` (~5 phút) |

---

## Chạy

```bash
source ../../env.sh
cd terraform && terraform init && terraform apply    # ~6 phút
cd ../ansible && ansible-playbook site.yml --tags cache
cd .. && ./verify.sh
```

Route 53, nếu chấp nhận chi ~$0,05:

```bash
cd terraform
terraform apply -var enable_route53=true
# xem weighted + failover trong console, ghi lại
terraform apply -var enable_route53=false    # XOÁ, đừng để quên
```

---

## Phần đáng học nhất: cache key

**Cache key** là "vân tay" của một request. Hai request có cùng cache key thì CloudFront
coi là **cùng một thứ** và trả cùng một bản cache.

Cache key được tạo từ: **đường dẫn + những header/cookie/query string mà BẠN chọn đưa vào**.

> Càng đưa nhiều thứ vào cache key → càng nhiều bản cache khác nhau → tỉ lệ Hit càng **thấp**
> → càng phải đi tới origin nhiều lần → chậm hơn và đắt hơn.

### Sai lầm kinh điển

Đưa **tất cả** query string vào cache key. Khi đó `/trang?utm_source=facebook` và
`/trang?utm_source=google` thành **hai bản cache riêng**, dù nội dung y hệt.
Chạy một chiến dịch có 50 nguồn utm là tỉ lệ Hit sụp đổ.

Cache policy trong lab chỉ nhận đúng hai tham số thực sự đổi nội dung:

```hcl
query_string_behavior = "whitelist"
query_strings { items = ["trang", "ngon_ngu"] }
```

Playbook `--tags cache` đo cho bạn thấy:

| Request | Kết quả | Vì sao |
|---|---|---|
| `/index.html` (lần 2) | **Hit** | cùng cache key |
| `?utm_source=facebook` | **Hit** | utm_* không trong cache key |
| `?utm_source=google` | **Hit** | vẫn cùng cache key |
| `?trang=1` | **Miss** | "trang" CÓ trong cache key → bản cache mới |
| `/api/*` | **luôn Miss** | CachingDisabled |

### Vì sao cookie gần như luôn phải để `none`

Cookie thường mang **session ID** — mỗi người một giá trị khác nhau. Đưa cookie vào
cache key nghĩa là **mỗi người dùng một bản cache riêng**, tức là gần như không cache gì.

---

## Thứ tự cache behavior quan trọng

`ordered_cache_behavior` được xét **theo thứ tự khai báo**, và cái khớp **đầu tiên thắng**.

Đặt pattern rộng (`*`) lên trước pattern hẹp (`/api/*`) là lỗi cấu hình kinh điển:
pattern hẹp sẽ **không bao giờ** được dùng tới.

Ba behavior trong lab:

| Pattern | Cache | Vì sao |
|---|---|---|
| `/api/*` | **Tắt** | API mà cache thì người dùng nhận dữ liệu cũ |
| `/static/*` | **1 năm** | An toàn **chỉ khi** tên file có hash |
| mặc định | 1 ngày, bỏ qua utm | Trang HTML |

---

## CloudFront Function vs Lambda@Edge

| | CloudFront Function | Lambda@Edge |
|---|---|---|
| Sự kiện | viewer-request, viewer-response | **cả 4** (thêm origin-request/response) |
| Thời gian | **< 1 ms** | tới 5s (viewer) / 30s (origin) |
| Ngôn ngữ | JavaScript (ECMAScript 5.1+) | Node.js, Python |
| Mạng | **Không** | Có |
| Đọc body | **Không** | Có |
| Giá | **Rẻ hơn ~6 lần** | Đắt hơn |
| Chạy ở | **Mọi** edge location | Regional edge cache |

**Quy tắc chọn:** thao tác header/URL đơn giản → CloudFront Function.
Cần gọi mạng, đọc body, hoặc can thiệp ở tầng origin → Lambda@Edge.

Lab có hai function: một chèn security header (viewer-response), một chuẩn hoá đường dẫn
và gán nhóm A/B (viewer-request).

---

## Bảy routing policy của Route 53 — kiến thức NHỚ

Đây là phần bạn **không cần tay chạm** vẫn thi được. Học thuộc bảng này:

| Policy | Làm gì | Dùng khi |
|---|---|---|
| **Simple** | Một record, một hoặc nhiều IP | Trường hợp đơn giản nhất |
| **Weighted** | Chia lưu lượng theo tỉ lệ (90/10) | **Canary deploy**, A/B testing |
| **Latency** | Trả endpoint có độ trễ thấp nhất | Đa region, tối ưu tốc độ |
| **Failover** | PRIMARY, hỏng thì SECONDARY | **DR active/passive** |
| **Geolocation** | Theo **vị trí người dùng** | Nội dung theo quốc gia, tuân thủ pháp lý |
| **Geoproximity** | Theo khoảng cách địa lý, có **bias** chỉnh được | Dịch chuyển lưu lượng giữa region |
| **Multivalue** | Trả nhiều IP kèm health check | Cân bằng tải "nghèo", không thay LB |

**Hai cặp hay bị nhầm:**

- **Latency vs Geolocation:** latency theo **thời gian mạng thực đo**, geolocation theo
  **vị trí địa lý**. Người ở Hà Nội có thể có latency tới Singapore thấp hơn tới
  một datacenter gần hơn về địa lý.
- **Geolocation vs Geoproximity:** geolocation là quy tắc cứng theo quốc gia;
  geoproximity tính khoảng cách và cho bạn chỉnh **bias** để kéo lưu lượng.

### Alias vs CNAME

| | Alias | CNAME |
|---|---|---|
| Đặt ở zone apex (`example.com`) | **Được** | **Không được** |
| Giá | **Miễn phí** | Tính theo truy vấn |
| Trỏ tới | Tài nguyên AWS (ALB, CloudFront, S3) | Bất kỳ tên miền nào |

Đề thi hỏi *"trỏ example.com tới ALB"* → **Alias**, vì CNAME không đặt được ở apex.

---

## CloudFront vs Global Accelerator

| | CloudFront | Global Accelerator |
|---|---|---|
| Làm gì | **Cache nội dung** ở edge | **Tối ưu đường mạng** qua backbone AWS |
| Giao thức | HTTP/HTTPS | **TCP/UDP bất kỳ** |
| IP | Thay đổi | **2 IP tĩnh anycast** |
| Chọn khi | Web, API, nội dung tĩnh | Game, VoIP, IoT, cần IP tĩnh |

Đề hỏi *"cần IP tĩnh và tối ưu độ trễ cho giao thức không phải HTTP"* → **Global Accelerator**.
Nhưng nhớ nó **~$18/tháng** — chỉ học lý thuyết, đừng bật.

---

## Chứng chỉ ACM — chi tiết hay ra thi

Dùng domain riêng cho CloudFront thì chứng chỉ ACM **bắt buộc nằm ở `us-east-1`**,
dù distribution phục vụ toàn cầu. Cert ở region khác sẽ không chọn được.

(Với ALB thì ngược lại: cert phải ở **cùng region** với ALB.)

---

## Checklist

- [ ] `terraform apply`, đợi distribution deploy xong
- [ ] `ansible-playbook site.yml --tags cache` — đọc kỹ cả 4 bài đo
- [ ] Giải thích được vì sao `?utm_source=...` vẫn Hit mà `?trang=1` thì Miss
- [ ] Giải thích được vì sao cookie trong cache key ≈ không cache
- [ ] `./verify.sh` — 4 security header đều có
- [ ] Chạy `--tags invalidate`, hiểu `/api/*` tính là **một** path
- [ ] **Thuộc bảng 7 routing policy** và khi nào dùng cái nào
- [ ] Phân biệt được Alias vs CNAME, latency vs geolocation
- [ ] Nếu có bật Route 53: **đã xoá hosted zone và health check**
- [ ] `terraform destroy`
