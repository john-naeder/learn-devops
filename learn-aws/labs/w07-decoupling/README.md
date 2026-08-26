# Tuần 7 — Tách rời hệ thống và tích hợp

`Domain 2 · Resilient`

| | |
|---|---|
| **Chi phí** | **~$0,00** — SNS 1M publish, SQS 1M request, SFN 4000 transition, Lambda 1M invoke |
| **Dọn dẹp** | `terraform destroy`, hoặc ít nhất **tắt EventBridge rule** |

---

## Chạy

```bash
source ../../env.sh
cd terraform && terraform init && terraform apply
cd ../ansible && ansible-playbook site.yml --tags fanout
cd .. && ./verify.sh
```

Xem DLQ hoạt động (cần ~2 phút chờ):

```bash
cd terraform && terraform apply -var gay_loi_don_hang=true
cd ../ansible && ansible-playbook site.yml --tags fanout,dlq
cd ../terraform && terraform apply -var gay_loi_don_hang=false   # tắt lại
```

---

## Kiến trúc

```
                       ┌── filter: don-hang ──────→ SQS đơn hàng ──→ Lambda ──(lỗi x3)──→ DLQ
publish → SNS topic ───┤
                       └── filter: don-hang,       → SQS kho hàng ──→ Lambda kho
                                   nhap-kho

EventBridge rate(5 min) ──→ Lambda báo cáo          [MẶC ĐỊNH TẮT]
Step Functions ──→ KiemTra → Wait 3s → GhiNhanKho
                     └─(catch)─→ XuLyLoi
```

**Ý chính:** producer publish vào **một** topic và **không biết** có bao nhiêu consumer.
Thêm consumer thứ ba = thêm một subscription, **không sửa một dòng nào** ở producer.
Đó chính là "tách rời".

---

## Bốn con số trong code quyết định hành vi

### 1. `visibility_timeout_seconds = 60` vs Lambda `timeout = 10`

Khi consumer nhận message, message bị **ẩn** trong khoảng visibility timeout.
Nếu consumer không xoá kịp trước khi hết hạn, message **hiện lại** và consumer khác
nhận được → **xử lý trùng**.

> **Quy tắc vàng:** visibility timeout phải **lớn hơn** timeout của Lambda.

Đảo ngược (visibility 5s, Lambda 10s) là công thức chắc chắn để có xử lý trùng lặp.
Đây là câu hỏi thi rất hay gặp. Plan gốc yêu cầu "nghịch visibility timeout để tự thấy
hiện tượng xử lý trùng lặp" — sửa `visibility_timeout_seconds` xuống 5 rồi apply lại.

### 2. `receive_wait_time_seconds = 20` — long polling

| | Short polling (0) | Long polling (20) |
|---|---|---|
| Hành vi | Hỏi liên tục, phần lớn trả rỗng | Giữ kết nối chờ tối đa 20s |
| Chi phí | Cao — trả tiền cho request rỗng | **Thấp** |
| Độ trễ | Cao hơn | Thấp hơn |

**Luôn dùng 20.** Đây cũng là đáp án cho *"giảm chi phí SQS"*.

### 3. `maxReceiveCount = 3` — ngưỡng vào DLQ

Thất bại 3 lần thì message sang DLQ, giữ **14 ngày** để bạn điều tra.
Quy trình thật: xem message hỏng → sửa code → **redrive** từ DLQ về hàng đợi chính
(console có nút sẵn).

Không có DLQ thì message lỗi **quay vòng vô tận** — tốn tiền, và nó **chặn luôn**
những message tốt phía sau.

### 4. `batch_size = 5` — cái bẫy ẩn

Nếu **một** message trong batch lỗi mà không bật `report_batch_item_failures`,
thì **cả batch** bị thử lại, kể cả những message đã xử lý xong. Đây là nguyên nhân
phổ biến của "sao message này được xử lý hai lần".

Bài tập mở rộng: trả về `{"batchItemFailures": [{"itemIdentifier": "<messageId>"}]}`
để chỉ message hỏng bị thử lại.

---

## Filter policy — fanout thông minh

```hcl
filter_policy = jsonencode({ loai_su_kien = ["don-hang"] })
```

Việc lọc diễn ra **ở SNS, trước khi gửi**. Nghĩa là:

- Bạn **không trả tiền** cho message không liên quan
- Consumer **không phải viết code lọc**

Playbook publish 3 `don-hang` + 2 `nhap-kho` vào cùng một topic. Hàng đợi đơn hàng
nhận 3, hàng đợi kho nhận 5. `verify.sh` in ra filter policy của từng subscription.

Đề thi: *"làm sao để mỗi consumer chỉ nhận loại sự kiện nó quan tâm"* → **filter policy**.

### `raw_message_delivery = true`

Không bật thì SNS **bọc** message trong một phong bì JSON, và consumer phải tự bóc
lớp `"Message"` bên trong. Chi tiết nhỏ nhưng hay làm người mới bối rối hàng giờ.

