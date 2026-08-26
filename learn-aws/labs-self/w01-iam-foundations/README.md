# Tuần 1 — Ai được làm gì  (tự viết)

`Domain 1 · Security (30% đề)`

| | |
|---|---|
| **Chi phí khi chạy** | **$0,00/giờ** |
| **Quên 1 tháng** | **$0,00** (vài KB S3 làm tròn xuống 0; IAM và STS miễn phí) |
| **Thời gian** | ~3 giờ |
| **Điều kiện** | không cần lab nào trước. Nên đọc `docs/aws/w01-iam-foundations.md` trước. |

---

## Bối cảnh

Bạn phụ trách hạ tầng cho một công ty bán lẻ nhỏ. Phòng kế toán đẩy báo cáo doanh
thu hàng ngày vào một kho lưu trữ dùng chung. Ba bên cần đụng vào kho đó:

- **Chị Lan, phân tích dữ liệu** — mở báo cáo doanh thu bằng laptop, đọc thôi.
- **Job tổng hợp chạy trên một máy chủ trong AWS** — mỗi đêm ghi thêm báo cáo mới.
- **Một công ty kiểm toán bên ngoài** — mỗi quý một lần, cần đọc báo cáo trong
  vài giờ. Họ có account AWS riêng và **không được cầm mật khẩu hay khoá nào của bạn**.

Trong kho đó cũng có bảng lương. Ngoài giám đốc, **không ai** được mở nó — kể cả
job tổng hợp, kể cả kiểm toán, kể cả khi ai đó lỡ tay cấp thừa quyền tháng sau.

Và toàn bộ dữ liệu chỉ được truyền đi khi đã mã hoá đường truyền.

---

## Yêu cầu

Mỗi yêu cầu tương ứng đúng một nhóm check trong `verify.sh`.

1. **Kho lưu trữ tồn tại** và có hai khu vực tách biệt: khu báo cáo và khu lương.
2. **Kho không lộ ra internet.** Một request ẩn danh từ máy bạn phải bị từ chối.
3. **Kho tự từ chối mọi request không mã hoá đường truyền** — kể cả request đến từ
   một danh tính đã được cấp đủ quyền. Việc chặn này phải nằm ở *phía kho*, không
   phải trông chờ từng danh tính tự giữ kỷ luật.
4. **Danh tính của chị Lan** đọc được khu báo cáo, và **không** đọc được khu lương,
   **không** ghi, **không** xoá được gì.
5. **Danh tính của job tổng hợp** ghi được vào khu báo cáo nhưng **không xoá** được
   object nào, và **không** đọc được khu lương. Danh tính này phải là loại
   **không tồn tại credential dài hạn** — không có access key để rò rỉ.
6. **Danh tính cho công ty kiểm toán** chỉ mượn được khi bên mượn xuất trình đúng
   một chuỗi bí mật đã thoả thuận trước. Mượn mà không có chuỗi đó phải thất bại.
7. **Không danh tính nào của lab tự nới quyền cho chính mình được** — không sửa
   được policy đang giới hạn nó, không gắn thêm được policy mới cho nó.

> Yêu cầu 3 và 4 nói về hai loại policy khác nhau. Nếu bạn định giải cả hai bằng
> cùng một chỗ, hãy dừng lại và đọc lại đề.

---

## Hợp đồng output

`verify.sh` chỉ biết hạ tầng của bạn qua các output này. Thiếu một cái là không chấm
được. Đây là **giao diện**, không phải gợi ý — tên phải khớp từng ký tự.

| Output | Kiểu | `verify.sh` dùng để |
|---|---|---|
| `bucket_name` | string | dựng URL công khai thử request ẩn danh; đọc Block Public Access; đọc resource policy thật |
| `bucket_arn` | string | làm `--resource-arns` cho IAM Policy Simulator |
| `prefix_bao_cao` | string | tiền tố khu báo cáo, **có dấu `/` cuối** (ví dụ `bao-cao/`) |
| `prefix_luong` | string | tiền tố khu lương, có dấu `/` cuối |
| `analyst_arn` | string | ARN danh tính của chị Lan — làm `--policy-source-arn` |
| `app_role_arn` | string | ARN danh tính của job tổng hợp; verify kiểm tra nó **là role**, không phải user |
| `partner_role_arn` | string | ARN danh tính cho kiểm toán — verify thật sự thử mượn nó |
| `partner_external_id` | string | chuỗi bí mật; verify thử mượn có và không có chuỗi này |
| `chi_phi` | string | in ra trước khi bạn gõ `yes`. Lab này phải là `$0` |

Ví dụ khối output bạn phải viết (giá trị là của bạn, tên là bắt buộc):

