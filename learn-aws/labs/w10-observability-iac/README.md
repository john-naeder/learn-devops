# Tuần 10 — Giám sát, vận hành và hạ tầng dạng mã

`Domain 2 · Resilient` `Domain 4 · Cost`

| | |
|---|---|
| **Chi phí** | **~$0,00** — 10 metric tuỳ chỉnh + 10 alarm + 5 GB log miễn phí mỗi tháng |
| **Dọn dẹp** | `terraform destroy` |

> Plan gốc gọi đây là *"kỹ năng đi làm quan trọng nhất trong cả khóa"*, và đúng vậy:
> dựng được hệ thống là một chuyện, **biết nó đang hỏng** lại là chuyện khác.

---

## Chạy

**Đặt email thật của bạn** — cả điểm của lab là nhận được một cảnh báo thật:

```bash
source ../../env.sh
cd terraform && terraform init
terraform apply -var email_canh_bao=ban@example.com
```

Rồi **vào hộp thư bấm "Confirm subscription"**. Chưa xác nhận thì alarm kêu vào hư không —
Terraform không thể tự bấm link giúp bạn. Đây là một trong số ít chỗ IaC phải dừng chờ con người.

```bash
cd ../ansible && ansible-playbook site.yml    # gây lỗi, đợi alarm, nhận email
cd .. && ./verify.sh
```

---

## Bốn thứ lab dựng

### 1. Alarm trên `Errors` → SNS → email

`ansible-playbook site.yml --tags loi` gọi Lambda 5 lần với `gay_loi=true`, đợi 2 phút,
rồi cho bạn xem alarm chuyển `OK → ALARM`. **Điện thoại bạn sẽ rung.**

### 2. Metric filter — biến dòng log thành metric

```hcl
pattern = "{ $.muc = \"ERROR\" }"
```

Dùng khi metric bạn cần **không tồn tại sẵn**: số lần đăng nhập thất bại, số đơn hàng bị huỷ —
những thứ chỉ ứng dụng của bạn biết.

Ba cách tạo custom metric, theo thứ tự chi phí:

| Cách | Chi phí | Dùng khi |
|---|---|---|
| **Metric filter từ log** | **Rẻ nhất** — đã trả tiền log rồi | Metric đơn giản, đếm sự kiện |
| `PutMetricData` từ code | Phí API mỗi lần gọi | Ít metric, cần ngay lập tức |
| **Embedded Metric Format** | Rẻ nhất khi **khối lượng lớn** | Nhiều metric, nhiều chiều |

### 3. Composite alarm — chống "alarm fatigue"

Hệ thống hỏng thật thì **nhiều alarm kêu cùng lúc**. Bạn nhận 8 email cho một sự cố,
và lần sau bạn bắt đầu **bỏ qua** email — đó mới là nguyên nhân thật sự khiến sự cố bị bỏ lỡ.

```hcl
alarm_rule = "ALARM(co-loi) AND ALARM(p99-cham)"
```

Chỉ kêu khi **cả hai** cùng sai, tức là nhiều khả năng có sự cố thật chứ không phải
một trục trặc thoáng qua.

### 4. Dashboard

Bốn widget, trong đó widget "Độ trễ" vẽ **cùng lúc** trung bình / p50 / p99 / tệ nhất
để bạn thấy tận mắt vì sao trung bình là con số dối trá.

---

## Hai cái bẫy cấu hình có trong đề thi

### `treat_missing_data` — tham số bị hiểu sai nhiều nhất

| Giá trị | Nghĩa | Dùng cho |
|---|---|---|
| `missing` (mặc định) | Giữ nguyên trạng thái trước | hiếm khi đúng |
| **`notBreaching`** | Coi như bình thường | **metric lỗi** |
| `breaching` | Coi như đang lỗi | **metric heartbeat** ("hệ thống còn sống") |
| `ignore` | Không đánh giá | metric rời rạc |

**Vì sao quan trọng:** Lambda **không** phát metric `Errors` khi không có lỗi — nó không gửi
số 0. Để `missing` thì sau lần lỗi **đầu tiên**, alarm **mắc kẹt ở ALARM mãi mãi**, vì
không bao giờ có dữ liệu mới đưa nó về OK.

`verify.sh` mục 3 kiểm tra đúng chỗ này.

### `default_value = 0` trên metric filter

Cùng một cái bẫy, ở một chỗ khác. Không đặt nó thì metric chỉ xuất hiện khi **có** lỗi,
và alarm lại rơi vào tình huống thiếu dữ liệu.

---

## Vì sao p99 chứ không phải trung bình

`ansible-playbook site.yml --tags cham` gọi 3 lần chậm (3,5 giây) và 20 lần nhanh (~1 ms):

```
Trung bình ≈ (3 × 3500 + 20 × 1) / 23 ≈ 457 ms   → trông chấp nhận được
p99        ≈ 3500 ms                              → phản ánh đúng sự thật
```

**13% người dùng vừa đợi 3,5 giây, mà con số trung bình không hề cho bạn biết.**

Trung bình che giấu đuôi phân phối. p99 = "99% request nhanh hơn giá trị này" — đó mới là
thứ phản ánh trải nghiệm tồi tệ mà một phần người dùng thực sự gặp.

---

