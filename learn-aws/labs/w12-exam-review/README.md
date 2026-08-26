# Tuần 12 — Ôn tập và thi thử

`Cả 4 domain` · **Miễn phí**

---

## Nguyên tắc của tuần này

Plan gốc nói rất rõ: **"viết ra bằng tay, không copy"**.

Mười bảng dưới đây có phần **khung trống để bạn tự điền**, và **đáp án nằm ở
`dap-an.md`** trong cùng thư mục. Điền xong mới mở đáp án ra đối chiếu.

Lý do: nhận ra một bảng đúng khi nhìn thấy nó là **ảo giác về năng lực**.
Tự dựng lại được bảng đó từ trí nhớ mới là năng lực thật, và đó chính là thứ
phòng thi đòi hỏi.

---

## Trước khi làm bảng: hai việc có hiệu suất cao nhất

1. **Đọc sáu trang FAQ chính thức**: S3, EC2, VPC, RDS, DynamoDB, Lambda.
   Riêng việc này phủ một phần rất lớn của đề, và hầu hết mọi người bỏ qua.

2. **Đọc Exam Guide chính thức** — đặc biệt là danh sách **out-of-scope services**.
   Đó là ranh giới ôn tập của bạn. Học thứ ngoài phạm vi là lãng phí thời gian.

Sau đó đọc Well-Architected Framework, cả sáu trụ cột:
Operational Excellence · Security · Reliability · Performance Efficiency ·
Cost Optimization · **Sustainability**.

---

## Mười bảng phải tự viết được

> Copy phần này ra một file riêng, điền tay, rồi đối chiếu `dap-an.md`.

### 1. SQS · SNS · EventBridge · Kinesis

| | SQS | SNS | EventBridge | Kinesis Data Streams |
|---|---|---|---|---|
| Mô hình | | | | |
| Số consumer mỗi message | | | | |
| Giữ dữ liệu | | | | |
| Tua lại được? | | | | |
| Đảm bảo thứ tự | | | | |
| Chọn khi | | | | |

### 2. EBS · EFS · S3 · FSx · Instance store

| | EBS | EFS | S3 | FSx | Instance store |
|---|---|---|---|---|---|
| Loại | | | | | |
| Gắn được mấy máy | | | | | |
| Đa AZ? | | | | | |
| Dữ liệu sống sau khi stop instance? | | | | | |
| Chọn khi | | | | | |

### 3. Multi-AZ · Read Replica · Aurora Global Database

| | Multi-AZ | Read Replica | Global Database |
|---|---|---|---|
| Mục đích | | | |
| Standby/replica phục vụ đọc? | | | |
| Đồng bộ hay bất đồng bộ | | | |
| Failover | | | |
| Cross-region? | | | |

### 4. Security Group · Network ACL

| | Security Group | Network ACL |
|---|---|---|
| Áp dụng ở mức | | |
| Stateful hay stateless | | |
| Có rule Deny? | | |
| Thứ tự xét rule | | |
| Mặc định | | |

### 5. ALB · NLB · Gateway Load Balancer

| | ALB | NLB | GWLB |
|---|---|---|---|
| Tầng OSI | | | |
| Định tuyến theo | | | |
| IP tĩnh? | | | |
| Chọn khi | | | |

### 6. CloudFront · Global Accelerator

| | CloudFront | Global Accelerator |
|---|---|---|
| Làm gì | | |
| Giao thức | | |
| IP tĩnh? | | |
| Chọn khi | | |

### 7. Cognito user pool · identity pool

| | User pool | Identity pool |
|---|---|---|
| Trả về cái gì | | |
| Dùng để | | |
| Ví dụ tình huống | | |

### 8. SQS Standard · SQS FIFO

| | Standard | FIFO |
|---|---|---|
| Thứ tự | | |
| Số lần giao | | |
| Throughput | | |
| Tham số bắt buộc thêm | | |

### 9. Gateway Endpoint · Interface Endpoint · NAT Gateway

| | Gateway Endpoint | Interface Endpoint | NAT Gateway |
|---|---|---|---|
| Cơ chế | | | |
| Dịch vụ hỗ trợ | | | |
| **Giá** | | | |
| Chọn khi | | | |

