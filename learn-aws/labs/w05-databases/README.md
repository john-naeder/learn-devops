# Tuần 5 — Cơ sở dữ liệu

`Domain 2 · Resilient` `Domain 3 · Performance`

| | |
|---|---|
| **Chi phí mặc định** | **~$0** — chỉ DynamoDB + Lambda, nằm trong always free |
| **Nếu bật RDS** | **~$0,019/giờ** → 2 tiếng ≈ $0,04 · quên 1 tháng ≈ **$14** |
| **Dọn dẹp** | `cd terraform && terraform destroy` |

Lab chia đôi theo chi phí: **DynamoDB chơi thoải mái**, **RDS bật 2 tiếng rồi xoá**
(đủ để lấy $20 nhiệm vụ credit).

---

## Chạy

```bash
source ../../env.sh
cd terraform && terraform init && terraform apply    # chỉ DynamoDB, ~$0
cd ../ansible && ansible-playbook site.yml           # nạp 2200 item + đo
cd .. && ./verify.sh
```

RDS, khi bạn sẵn sàng dành đúng 2 tiếng:

```bash
cd terraform
terraform apply -var enable_rds=true    # ~8 phút để RDS sẵn sàng
# ĐẶT HẸN GIỜ ĐIỆN THOẠI NGAY BÂY GIỜ
terraform apply -var enable_rds=false   # xoá, không giữ final snapshot
```

---

## Phần đáng giá nhất: nhìn thấy con số Query vs Scan

Ai cũng đọc "Scan chậm và đắt hơn Query" rồi gật đầu và quên. Playbook nạp 2200 item
rồi bắt bạn nhìn số thật:

```
CÂU HỎI 1: tất cả đơn hàng của khách #42
Query theo khoá chính  (ĐÚNG)     10 kết quả    0.5 RCU     12 ms
Scan + FilterExpression (SAI)      10 kết quả  138.0 RCU    890 ms
                                → Scan tốn nhiều hơn 276 lần
```

**Điểm mấu chốt mà đề thi hỏi:** `FilterExpression` **không** làm giảm lượng đọc.
DynamoDB đọc toàn bộ bảng, tính tiền toàn bộ, rồi mới lọc trước khi trả về.
Bạn trả tiền cho mọi item bị quét qua, kể cả item bị loại.

Câu hỏi 2 cho thấy vì sao GSI tồn tại: *"tất cả đơn đang giao, của mọi khách"* —
khoá chính không trả lời được, và không có GSI thì bạn buộc phải Scan.

---

## Single-table design

```
Khách hàng   PK=KHACH#42   SK=HOSO
Đơn hàng     PK=KHACH#42   SK=DON#2026-08-15#0007
                           GSI1PK=TRANGTHAI#dang-giao   GSI1SK=2026-08-15#0007
```

Đơn hàng dùng **chung partition key** với khách. Nhờ vậy *"lấy khách và toàn bộ đơn
của họ"* chỉ tốn **một** lần Query.

Đây là điều ngược hẳn với thói quen SQL. Trong DynamoDB bạn thiết kế khoá theo
**cách sẽ truy vấn**, không theo cách hình dung thực thể. Chọn sai partition key là
sai lầm **không sửa được** — phải tạo bảng mới và migrate.

### Hot partition

Nếu 90% request đổ vào một giá trị PK, bạn bị **throttle** dù bảng còn thừa capacity.
Nguyên tắc: PK phải có **độ phân tán cao**. Đề thi hay cho tình huống
*"bảng bị throttle nhưng capacity chưa dùng hết"* — đáp án là hot partition.

---

## Bảng so sánh phải thuộc

### Multi-AZ vs Read Replica — gần như chắc chắn ra thi

| | Multi-AZ | Read Replica |
|---|---|---|
| Mục đích | **Chịu lỗi** | **Mở rộng đọc** |
| Standby/replica phục vụ đọc? | **KHÔNG** | **CÓ** |
| Đồng bộ | Synchronous | Asynchronous (có độ trễ) |
| Failover | Tự động, đổi DNS | Thủ công (promote) |
| Cùng region? | Bắt buộc | Có thể khác region |
| Giá | **Gấp đôi** | Cộng thêm mỗi replica |

Câu bẫy kinh điển: *"database quá tải vì quá nhiều truy vấn đọc"* → **Read Replica**,
không phải Multi-AZ. Multi-AZ không giảm tải một chút nào.

### GSI vs LSI

