# Tuần 4 — Kho đóng, cửa hàng mở  (tự viết)

`Domain 1 · Security (30%)` `Domain 3 · Performance (24%)` `Domain 4 · Cost (20%)`

| | |
|---|---|
| **Chi phí khi chạy** | **~$0,000/giờ** — không thành phần nào tính theo giờ |
| **Quên 1 tháng** | **~$0,03** (vài MB lưu trữ + vài nghìn request; 1 TB truyền ra và 10M request/tháng nằm trong hạn mức always free của CDN) |
| **Thời gian** | ~3 giờ, trong đó ~20 phút là ngồi chờ CDN triển khai |
| **Điều kiện** | nên xong `w01-iam-foundations` — bạn sẽ viết một resource policy có `Principal` là một dịch vụ AWS, không phải một người |

> Lab này gần như miễn phí, nhưng nó là lab dễ để lại rác nhất cả bộ: bucket bật
> versioning **không xoá được bằng cách xoá file thường**. Đọc kỹ mục Dọn dẹp.

---

## Bối cảnh

Sản phẩm của công ty có một trang tài liệu kỹ thuật. Người đọc ở khắp nơi —
Việt Nam, Đức, Brazil — và họ than trang tải chậm.

Ba ràng buộc từ ba phía:

- **Đội bảo mật** vừa đọc một bài viết về hàng nghìn bucket bị lộ trên internet.
  Quy định mới: **không kho lưu trữ nào của công ty được truy cập trực tiếp từ
  internet.** Không ngoại lệ, kể cả với nội dung công khai. Lý do họ đưa ra rất
  đúng: một bucket mở là một bucket có thể bị liệt kê, và cấu trúc thư mục cũng
  là thông tin.
- **Đội tài liệu** thỉnh thoảng ghi đè nhầm một trang bằng bản nháp. Họ cần khôi
  phục được bản trước đó mà không phải nhờ ai.
- **Đội tài chính** phát hiện có 4 GB bản nháp cũ từ ba năm trước vẫn đang được
  lưu ở mức giá cao nhất. Họ muốn chuyện đó tự dọn.

---

## Yêu cầu

1. **Một địa chỉ HTTPS công khai** phục vụ trang tài liệu. Gọi vào phải trả `200`
   và nội dung phải chứa một chuỗi mốc do bạn đặt.
2. **PHỦ ĐỊNH — gọi thẳng vào kho lưu trữ phải bị từ chối.** Cùng một file, cùng
   một đường dẫn: qua địa chỉ công khai thì được, gọi thẳng vào kho thì `403`.
3. **Kho không có một đường nào ra internet công cộng**: bốn khoá chặn public đều
   bật, và không có quyền nào cấp cho `AllUsers`.
4. **PHỦ ĐỊNH — truy cập không mã hoá bị chuyển hướng.** Gọi vào địa chỉ công khai
   bằng `http://` phải nhận một mã chuyển hướng, không phải nội dung.
5. **Nội dung được nén trước khi truyền đi** khi trình duyệt báo là nó hiểu được
   nén. Response phải có header cho biết đã nén.
   > Ràng buộc thật của dịch vụ CDN: nó chỉ nén file **lớn hơn 1 KB** và có
   > content-type thuộc nhóm nén được. Trang chủ dài 20 chữ sẽ không bao giờ được
   > nén và bạn sẽ debug nhầm chỗ. Viết cho nó dài hơn 1 KB.
6. **Lần gọi thứ hai được phục vụ từ bộ nhớ đệm ở biên**, không phải từ kho.
   Response phải có header cho biết đã trúng cache.
7. **Bản cũ của một file khôi phục được** sau khi bị ghi đè.
8. **Rác tự dọn**: có quy tắc vòng đời đang bật, xử lý được ít nhất các bản cũ
   không còn hiện hành.
9. **Dữ liệu được mã hoá khi lưu.**

---

## Hợp đồng output