> Bảng này bạn đã **tự tay trải nghiệm** ở tuần 2. Nếu quên thì mở lại
> [`w02-vpc-networking/README.md`](../w02-vpc-networking/).

### 10. Bốn chiến lược DR

| | Backup & Restore | Pilot Light | Warm Standby | Multi-Site |
|---|---|---|---|---|
| RTO | | | | |
| RPO | | | | |
| Chi phí | | | | |
| Ở region phụ có gì | | | | |

---

## Bảng thứ mười một — của riêng bạn

Mười bảng trên là chuẩn. Nhưng bảng có giá trị nhất là bảng bạn tự nhận ra mình
hay nhầm. Sau bài thi thử đầu tiên, hãy lập nó.

Gợi ý những chỗ hay nhầm mà repo này đã chạm tới:

- **Lambda in VPC** — khi nào cần, khi nào là thừa (tuần 6)
- **`treat_missing_data`** — bốn giá trị, chọn cái nào (tuần 10)
- **`implicitDeny` vs `explicitDeny`** (tuần 9)
- **Parameter Store vs Secrets Manager** — khác biệt quyết định là gì (tuần 9)
- **Alias vs CNAME** — cái nào đặt được ở zone apex (tuần 8)
- **HTTP API vs REST API** — khi nào buộc phải dùng REST (tuần 6)
- **Query vs Scan** — `FilterExpression` có giảm chi phí đọc không (tuần 5)
- **visibility timeout vs Lambda timeout** — cái nào phải lớn hơn (tuần 7)

---

## Lịch thi thử

| Bài | Điều kiện |
|---|---|
| Thi thử #1 | Sau khi hoàn thành 10 bảng |
| Thi thử #2 | Sau khi review hết bài #1 |
| Thi thử #3 | |
| Thi thử #4 | |

**Quy tắc:** 65 câu, bấm giờ đúng **130 phút**, ngồi liền mạch **không nghỉ**.
Làm nửa chừng rồi đứng dậy pha cà phê là bạn đang luyện một thứ khác với kỳ thi thật.

### Sau mỗi bài — phần quan trọng hơn cả bài thi

Review **toàn bộ** câu sai **và** mọi câu đúng nhưng **do đoán**.

Câu đúng do đoán nguy hiểm hơn câu sai: nó cho bạn cảm giác đã hiểu, trong khi thực tế
bạn chưa. Ghi cả hai loại vào sổ lỗi.

### Mẫu sổ lỗi

```
Bài #  | Câu | Miền      | Tôi chọn | Đúng là | Vì sao tôi sai        | Đã ôn lại
-------|-----|-----------|----------|---------|-----------------------|----------
1      | 12  | Security  | B        | D       | Nhầm SG với NACL      | w02 ✓
1      | 31  | Cost      | A        | A(đoán) | Không chắc về NAT giá | w02 ✓
```

Cột **"Vì sao tôi sai"** là cột duy nhất thật sự quan trọng. Nếu bạn không viết được lý do,
nghĩa là bạn chưa hiểu và cần quay lại đọc.

### Ngưỡng đăng ký thi thật

**Đạt ≥ 80% ở hai bài liên tiếp.**

Chưa đạt thì **lùi lịch một tuần** và cày lại đúng những miền yếu — đừng làm thêm bài thi thử
mới. Làm nhiều đề mà không sửa lỗ hổng chỉ tạo cảm giác bận rộn.

---

## Chiến thuật phòng thi

### Ba mẹo lấy điểm rẻ nhất

1. **Bảo mật nặng nhất — 30%.** Nếu chỉ còn thời gian ôn một thứ, ôn IAM và mã hoá.

2. **Loại trừ trước, chọn sau.** Phần lớn câu hỏi có **hai đáp án sai rõ ràng**.
   Trong hai đáp án còn lại, đọc lại đề tìm **từ khoá ràng buộc**:
   - "chi phí thấp nhất"
   - "ít thao tác vận hành nhất"
   - "thay đổi code ít nhất"
   - "thời gian triển khai nhanh nhất"

   **Từ khoá đó mới là thứ quyết định**, không phải phần mô tả kỹ thuật.

