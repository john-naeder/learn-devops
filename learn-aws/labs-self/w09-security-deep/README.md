# Tuần 09 — Những thứ KHÔNG được phép xảy ra  (tự viết)

`Domain 1 · Secure Architectures (30% đề — miền nặng nhất)`

| | |
|---|---|
| **Chi phí khi chạy** | **$0,00/giờ** — IAM, STS và SSM Parameter Store Standard miễn phí hoàn toàn |
| **Quên 1 tháng** | **$0,00** (vài KB S3 làm tròn xuống 0) |
| **Thời gian** | ~4 giờ — lab dài nhất và đáng nhất trong bộ |
| **Điều kiện** | nên xong `w01-iam-foundations` trước. Đọc [`docs/aws/w09-security-deep.md`](../../../docs/aws/w09-security-deep.md) |

> Nếu bạn chỉ còn thời gian làm **một** lab tự viết, làm lab này. 30% đề thi, và
> phần lớn câu hỏi "security" thực chất là câu hỏi IAM trá hình.

---

## Bối cảnh

Công ty bạn thuê một đội vận hành bên ngoài. Họ cần vào hệ thống để xử lý sự cố,
nhưng ba điều sau là **không thương lượng**:

- Họ **không được cầm bất kỳ khoá dài hạn nào** của bạn. Mỗi lần vào phải là một
  phiên tạm thời, và phiên đó không được sống quá một giờ.
- Đội vận hành có nhiều khách hàng. Nếu một khách hàng khác biết được cách gọi
  vào hệ thống của bạn, họ vẫn phải bị chặn — kể cả khi họ dùng đúng công cụ của
  đội vận hành.
- Bảng lương nằm cùng kho dữ liệu với dữ liệu vận hành. **Không ai được đọc nó** —
  không phải đội vận hành, không phải bạn, không phải cái role admin đang chạy
  `terraform apply`. Chỉ đúng một danh tính "phá kính" được mở, và việc mở đó
  phải để lại dấu vết.

Ba tháng nữa sẽ có một kỹ sư mới, vội, gắn `AdministratorAccess` vào role của đội
vận hành để "cho nhanh". Hệ thống của bạn phải sống sót qua ngày đó.

---

## Yêu cầu

1. **Vào bằng phiên tạm thời, không bằng khoá.** Có một danh tính "vận hành viên"
   mà bên ngoài mượn được. Mượn thành công thì nhận về credential **hết hạn**.
   Phiên **không được** dài quá 1 giờ — xin 2 giờ phải bị từ chối.

2. **Mượn phải có mật khẩu ngữ cảnh.** Mượn mà không kèm một chuỗi bí mật đã
   thoả thuận trước thì bị từ chối. Kèm sai chuỗi cũng bị từ chối.

3. **Vận hành viên làm được đúng việc của mình, không hơn.** Đọc và ghi được
   trong khu làm việc của mình ở kho dữ liệu. Và **không** làm được:
   liệt kê danh tính trong account, xem tài nguyên máy chủ, liệt kê toàn bộ kho
   dữ liệu của công ty.

4. **Bảng lương: không ai đọc được, kể cả admin.** Khu `bi-mat/` trong kho dữ
   liệu phải từ chối `GetObject` với **mọi** danh tính — kể cả danh tính đang
   chạy `terraform apply`, vốn có `AdministratorAccess`. Việc chặn phải nằm ở
   **phía kho dữ liệu**, không phải trông chờ từng danh tính tự kiềm chế.

5. **Đúng một cửa phá kính.** Một danh tính duy nhất đọc được `bi-mat/`. Và việc
   chặn ở yêu cầu 4 phải **hẹp**: khu `lam-viec/` vẫn phải đọc được bình thường
   bởi admin.

6. **Bí mật cấu hình lưu đúng chỗ.** Mật khẩu dịch vụ phải nằm ở một nơi **mã
   hoá** và **miễn phí**. Vận hành viên đọc được bí mật của mình (kèm giải mã),
   và **không** đọc được bí mật của đội khác.

7. **Tự viết một trần quyền.** Viết một policy đóng vai **permission boundary**
   cho vận hành viên: một trần quyền sao cho **dù ngày mai có ai gắn
   `AdministratorAccess` vào vai đó**, nó vẫn không:
   - tạo được danh tính mới,
   - khởi động được máy chủ,
   - đọc được kho dữ liệu nào khác ngoài kho của lab,
   - tự tháo trần quyền của chính mình.

   Mà vẫn phải: đọc/ghi được khu `lam-viec/` trong kho dữ liệu của lab.

