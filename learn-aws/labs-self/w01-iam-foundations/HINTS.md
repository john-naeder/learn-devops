# Gợi ý — tuần 1

Mở theo thứ tự. Mở tầng sau khi đã thật sự thử tầng trước, không phải khi vừa
thấy hơi khó. Cảm giác bí là lúc bạn đang học; đọc gợi ý sớm là đổi kiến thức
lấy tốc độ.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bài này có bảy yêu cầu nhưng thực ra chỉ có **ba câu hỏi**:

1. *Danh tính này được làm gì?* — yêu cầu 4, 5, 7
2. *Ai được đụng vào kho của tôi?* — yêu cầu 2, 3
3. *Ai được phép hoá thân thành danh tính này?* — yêu cầu 6

Ba câu hỏi đó ứng với ba loại tài liệu khác nhau trong IAM, gắn vào ba chỗ khác
nhau. Nếu bạn đang định viết tất cả vào một chỗ thì đó là chỗ sai đầu tiên.

Thứ tự làm gợi ý:

- Dựng kho trước, tạo hai khu vực bằng cách đặt tên object có tiền tố. Nhớ rằng
  trong object storage **không có thư mục thật** — chỉ có key dài và dấu `/`
  là ký tự bình thường.
- Bật khoá công khai cho kho ngay từ đầu, đừng để làm sau.
- Làm chị Lan trước vì đơn giản nhất, chạy `./verify.sh` để thấy nhóm check của
  Lan xanh lên. Có phản hồi rồi thì phần còn lại dễ hơn nhiều.
- Job tổng hợp: chú ý đề nói "không tồn tại credential dài hạn". Câu đó loại bỏ
  một loại danh tính khỏi cuộc chơi.
- Kiểm toán: bên kia có account riêng, nên bạn không tạo danh tính cho họ —
  bạn tạo một thứ **cho họ mượn**. Cái được mượn cần một tài liệu trả lời câu
  "ai được mượn", và tài liệu đó cần thêm một điều kiện.

Khái niệm cần tra: `identity-based policy`, `resource-based policy`,
`trust policy` (còn gọi `assume role policy`), `principal`, `prefix`,
`Block Public Access`, `external ID`, `condition key`.

Đọc kèm: `docs/aws/w01-iam-foundations.md` mục 2, 3, 4.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Kho lưu trữ.** Đề nói "object", "tiền tố", "vài KB", "miễn phí". Chỉ có một
dịch vụ hợp. Đừng nghĩ đến file system hay block storage.

**Danh tính của chị Lan.** Hai lựa chọn: IAM user hay IAM role?
Câu hỏi giúp chọn: chị Lan ngồi ở laptop, đăng nhập bằng cái gì? Trong lab này
`verify.sh` chấm bằng **mô phỏng**, không thật sự đăng nhập, nên cả hai đều
chấm được. Chọn cái bạn giải thích được lý do — và ghi lý do đó ra giấy, vì
tiêu chí đạt sẽ hỏi.

**Danh tính của job tổng hợp.** Đề đã loại một lựa chọn giúp bạn rồi: "không tồn
tại credential dài hạn". Còn đúng một loại. Và vì job chạy trên máy chủ EC2, hãy
tự hỏi thêm: để gắn được thứ đó vào một máy EC2 thì cần thêm một lớp vỏ tên là gì?
(Lab không chấm lớp vỏ đó, nhưng đề thi có hỏi.)

**Chặn request không mã hoá.** Ba nơi có thể đặt điều kiện:
- trên identity policy của từng danh tính,
- trên resource policy của kho,
- trên permission boundary.

Đề nói "kể cả request đến từ một danh tính đã được cấp đủ quyền" và "không trông
chờ từng danh tính tự giữ kỷ luật". Câu đó loại hai trong ba. Câu hỏi tự kiểm:
nếu ngày mai có người tạo thêm một danh tính thứ tư, cách bạn chọn có tự động
bảo vệ nó không?