3. **Ánh xạ từ khoá → đáp án:**

| Từ khoá trong đề | Hướng đáp án |
|---|---|
| "ít thao tác vận hành nhất" | **Managed / serverless** |
| "chi phí thấp nhất" | Spot, S3 lifecycle, **Gateway Endpoint thay NAT** |
| "không được downtime" | Multi-AZ, Active/Active |
| "mở rộng đọc" | **Read Replica** (không phải Multi-AZ) |
| "cần IP tĩnh, không phải HTTP" | **NLB** hoặc **Global Accelerator** |
| "dữ liệu phải ở tại chỗ" | **Outposts** |
| "tự động xoay vòng credential" | **Secrets Manager** |
| "chạy lâu hơn 15 phút" | Không phải Lambda → **Fargate / Step Functions** |
| "cần thứ tự chính xác" | **SQS FIFO** hoặc **Kinesis** (theo shard) |
| "nhiều consumer đọc cùng dữ liệu" | **Kinesis**, không phải SQS |

### Quản lý thời gian

130 phút / 65 câu = **2 phút mỗi câu**. Nhưng phân bổ không đều:

- Vòng 1 (~90 phút): làm hết, **đánh dấu** câu nào lưỡng lự, **không dừng lại quá 3 phút**
- Vòng 2 (~30 phút): quay lại câu đã đánh dấu
- Vòng 3 (~10 phút): rà lại câu nhiều đáp án, đếm xem đã chọn đủ số lượng đề yêu cầu chưa

**Không trừ điểm khi đoán.** Không bao giờ để trống câu nào.

---

## Thông số kỳ thi

| | |
|---|---|
| Số câu | **65** (50 tính điểm, 15 thử nghiệm không tính) |
| Thời gian | **130 phút** |
| Điểm đậu | **720/1000**, chấm bù giữa các miền |
| Lệ phí | **150 USD** |
| Hình thức | Pearson VUE hoặc online có giám thị |

### Trọng số bốn miền

| Miền | Trọng số | Số câu ước tính |
|---|---|---|
| Thiết kế kiến trúc **bảo mật** | **30%** | ~15 |
| Thiết kế kiến trúc **có khả năng phục hồi** | 26% | ~13 |
| Thiết kế kiến trúc **hiệu năng cao** | 24% | ~12 |
| Thiết kế kiến trúc **tối ưu chi phí** | 20% | ~10 |

> "Chấm bù giữa các miền" nghĩa là bạn **không cần đạt ngưỡng ở từng miền riêng lẻ** —
> chỉ cần tổng điểm đạt 720. Nhưng đừng bỏ hẳn một miền: 30% là quá nhiều để mất.

---

## Checklist cuối cùng

- [ ] Đọc hết 6 trang FAQ (S3, EC2, VPC, RDS, DynamoDB, Lambda)
- [ ] Đọc Exam Guide, nắm rõ danh sách **out-of-scope**
- [ ] Đọc Well-Architected Framework, 6 trụ cột
- [ ] Đọc whitepaper Disaster Recovery (tuần 11)
- [ ] **Tự viết tay** đủ 10 bảng, chưa mở `dap-an.md`
- [ ] Đối chiếu đáp án, đánh dấu chỗ sai
- [ ] Lập bảng thứ 11 của riêng mình
- [ ] Thi thử #1 — có sổ lỗi
- [ ] Thi thử #2 — có sổ lỗi
- [ ] Thi thử #3
- [ ] Thi thử #4 — **≥ 80% hai bài liên tiếp**
- [ ] Kiểm tra lại trang certification chính thức: **SAA-C03 vẫn là bản hiện hành?**
- [ ] Săn voucher giảm giá (AWS Educate, re/Start, hoặc voucher 50% nếu đã có chứng chỉ)
- [ ] **Đặt lịch thi tại Pearson VUE**
- [ ] Chạy `../../scripts/find-orphans.sh --all` lần cuối — đừng để hoá đơn bất ngờ
      làm hỏng ngày thi