### Đọc kỹ chỗ này trước khi làm yêu cầu 7

Bạn **không attach được** trần quyền tự viết vào role. Thử là gặp `AccessDenied`.
Đó **không phải bug** — đó là hàng rào của chính bộ lab này đang làm đúng việc:

```
DenyPrincipalWithoutBoundary:
  Deny iam:CreateRole, iam:PutRolePermissionsBoundary
  khi iam:PermissionsBoundary != arn:aws:iam::<acct>:policy/labs-self-boundary
```

Bạn đang sống *bên trong* một permission boundary, và điều khoản tự bảo vệ của nó
cấm bạn thay nó bằng cái khác. Đây chính là bài học của yêu cầu 7, chỉ là bạn học
nó từ phía bị nhốt.

Nên `verify.sh` chấm trần quyền của bạn bằng cách khác — bằng **chính bộ máy đánh
giá quyền của IAM**: `iam:SimulateCustomPolicy` với tham số
`--permissions-boundary-policy-input-list`. Nó áp dụng đúng ngữ nghĩa boundary
thật (quyền hiệu dụng = giao của identity policy và boundary), chỉ là không gắn
vào ai cả. Đây cũng là thứ bạn chạy trong đời thật **trước khi** rollout một
boundary lên production, chứ không phải gắn rồi mới xem chuyện gì xảy ra.

---

## Hợp đồng output

| Output | Kiểu | `verify.sh` dùng để làm gì |
|---|---|---|
| `vai_van_hanh` | string (ARN role) | Mượn nó để thử mọi thứ vận hành viên được và không được làm |
| `ma_ngoai` | string | Chuỗi bí mật phải kèm khi mượn `vai_van_hanh` |
| `vai_pha_kinh` | string (ARN role) | Danh tính duy nhất đọc được `bi-mat/`. Phải mượn được từ danh tính đang chạy lab |
| `kho_du_lieu` | string | Tên kho dữ liệu |
| `ranh_gioi_quyen` | string (ARN policy) | Trần quyền bạn tự viết ở yêu cầu 7. Phải là một **customer managed policy** có thật |
| `duong_bi_mat` | string | Tên tham số bí mật mà vận hành viên **được** đọc |
| `duong_bi_mat_cam` | string | Tên tham số bí mật mà vận hành viên **không được** đọc |

### Hợp đồng nội dung

Kho dữ liệu phải có sẵn hai object, `verify.sh` gọi đúng hai khoá này:

```
lam-viec/thu.txt     khu làm việc — vận hành viên và admin đều đọc được
bi-mat/thu.txt       bảng lương  — chỉ vai phá kính đọc được
```

Đặt tên resource với prefix `self-w09-`.

---

## Hàng rào của lab này

**Trần chi phí: $0,00/giờ, $0,00 nếu quên một tháng.** IAM, STS, IAM Policy
Simulator và SSM Parameter Store **Standard** đều miễn phí không giới hạn. Đây là
lab an toàn nhất trong bộ — bạn không thể làm cháy ví ở đây kể cả khi cố tình.

**Hai cái bẫy tiền lab này cố tình tránh, và bạn phải biết vì sao:**

| Nếu bạn dùng | Giá | Vì sao lab không dùng |
|---|---|---|
| Secrets Manager | **$0,40/secret/tháng** + $0,05/10k gọi API | Parameter Store SecureString làm được y hệt việc lưu bí mật mã hoá, miễn phí. Khác biệt thật sự là **rotation tự động** — thứ lab này không cần. Đây là một câu hỏi Domain 4 rất hay gặp |
| KMS customer managed key | **$1/key/tháng** | Khoá AWS-managed `alias/aws/ssm` miễn phí và đủ cho lab. CMK chỉ cần khi bạn phải tự kiểm soát key policy, rotation, hoặc chia sẻ cross-account |

**Boundary chặn gì ở lab này:**

- `iam:CreateRole` / `iam:PutRolePermissionsBoundary` khi boundary không phải
  `labs-self-boundary` → **mọi role bạn tạo phải khai
  `permissions_boundary = "arn:aws:iam::<acct>:policy/labs-self-boundary"`**.
  Đây là lỗi số một khiến `terraform apply` gãy ở lab này.
