# Tuần 08 — Tầng biên: cái gì được cache, cái gì không  (tự viết)

`Domain 3 · High-Performing Architectures (24% đề)`

| | |
|---|---|
| **Chi phí khi chạy** | **$0,00/giờ** — CloudFront always free 1 TB ra + 10 triệu request/tháng; S3 vài KB |
| **Quên 1 tháng** | **$0,00**, hoặc **$0,50** nếu bạn làm phần Route 53 tuỳ chọn và quên xoá hosted zone |
| **Thời gian** | ~3 giờ viết + ~15 phút `apply` + ~2 phút `verify.sh` |
| **Điều kiện** | không cần lab nào trước. Nên đọc [`docs/aws/w08-dns-cdn-edge.md`](../../../docs/aws/w08-dns-cdn-edge.md) trước |

> **Đọc trước khi apply:** một CloudFront distribution mất **8–15 phút** để triển
> khai, và cũng chừng đó để xoá. Đừng bắt đầu lab này lúc 23h50.

---

## Bối cảnh

Trang web của bạn phục vụ ba loại nội dung rất khác nhau, nhưng tất cả nằm trên
cùng một kho lưu trữ và cùng một tên miền:

- **Ảnh, CSS, JS** — giống hệt nhau với mọi khách, đổi vài tháng một lần. Đội
  frontend gắn thêm `?v=8f2a1` vào URL mỗi lần build để "phá cache trình duyệt".
- **Trang cá nhân hoá** — nội dung phụ thuộc vào tham số `?u=<mã người dùng>`.
  Hai người dùng khác nhau phải thấy hai nội dung khác nhau. Người dùng cũ quay
  lại thì nên thấy ngay, không phải chờ.
- **API trạng thái đơn hàng** — phải luôn là số liệu mới nhất. Trả về dữ liệu cũ
  dù chỉ 10 giây cũng là sai.

Tuần trước có sự cố: đội frontend đổi `?v=` liên tục nên hoá đơn CloudFront tăng
gấp bốn vì mỗi URL là một bản cache mới, còn tỉ lệ trúng cache rớt xuống 12%.
Đồng thời, một khách hàng phàn nàn rằng anh ta nhìn thấy **tên của người khác**
trên trang cá nhân hoá.

Nhiệm vụ của bạn: cùng một kho lưu trữ, ba hành vi biên khác nhau, và chứng minh
được từng cái.

---

## Yêu cầu

1. **Kho lưu trữ không lộ ra internet.** Truy cập thẳng vào kho bằng địa chỉ gốc
   của nó phải bị **từ chối**. Đường duy nhất vào nội dung là qua tầng biên.

2. **Chỉ HTTPS.** Gọi bằng `http://` không được trả về nội dung — phải bị đẩy
   sang `https://`.

3. **Ba đường dẫn, ba hành vi.** Tầng biên phải phục vụ HTTP 200 ở cả ba đường
   dẫn dưới đây, mỗi đường một hành vi cache khác nhau:

   | Đường dẫn | Hành vi bắt buộc |
   |---|---|
   | `/tinh/thu.txt` | Query string **không** được tham gia vào việc phân biệt bản cache. `?v=abc` và `?v=xyz` phải dùng **chung một bản** đã lưu ở biên |
   | `/nguoidung/thu.txt` | Query string **có** tham gia. `?u=alice` và `?u=bob` là **hai bản riêng biệt**. Gọi lại cùng một `u` thì được phục vụ từ biên |
   | `/api/thu.txt` | **Không bao giờ** phục vụ từ bản đã lưu. Mọi request đều phải đi tới tận kho |

4. **Biên tự chèn header bảo mật.** Mọi phản hồi phải mang
   `x-content-type-options: nosniff`. Header này phải do **tầng biên** sinh ra,
   không phải do kho lưu trữ đính kèm vào từng file — vì tháng sau sẽ có 4000
   file và không ai đi sửa metadata từng cái.

5. **Tuỳ chọn (tốn $0,50/tháng): tên miền riêng.** Nếu bạn có một domain thật,
   trỏ nó vào tầng biên bằng một bản ghi **không mất phí truy vấn** và **dùng
   được ở gốc tên miền** (`example.com`, không phải `www.example.com`). Không có
   domain thì bỏ qua — `verify.sh` sẽ báo *bỏ qua*, không báo *hỏng*, và bạn vẫn
   đạt lab.

### Hợp đồng nội dung

`verify.sh` gọi đúng ba URL ở bảng trên. Nội dung file là gì không quan trọng —
vài chữ cũng được — miễn là cả ba trả về **200**. Ba file đó bạn tự đưa lên kho
(Terraform làm được việc này).

---

## Hợp đồng output

| Output | Kiểu | `verify.sh` dùng để làm gì |
|---|---|---|
| `dia_chi_bien` | string | Tên miền của điểm truy cập biên, **không kèm** `https://` và không kèm dấu `/` cuối. Ví dụ `d111111abcdef8.cloudfront.net` |
| `kho_luu_tru` | string | Tên kho lưu trữ gốc. Dùng để thử truy cập thẳng và để kiểm tra chặn public |
| `ten_mien` | string, **tuỳ chọn** | Tên miền riêng, nếu bạn làm yêu cầu 5. Không làm thì **không khai output này** |
| `vung_dns` | string, **tuỳ chọn** | ID của vùng DNS chứa bản ghi đó |

