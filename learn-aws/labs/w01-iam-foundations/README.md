# Tuần 1 — Nền móng và quyền hạn

`Domain 1 · Security (30% đề)` `Domain 4 · Cost`

| | |
|---|---|
| **Chi phí** | **$0,00** — IAM miễn phí hoàn toàn, S3 vài KB không đáng kể |
| **Thời gian** | ~2 giờ |
| **Dọn dẹp** | `cd terraform && terraform destroy` |
| **Rủi ro đốt tiền** | Không có. Đây là lab an toàn nhất cả khóa. |

---

## Tại sao lab này quan trọng hơn nó trông có vẻ

Security chiếm **30% đề thi SAA-C03** — miền nặng nhất. Và phần lớn câu hỏi security
thực chất là câu hỏi IAM trá hình. Nếu bạn chỉ ôn được một thứ, ôn cái này.

Tạo IAM user thì console làm trong 10 giây. Lab này không dạy điều đó. Nó dạy bạn phân biệt
**bốn loại policy** mà đề thi liên tục trộn lẫn để bẫy:

| Loại | Gắn vào đâu | Trả lời câu hỏi |
|---|---|---|
| **Identity policy** | user, group, role | "Danh tính này được làm gì?" |
| **Resource policy** | bucket, queue, key… | "Ai được đụng vào tôi?" |
| **Trust policy** | role (và chỉ role) | "Ai được phép hóa thân thành tôi?" |
| **Permission boundary** | user, role | "Trần quyền tối đa là bao nhiêu?" (tuần 9) |

---

## Chạy

```bash
source ../../env.sh          # PATH + locale + AWS_PROFILE
cd terraform
terraform init
terraform apply              # ~15 giây, không tốn tiền

cd .. && ./verify.sh         # kiểm chứng bằng IAM Policy Simulator
```

Sau đó chạy phần Ansible — nó làm việc khác hẳn Terraform:

```bash
cd ansible
ansible-playbook site.yml                  # mô phỏng quyền + soi vệ sinh IAM
ansible-playbook site.yml --tags simulate   # chỉ phần mô phỏng
ansible-playbook site.yml --tags audit      # chỉ phần audit
```

### Vì sao ở đây Ansible không dựng hạ tầng

Trong repo này phân vai rõ ràng: **Terraform dựng hạ tầng, Ansible vận hành nó.**
Tuần 1 không có máy nào để cấu hình, nên Ansible làm việc gần nhất với vai trò thật của nó —
kiểm tra và báo cáo. Playbook sẽ:

- chạy **Policy Simulator** trên ma trận action để chứng minh policy chặn đúng chỗ,
- kiểm tra **root account đã bật MFA chưa**,
- đếm **access key tĩnh** (thứ rò rỉ nhiều nhất trong thực tế — commit nhầm lên GitHub),
- liệt kê ai đang cầm **AdministratorAccess**,
- đọc finding của **IAM Access Analyzer**.

Đó là một bài audit bảo mật thu nhỏ, chạy lại được bất cứ lúc nào.

---

## Terraform dựng những gì

```
S3 bucket (private, chặn public hoàn toàn)
├── readme.txt
├── private/luong.txt          ← cố ý để bạn phát hiện lỗ hổng
└── bucket policy: Deny mọi request không dùng TLS   ← resource policy

IAM policy "w01-s3-reader"     ← identity policy, dùng chung cho cả hai bên dưới
├── IAM user "w01-reader"
└── IAM role "w01-ec2-reader"  ← trust policy: chỉ ec2.amazonaws.com assume được
    └── instance profile        ← vỏ bọc bắt buộc để gắn role vào EC2

IAM Access Analyzer             ← miễn phí, soi policy hở ra ngoài account
```

---

## Ba cái bẫy được cài sẵn trong code

### 1. ARN có `/*` và ARN không có `/*` là hai thứ khác nhau

```hcl
resources = [aws_s3_bucket.lab.arn]         # arn:aws:s3:::bucket   → cho ListBucket
resources = ["${aws_s3_bucket.lab.arn}/*"]  # arn:aws:s3:::bucket/* → cho GetObject
```

