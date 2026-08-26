# Tuần 4 — S3 và các loại lưu trữ

`Domain 1 · Security` `Domain 3 · Performance` `Domain 4 · Cost`

| | |
|---|---|
| **Chi phí** | **~$0** — CloudFront 1 TB/tháng always free, site vài chục KB |
| **Thời gian** | ~2,5 giờ (CloudFront deploy mất 5–10 phút, cứ để chạy) |
| **Dọn dẹp** | `cd terraform && terraform destroy` (~5 phút vì CloudFront xoá chậm) |

> Lab này gần như miễn phí và **đáng giữ lại** — capstone tuần 6 sẽ nối API vào chính
> distribution này.

---

## Chạy

```bash
source ../../env.sh
cd terraform && terraform init && terraform apply     # ~6 phút
cd .. && ./verify.sh

cd ansible
ansible-playbook site.yml --tags deploy      # đẩy nội dung + invalidate
ansible-playbook site.yml --tags versioning  # bài delete marker
ansible-playbook site.yml --tags presigned   # URL có hạn
```

---

## Ý chính: bucket đóng hoàn toàn mà website vẫn chạy

```
Người dùng → CloudFront → (OAC, ký SigV4) → S3 bucket ĐÓNG
                                              Block Public Access: 4/4 bật
                                              static website hosting: TẮT
```

Gọi thẳng URL S3 → **403**. `verify.sh` kiểm tra đúng điều này.

Đây là mẫu chuẩn và là đáp án cho *"host web tĩnh an toàn, chi phí thấp"*.
Cách sai phổ biến là bật static website hosting rồi mở bucket public — vừa hở,
vừa không có HTTPS.

### OAC chứ không phải OAI

**OAI** (Origin Access Identity) là cơ chế cũ. **OAC** (Origin Access Control) thay thế nó:
hỗ trợ SSE-KMS, mọi region, và mọi phương thức HTTP. Tài liệu nào còn dạy OAI là tài liệu cũ.

### Điều kiện `AWS:SourceArn` không phải trang trí

```hcl
condition {
  test     = "StringEquals"
  variable = "AWS:SourceArn"
  values   = [aws_cloudfront_distribution.site.arn]
}
```

Bỏ dòng này đi thì principal là `cloudfront.amazonaws.com` — nghĩa là **bất kỳ
distribution CloudFront nào của bất kỳ ai** cũng đọc được bucket của bạn.
Đó là lỗ hổng **confused deputy**, và nó xuất hiện trong đề thi security.

---

## Ba cái bẫy tiền được cài sẵn trong lifecycle rule

### 1. Version cũ tính tiền mãi mãi

Bật versioning mà không có rule dọn thì mỗi lần ghi đè là thêm một bản lưu trữ vĩnh viễn.

```hcl
noncurrent_version_expiration { noncurrent_days = 7 }
```

### 2. Multipart upload dở dang là chi phí vô hình

Upload lớn thất bại để lại các phần đã tải. Chúng **không hiện trong danh sách object**
nhưng **vẫn tính tiền**. Rất nhiều người không bao giờ phát hiện ra.

```hcl
abort_incomplete_multipart_upload { days_after_initiation = 3 }
```

### 3. Ngưỡng lưu tối thiểu của Glacier

Chuyển object sang Glacier rồi xoá sau 10 ngày → **vẫn bị tính đủ 90 ngày**.

| Storage class | Giá/GB | Tối thiểu | Lấy ra mất bao lâu |
|---|---|---|---|
| Standard | $0,023 | — | tức thì |
| Standard-IA | $0,0125 | 30 ngày | tức thì |
| One Zone-IA | $0,010 | 30 ngày | tức thì (mất AZ là mất data) |
| Glacier Instant Retrieval | $0,004 | 90 ngày | tức thì |
| Glacier Flexible Retrieval | $0,0036 | 90 ngày | vài phút → 12 giờ |
| Glacier Deep Archive | $0,00099 | 180 ngày | 12 → 48 giờ |

Đề thi cho tình huống rồi hỏi chọn lớp nào. Từ khoá quyết định là **tần suất truy cập**,
**thời gian chấp nhận chờ**, và **thời gian lưu tối thiểu**.

---

## Delete marker — vì sao bucket "đã xoá hết file" vẫn không xoá được

Chạy `ansible-playbook site.yml --tags versioning` để tự thấy:

1. Ghi đè `version.txt` ba lần → có 4 version.
2. `delete-object` → **không xoá gì cả**, chỉ đặt một *delete marker* lên trên cùng.
3. File biến mất khỏi danh sách, nhưng mọi version cũ **vẫn còn và vẫn tính tiền**.
4. Khôi phục = **xoá delete marker**, không phải "undelete".

Đây là lý do `terraform destroy` cần `force_destroy = true`, và là lý do xoá bucket
bằng console hay thất bại với *"bucket not empty"* dù nhìn thấy trống.

---

## Invalidation vs đổi tên file

Đẩy file mới lên S3 **không** cập nhật cache CloudFront. Hai cách:

| Cách | Chi phí | Dùng khi |
|---|---|---|
| Invalidation | 1000 path/tháng free, sau đó **$0,005/path** | Sửa gấp, ít file |
| **Tên file có hash** (`app.a3f9c2.js`) | **Miễn phí** | Mặc định nên dùng |

URL mới thì không có cache cũ để mà xoá. Đây là cách các đội chuyên nghiệp làm,
và là đáp án cho *"cập nhật nội dung CDN với chi phí thấp nhất"*.

---

## Cross-Region Replication — bật rồi TẮT NGAY

```bash
terraform apply -var enable_crr=true      # tạo bucket ở us-west-2
# ... kiểm chứng file được nhân bản ...
terraform apply -var enable_crr=false     # TẮT
```

Ba điều kiện bắt buộc của CRR, đều hay ra thi:

1. **Cả hai** bucket phải bật versioning.
2. Cần IAM role cho S3 assume.
3. **Chỉ object tạo SAU khi bật rule** mới được nhân bản. Object cũ cần S3 Batch Replication.

> ⚠️ Bucket ở region thứ hai là thứ bị bỏ quên nhiều nhất — bạn sẽ không bao giờ
> mở console region đó nữa. `verify.sh` mục 8 kiểm tra đúng chỗ này, và
> `../../scripts/find-orphans.sh --all` quét mọi region.

---

## Bài tập: hai yêu cầu bảo mật mâu thuẫn nhau

```bash
terraform apply -var enable_ip_restriction=true -var allowed_ip="$(curl -s ifconfig.me)/32"
```

Bucket giờ chỉ cho IP của bạn đọc. **Website sẽ hỏng** — vì CloudFront gọi từ IP edge,
không phải IP của bạn.

Đó chính là điểm của bài tập: bạn vừa gặp một xung đột policy thật. Nhớ lại thứ tự
đánh giá quyền ở tuần 1 — **explicit Deny thắng tất cả**, kể cả Allow dành cho CloudFront.

Câu hỏi: làm sao vừa giới hạn IP cho người dùng cuối, vừa để CloudFront hoạt động?
(Gợi ý: giới hạn IP không thuộc về bucket policy. Nó thuộc về tầng nào?)

---

## Ranh giới Terraform / Ansible ở tuần này

| | Terraform | Ansible |
|---|---|---|
| Việc | Bucket, distribution, OAC, lifecycle, policy | Đẩy nội dung, invalidate, presigned URL |
| Tần suất | Dựng một lần | Vài chục lần mỗi tuần |

Đây đúng là cách các đội làm thật. Đưa việc deploy nội dung vào Terraform là dùng sai
công cụ — mỗi lần sửa một dòng HTML mà phải `terraform apply` thì quy trình sẽ tắc.

---

## Checklist

- [ ] `terraform apply`, đợi CloudFront deploy xong
- [ ] `./verify.sh` — mục 2 phải cho **403** khi gọi thẳng S3
- [ ] Mở CloudFront URL, xem header `x-cache` đổi từ Miss sang Hit
- [ ] Chạy `--tags versioning`, hiểu delete marker
- [ ] Chạy `--tags presigned`, đợi hết hạn rồi gọi lại để thấy lỗi
- [ ] Bật CRR, kiểm chứng, **tắt lại**
- [ ] Thử `enable_ip_restriction=true` và giải thích được vì sao web hỏng
- [ ] Viết được bảng 6 storage class kèm ngưỡng tối thiểu
- [ ] Nếu destroy: xác nhận bucket region phụ cũng đã mất

---

## Dọn dẹp

```bash
cd terraform && terraform destroy    # ~5 phút, CloudFront xoá chậm
```

Hoặc **giữ lại** — lab này gần như $0 và tuần 6 sẽ nối API vào distribution này để
thành capstone. Nếu giữ, chỉ cần chắc chắn `enable_crr = false`.
