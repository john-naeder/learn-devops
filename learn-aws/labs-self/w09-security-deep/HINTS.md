# Gợi ý — tuần 9

Lab này dài và bạn sẽ gặp `AccessDenied` rất nhiều. Trước khi mở bất kỳ tầng
nào, làm một việc: đọc lại bảng ba loại thông điệp lỗi trong `README.md`, mục
"Hàng rào của lab này". Nửa số lần kẹt ở lab này là do đọc nhầm loại lỗi.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bảy yêu cầu, nhưng chỉ có **bốn cơ chế**. Nhận ra được bốn cơ chế đó là xong bài.
Chia thành bảy bước nhỏ, `terraform apply` sau mỗi bước — viết một lượt rồi apply
là bạn sẽ mất một giờ để biết lỗi nằm ở đâu.

**Bước 1 — kho dữ liệu và hai khu.** Một kho, hai object. Chưa chặn gì cả. Kiểm
tra bằng chính danh tính đang chạy lab: cả hai đều đọc được. Đây là trạng thái
"trước khi bảo mật", và bạn cần nhìn thấy nó để lát nữa thấy được sự khác biệt.
Bật `force_destroy` ngay từ bây giờ.

**Bước 2 — vai vận hành viên mượn được.** Câu hỏi phải trả lời trước khi gõ:
*ai được mượn vai này, và điều đó khai ở đâu?* Có hai loại policy dính vào một
role, và chúng trả lời hai câu hỏi khác nhau: "ai được mượn tôi" và "mượn xong
thì làm được gì". Tra tên hai loại đó. Ba ràng buộc của yêu cầu 1 và 2 — mượn
được, phải kèm chuỗi bí mật, phiên không quá 1 giờ — nằm ở **ba chỗ khác nhau**:
một điều kiện trong trust policy, và một thuộc tính của chính role. Tìm ra chỗ
thứ ba là phần khó.

**Bước 3 — quyền của vận hành viên.** Yêu cầu 3 nói cả cái được lẫn cái không
được. Cái "không được" ở đây **không cần** một dòng Deny nào: nếu bạn chỉ cấp
đúng thứ cần cấp thì mọi thứ khác đã bị từ chối sẵn. Tra khái niệm *implicit
deny*. Viết Deny khi chưa cần là thói quen làm policy phình ra và khó đọc.

**Bước 4 — bí mật.** Yêu cầu 6 nói "mã hoá" và "miễn phí". Hai chữ đó chỉ về
đúng một dịch vụ và đúng một kiểu tham số trong dịch vụ đó. Phần khó không phải
lưu, mà là phân quyền: hai tham số, một đọc được một không. Nghĩ theo hướng
**đường dẫn phân cấp** — đặt tên tham số như đường dẫn thư mục rồi cấp quyền
theo tiền tố. Chú ý: đọc một tham số mã hoá cần **hai** quyền, không phải một.

**Bước 5 — chặn bảng lương ở phía kho.** Đây là trái tim của bài. Yêu cầu 4 nói
rõ: việc chặn phải nằm ở phía kho dữ liệu, không phải trông chờ từng danh tính
tự kiềm chế. Cơ chế cần tra: **resource-based policy**. Và câu hỏi cần trả lời:
*làm sao viết "từ chối tất cả TRỪ một danh tính" trong một policy?* Có hai cách
viết, và một trong hai nổi tiếng là bẫy. Tầng 3 nói rõ cái nào.

**Bước 6 — cửa phá kính.** Một role nữa, trust policy cho danh tính đang chạy
lab mượn (không cần mã ngoài — đọc lại yêu cầu 5, nó không đòi). Điều duy nhất
đặc biệt: nó là ngoại lệ trong policy ở bước 5.

**Bước 7 — trần quyền tự viết.** Đọc kỹ mục "Đọc kỹ chỗ này trước khi làm yêu
cầu 7" trong README trước khi gõ. Bạn **không** attach nó vào đâu cả. Nó chỉ cần
tồn tại như một customer managed policy, và `verify.sh` sẽ đem nó đi giao với
`AdministratorAccess` bằng chính bộ máy của IAM.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Cho việc "đội ngoài vào được nhưng không cầm khoá" (yêu cầu 1, 2)** — ba ứng
viên, và chỉ một cái đúng:

| | Cấp cái gì | Sống bao lâu | Thu hồi thế nào |
|---|---|---|---|
| IAM user + access key | khoá dài hạn | tới khi có người phát hiện | phải nhớ mà xoá |
| IAM role + `sts:AssumeRole` | credential tạm thời | tối đa `max_session_duration` | hết hạn tự động |
| IAM Identity Center | phiên gắn với danh tính công ty | theo phiên SSO | ở tầng thư mục người dùng |

Hàng rào của bộ lab này **chặn thẳng** `iam:CreateAccessKey` — nên nếu bạn thấy
mình đang đi hướng thứ nhất, hàng rào sẽ nói cho bạn biết trước khi bài nói.
Hướng thứ ba đúng trong đời thật nhưng cần Organizations, mà hàng rào chặn
`organizations:*`. Còn lại một.