---

## Bảng so sánh phải thuộc — đề thi rất thích bộ này

### SQS · SNS · EventBridge · Kinesis

| | SQS | SNS | EventBridge | Kinesis Data Streams |
|---|---|---|---|---|
| Mô hình | Hàng đợi, **kéo** | Pub/sub, **đẩy** | Bus sự kiện, luật định tuyến | Luồng, **kéo** |
| Consumer | **Một** consumer lấy mỗi message | Nhiều subscriber | Nhiều target theo luật | **Nhiều** consumer đọc **cùng** dữ liệu |
| Giữ lại | 14 ngày, xoá sau khi xử lý | Không giữ | Không giữ | **1–365 ngày, tua lại được** |
| Thứ tự | FIFO queue mới có | Không | Không | **Theo shard** |
| Chọn khi | Xử lý nền, đệm tải | Thông báo, fanout | Tích hợp SaaS, luật phức tạp | Phân tích thời gian thực, replay |

**Câu hỏi phân biệt then chốt:** cần **nhiều consumer độc lập đọc cùng một dữ liệu**
và **tua lại được** → **Kinesis**. Mỗi message chỉ cần **một** consumer xử lý rồi bỏ
→ **SQS**.

### SQS Standard vs FIFO

| | Standard | FIFO |
|---|---|---|
| Thứ tự | **Không đảm bảo** | Đảm bảo trong mỗi message group |
| Giao hàng | **Ít nhất một lần** (có thể trùng) | **Đúng một lần** |
| Throughput | Gần như không giới hạn | 300 msg/s (3000 với batch) |
| Tên hàng đợi | bất kỳ | phải kết thúc `.fifo` |
| Bắt buộc thêm | — | `MessageGroupId`, `MessageDeduplicationId` |

---

## Step Functions

### Standard vs Express

| | Standard | Express |
|---|---|---|
| Thời gian tối đa | **1 năm** | 5 phút |
| Ngữ nghĩa | Exactly-once | At-least-once |
| Lịch sử | Đầy đủ trong console | Chỉ CloudWatch Logs |
| Tính tiền | Theo **state transition** (4000/tháng free) | Theo số lần chạy + thời lượng |
| Chọn khi | Quy trình dài, cần audit | Tần suất cao, luồng ngắn |

### Ba thứ trong định nghĩa quy trình

- **`Retry`** — lỗi **tạm thời** (throttle, timeout mạng). Có `BackoffRate = 2.0`
  → chờ 2s, 4s, 8s. Nên có ở **mọi** Task gọi dịch vụ ngoài.
- **`Catch`** — lỗi **vĩnh viễn**. Hết retry vẫn hỏng thì rẽ nhánh, thay vì làm sập
  cả quy trình. `ResultPath = "$.loi"` giữ input gốc và thêm chi tiết lỗi.
- **`Wait`** — **không tốn tiền theo thời gian chờ** trong Standard workflow.
  Chờ 30 ngày cũng chỉ là một state transition. Chờ bằng Lambda thì bạn trả tiền
  GB-giây cho thời gian ngủ. Đây là một câu hỏi tối ưu chi phí rất hay.

---

## EventBridge rule mặc định TẮT

```hcl
state = var.bat_lich ? "ENABLED" : "DISABLED"
```

Plan gốc nhắc riêng ở tuần 7: *"đã tắt EventBridge schedule — để chạy mãi sẽ sinh log
vô ích"*. Một rule mỗi 5 phút = **8640 lần gọi mỗi tháng**. Không đủ để hết hạn mức,
nhưng đủ để làm bẩn CloudWatch và **che mất tín hiệu thật** khi bạn cần debug.

```bash
terraform apply -var bat_lich=true     # bật khi làm bài
terraform apply -var bat_lich=false    # TẮT khi xong
```

`verify.sh` kiểm tra đúng chỗ này.

---

## Checklist

- [ ] `terraform apply`, `ansible-playbook site.yml --tags fanout`
- [ ] Xác nhận hàng đợi đơn hàng nhận **3**, kho hàng nhận **5** — hiểu vì sao
- [ ] Bật `gay_loi_don_hang=true`, quan sát message vào DLQ sau 3 lần thử
- [ ] Đọc `ApproximateReceiveCount` trong log để thấy số lần thử tăng dần
- [ ] Sửa `visibility_timeout_seconds` xuống 5, apply, quan sát xử lý trùng lặp
- [ ] Chạy Step Functions, mở console xem sơ đồ từng bước
- [ ] Viết được bảng SQS · SNS · EventBridge · Kinesis
- [ ] Nói được khi nào chọn SQS, khi nào chọn Kinesis
- [ ] **EventBridge rule đã TẮT** (`./verify.sh` xác nhận)
- [ ] `terraform destroy`