Viết `s3:GetObject` trên ARN không có `/*` thì policy **không bao giờ khớp** và bạn sẽ
ngồi debug hàng giờ. Đây là lỗi phổ biến nhất khi viết policy S3, và cũng là một dạng
câu hỏi thi.

### 2. Trust policy không nói role được làm gì

Rất nhiều người đọc `assume_role_policy` rồi tưởng đó là quyền của role. Không phải.
Nó chỉ trả lời **ai được phép mượn role này**. Quyền thật nằm ở policy gắn kèm.
Hai thứ tách rời hoàn toàn — và đó chính là điều làm role mạnh hơn user.

### 3. Bucket vẫn đang hở

`verify.sh` sẽ cho bạn thấy `w01-reader` đọc được cả `private/luong.txt`.
Policy viết `Resource = "bucket/*"` nên nó phủ **mọi** object, kể cả thư mục nhạy cảm.
Bài tập bắt buộc: sửa lại để chặn tiền tố `private/`, rồi chạy lại `verify.sh`.

Có hai cách, và câu hỏi hay là **cách nào an toàn hơn**:

```hcl
# Cách A — thu hẹp Allow
resources = ["${aws_s3_bucket.lab.arn}/public/*"]

# Cách B — thêm Deny riêng
statement {
  effect    = "Deny"
  actions   = ["s3:GetObject"]
  resources = ["${aws_s3_bucket.lab.arn}/private/*"]
}
```

Gợi ý để tự trả lời: nếu tháng sau có người thêm một Allow rộng vào account,
cách nào vẫn giữ được `private/` an toàn? Nhớ quy tắc **explicit Deny thắng tất cả**.

---

## Kiến thức thi — học ở lab này

### Thứ tự đánh giá quyền IAM

Ghi nhớ thứ tự này, đề thi hỏi liên tục:

```
1. Có explicit DENY ở bất kỳ đâu?        → TỪ CHỐI. Dừng. Không gì cứu được.
2. SCP của Organizations có cho phép?    → Không thì từ chối.
3. Có explicit ALLOW ở identity policy
   HOẶC resource policy?                 → Có thì cho phép.
4. Còn lại                               → TỪ CHỐI (implicit deny mặc định).
```

Trong output của Policy Simulator bạn sẽ thấy đúng ba giá trị này:
`allowed` · `implicitDeny` (không ai cho phép) · `explicitDeny` (có người cấm).

### Role hay user?

| | IAM user | IAM role |
|---|---|---|
| Credential | Access key **dài hạn** | Token **tạm thời**, tự xoay vòng |
| Rò rỉ thì | Sống mãi tới khi bạn phát hiện | Hết hạn sau vài giờ |
| Dùng cho | Con người (và ngày càng ít) | Dịch vụ AWS, ứng dụng, cross-account |
| Đề thi chọn | Gần như không bao giờ | **Gần như luôn luôn** |

Quy tắc để đi thi: thấy đáp án nào có "lưu access key trong ứng dụng / biến môi trường /
file config" → loại ngay, kể cả khi nghe có vẻ hợp lý.

---

## Checklist

- [ ] `terraform apply` chạy xong
- [ ] `./verify.sh` — 8/8 đúng
- [ ] `ansible-playbook site.yml` chạy xong, đọc hết output audit
- [ ] Root account **đã bật MFA** (playbook sẽ hét lên nếu chưa)
- [ ] Sửa policy chặn được `private/`, `verify.sh` phản ánh thay đổi
- [ ] Nói được bằng lời: identity policy khác resource policy ở đâu
- [ ] Nói được bằng lời: vì sao role an toàn hơn access key
- [ ] Vẽ được sơ đồ 4 bước đánh giá quyền
- [ ] `terraform destroy` — sạch

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Lab này không tốn tiền nên **giữ lại cũng được**. Nhưng tập thói quen destroy ngay từ
tuần 1, vì tới tuần 3 thói quen đó sẽ đáng giá thật.

> Nếu destroy báo lỗi bucket không rỗng: `force_destroy = true` đã được đặt sẵn nên
> không xảy ra. Trường hợp bạn tự upload thêm file có versioning thì xem cách xử lý
> ở [tuần 4](../w04-s3-cloudfront/).