Câu hỏi tự kiểm: chuỗi bí mật ở yêu cầu 2 chống lại **tấn công gì**? Nếu bạn trả
lời "chống người lạ" thì chưa đúng — người lạ đã bị chặn bởi việc họ không nằm
trong trust policy. Nó chống lại một thứ tinh vi hơn, có tên riêng, và tên đó là
từ khoá bạn cần tra. Gợi ý: đội vận hành có **nhiều khách hàng**.

**Cho việc "không ai đọc được bảng lương, kể cả admin" (yêu cầu 4)** — bốn ứng
viên, xếp theo mức độ đúng:

| | Chặn được admin không | Chi phí | Nhận xét |
|---|---|---|---|
| Sửa identity policy của từng danh tính | **Không** — admin vẫn là admin, và ngày mai có danh tính mới | $0 | đây là "trông chờ từng danh tính tự kiềm chế" mà đề bài loại thẳng |
| Resource-based policy có `Deny` | **Có** | $0 | explicit Deny thắng mọi Allow, ở bất kỳ đâu |
| Mã hoá bằng KMS customer managed key rồi khoá key policy | **Có** | **$1/tháng** | đúng về kỹ thuật, nhưng tốn tiền và phức tạp hơn cần thiết cho bài này |
| SCP trong Organizations | **Có**, và chặn cả root | $0 nhưng cần Organizations | hàng rào chặn `organizations:*`; `DOI-CHIEU.md` bàn khi nào đây mới là đáp án đúng |

**Cho việc lưu bí mật (yêu cầu 6)** — hai ứng viên, và đề bài đã cho sẵn hai từ
khoá quyết định là "mã hoá" và "miễn phí":

| | Giá | Có gì hơn |
|---|---|---|
| SSM Parameter Store, kiểu chuỗi mã hoá | **$0** (bậc Standard) | đủ cho bài này |
| Secrets Manager | **$0,40/secret/tháng** | **rotation tự động**, tích hợp sẵn với RDS, cross-account resource policy |

Câu hỏi để tự chọn: bí mật trong bài này có cần **tự đổi định kỳ** không? Nếu
không thì bạn đang trả $0,40/tháng cho tính năng nào? Đây là một câu hỏi Domain 4
rất hay gặp, và cả hai đáp án đều "chạy được" — đề thi hỏi cái **tốt nhất**.

**Cho trần quyền tự viết (yêu cầu 7)** — hai lối viết, cả hai đều đạt, nhưng
chúng dạy hai thứ khác nhau:

- **Liệt kê Allow hẹp**: chỉ Allow đúng vài action trên đúng vài resource. Mọi
  thứ khác rơi vào implicit deny. Ngắn, an toàn, nhưng phải sửa mỗi lần vai đó
  cần thêm việc.
- **Allow rộng rồi Deny hẹp**: đúng cách `labs-self-boundary` được viết (đọc
  `../_boundary/main.tf`). Rộng rãi hơn, nhưng bạn phải nghĩ ra trước mọi đường
  thoát cần bịt — và bỏ sót một cái là thủng.

Chọn cái nào cũng được, nhưng phải nói được vì sao. `DOI-CHIEU.md` bàn khi nào
mỗi lối là lựa chọn đúng trong tổ chức thật.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**`terraform apply` báo `AccessDenied` ngay ở `aws_iam_role` đầu tiên.**
Thiếu `permissions_boundary`. Hàng rào từ chối tạo mọi role không mang đúng
boundary của nó — xem `../_boundary/README.md` mục 6a. Lấy ARN:
`terraform -chdir=../../_boundary output -raw lab_boundary_arn`.
Nếu đã có `permissions_boundary` mà vẫn `AccessDenied` **và** thông điệp nhắc
tới permissions boundary: kiểm tra **tên role**. Sai prefix `self-w09-` là
`DenyCredentialEscalation` bắn, và thông điệp của nó nghe y hệt.

**`verify.sh` báo "mượn mà KHÔNG kèm mã ngoài thì bị từ chối" là ✗ — tức là mượn
được.** Điều kiện `sts:ExternalId` của bạn đang dùng toán tử cho phép khoá vắng
mặt. `StringEquals` với khoá **không có trong request** cho kết quả *sai*, nên
statement Allow không khớp và request bị từ chối — đó là hành vi đúng. Nhưng nếu
bạn viết `StringNotEquals` trong một statement `Deny`, khoá vắng mặt làm điều
kiện *đúng*... hoặc ngược lại, tuỳ bạn viết. Quy tắc phải thuộc: **toán tử phủ
định cộng khoá vắng mặt là chỗ policy IAM hay thủng nhất**. Cách an toàn là đặt
điều kiện ở statement `Allow` với toán tử khẳng định.

**"xin phiên 2 giờ thì bị từ chối" là ✗.** Bạn đang nghĩ tới `sts:DurationSeconds`
trong trust policy. Được, nhưng có một thuộc tính ngay trên role đơn giản hơn
nhiều và `verify.sh` đọc thẳng nó bằng `iam:GetRole`. Tra `MaxSessionDuration`.
Chú ý AWS chỉ nhận từ 3600 giây trở lên — 1 giờ là **giá trị nhỏ nhất hợp lệ**.