## Log có cấu trúc — thói quen phân biệt người biết vận hành

Hàm Lambda in log dạng **JSON**, không phải chuỗi tự do:

```python
print(json.dumps({"muc": "INFO", "nguoi_dung": ..., "thoi_gian_ms": 42.1}))
```

Nhờ vậy Logs Insights query được thẳng:

```
fields @timestamp, nguoi_dung, thoi_gian_ms
| filter thoi_gian_ms > 1000
| sort thoi_gian_ms desc
```

Nếu log là `"Xu ly xong trong 1234ms"` thì phải parse bằng biểu thức chính quy —
chậm hơn, đắt hơn, và **vỡ ngay khi ai đó đổi câu chữ**.

Cùng lý do đó, `pattern = "{ $.muc = \"ERROR\" }"` của metric filter mới viết được gọn thế.

---

## Bài IaC: chuyển state lên S3

Từ tuần 1 tới giờ state nằm ở file `terraform.tfstate` local. Với một người thì ổn.
Với một đội thì **hỏng**: hai người `apply` cùng lúc sẽ ghi đè state của nhau và tài nguyên
trở thành mồ côi.

| | Giải quyết gì |
|---|---|
| **S3 backend** | State ở một chỗ chung, có versioning để khôi phục |
| **DynamoDB lock** | Người thứ hai `apply` bị **chặn** cho tới khi người đầu xong |

### Bài toán con gà quả trứng

Terraform **không tự tạo được backend cho chính nó**. Nên phải làm hai bước:

```bash
# Bước 1 — tạo hạ tầng backend bằng local state
terraform apply -var tao_backend=true -var email_canh_bao=ban@example.com

# Bước 2 — xem cấu hình cần dán
terraform output -raw backend_config_mau
```

Dán khối đó vào `versions.tf` (đã có sẵn chỗ, đang bị comment), rồi:

```bash
terraform init -migrate-state    # Terraform hỏi có chuyển state lên S3 không → yes
```

> **Chú ý:** khối `backend` **không cho dùng biến hay biểu thức** — nó được đọc trước khi
> Terraform biết gì về variables. Phải điền số account thật vào. Đây là giới hạn có thật
> và hay làm người mới bối rối.

### Vì sao versioning trên bucket state là bắt buộc

State file chứa **mọi thứ ở dạng nguyên văn**: mật khẩu, khoá, endpoint riêng tư.
Nó cũng là thứ duy nhất Terraform dùng để biết cái gì đang tồn tại. State hỏng =
Terraform "quên" mất hạ tầng và sẵn sàng tạo lại từ đầu.

Versioning là **cách duy nhất** khôi phục. Code cũng cố tình **không** đặt
`force_destroy` trên bucket này.

---

## Terraform vs CloudFormation cho kỳ thi

Repo này dùng Terraform, nhưng **đề thi hỏi về CloudFormation**. Ánh xạ khái niệm:

| Terraform | CloudFormation | Ghi chú |
|---|---|---|
| `terraform plan` | **Change set** | Xem trước thay đổi |
| `terraform apply` | Create/Update stack | |
| `terraform destroy` | Delete stack | |
| State file | Stack (AWS tự quản lý) | CFN không có file state để mất |
| Module | **Nested stack** / module | |
| — | **StackSet** | Deploy nhiều account/region cùng lúc |
| `terraform plan` phát hiện | **Drift detection** | Ai đó sửa tay ngoài IaC |
| Workspace | Stack riêng theo môi trường | |

Khái niệm CFN cần biết cho kỳ thi: **change set**, **drift detection**, **nested stack**,
**StackSet**, **DeletionPolicy** (`Retain` để giữ tài nguyên khi xoá stack), và
**SAM** (phần mở rộng của CFN dành cho serverless).

---

## Checklist

- [ ] `terraform apply -var email_canh_bao=...` và **đã bấm Confirm trong hộp thư**
- [ ] `ansible-playbook site.yml --tags loi` — **nhận được email cảnh báo thật**
- [ ] Alarm tự trở về `OK` sau đó (nhờ `treat_missing_data = notBreaching`)
- [ ] Chạy `--tags cham`, mở dashboard so sánh trung bình với p99
- [ ] Chạy `--tags insights`, đọc được query Logs Insights
- [ ] Giải thích được `treat_missing_data` cho metric lỗi vs metric heartbeat
- [ ] Giải thích được composite alarm giải quyết vấn đề gì
- [ ] `terraform apply -var tao_backend=true`, migrate state lên S3, `terraform init -migrate-state`
- [ ] Xác nhận file `terraform.tfstate` local đã thành rỗng/backup
- [ ] Viết được bảng ánh xạ Terraform ↔ CloudFormation
- [ ] `terraform destroy` (nếu đã migrate state thì destroy vẫn chạy bình thường)

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Nếu đã tạo backend: bucket state **không** có `force_destroy` nên `destroy` sẽ báo lỗi
nếu bucket còn file. Đó là chủ ý — bạn phải xoá tay và có ý thức về việc mình đang xoá gì:

```bash
aws s3 rm s3://<bucket-state> --recursive
aws s3api delete-objects --bucket <bucket-state> \
  --delete "$(aws s3api list-object-versions --bucket <bucket-state> \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"
terraform destroy
```