| | GSI | LSI |
|---|---|---|
| Partition key | **Khác** khoá chính | **Giống** khoá chính, chỉ đổi sort key |
| Tạo lúc nào | Bất cứ lúc nào | **Chỉ khi tạo bảng** — không thêm sau được |
| Capacity | Riêng | Dùng chung với bảng |
| Consistency | Chỉ eventually | Hỗ trợ strongly consistent |
| Giới hạn | 20 mỗi bảng | 5 mỗi bảng, 10 GB mỗi partition key |

Thực tế gần như luôn dùng GSI.

### On-demand vs Provisioned

| | PAY_PER_REQUEST | PROVISIONED |
|---|---|---|
| Đoán tải | Không cần | Phải đoán |
| Giá mỗi request | Đắt hơn ~7 lần | Rẻ hơn |
| Free tier | Tính theo request | **25 WCU + 25 RCU miễn phí** |
| Chọn khi | Tải thất thường, mới ra mắt | Tải ổn định, dự đoán được |

---

## TTL — chi tiết hay bị hiểu sai

TTL **miễn phí hoàn toàn**, không tốn write capacity. Đó là lý do nó là đáp án cho
*"tự động dọn dữ liệu hết hạn với chi phí thấp nhất"*.

Nhưng: AWS chỉ cam kết xoá **trong vòng 48 giờ** sau thời điểm TTL, **không tức thì**.

Hệ quả thiết kế: nếu ứng dụng **phải không** được thấy item hết hạn, bạn vẫn phải
tự lọc theo `expires_at` khi đọc. Đừng tin TTL xoá đúng giờ.

---

## Streams — nền của kiến trúc event-driven

Bảng có `stream_view_type = NEW_AND_OLD_IMAGES`, nối vào một Lambda qua
event source mapping. Mọi thay đổi đều chảy qua Lambda mà ứng dụng ghi dữ liệu
**không cần biết gì cả**.

Một chi tiết tinh tế trong code Lambda: bản ghi `REMOVE` do **TTL** tạo ra có
`userIdentity.principalId = dynamodb.amazonaws.com`. Đó là cách duy nhất phân biệt
"người dùng xoá" với "TTL tự xoá".

---

## RDS — ba thứ bị cấm trong tuần này

| Cấm | Vì sao |
|---|---|
| **Multi-AZ** | Nhân đôi giá, mà standby không phục vụ đọc → không có gì để quan sát |
| **Aurora** | Đắt hơn nhiều, không có instance nhỏ rẻ |
| **ElastiCache** | Cluster nhỏ nhất cũng ~$12/tháng |

Kiến thức thi về ba thứ này học bằng bảng so sánh ở trên, **không cần tay chạm**.
Chạy chúng không dạy bạn thêm điều gì mà đề thi hỏi.

### Chi tiết đáng chú ý trong code RDS

```hcl
manage_master_user_password = true    # RDS tự sinh + tự xoay vòng mật khẩu
```

Tốt hơn nhiều so với đặt mật khẩu trong biến Terraform — biến đó sẽ nằm **nguyên văn**
trong file state. (Đánh đổi: secret do RDS quản lý tính $0,40/tháng; với lab 2 tiếng
thì ~$0,001.)

```hcl
skip_final_snapshot = true    # lab: xoá là xoá luôn
```

Production thì **bắt buộc ngược lại**. Ở đây đặt `true` vì snapshot bị bỏ quên là
một khoản tiền âm thầm — `verify.sh` mục 8 quét đúng thứ đó.

```hcl
subnet_ids = module.vpc[0].private_subnet_ids    # BẮT BUỘC ≥ 2 AZ
```

RDS yêu cầu subnet group trải ít nhất 2 AZ **kể cả khi chạy Single-AZ**, để sau này
bật Multi-AZ được mà không phải dựng lại.

---

## Checklist

- [ ] `terraform apply` (không RDS), `ansible-playbook site.yml`
- [ ] Đọc kỹ bảng số Query vs Scan — ghi lại tỉ lệ chênh lệch
- [ ] Giải thích được vì sao `FilterExpression` không giảm chi phí đọc
- [ ] Xem log Lambda phản ứng với stream
- [ ] Hiểu TTL xoá trong 48 giờ, không tức thì
- [ ] Viết được bảng Multi-AZ vs Read Replica **bằng lời của mình**
- [ ] Bật RDS, đặt hẹn giờ, tạo snapshot, restore, **xoá cả instance lẫn snapshot**
- [ ] Nhận $20 nhiệm vụ credit "cấu hình một RDS database"
- [ ] `./verify.sh` mục 7 và 8 đều sạch
- [ ] `terraform destroy`

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
cd ../.. && ./scripts/find-orphans.sh    # kiểm tra RDS + snapshot
```

DynamoDB không mất tiền khi để trống nên giữ lại cũng được. **RDS thì tuyệt đối phải xoá**,
kèm mọi snapshot thủ công của nó.