```
bucket_name = "self-w01-bao-cao-123456789012"
prefix_luong = "luong/"
```

---

## Hàng rào của lab này

**Trần chi phí: $0,00/giờ, $0,00 nếu quên một tháng.** Không có gì trong lab này
tính tiền theo giờ. Đây là lab duy nhất bạn được phép quên destroy mà không sao —
nhưng vẫn destroy, để thành thói quen trước tuần 3.

Permission boundary `labs-self-boundary` gắn trên role `lab-builder` chặn, trong
phạm vi lab này:

| Boundary chặn | Vì sao |
|---|---|
| `iam:CreateAccessKey`, `iam:CreateLoginProfile` | Lab này không cần một access key nào. Nếu bạn thấy mình sắp tạo key, nghĩa là bạn đang chọn user ở chỗ nên chọn role — đúng cái bẫy đề thi hay giăng |
| `iam:CreateUser` / `iam:*` ngoài tiền tố `self-w01-` | giữ IAM của account sạch, và bắt bạn đặt tên có kỷ luật |
| mọi API ngoài region `us-east-1` | tài nguyên bỏ quên ở region lạ là cách đốt credit phổ biến nhất |
| `iam:DeletePolicy` / `iam:DetachRolePolicy` trên chính `labs-self-boundary` | không ai được tự tháo hàng rào của mình |

**Gặp `AccessDenied` — của boundary hay bug của bạn?**

```bash
aws sts get-caller-identity          # phải thấy .../lab-builder/...
```

- Thông báo lỗi chứa `with an explicit deny in a permissions boundary` → **boundary**.
  Đọc lại đề: gần như chắc chắn bạn đang đi một con đường mà lab không cần.
- Thông báo chứa `is not authorized to perform` mà **không** nhắc boundary →
  role `lab-builder` không có quyền đó ngay từ đầu, hoặc bạn gõ nhầm ARN.
- Lỗi xuất hiện lúc `verify.sh` chạy chứ không phải lúc `apply` → thường là bug
  policy của bạn: đó chính là thứ lab đang chấm.

**Không bao giờ tắt boundary để làm bài.** Nếu bạn tin rằng lab cần một quyền mà
boundary chặn, thì đề bài sai — báo lại, đừng nới hàng rào.

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh toàn bộ, bao gồm cả bốn check phủ định
- [ ] `terraform destroy` sạch trong một lần
- [ ] Giải thích được: yêu cầu 3 phải giải bằng loại policy nào, **và vì sao
      không giải được bằng loại policy của yêu cầu 4**
- [ ] Vẽ được bằng lời bốn bước của logic đánh giá quyền, và chỉ ra check nào
      trong `verify.sh` trả về `explicitDeny` chứ không phải `implicitDeny` — và
      khác nhau ở đâu
- [ ] Trả lời được: nếu tháng sau có người gắn thêm `AmazonS3FullAccess` vào
      danh tính của chị Lan, khu lương có còn an toàn không? Thiết kế của bạn
      có chịu được điều đó không?
- [ ] Nói được vì sao chuỗi bí mật của công ty kiểm toán tồn tại, và nó chống
      lại kiểu tấn công nào (tra: *confused deputy*)

`verify.sh` xanh là điều kiện **cần**. Ba gạch đầu dòng cuối là điều kiện **đủ**,
và chúng mới là thứ ra thi.

---

## Quy trình

```bash
source ../../env.sh                 # PATH + locale
../guard.sh                         # kiểm tra boundary và budget còn sống

cd terraform
terraform init
terraform apply                     # đọc output chi_phi trước khi gõ yes

cd ..
./verify.sh                         # trọng tài; chạy lại bao nhiêu lần cũng được

# xanh hết rồi mới mở:
$PAGER DOI-CHIEU.md

cd terraform && terraform destroy
```

Bí quá thì mở `HINTS.md` theo đúng thứ tự tầng, và chỉ mở tầng tiếp theo sau khi
đã thật sự thử tầng trước.

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Bucket có object bạn tự upload sẽ làm `destroy` báo *BucketNotEmpty*. Hai cách:
đặt thuộc tính cho phép xoá cưỡng bức ngay từ đầu, hoặc dọn tay rồi destroy lại.

Kiểm tra đã sạch:

```bash
aws s3 ls --profile lab-builder | grep self-w01 || echo "sạch bucket"
aws iam list-roles --profile lab-builder \
  --query 'Roles[?starts_with(RoleName, `self-w01`)].RoleName' --output text
aws iam list-users --profile lab-builder \
  --query 'Users[?starts_with(UserName, `self-w01`)].UserName' --output text
```

Ba lệnh trên phải không in ra gì.
