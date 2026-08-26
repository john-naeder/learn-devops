# Đối chiếu — tuần 1

> Đọc file này **sau khi** `./verify.sh` đã xanh. Đọc trước là tự tước mất phần
> giá trị nhất của lab.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong đề | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1 — hai khu vực trong một kho | prefix, và sự thật "object storage không có thư mục" | [Bucket, key, prefix](../../../docs/aws/w04-s3-cloudfront.md#2-bucket-key-prefix--và-sự-thật-rằng-không-có-thư-mục) |
| 2 — kho không lộ ra internet | S3 Block Public Access, bốn cơ chế bảo mật S3 | [Bảo mật S3](../../../docs/aws/w04-s3-cloudfront.md#7-bảo-mật-s3--bốn-cơ-chế-và-thứ-tự-đánh-giá) |
| 3 — chặn đường truyền không mã hoá **ở phía kho** | **resource-based policy** + condition key `aws:SecureTransport` | [Identity vs resource policy](../../../docs/aws/w01-iam-foundations.md#2-identity-based-policy-vs-resource-based-policy) · [Condition](../../../docs/aws/w01-iam-foundations.md#condition--nơi-least-privilege-sống) |
| 4 — chị Lan chỉ đọc báo cáo | **identity-based policy**, least privilege, ARN có `/*` và không có | [ARN — chỗ sai nhiều nhất](../../../docs/aws/w01-iam-foundations.md#arn--chỗ-sai-nhiều-nhất) · [Least privilege](../../../docs/aws/w01-iam-foundations.md#9-least-privilege-trên-thực-tế) |
| 5 — job tổng hợp không có khoá dài hạn | IAM role cho EC2, instance profile, credential từ IMDS | [IAM role cho EC2](../../../docs/aws/w01-iam-foundations.md#6-iam-role-cho-ec2--instance-profile) · [Credential đến từ đâu](../../../docs/aws/w01-iam-foundations.md#cơ-chế-credential-đến-từ-đâu) |
| 6 — kiểm toán mượn role kèm chuỗi bí mật | **trust policy**, `sts:AssumeRole`, `sts:ExternalId`, confused deputy | [IAM role](../../../docs/aws/w01-iam-foundations.md#iam-role) · [STS](../../../docs/aws/w01-iam-foundations.md#7-sts-và-credential-tạm-thời) · [Confused deputy](../../../docs/aws/w04-s3-cloudfront.md#confused-deputy--bẫy-security-hay-ra-thi) |
| 7 — không tự nới quyền | privilege escalation, permission boundary | [Permission boundary vs SCP](../../../docs/aws/w01-iam-foundations.md#5-permission-boundary-vs-scp) |
| Chuỗi `allowed / implicitDeny / explicitDeny` trong output | logic đánh giá quyền bốn bước | [Logic đánh giá quyền](../../../docs/aws/w01-iam-foundations.md#4-logic-đánh-giá-quyền--trái-tim-của-domain-1) |

**Ba tài liệu, ba câu hỏi khác nhau — đây là thứ đề thi trộn lẫn nhiều nhất:**

| Tài liệu | Gắn vào | Trả lời câu |
|---|---|---|
| Identity policy | user, group, role | "Danh tính này được làm gì?" |
| Resource policy | bucket, queue, key, role | "Ai được đụng vào tôi?" |
| Trust policy | **chỉ role** | "Ai được phép hoá thân thành tôi?" |

Trust policy **không** nói role được làm gì. Rất nhiều người đọc `assume_role_policy`
rồi tưởng đó là quyền của role. Quyền nằm ở policy gắn kèm; hai thứ tách rời hoàn
toàn — và chính sự tách rời đó làm role mạnh hơn user.

---

## Ba cách khác để giải bài này

Đây là mục quan trọng nhất của cả file. Đề SAA gần như không bao giờ hỏi
"cách nào chạy được" — nó hỏi **"cách nào TỐT NHẤT"**, và bốn lựa chọn thường
đều chạy được.

### Cách A — cấp cho kiểm toán một IAM user trong account của bạn

Tạo `self-w01-kiem-toan` là IAM user, sinh access key, gửi qua email cho họ.

- **Tốt hơn khi:** bên kia không có account AWS và không biết `sts:AssumeRole` là gì.
  Một số nhà cung cấp SaaS cũ chỉ nhận access key.
- **Tệ hơn ở chỗ:** khoá sống mãi. Nhân viên kiểm toán nghỉ việc, khoá vẫn còn.
  Khoá bị commit lên GitHub, bạn không biết. Không có thời hạn tự nhiên, không
  có nhật ký "ai đã mượn lúc mấy giờ" — CloudTrail chỉ thấy một danh tính duy nhất
  chứ không thấy người thật phía sau.
- **Đề thi hỏi thế nào:** bất cứ lựa chọn nào chứa "tạo IAM user và chia sẻ access
  key với bên thứ ba" đều **sai**, kể cả khi nghe rất hợp lý. Đây là mẫu loại trừ
  nhanh nhất bạn có.

### Cách B — dùng presigned URL thay vì cấp danh tính

Không cấp gì cả. Mỗi quý, bạn sinh một loạt presigned URL cho đúng những file
kiểm toán cần, hết hạn sau 24 giờ, rồi gửi link.

- **Tốt hơn khi:** bên kia chỉ cần **vài file cụ thể**, một lần, và bạn muốn họ
  không cần biết AWS là gì. Không tạo bất kỳ danh tính nào — bề mặt tấn công bằng 0.
- **Tệ hơn ở chỗ:** không mở rộng được. Kiểm toán cần duyệt cả thư mục, cần liệt kê
  file mới phát sinh, hoặc cần chạy công cụ của họ trỏ vào kho — presigned URL
  chịu. URL cũng là **bearer token**: ai cầm được link là đọc được, chuyển tiếp
  qua Slack là rò.
- **Đề thi hỏi thế nào:** presigned URL là đáp án đúng khi đề nhấn mạnh
  *"người dùng không có tài khoản AWS"*, *"truy cập tạm thời một object"*,
  *"không muốn mở bucket ra public"*. Thấy *"cần liệt kê"* hay *"truy cập lặp lại
  trong nhiều ngày"* thì loại nó.

### Cách C — cấp quyền bằng resource policy trên kho, thay vì role

Bỏ role kiểm toán. Thay vào đó, viết thẳng vào resource policy của kho:
`Principal = arn:aws:iam::<account-kiem-toan>:root`, `Action = s3:GetObject`,
`Resource = kho/bao-cao/*`.

- **Tốt hơn khi:** chỉ có **một** dịch vụ cần chia sẻ (một bucket, một queue) và
  bạn muốn cấp quyền cross-account chỉ bằng một thay đổi ở một chỗ, không cần bên
  kia làm gì thêm ngoài việc gọi API. Ít bước hơn cách bạn vừa làm.
- **Tệ hơn ở chỗ:** không mở rộng theo chiều rộng. Quý sau kiểm toán cần đọc thêm
  một bảng DynamoDB và một queue — bạn phải sửa ba resource policy ở ba nơi. Với
  role, bạn sửa **một** policy gắn vào role. Resource policy cũng khó gắn điều kiện
  kiểu external ID một cách tự nhiên, và khó thu hồi khẩn cấp (không có "kết thúc
  phiên" — chỉ có sửa policy).
- **Đề thi hỏi thế nào:** khi đề nói *"chia sẻ MỘT bucket cho một account khác,
  đơn giản nhất"* → bucket policy. Khi đề nói *"bên thứ ba cần truy cập NHIỀU dịch
  vụ"*, *"truy cập tạm thời"*, *"kiểm soát được thời hạn phiên"* → cross-account role.

### Bảng quyết định rút ra

| Tình huống trong đề | Chọn |
|---|---|
| Ứng dụng chạy trên EC2/Lambda/ECS cần gọi AWS | **IAM role** — không bao giờ là access key |
| Bên thứ ba có account AWS, cần nhiều dịch vụ, lặp lại | **Cross-account role + external ID** |
| Bên thứ ba chỉ cần vài object, một lần | **Presigned URL** |
| Chia sẻ đúng một bucket cho một account | **Bucket policy** |
| Ép một quy tắc lên MỌI danh tính hiện tại và tương lai | **Resource policy** hoặc **SCP**, không phải identity policy |
| Chặn dứt khoát, không ai cứu được | **Explicit Deny** |

---

## Nếu đề thi hỏi

<details><summary>Câu 1 — Một công ty kiểm toán bên ngoài (có account AWS riêng) cần đọc báo cáo trong bucket S3 của bạn mỗi quý một lần. Giải pháp nào an toàn nhất?</summary>

**A.** Tạo IAM user cho kiểm toán, sinh access key, gửi qua email đã mã hoá.
**B.** Tạo IAM role trong account của bạn, trust policy cho phép account của kiểm
toán assume, kèm điều kiện `sts:ExternalId`.
**C.** Bật static website hosting cho bucket và gửi URL cho kiểm toán.
**D.** Thêm account của kiểm toán vào ACL của bucket với quyền `READ`.

**Đáp án: B.**

- **A sai** vì access key là credential dài hạn nằm ngoài tầm kiểm soát của bạn.
  Không có thời hạn tự nhiên, không thu hồi tự động, và CloudTrail không phân biệt
  được ai trong công ty kiểm toán đang dùng. Mã hoá email không sửa được điều đó.
- **C sai** hoàn toàn: static website hosting nghĩa là **public**. Bất kỳ ai trên
  internet cũng đọc được báo cáo doanh thu.
- **D sai** vì ACL là cơ chế cũ, AWS khuyến nghị tắt hẳn (`BucketOwnerEnforced`),
  không hỗ trợ điều kiện, và không giải quyết được confused deputy.
- **B đúng**: credential tạm thời, hết hạn tự động, external ID chống confused
  deputy, và CloudTrail ghi lại từng phiên assume.

</details>

<details><summary>Câu 2 — Bạn cần bảo đảm MỌI request tới một bucket S3 đều dùng TLS, kể cả từ các danh tính sẽ được tạo trong tương lai. Cách nào?</summary>

**A.** Thêm điều kiện `aws:SecureTransport = true` vào Allow của từng identity policy.
**B.** Bật Block Public Access cả bốn tuỳ chọn.
**C.** Gắn bucket policy có statement `Deny` khi `aws:SecureTransport` là `false`.
**D.** Bật SSE-KMS cho bucket.

**Đáp án: C.**

- **A sai** ở chữ "mọi danh tính trong tương lai": bạn phải nhớ thêm điều kiện vào
  từng policy mới, và một lần quên là thủng. Đây là kiểm soát dựa vào kỷ luật con
  người, không phải dựa vào cơ chế.
- **B sai** vì Block Public Access chỉ chặn truy cập **ẩn danh / public**. Một
  danh tính IAM hợp lệ gọi qua HTTP vẫn lọt.
- **D sai** vì SSE-KMS là mã hoá **khi lưu** (at rest), còn đề hỏi mã hoá **khi
  truyền** (in transit). Đây là cặp đánh tráo kinh điển của đề thi.
- **C đúng**: resource policy áp lên mọi principal, và `Deny` thắng mọi `Allow`.

</details>

<details><summary>Câu 3 — Một ứng dụng chạy trên EC2 cần ghi vào S3. Cách cấp quyền nào đúng?</summary>

**A.** Lưu access key trong biến môi trường của instance.
**B.** Lưu access key trong SSM Parameter Store, ứng dụng đọc ra lúc khởi động.
**C.** Gắn IAM role vào instance qua instance profile.
**D.** Ghi access key vào user data để chỉ chạy một lần lúc boot.

**Đáp án: C.**

- **A, B, D** đều sai vì cùng một lý do: chúng vẫn là **credential dài hạn**.
  B nghe an toàn hơn (có mã hoá, có audit) nhưng khoá vẫn tồn tại vĩnh viễn và
  vẫn phải xoay vòng bằng tay. D còn tệ hơn nữa: user data đọc được từ IMDS bởi
  bất kỳ process nào trên máy, kể cả một web app bị SSRF.
- **C đúng**: instance lấy credential tạm thời từ IMDS, AWS tự xoay vòng, không
  có gì để rò rỉ. Nhớ thêm: role gắn vào EC2 phải đi qua **instance profile** —
  đó là chi tiết đề thi thích hỏi riêng.

</details>

<details><summary>Câu 4 — Identity policy của một user cho phép `s3:GetObject` trên bucket X. Bucket policy của X có statement Deny `s3:GetObject` cho user đó. Kết quả?</summary>

**A.** Được phép, vì identity policy cụ thể hơn.
**B.** Được phép, vì Allow và Deny triệt tiêu nhau.
**C.** Bị từ chối.
**D.** Tuỳ vào thứ tự statement trong policy.

**Đáp án: C.**

- **A sai**: IAM không có khái niệm "policy nào cụ thể hơn thì thắng". Đó là tư
  duy từ firewall rule hoặc routing, mang nhầm sang.
- **B sai**: không có phép triệt tiêu. Deny luôn thắng.
- **D sai**: thứ tự statement trong một policy **không có ý nghĩa gì**. IAM đánh
  giá toàn bộ tập hợp cùng lúc. Đây là khác biệt lớn so với security group của
  nhiều firewall truyền thống và so với NACL (NACL thì có số thứ tự).
- **C đúng**: bước 1 của logic đánh giá là "có explicit Deny ở bất kỳ đâu không".
  Có thì dừng, không gì cứu được.

</details>

<details><summary>Câu 5 — Đội bảo mật muốn cho phép developer tự tạo IAM role cho ứng dụng của họ, nhưng role tạo ra không được vượt quá quyền đọc S3 và DynamoDB. Cơ chế nào?</summary>

**A.** Service Control Policy gắn vào OU chứa account.
**B.** Permission boundary gắn vào role mà developer tạo ra, và bắt buộc bằng điều kiện `iam:PermissionsBoundary`.
**C.** Session policy truyền lúc `AssumeRole`.
**D.** Đặt tất cả developer vào một IAM group có policy chỉ đọc.

**Đáp án: B.**

- **A gần đúng nhưng sai phạm vi**: SCP áp cho **toàn bộ account**, kể cả các role
  không do developer tạo, kể cả pipeline CI cần quyền ghi. Đề nói "role tạo ra
  không được vượt quá" — đó là ràng buộc trên từng role, không phải trên account.
- **C sai** vì session policy chỉ sống trong một phiên và do người gọi tự truyền —
  developer có thể đơn giản không truyền nó.
- **D sai** vì nó giới hạn quyền của **developer**, không giới hạn quyền của
  **role mà developer tạo ra**. Đây chính là bẫy: hai chủ thể khác nhau.
- **B đúng**: đây là bài toán kinh điển của permission boundary — uỷ quyền việc
  tạo role mà vẫn giữ được trần quyền. Chi tiết bắt buộc: policy cấp quyền
  `iam:CreateRole` cho developer phải kèm điều kiện
  `iam:PermissionsBoundary = <arn boundary>`, nếu không developer chỉ việc tạo
  role mà không gắn boundary.

</details>

<details><summary>Câu 6 — Trong IAM Policy Simulator, kết quả `implicitDeny` khác `explicitDeny` ở chỗ nào, và vì sao khác biệt đó quan trọng?</summary>

**A.** Không khác gì, cả hai đều là từ chối.
**B.** `implicitDeny` nghĩa là không policy nào cho phép; `explicitDeny` nghĩa là có policy cấm — và một `Allow` thêm vào sau sẽ lật được cái thứ nhất chứ không lật được cái thứ hai.
**C.** `explicitDeny` chỉ xuất hiện khi có SCP.
**D.** `implicitDeny` là lỗi cấu hình cần sửa.

**Đáp án: B.**

- **A sai** vì hệ quả vận hành khác hẳn nhau, dù kết quả trước mắt giống nhau.
- **C sai**: explicit Deny đến từ bất kỳ đâu — identity policy, resource policy,
  SCP, permission boundary, session policy.
- **D sai**: implicit deny là **trạng thái mặc định đúng đắn** của IAM. Mọi thứ
  bạn chưa cấp đều implicit deny, và đó là lý do least privilege khả thi.
- **B đúng**, và đây chính là câu trả lời cho gạch đầu dòng trong "Tiêu chí đạt":
  nếu bạn chặn khu lương bằng cách **thu hẹp Resource của Allow**, kết quả là
  implicitDeny — ai đó gắn thêm `AmazonS3ReadOnlyAccess` tháng sau là thủng.
  Nếu bạn chặn bằng một **statement Deny riêng**, kết quả là explicitDeny — không
  Allow nào lật được.

</details>

---

## Chỗ dễ hiểu sai

**"verify.sh xanh nghĩa là policy của tôi đúng."** Không hẳn. Nó nghĩa là policy
của bạn đúng **với những câu hỏi mà verify.sh nghĩ ra**. Least privilege thật sự
đo bằng thứ khác: chạy hệ thống một thời gian rồi dùng IAM Access Analyzer sinh
policy từ CloudTrail thực tế, so với policy bạn viết tay. Chênh lệch chính là
phần quyền thừa.

**Thu hẹp Allow và thêm Deny không tương đương.** Trong lab, hai cách đều làm
`verify.sh` xanh. Trong production chúng khác nhau về khả năng chịu đựng sai lầm
tương lai. Đây là khác biệt duy nhất giữa "chạy được" và "đúng" mà lab này dạy —
và nó ra thi.

**Permission boundary không cấp quyền.** Nó chỉ **giới hạn**. Một role có boundary
cho phép `s3:*` nhưng không có identity policy nào thì vẫn không làm được gì. Giao
của hai tập hợp, không phải hợp.

**External ID không phải bí mật quân sự.** Nó không cần bảo vệ như mật khẩu — nó
chỉ cần **khác nhau giữa các khách hàng** của bên thứ ba. Nó chống lại đúng một
kịch bản: một khách hàng khác của cùng công ty kiểm toán lừa công ty đó dùng role
ARN của bạn. Nếu bạn hiểu nó là "mật khẩu thứ hai" thì bạn hiểu sai bài toán.

**Trong production, resource policy còn có một vai trò mà identity policy không
có:** nó là nơi duy nhất bạn nói được "Principal = *" một cách có kiểm soát — tức
là cấp quyền cho những danh tính bạn không liệt kê trước được. Đó là cách các
dịch vụ AWS gọi lẫn nhau (`Service = cloudfront.amazonaws.com`), và tuần 4 bạn sẽ
gặp lại đúng mẫu đó với Origin Access Control.