| Output | Kiểu | `verify.sh` dùng để |
|---|---|---|
| `cdn_url` | string | gốc của địa chỉ công khai, ví dụ `https://d111111abcdef8.cloudfront.net` — **không có dấu `/` ở cuối** |
| `duong_dan_trang_chu` | string | đường dẫn trang chủ, **bắt đầu bằng `/`**, ví dụ `/index.html` |
| `bucket_name` | string | kiểm tra khoá public, ACL, versioning, vòng đời, mã hoá |
| `bucket_regional_domain` | string | tên miền REST của kho, ví dụ `<ten>.s3.us-east-1.amazonaws.com` — dùng cho check phủ định "gọi thẳng vào kho" |
| `chuoi_moc` | string | chuỗi phải xuất hiện trong trang chủ, để chứng minh CDN đang phục vụ **đúng nội dung của bạn** chứ không phải trang lỗi |
| `chi_phi` | string | in ra trước khi gõ `yes` |

Đặt `chuoi_moc` là thứ không thể trùng ngẫu nhiên, ví dụ `MOC-W04-<vài ký tự ngẫu nhiên>`.

---

## Hàng rào của lab này

### Trần chi phí

| Thành phần | Giá | Nếu quên 1 tháng |
|---|---|---|
| Phân phối CDN (tồn tại) | **$0/giờ** — không tính theo giờ | $0 |
| CDN truyền ra | 1 TB/tháng **miễn phí vĩnh viễn** | $0 |
| CDN request | 10 triệu/tháng **miễn phí vĩnh viễn** | $0 |
| S3 Standard | $0,023/GB-tháng | ~$0,0001 cho vài MB |
| S3 request | $0,0004/1000 GET | ~$0,001 |
| Invalidation | 1.000 đường dẫn đầu/tháng miễn phí | $0 |
| **Tổng** | **~$0,000/giờ** | **~$0,03** |

Đây là lab rẻ nhất sau tuần 1. Nhưng nó có **hai bẫy tiền thật**, và cả hai đều
không nằm ở tiền theo giờ:

- **Bucket có versioning là bucket không bao giờ tự nhỏ đi.** Mỗi lần ghi đè tạo
  một version mới; version cũ vẫn tính tiền lưu trữ. Đây chính là 4 GB bản nháp
  mà đội tài chính phát hiện, và là lý do yêu cầu 8 tồn tại.
- **Logging của CDN vào S3** ghi liên tục và không có giới hạn. Đừng bật nó trong
  lab này.

### Cách làm rẻ nhất

- Đặt price class về nhóm rẻ nhất (chỉ Bắc Mỹ + châu Âu). Bạn ở Việt Nam nên sẽ
  thấy độ trễ cao hơn — nhưng bài học không đổi, và với hạn mức 1 TB miễn phí thì
  đây là tiết kiệm mang tính nguyên tắc chứ không phải tiền. Trong production đây
  là một đòn bẩy chi phí thật.
- **Không bật** cross-region replication trong lab này. Nó nhân đôi tiền lưu trữ
  và tạo một bucket ở region thứ hai — thứ dễ quên nhất trong cả khoá.
- **Không tạo customer managed KMS key** ($1/tháng mỗi key). Mã hoá quản lý bởi
  chính dịch vụ lưu trữ là miễn phí và đủ cho yêu cầu 9.
- Không mua tên miền, không tạo hosted zone ($0,50/tháng). Tên miền mặc định của
  CDN có sẵn chứng chỉ TLS hợp lệ.

### Boundary chặn gì, vì sao

| Boundary chặn | Vì sao |
|---|---|
| `s3:PutBucketPublicAccessBlock` với giá trị `false` | biến một bucket thành public là cách rò rỉ dữ liệu số một trên thế giới. Boundary không cho bạn tự bắn vào chân — **và yêu cầu 3 của đề bài là cùng một điều, nhìn từ phía kiến trúc** |
| `kms:CreateKey` | $1/tháng mỗi key, và lab không cần |
| `s3:PutBucketReplication` | nhân đôi lưu trữ + bucket ở region thứ hai dễ bị bỏ quên |
| mọi API ngoài `us-east-1` | như mọi tuần. Lưu ý: CDN là dịch vụ **global**, API của nó luôn đi qua `us-east-1` — nên nó không vướng hàng rào này |

**Gặp `AccessDenied` — boundary hay bug?**