**"danh tính admin cũng KHÔNG đọc được bảng lương" là ✗.**
Policy phía kho của bạn chưa chặn được chính bạn. Hai lối viết, và một cái là bẫy:

- `NotPrincipal` với `Effect: Deny` — cú pháp có tồn tại, nhưng AWS khuyến cáo
  tránh: nó so khớp theo **danh tính chính xác**, và một role được assume xuất
  hiện dưới ARN phiên (`arn:aws:sts::...:assumed-role/Ten/Phien`) chứ không phải
  ARN role. Viết `NotPrincipal` với ARN role là bạn vừa Deny luôn cả vai phá
  kính của mình.
- `Deny` cho mọi principal, kèm **điều kiện phủ định trên khoá ngữ cảnh** — lối
  được khuyến nghị. Khoá cần tra: `aws:PrincipalArn`, toán tử `ArnNotLike`. Vì
  hai dạng ARN nói ở trên, hãy cho **cả hai mẫu** vào danh sách ngoại lệ:
  `arn:aws:iam::*:role/self-w09-...` và
  `arn:aws:sts::*:assumed-role/self-w09-.../*`. Thừa một mẫu không hại gì; thiếu
  một mẫu thì cửa phá kính không mở được và bạn sẽ tưởng mình viết sai chỗ khác.

  Có một lối thứ ba, cổ điển hơn và bền hơn: điều kiện trên `aws:userId` với
  **unique ID** của role (dạng `AROA...:*`). Nó miễn nhiễm với việc đổi tên role.
  Đắt hơn về mặt đọc hiểu, nên chỉ dùng khi bạn cần.

**"cùng danh tính đó vẫn đọc được khu làm việc" là ✗.**
Deny của bạn quá rộng — nó đang áp lên cả `lam-viec/`. `Resource` phải là
`arn:aws:s3:::<kho>/bi-mat/*`, không phải `arn:aws:s3:::<kho>/*`. Đây chính là
bài học "explicit Deny quá rộng chặn cả chính bạn" mà README cảnh báo, chỉ là ở
quy mô nhỏ và không đau.

**`terraform destroy` treo ở object trong `bi-mat/`.**
Deny của bạn bao cả `s3:DeleteObject`. Thu hẹp lại còn đúng `s3:GetObject`. Nếu
đã lỡ: sửa bucket policy, apply, rồi destroy.

**"vận hành viên đọc và giải mã được bí mật của mình" là ✗ dù đã cấp
`ssm:GetParameter`.** Đọc một tham số mã hoá đi qua **hai** dịch vụ. Tham số
được mã hoá bằng khoá AWS-managed `alias/aws/ssm`, và giải mã cần một action của
dịch vụ khoá. Thiếu quyền đó thì `--with-decryption` hỏng còn đọc thường thì
được — đúng triệu chứng bạn đang thấy.

**Cấp quyền theo tiền tố đường dẫn tham số.** ARN của tham số có dạng
`arn:aws:ssm:us-east-1:<acct>:parameter/self-w09/van-hanh/*` — chú ý **không có
dấu `/` lặp**: tên tham số bắt đầu bằng `/` và ARN đã có sẵn một dấu `/` sau chữ
`parameter`. Đây là chỗ ghép ARN sai nhiều nhất trong cả lab, và triệu chứng là
implicit deny khó hiểu.

**Nhóm check 5 (trần quyền) toàn `LOI_GOI_API` hoặc `implicitDeny` hết.**
`ranh_gioi_quyen` phải là ARN của một **customer managed policy** (dạng
`arn:aws:iam::<acct>:policy/...`), không phải ARN của AWS managed policy, không
phải tên policy. Và policy đó phải thật sự Allow được thứ ở yêu cầu 7 — nhớ rằng
`simulate-custom-policy` áp đúng phép giao: identity policy là `Allow *` mà trần
của bạn không Allow `s3:PutObject` trên `lam-viec/*` thì kết quả là
`implicitDeny`, và check "trần vẫn cho ghi" sẽ đỏ.

**Cú pháp lạ duy nhất đáng trích** — chèn một tài liệu policy JSON vào HCL, và
tham chiếu chính ARN của policy đang khai (dùng cho điều khoản "không tự sửa
trần"):

```hcl
data "aws_caller_identity" "toi" {}
locals { arn_tran = "arn:aws:iam::${data.aws_caller_identity.toi.account_id}:policy/self-w09-tran-quyen" }
```

**Tài liệu cần tra:**
- [IAM JSON policy evaluation logic](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html) — đọc cả trang, đây là bài học của tuần
- [How to use an external ID](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html)
- [Bucket policy examples](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html)
- [aws:PrincipalArn và các khoá điều kiện global](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html)
- [Restricting access to Systems Manager parameters](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html)
- Terraform: `aws_iam_role` (`assume_role_policy`, `max_session_duration`,
  `permissions_boundary`), `aws_s3_bucket_policy`, `aws_ssm_parameter`,
  `aws_iam_policy`, `aws_iam_policy_document`

</details>