- `iam:DeleteRolePermissionsBoundary` trên mọi resource → không tháo rào được.
- `organizations:*` và `account:*` → bạn không dựng được SCP thật. SCP là kiến
  thức **đọc**, không lab được ở account đơn lẻ. `DOI-CHIEU.md` bàn nó.

**Phân biệt `AccessDenied` của hàng rào với bug của bạn** — lab này bạn sẽ gặp
`AccessDenied` **rất nhiều**, và phần lớn là *cố ý*. Ba loại:

| Thông điệp chứa | Nghĩa là | Làm gì |
|---|---|---|
| `explicit deny in a permissions boundary` | hàng rào của bộ lab | đọc lại mục trên, đừng gỡ rào |
| `explicit deny in a resource-based policy` | bucket policy **bạn viết** đang chặn | nếu đây là check `bi-mat/` thì **đúng như thiết kế** |
| `is not authorized to perform ... no identity-based policy allows` | implicit deny — policy bạn viết thiếu | bug của bạn |

Học thuộc ba dòng này. Đề thi hỏi đúng sự khác nhau giữa chúng.

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh hết — **10 trong số các check là negative check**, tức
      là chúng xanh khi thứ gì đó **bị chặn thành công**
- [ ] Vẽ được (bằng tay, không nhìn tài liệu) sơ đồ thứ tự đánh giá quyền IAM,
      đủ 6 bước, có cả SCP, resource policy, session policy và permission boundary
- [ ] Giải thích được: vì sao permission boundary **không cấp** quyền nào, mà chỉ
      giới hạn; và điều gì xảy ra nếu một role **chỉ có** boundary mà không có
      identity policy
- [ ] Giải thích được: external ID chống lại tấn công gì, và vì sao chỉ dùng
      account ID của bên kia thì chưa đủ
- [ ] Giải thích được: khác nhau giữa **permission boundary**, **session policy**
      và **SCP** — cả ba đều là "trần quyền", nhưng ba tầng khác nhau
- [ ] Trả lời được: nếu công ty chuyển sang AWS Organizations, bạn sẽ chuyển
      quy tắc nào ở lab này lên SCP, và giữ quy tắc nào ở boundary? Vì sao?

---

## Quy trình

```bash
source ../../env.sh
../_boundary/guard.sh

cd terraform
terraform init
# viết main.tf + outputs.tf của bạn
terraform apply

cd ..
./verify.sh                # ~1 phút, chỉ đọc
cat DOI-CHIEU.md

cd terraform && terraform destroy
```

`verify.sh` ở lab này **chỉ đọc**: nó mượn role, gọi các API đọc, và dùng IAM
Policy Simulator cho những hành động ghi (mô phỏng, không thực hiện). Không có
tài nguyên nào bị tạo, sửa hay xoá.

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Kiểm tra đã sạch:

```bash
aws iam list-roles --profile lab-builder --query "Roles[?starts_with(RoleName,'self-w09')].RoleName"
aws iam list-policies --scope Local --profile lab-builder --query "Policies[?starts_with(PolicyName,'self-w09')].PolicyName"
aws ssm describe-parameters --profile lab-builder --query "Parameters[?starts_with(Name,'/self-w09')].Name"
aws s3 ls --profile lab-builder | grep self-w09
```

Cả bốn phải rỗng.

**Hai chỗ `destroy` hay gãy ở lab này:**

1. *Bucket không rỗng.* Đặt `force_destroy = true` trên bucket từ đầu.
2. *Policy còn đang được gắn.* IAM không cho xoá một customer managed policy khi
   nó còn attach vào role/user nào. Terraform thường tự xử lý đúng thứ tự; nếu
   không, `terraform destroy` lần hai là xong.

Bucket policy Deny của bạn **chỉ được chặn `s3:GetObject`**. Nếu bạn chặn cả
`s3:DeleteObject` thì `terraform destroy` sẽ không xoá nổi object trong `bi-mat/`
và bạn tự khoá mình ra khỏi việc dọn dẹp. Đây là một bài học thật: **explicit
Deny quá rộng sẽ chặn cả chính bạn**, và trong production thì hậu quả là một
ticket khẩn cấp lúc 3 giờ sáng.