**Effect nào?** Bạn cần `Allow` hay `Deny`? Nhớ: `Allow` có điều kiện và `Deny`
có điều kiện phủ định KHÔNG tương đương nhau khi có nhiều policy chồng lên.
Tra `explicit deny` và thứ tự đánh giá quyền.

**Chuỗi bí mật của kiểm toán.** Nó không phải mật khẩu, không lưu ở Secrets
Manager, và không phải thứ bạn sinh ngẫu nhiên rồi giấu đi. Nó là một **condition
key** trong tài liệu trả lời câu "ai được mượn". Tra `sts:ExternalId`.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**Lỗi 1 — policy đúng mà simulator vẫn `implicitDeny` trên `s3:GetObject`.**
Gần như chắc chắn là ARN. `arn:aws:s3:::ten-bucket` và `arn:aws:s3:::ten-bucket/*`
là hai resource khác nhau. Action tác động lên *bucket* (`s3:ListBucket`) dùng
cái thứ nhất; action tác động lên *object* (`s3:GetObject`, `s3:PutObject`) dùng
cái thứ hai. Viết nhầm thì policy không bao giờ khớp và không có thông báo lỗi nào.

**Lỗi 2 — chặn được khu lương nhưng cũng chặn luôn khu báo cáo.**
Kiểm tra dấu `/` và dấu `*`. `luong/*` khớp `luong/thang-01.csv` nhưng không khớp
`luong/`. Còn `*luong*` thì khớp cả `bao-cao/luong-thuong.csv` — không phải thứ
bạn muốn.

**Lỗi 3 — `terraform apply` báo `MalformedPolicyDocument`.**
Đừng nhúng JSON bằng chuỗi nhiều dòng. Terraform có hai cách sạch hơn: hàm
`jsonencode()` nhận cấu trúc HCL rồi tự sinh JSON hợp lệ, và data source
`aws_iam_policy_document` sinh policy có kiểm tra cú pháp lúc plan. Cách thứ hai
bắt được lỗi sớm hơn.

Cú pháp `jsonencode` (đây là ví dụ cú pháp, không phải lời giải):

```hcl
policy = jsonencode({ Version = "2012-10-17", Statement = [] })
```

**Lỗi 4 — bật khoá công khai xong `apply` báo lỗi khi gắn resource policy.**
Terraform chạy song song. Bạn cần nói cho nó biết thứ tự bằng `depends_on`, hoặc
tách khoá công khai và resource policy ra hai lần apply. Tra
`aws_s3_bucket_public_access_block` và ghi chú về `depends_on` trong docs của
`aws_s3_bucket_policy`.

**Lỗi 5 — check "mượn danh tính khi không có chuỗi bí mật" lại thành công.**
Điều kiện của bạn đang dùng toán tử sai. `StringEquals` trên một key **vắng mặt**
sẽ làm cả statement không khớp — nghĩa là không `Allow`, tốt. Nhưng nếu bạn viết
điều kiện đó trên một statement `Deny` thì logic đảo ngược và request vắng key sẽ
lọt. Tra `Null` condition operator và cách xử lý key vắng mặt.

**Lỗi 6 — `verify.sh` báo không đọc được resource policy.**
`aws s3api get-bucket-policy` trả về JSON có một trường `Policy` là **chuỗi JSON
lồng trong JSON**. Nếu bạn debug tay, nhớ bóc một lớp.

**Resource Terraform cần tra:** `aws_s3_bucket`, `aws_s3_object`,
`aws_s3_bucket_public_access_block`, `aws_s3_bucket_policy`, `aws_iam_role`,
`aws_iam_policy`, `aws_iam_role_policy_attachment`, `aws_iam_user`,
`data.aws_iam_policy_document`, `random_password` hoặc `random_id` cho chuỗi bí mật.

**Docs:**
- Registry AWS provider: <https://registry.terraform.io/providers/hashicorp/aws/latest/docs>
- Logic đánh giá quyền: <https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_evaluation-logic.html>
- External ID và confused deputy: <https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html>
- Condition key `aws:SecureTransport`: <https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_condition-keys.html>

</details>