- `AccessDenied` lúc `apply` khi tắt Block Public Access → **boundary, đúng thiết
  kế.** Bạn đang đi sai hướng: bài này giải bằng cách cho CDN một danh tính để đọc
  kho, chứ không phải bằng cách mở kho ra.
- `403` khi `curl` vào địa chỉ CDN → **bug của bạn**, và gần như luôn là resource
  policy của kho chưa cho phép đúng principal, hoặc cho phép sai điều kiện.
- `403` khi `curl` thẳng vào kho → **đúng thiết kế**, đó là yêu cầu 2 đang xanh.
- CDN trả `403` với body XML `AccessDenied` cho một file **có tồn tại** → xem lại
  điều kiện trong resource policy (thường là điều kiện so ARN của phân phối).

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh toàn bộ, gồm cả ba check phủ định
- [ ] `terraform destroy` sạch, và bucket **thật sự biến mất** (kiểm tra bằng lệnh
      ở mục Dọn dẹp — bucket có version rất hay sót lại)
- [ ] Giải thích được: resource policy của kho cấp quyền cho **cái gì**? Nó là
      một người, một dịch vụ, hay một phân phối cụ thể? Và vì sao câu trả lời
      chính xác lại quan trọng
- [ ] Trả lời được: nếu ai đó biết tên kho của bạn, họ làm được gì? Liệt kê được
      danh sách file không? Vì sao?
- [ ] Sửa một file, upload đè, rồi khôi phục bản cũ **bằng CLI**. Giải thích được
      `delete marker` là gì và vì sao xoá một file trong bucket có versioning
      lại không làm nó nhỏ đi
- [ ] Trả lời được: bạn vừa sửa nội dung nhưng CDN vẫn trả bản cũ. Có hai cách xử
      lý, một cách tốn tiền và một cách miễn phí. Cách nào tốt hơn trong
      production, và vì sao?

---

## Quy trình

```bash
source ../../env.sh
../guard.sh

cd terraform
terraform init
terraform apply       # phân phối CDN mất 5–15 phút để triển khai xong

# Chờ tới khi trạng thái là Deployed:
watch -n 30 "aws cloudfront list-distributions --profile lab-builder \
  --query 'DistributionList.Items[].[Id,Status,DomainName]' --output table"

cd .. && ./verify.sh
$PAGER DOI-CHIEU.md

cd terraform && terraform destroy
```

---

## Dọn dẹp

**Đây là lab để lại rác nhiều nhất.** Hai lý do:

1. Bucket bật versioning: xoá file thường chỉ tạo thêm một *delete marker*.
   Bucket vẫn không rỗng, và `terraform destroy` báo `BucketNotEmpty`.
2. Xoá một phân phối CDN cần hai bước: tắt (disable) rồi mới xoá được, và giữa
   hai bước là 5–15 phút chờ. Terraform tự làm, nhưng nếu bạn `Ctrl-C` giữa chừng
   thì phân phối kẹt lại ở trạng thái nửa vời.

```bash
cd terraform && terraform destroy
```

Nếu treo ở bucket:

```bash
B=$(terraform output -raw bucket_name)
# Xoá mọi version VÀ mọi delete marker — hai danh sách khác nhau
aws s3api list-object-versions --bucket "$B" --profile lab-builder \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json > /tmp/v.json
aws s3api delete-objects --bucket "$B" --profile lab-builder --delete file:///tmp/v.json
aws s3api list-object-versions --bucket "$B" --profile lab-builder \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json > /tmp/d.json
aws s3api delete-objects --bucket "$B" --profile lab-builder --delete file:///tmp/d.json
terraform destroy
```

Cách phòng bệnh cho lần sau: khai `force_destroy = true` ngay từ đầu. Trong
production thì tuyệt đối không — đó là nút xoá không hỏi lại.

Kiểm tra đã sạch:

```bash
aws s3 ls --profile lab-builder | grep self-w04 || echo "sạch bucket"
aws cloudfront list-distributions --profile lab-builder \
  --query 'DistributionList.Items[].[Id,Status]' --output table
aws cloudfront list-origin-access-controls --profile lab-builder \
  --query 'OriginAccessControlList.Items[].[Id,Name]' --output table
../../scripts/find-orphans.sh
```