Đặt tên resource với prefix `self-w08-`.

> `ten_mien` và `vung_dns` được đọc bằng `terraform output` trực tiếp chứ không
> qua `need_output`, nên thiếu chúng thì `verify.sh` bỏ qua nhóm check đó thay vì
> dừng. Đây là chỗ duy nhất trong cả bộ lab có output tuỳ chọn, và lý do là tiền:
> một hosted zone tốn $0,50/tháng dù bạn không truy vấn lần nào.

---

## Hàng rào của lab này

**Trần chi phí: $0,00/giờ.** CloudFront nằm trong danh sách *always free*: 1 TB
dữ liệu ra và 10 triệu request HTTPS mỗi tháng, vĩnh viễn. `verify.sh` gọi
khoảng 15 request. Bản thân distribution **không** tính tiền theo giờ — đây là
một trong số rất ít dịch vụ AWS như vậy, và là lý do lab này an toàn.

**Hai chỗ tốn tiền, cả hai đều tự chọn:**

| Thứ | Giá thật | Cách tránh |
|---|---|---|
| Route 53 hosted zone | **$0,50/tháng mỗi zone**, tính cả khi không truy vấn | Bỏ yêu cầu 5. Lab vẫn đạt |
| Route 53 health check | **$0,50/tháng** | Lab này không yêu cầu health check |
| Invalidation | 1000 đường dẫn đầu mỗi tháng miễn phí, sau đó $0,005/đường dẫn | Dùng versioned URL thay vì invalidation — chính là bài học của lab |

**Boundary chặn gì ở lab này:**

- `globalaccelerator:*` — ~$18/tháng. Nếu bạn định "tăng tốc" bằng Global
  Accelerator thì hàng rào chặn. Đó là cố ý: với nội dung web tĩnh, Global
  Accelerator là **đáp án sai**, xem `DOI-CHIEU.md`.
- `route53domains:RegisterDomain` — mua domain là tiền thật, không hoàn lại.
- Mọi API ngoài `us-east-1`. Lưu ý CloudFront, Route 53 và ACM-cho-CloudFront
  đều là dịch vụ **global**, hàng rào đã chừa chúng ra nên bạn không bị chặn.

**Phân biệt `AccessDenied` của hàng rào với bug của bạn:**

- `explicit deny in a permissions boundary` → hàng rào.
- `Access Denied` khi CloudFront gọi tới kho lưu trữ (biểu hiện: trình duyệt
  nhận 403 với thân XML của S3) → **bug của bạn**, không phải hàng rào. Đó là
  bucket policy chưa cho phép tầng biên đọc.
- Phân biệt nhanh: 403 kèm XML `<Code>AccessDenied</Code>` là S3 nói; 403 kèm
  trang HTML của CloudFront là CloudFront nói. Hai chỗ khác nhau hoàn toàn.

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh hết (phần Route 53 báo *bỏ qua* cũng tính là đạt)
- [ ] Giải thích được **cache key** gồm những thành phần nào, và vì sao thêm một
      thành phần vào cache key luôn làm giảm tỉ lệ trúng cache
- [ ] Giải thích được sự khác nhau giữa **cache policy** và **origin request
      policy** — cái nào ảnh hưởng tỉ lệ trúng, cái nào không
- [ ] Chạy một invalidation bằng tay, quan sát `x-cache` đổi từ `Hit` về `Miss`,
      rồi nói được vì sao **versioned URL rẻ hơn invalidation** ở quy mô lớn
- [ ] Trả lời được: sự cố "khách hàng nhìn thấy tên người khác" trong Bối cảnh
      xảy ra do cấu hình sai chỗ nào, và cấu hình sai đó tên là gì
- [ ] Nói được vì sao bản ghi Alias dùng được ở gốc tên miền còn CNAME thì không

---

## Quy trình

```bash
source ../../env.sh
../_boundary/guard.sh

cd terraform
terraform init
# viết main.tf + outputs.tf của bạn
terraform apply            # 8–15 phút, phần lớn là chờ distribution triển khai

cd ..
./verify.sh                # ~2 phút
cat DOI-CHIEU.md           # chỉ khi đã xanh hết

cd terraform && terraform destroy   # cũng 8–15 phút
```

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

`destroy` chậm vì CloudFront phải disable distribution trước rồi mới xoá được.
Nếu Terraform báo timeout, chạy lại `terraform destroy` lần nữa — nó sẽ tiếp tục
từ chỗ dở.

Kiểm tra đã sạch:

```bash
aws cloudfront list-distributions --profile lab-builder \
  --query "DistributionList.Items[?Comment && contains(Comment,'self-w08')].[Id,Status,Enabled]" --output table
aws s3 ls --profile lab-builder | grep self-w08
aws route53 list-hosted-zones --profile lab-builder --query "HostedZones[].Name"
```

Ba lệnh phải trả về rỗng. **Lệnh thứ ba quan trọng nhất**: hosted zone là thứ
duy nhất trong lab này còn tính tiền sau khi bạn đóng máy.

Nếu `destroy` báo bucket không rỗng: bạn đã bật versioning hoặc tự upload thêm
file. Xoá hết version rồi destroy lại, hoặc đặt `force_destroy = true` từ đầu.
