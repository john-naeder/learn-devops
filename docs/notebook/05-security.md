# Bảo mật và danh tính

> **Tra nhanh:** ai được làm gì trên AWS, quyền đó được tính ra sao, dữ liệu mã hoá bằng khoá nào, và dịch vụ nào trả lời câu hỏi bảo mật nào.

`Domain 1 · Design Secure Architectures (30% đề)`

Miền nặng nhất của SAA-C03, và phần lớn câu hỏi trong đó là câu hỏi IAM trá hình.

## Bản đồ

| Mục | Khi nào bạn cần đọc |
|---|---|
| [1. Cấu trúc policy](#1-cấu-trúc-policy--cách-máy-đọc-một-request) | Viết policy, hoặc không hiểu vì sao policy không ăn |
| [2. Luồng đánh giá quyền](#2-luồng-đánh-giá-quyền--sáu-cửa-một-request-phải-qua) | Đề trộn 4 loại policy rồi hỏi "có được không" |
| [3. Role và AssumeRole](#3-role-assumerole-và-trust-policy) | Cross-account, vendor bên thứ ba, service role |
| [4. Instance profile](#4-instance-profile--role-đi-vào-ec2-bằng-đường-nào) | EC2/ECS/Lambda cần gọi API AWS |
| [5. Permission boundary](#5-permission-boundary--trần-quyền-không-phải-quyền) | Cho dev tạo role mà không bị leo thang |
| [6. ABAC vs RBAC](#6-abac-vs-rbac) | "Hàng nghìn dự án, không muốn sửa policy mỗi lần" |
| [7. IAM Identity Center](#7-iam-identity-center) | Nhiều account, SSO, nhân viên vào/ra |
| [8. KMS](#8-kms--dịch-vụ-khoá-không-phải-dịch-vụ-mã-hoá) | Mọi câu hỏi có chữ "encrypt at rest" |
| [9. Secrets Manager vs Parameter Store](#9-secrets-manager-vs-parameter-store) | Mật khẩu DB, API key, config app |
| [10. ACM](#10-acm--chứng-chỉ-và-hai-cái-bẫy-region) | HTTPS, CloudFront, "cert không hiện trong dropdown" |
| [11. WAF và Shield](#11-waf-và-shield) · [12. Phát hiện](#12-sáu-dịch-vụ-phát-hiện--mỗi-cái-trả-lời-một-câu-hỏi-khác-nhau) · [13. CloudHSM](#13-cloudhsm-vs-kms) | DDoS, SQLi, GuardDuty/Inspector/Macie, FIPS 140-3 L3 |
| [14. Cognito](#14-cognito--user-pool-vs-identity-pool) | App web/mobile có người dùng cuối |

Liên quan: [networking](04-networking.md) (SG/NACL/endpoint policy),
[quản trị và giám sát](07-quan-tri-giam-sat.md) (CloudTrail/Config/SCP),
[tuần 1](../aws/w01-iam-foundations.md) và [tuần 9](../aws/w09-security-deep.md).

---

## 1. Cấu trúc policy — cách máy đọc một request

Mỗi lời gọi API được biến thành một **request context**: principal là ai, action gì
(`s3:GetObject`), resource nào (ARN), và một tập **condition key** (IP nguồn, thời
gian, có MFA chưa, đi qua VPC endpoint nào, tag của principal, tag của resource).
Policy là hàm nhận context đó và trả `Allow` / `Deny` / *không ý kiến*. Mọi thứ
còn lại là hệ quả của câu này.

Bốn chi tiết tài liệu nông hay bỏ qua:

**`Version` là phiên bản *ngôn ngữ*, không phải phiên bản policy của bạn.** `2012-10-17`
bật policy variable (`${aws:username}`); bỏ trường này thì AWS mặc định `2008-10-17` và
variable im lặng bị coi là chuỗi literal.

**`Action` và `Resource` phải khớp tầng.** `s3:ListBucket` là action trên *bucket*,
`s3:GetObject` trên *object* — đó là lý do phải có hai ARN. Chỉ cho `bucket/*` thì
`aws s3 ls` báo AccessDenied trong khi `aws s3 cp` vẫn chạy. Bug số một của người mới.

**`NotAction` + `Allow` là bẫy leo thang:** `Allow NotAction iam:*` cho phép mọi thứ trừ
IAM, kể cả dịch vụ AWS ra mắt sau này. An toàn khi đi với `Deny`.

**Condition có bản `IfExists` và toán tử tập hợp.** `StringEquals` **không** khớp khi
key vắng mặt (kết quả là *không ý kiến*, không phải deny) — muốn "có thì phải bằng"
dùng `StringEqualsIfExists`, muốn chặn khi vắng dùng `Null`. Key nhiều giá trị phải
bọc `ForAllValues:` hoặc `ForAnyValue:`. Bẫy kinh điển:
**`ForAllValues:StringEquals` trả true khi key vắng mặt hoàn toàn** — tập rỗng thoả
mãn "mọi phần tử đều thoả". Ghép với `Allow` mà không `Null` chặn kèm là mở toang.

### Giới hạn kích thước — con số ra thi

| Thứ | Giới hạn |
|---|---|
| Managed policy | 6.144 ký tự (không tính whitespace) |
| Inline policy: user / group / role | 2.048 / 5.120 / 10.240 ký tự |
| Managed policy gắn vào **role** | **20** mặc định, nâng lên **25** |
| Managed policy gắn vào **user** | 10, nâng lên 20 |
| Managed policy gắn vào **group** | 10, **không nâng được** |

Con số "10 managed policy mỗi role" trong hầu hết tài liệu ôn cũ là **sai** — xem
[Nguồn nói khác](#nguồn-nói-khác). Hết chỗ thì gộp policy, hoặc chuyển sang inline
(inline không tính vào quota managed).

---

## 2. Luồng đánh giá quyền — sáu cửa một request phải qua

Đừng học thuộc sơ đồ — học **vì sao** mỗi cửa tồn tại rồi tự suy ra thứ tự. Nguyên tắc
nền: **mặc định deny**; một `Allow` bật đèn xanh; một `Deny` tường minh tắt hết mọi đèn
xanh, ở bất kỳ đâu.

```
Request context (principal, action, resource, condition key)
  │
  ├─(0) Deny tường minh ở BẤT KỲ policy nào? ── có ──► DENY. Dừng.
  │
  ├─(1) SCP  — principal thuộc member account của Organizations?
  │        Nếu có: SCP phải Allow. Không Allow = implicit deny.
  │        KHÔNG áp lên management account, không áp lên service-linked role.
  │
  ├─(2) RCP  — resource có được RCP của org cho phép bị đụng vào không?
  │
  ├─(3) Resource-based policy — bucket/key/queue policy, trust policy
  │        CÙNG ACCOUNT: Allow ở đây LÀ ĐỦ, không cần identity policy.
  │        KHÁC ACCOUNT: cần Allow ở CẢ HAI phía.
  │
  ├─(4) Identity-based policy
  ├─(5) Permission boundary  — GIAO với (4)
  └─(6) Session policy       — GIAO tiếp
```

**Vì sao Deny đi trước tất cả.** Nếu Deny phải xếp hàng theo thứ tự, muốn chặn một hành
động bạn phải đi kiểm toán và xoá mọi Allow đang tồn tại. Cho Deny quyền phủ quyết tuyệt
đối biến "chặn" thành thao tác *thêm một statement* — đó là lý do mọi guardrail thực tế
đều viết bằng Deny.

**Vì sao SCP và boundary là phép GIAO, không phải HỢP.** Cả hai là *trần* do bên trên đặt
ra để bên dưới không tự nâng quyền cho mình; nếu là phép hợp thì người bị giới hạn chỉ
cần tự viết thêm một Allow là thoát rào. Hệ quả: **chúng không bao giờ cấp quyền**, kể cả
khi bên trong ghi `Allow *` — `Allow` ở đó chỉ nghĩa là "cửa này không chặn". Session
policy cùng logic, nó cắt một phiên cụ thể xuống mà không cần tạo role mới.

**Vì sao resource-based policy đi đường tắt trong cùng account.** Cùng account thì
identity policy và resource policy đều do cùng chủ sở hữu viết, nên AWS coi hai nguồn là
hợp lệ ngang nhau — **một Allow ở bất kỳ bên nào là đủ**. Qua biên giới account, mỗi bên
chỉ nói được cho phần của mình: A phải cho user gọi ra, B phải cho user đó gọi vào.
**Cả hai.** Hai ngoại lệ: **trust policy** là resource-based nhưng `sts:AssumeRole`
cross-account *vẫn* cần cả hai phía; **KMS key policy** thì bắt buộc, thiếu nó thì
identity policy vô dụng (mục 8).

### RCP — mảnh mới tài liệu ôn cũ không có

**Resource control policy** (cuối 2024) là bản đối xứng của SCP: SCP đặt trần cho
**principal** trong org, RCP đặt trần cho **resource** trong org. Bài toán điển
hình: "chặn mọi bucket trong toàn tổ chức không cho principal ngoài org đọc" —
SCP bó tay vì kẻ gọi nằm ngoài org nên không bị SCP chạm tới; RCP làm được vì nó
gắn ở phía resource.

Dịch vụ hỗ trợ lúc ra mắt: S3, STS, KMS, SQS, Secrets Manager; không áp lên resource
trong management account; cũng **không cấp quyền**; tối đa 5 RCP mỗi node, 5.120 ký tự,
miễn phí, cần bật "all features". Đề SAA hỏi SCP nhiều hơn RCP rất nhiều, nhưng từ khoá
**"data perimeter"** hoặc "chặn truy cập từ ngoài tổ chức vào resource" → RCP.

### Nuance rất ít nơi nói: boundary và ARN trong resource policy

AWS ghi thẳng trong docs: nếu bạn nêu **role session hoặc IAM user** ở `Principal`
của resource-based policy thì **không cần** Allow tường minh trong permission
boundary; nếu nêu **ARN của role** thì **cần**. Cả hai trường hợp, **Deny tường
minh trong boundary vẫn có hiệu lực**.

```jsonc
"Principal": {"AWS": "arn:aws:sts::111122223333:assumed-role/DevRole/alice"}  // A
"Principal": {"AWS": "arn:aws:iam::111122223333:role/DevRole"}                // B
```

A đi tắt qua implicit deny của boundary; B thì boundary vẫn phải Allow, nếu không là DENY.

**Cơ chế:** khi resource policy chỉ đích danh một *danh tính cụ thể đang tồn tại*
(user, hoặc một phiên đã có tên), AWS coi đó là chủ resource cấp quyền trực tiếp
cho một cá thể — không phải cấp cho "bất kỳ ai mang role này" — nên không cần trần
của role gật đầu. ARN role thì ngược lại: nó là một *lớp* danh tính, quyền đi qua
role, mà role bị boundary bó. Cùng logic áp cho session policy và SCP.

Ý nghĩa thực hành: nếu boundary là hàng rào bảo mật của bạn, **đừng để ai được
viết bucket policy có `assumed-role/.../session-name`** — đó là lỗ leo thang hợp lệ
về mặt kỹ thuật.

---

## 3. Role, AssumeRole và trust policy

**Role không có credential dài hạn.** Nó là vỏ chứa hai thứ: *permission policy*
(role làm được gì) và *trust policy* (ai được mặc role). Dùng role = gọi
`sts:AssumeRole` và nhận bộ ba tạm `AccessKeyId` / `SecretAccessKey` / `SessionToken`.

### AssumeRole là cửa hai chiều

Cả hai phải đúng: (1) trust policy của role `Allow` principal đó với `sts:AssumeRole`;
(2) principal có identity policy cho phép `sts:AssumeRole` lên ARN role đó. Ngoại lệ:
cùng account, trust policy nêu `"Principal": {"AWS": "arn:aws:iam::111122223333:root"}`
là đã ủy quyền cho IAM của account quyết định — chỉ cần điều kiện (2).

```json
{
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::444455556666:root" },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": { "sts:ExternalId": "chuoi-bi-mat-doi-tac-cap" },
    "Bool": { "aws:MultiFactorAuthPresent": "true" }
  }
}
```

### External ID — bài toán confused deputy

Bạn thuê một SaaS giám sát chi phí, tạo role trust account `999988887777` của họ. Nhưng
SaaS đó phục vụ 5.000 khách bằng **cùng một account**. Nếu khách khác biết ARN role của
bạn, họ chỉ cần bảo SaaS "hãy assume role này" — SaaS dùng credential *của chính nó*,
trust policy gật đầu vì đúng account, và bạn bị đọc dữ liệu bởi kẻ chưa từng được ủy
quyền. Đó là **confused deputy**: bên đáng tin bị lừa dùng quyền của mình thay cho bên
không đáng tin. `sts:ExternalId` sửa việc này — nhà cung cấp phải kèm một chuỗi bí mật
riêng cho từng khách. Quy tắc thi: **cross-account với bên thứ ba → luôn có External
ID.** Bản tương đương cho *dịch vụ AWS* gọi thay bạn là `aws:SourceAccount` và
`aws:SourceArn`.

### Thời hạn phiên — con số hay bị hỏi

`AssumeRole`: 15 phút – `MaxSessionDuration` của role (1–12 giờ), **mặc định 1 giờ** —
nhưng khi **role chaining** (role assume role khác) thì **trần cứng 1 giờ**, không nâng
được, và CLI không cảnh báo, chỉ hết hạn giữa chừng job.
`AssumeRoleWithWebIdentity`/`WithSAML`: 15 phút – 12 giờ. `GetSessionToken` (user + MFA):
15 phút – **36 giờ**, mặc định 12 giờ; root chỉ được 1 giờ. Credential từ IMDS tự xoay,
luôn hợp lệ nếu bạn đọc lại.

### Ba kiểu role phải nhận ra ngay

**Service role** (trust một service principal như `lambda.amazonaws.com`),
**cross-account role** (trust account/role ARN khác), và **service-linked role** (AWS
tạo và kiểm soát, tên `AWSServiceRoleForX`). Service-linked role **không bị SCP chặn**
và bạn không sửa được trust policy của nó — chủ ý, vì một SCP viết ẩu sẽ làm hỏng cơ
chế nội bộ của Auto Scaling.

---

## 4. Instance profile — role đi vào EC2 bằng đường nào

**Instance profile là vỏ chứa đúng một IAM role**, và nó mới là thứ bạn gắn vào EC2 —
không phải gắn role trực tiếp. Console giấu chuyện này; Terraform bắt khai báo tường
minh (`aws_iam_instance_profile` có trường `role` số ít, không phải danh sách).

**Cơ chế:** EC2 gọi STS thay bạn rồi phục vụ credential qua **IMDS** tại
`169.254.169.254`. SDK/CLI tự tìm ở đó khi không có biến môi trường hay
`~/.aws/credentials`. Credential tự xoay trước khi hết hạn, nên **không bao giờ có
access key nằm trên đĩa** — đó là toàn bộ lý do "đừng để access key trên EC2" là
đáp án đúng trong mọi đề.

**IMDSv2** bắt lấy token bằng `PUT` rồi đính vào mọi `GET`:

```bash
TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

Vì sao `PUT` quan trọng: SSRF qua web app lỗi thường chỉ tạo được `GET` tới URL tuỳ ý —
IMDSv1 chỉ cần một `GET` là lộ credential. IMDSv2 chặn lớp tấn công đó, từ chối
`X-Forwarded-For`, và **hop limit TTL mặc định là 1** nên gói tin không qua nổi một lớp
bridge network của container (container bridge mode cần IMDS → đặt hop limit 2). Đổi
role trong instance profile có hiệu lực gần như ngay, nhưng credential đang cache trong
SDK vẫn là bộ cũ tới khi hết hạn.

---

## 5. Permission boundary — trần quyền, không phải quyền

Boundary là một **managed policy** gắn vào user/role với vai trò đặc biệt: nó
không cấp gì, nó nói "danh tính này tối đa chỉ tới đây".

```
Quyền hiệu lực = (identity-based policy) ∩ (permission boundary)
```

### Bài toán duy nhất nó giải

Bạn muốn dev tự tạo role cho Lambda của họ. Nhưng cho `iam:CreateRole` +
`iam:AttachRolePolicy` nghĩa là dev tạo được role `AdministratorAccess` rồi assume vào —
leo thang trong 30 giây. Lời giải: identity policy của dev có `Condition` bắt buộc mọi
role họ tạo phải mang một boundary cụ thể —
`"StringEquals": {"iam:PermissionsBoundary": "arn:aws:iam::...:policy/dev-boundary"}` —
cộng `Deny` cấm họ gỡ hoặc sửa chính boundary đó (`iam:DeleteRolePermissionsBoundary`,
`iam:PutRolePermissionsBoundary` trừ đúng ARN trên, và `iam:CreatePolicyVersion` trên
policy boundary).

### Boundary vs SCP

| | Permission boundary | SCP |
|---|---|---|
| Gắn vào | một IAM user / role | account hoặc OU |
| Ai đặt | IAM admin trong account | management account |
| Ảnh hưởng root user của account | **không** | **có** (trừ management account) |
| Ảnh hưởng service-linked role | không | không |
| Số lượng | 1 mỗi entity | 5 mỗi node, kế thừa dọc cây |

Cả hai là phép giao, cả hai không cấp quyền. Đề hay hỏi: "Dev có
`AdministratorAccess` nhưng vẫn không tạo được EC2 ở eu-west-1" → nguyên nhân là
SCP hoặc boundary, không phải identity policy.

---

## 6. ABAC vs RBAC

**RBAC** = quyền theo *vai*: mỗi vai một policy, resource liệt kê bằng ARN. Thêm dự án
→ sửa hoặc thêm policy; số policy tăng tuyến tính và bạn sẽ đụng trần 6.144 ký tự.
**ABAC** = quyền theo *thuộc tính*: gắn tag lên principal và lên resource, rồi viết
**một** policy so hai tag đó:

```json
{
  "Effect": "Allow",
  "Action": ["ec2:StartInstances", "ec2:StopInstances"],
  "Resource": "*",
  "Condition": {
    "StringEquals": { "aws:ResourceTag/du-an": "${aws:PrincipalTag/du-an}" }
  }
}
```

Policy này không đổi dù bạn có 3 hay 3.000 dự án. Thêm dự án = gắn tag, không đụng
IAM. Đây chính xác là đáp án cho đề dạng "công ty tăng trưởng nhanh, không muốn
cập nhật policy mỗi lần thêm team, giải pháp nào **ít công quản trị nhất**".

Cái giá là **quản trị tag phải chặt**, nếu không ai cũng tự gắn `du-an = tai-chinh` cho
mình. Hai điều kiện bắt buộc đi kèm: chặn tự sửa tag của chính mình
(`Deny iam:TagRole` / `iam:UntagRole` / `iam:TagUser`), và bắt buộc tag lúc tạo resource
(`aws:RequestTag/du-an` + `aws:TagKeys` với `ForAllValues:StringEquals` — nhớ bẫy tập
rỗng ở mục 1, phải kèm `Null` check). Với IAM Identity Center, tag của principal đến từ
**session tag** do IdP đẩy qua SAML attribute — đó là lý do ABAC và Identity Center hay
đi cùng nhau trong đề.

---

## 7. IAM Identity Center

Tên cũ AWS SSO. Nó **không thay thế IAM** — nó là lớp phân phối *danh tính con
người* vào nhiều account.

Cơ chế: bạn tạo một **permission set** (một tập policy + thời hạn phiên). Gán
permission set cho một nhóm ở một account → Identity Center **tạo ra một IAM role
thật trong account đó**, tên `AWSReservedSSO_<tên>_<hash>`, trust policy tin vào
SAML provider của Identity Center. Người dùng vào portal, chọn account + permission
set, thực chất đang `AssumeRoleWithSAML` vào role đó.

Hệ quả cần nhớ: permission set **tuân theo quota IAM của role** → trần managed policy
là 20 (nâng lên 25); xoá permission set = xoá role trong mọi account đã gán; thời hạn
phiên 1–12 giờ; identity source là thư mục nội bộ, AWS Managed Microsoft AD, hoặc IdP
ngoài (SAML 2.0 để đăng nhập, SCIM để đồng bộ user/group); `aws sso login` trên CLI v2
là cách đúng để dev dùng CLI thay access key dài hạn.

Khi nào **không** dùng: workload (máy móc) gọi API — máy dùng IAM role qua instance
profile hoặc OIDC federation, không đăng nhập portal.

---

## 8. KMS — dịch vụ khoá, không phải dịch vụ mã hoá

Chỉnh lại trong đầu ngay: KMS **không mã hoá dữ liệu của bạn**. Nó giữ khoá gốc trong
HSM (key material không bao giờ ra khỏi HSM ở dạng plaintext) và cung cấp API mã hoá/
giải mã **tối đa 4 KB**. Lớn hơn thì đi qua envelope encryption.

### Envelope encryption

```
Ghi:
  GenerateDataKey(KeyId=CMK, KeySpec=AES_256)
    → Plaintext DEK   (256-bit, dùng ngay rồi xoá khỏi RAM)
    → CiphertextBlob  (chính DEK đó, đã mã hoá bằng CMK)
  Mã hoá 500 GB bằng Plaintext DEK, cục bộ, tốc độ AES của CPU
  Lưu: [CiphertextBlob][dữ liệu đã mã hoá]

Đọc:
  Decrypt(CiphertextBlob) → Plaintext DEK   (đúng 1 lần gọi KMS)
  Giải mã 500 GB cục bộ
```

Ba lý do nó tồn tại, theo đúng thứ tự quan trọng: **giới hạn 4 KB** (không cách nào
đẩy 500 GB qua API), **băng thông/độ trễ** (mã hoá cục bộ ở tốc độ CPU), **chi phí và
quota request** (KMS có quota request/giây theo region, vượt là `ThrottlingException`).

`GenerateDataKeyWithoutPlaintext` trả về **chỉ** bản mã của DEK — dùng cho tiến trình
chỉ được ghi, không tự giải mã được: cách tách quyền ghi khỏi quyền đọc bằng chính API.

**Encryption context** là map key-value đi kèm mỗi lời gọi, đóng vai trò AAD: giải mã
phải cung cấp đúng context, sai một ký tự là hỏng. Nó hiện nguyên văn trong CloudTrail
(đừng nhét bí mật vào) và dùng được trong key policy qua `kms:EncryptionContext:<key>`
— cách khoá một CMK dùng chung xuống từng tenant.

### Ba loại khoá

| | Customer managed | AWS managed | AWS owned |
|---|---|---|---|
| Tên | bạn đặt, có alias riêng | `aws/s3`, `aws/rds`… | không thấy |
| Nằm trong account bạn | có | có | **không** |
| Key policy sửa được | **có** | **không** | không |
| Dùng cross-account | **có** | **không** | không |
| Rotation | bật/tắt, chu kỳ 90–2.560 ngày | tự động **hằng năm**, không tắt được | AWS lo |
| Giá | **$1/tháng** + request | miễn phí (chỉ tính request) | miễn phí |
| Thấy trong CloudTrail của bạn | có | có | **không** |
| Xoá được | có (7–30 ngày chờ) | không | không |

Quy tắc thi: đề nhắc **audit key usage / kiểm soát rotation / chia sẻ cross-account
/ tự xoá khoá** → **customer managed key**. Đề chỉ nói "mã hoá at rest, đơn giản"
→ AWS managed key đủ và rẻ hơn.

### Key policy vs IAM policy — chỗ sai nhiều nhất

KMS là ngoại lệ: **key policy bắt buộc và không thể vắng mặt**. Identity policy ghi
`"Action": "kms:*", "Resource": "*"` sẽ **không** cho phép gì nếu key policy không mở
cửa. Key policy mặc định chứa statement `Enable IAM User Permissions` với
`"Principal": {"AWS": "arn:aws:iam::111122223333:root"}` và `"Action": "kms:*"`.

`root` ở đây **không phải root user** — nó là ký hiệu "ủy quyền cho hệ thống IAM của
account này quyết định". Xoá statement đó thì chỉ principal được nêu đích danh mới
dùng được khoá, và bạn có thể tự khoá mình ra ngoài vĩnh viễn (phải mở ticket Support).

Cross-account KMS cần **ba** thứ, thiếu một là hỏng: key policy phía chủ khoá cho phép
account kia; identity policy phía kia cho phép `kms:Decrypt` lên ARN khoá; và grant nếu
là dịch vụ (S3 replication, copy snapshot EBS).

### Grant

Grant cấp quyền dùng khoá mà **không sửa key policy**. Chỉ cấp được thao tác mật
mã (`Encrypt`, `Decrypt`, `GenerateDataKey`, `CreateGrant`, `RetireGrant`,
`DescribeKey`), không cấp quyền quản trị. Có **grant constraint** ràng theo
encryption context — hạt mịn hơn key policy. Thu hồi bằng `RetireGrant` /
`RevokeGrant`. **Eventual consistent**: sau `CreateGrant` mất vài giây mới hiệu
lực, muốn dùng ngay thì truyền `GrantToken` trả về kèm request. Đây chính là cơ
chế các dịch vụ AWS dùng: bật mã hoá EBS bằng CMK của bạn → EC2 tạo một grant lên
khoá đó, sống theo vòng đời volume.

Chọn: quyền dài hạn, ít đổi, review được → key policy. Quyền tạm cho workload, số
lượng lớn, tự dọn → grant.

### Multi-Region key

Bình thường mỗi CMK bị nhốt trong một region và ciphertext của nó chỉ giải được ở
region đó. Multi-Region key phá lệ: **cùng key material, cùng key ID** (tiền tố `mrk-`),
khác ARN, tồn tại ở nhiều region — ciphertext mã hoá ở `us-east-1` giải được ở
`eu-west-1` mà không cần gọi xuyên region. Có một **primary** và nhiều **replica**;
primary promote đổi vai được. Key policy, alias, tag, rotation **quản lý độc lập từng
region**, không tự đồng bộ (trừ key material khi primary rotate).

Dùng khi: DynamoDB global table, S3 cross-Region replication của object đã mã hoá,
client-side encryption đa region, DR active-active. **Không** dùng làm mặc định — MRK
làm yếu biên giới cách ly region, và mỗi replica vẫn tính $1/tháng.

### Rotation — cái gì thực sự bị xoay

Chỗ tài liệu nông dạy sai nhiều nhất. Rotation **tạo key material mới** và dùng nó cho
mọi thao tác mã hoá **kể từ đó**. Không đổi: key ID, key ARN, alias, key policy, grant.
Không xảy ra: **dữ liệu cũ không được mã hoá lại** — KMS giữ mọi phiên bản material cũ
**vĩnh viễn**, mỗi ciphertext mang con trỏ tới phiên bản đã dùng.

Hệ quả phải nói được: **rotation KMS không giảm lượng dữ liệu bị lộ nếu material cũ rò
rỉ** — nó chỉ giới hạn lượng dữ liệu nằm dưới *một* phiên bản material, phục vụ tuân
thủ chứ không phải phục hồi sự cố. Muốn dữ liệu cũ dùng material mới phải `ReEncrypt`.

Con số tính đến 2026-08: chu kỳ tự động **90–2.560 ngày**, mặc định **365** (khoá bật
rotation từ trước vẫn giữ 1 năm); **on-demand rotation** tối đa **10 lần mỗi khoá** trọn
đời, không ảnh hưởng lịch tự động; giá rotation lần 1 và lần 2 mỗi lần cộng $1/tháng và
**trần dừng ở lần thứ hai**; **không** rotate tự động được với khoá bất đối xứng, HMAC,
custom key store, hoặc material import; `ListKeyRotations` cho xem lịch sử.

### Xoá khoá — vì sao phải chờ

`ScheduleKeyDeletion` đặt khoá vào `PendingDeletion` với thời gian chờ **7–30
ngày, mặc định 30**. Trong thời gian đó khoá **đã vô hiệu ngay** cho mọi thao tác
mật mã (không phải hỏng sau 30 ngày), nhưng `CancelKeyDeletion` vẫn cứu được. Vì
sao chờ: xoá khoá **không hoàn tác được** và biến mọi dữ liệu mã hoá bằng nó thành
rác vĩnh viễn — thời gian chờ cộng CloudWatch alarm trên `PendingDeletion` là cơ
hội duy nhất phát hiện nhầm lẫn. Muốn "tắt" mà không mất gì → `DisableKey`.

Với multi-Region: xoá primary khi còn replica → primary vào `PendingReplicaDeletion`
và **đứng đó vô thời hạn**; chỉ khi replica cuối cùng bị xoá thật thì đồng hồ 7–30
ngày mới chạy. Giá KMS: $1/khoá/tháng, $0,03 / 10.000 request, free tier 20.000
request/tháng.

---

## 9. Secrets Manager vs Parameter Store

| | Secrets Manager | Parameter Store Standard | Advanced |
|---|---|---|---|
| Giá lưu trữ | **$0,40 / secret / tháng** | **miễn phí** | **$0,05 / param / tháng** |
| Giá API | $0,05 / 10.000 lời gọi | miễn phí | $0,05 / 10.000 |
| Kích thước tối đa | **64 KB** | **4 KB** | **8 KB** |
| Rotation dựng sẵn | **có** (Lambda; managed rotation cho RDS/Aurora/Redshift/DocumentDB) | không | không |
| Resource policy (cross-account) | **có** | không | không |
| Parameter policy (hết hạn, nhắc đổi) | không cần | không | **có** |
| Throughput mặc định | cao | **40 TPS** dùng chung cho `Get*` | 40 TPS, nâng lên 10.000 |

Ba chi tiết quyết định trong phòng thi:

**Rotation tự động cho mật khẩu database → Secrets Manager, luôn luôn.** Cơ chế là
Lambda 4 bước (`createSecret` → `setSecret` → `testSecret` → `finishSecret`) với hai bộ
credential luân phiên, nên ứng dụng không đứt kết nối lúc đổi; RDS/Aurora/Redshift/
DocumentDB còn có *managed rotation*, không cần Lambda của bạn.

**Rẻ nhất mà vẫn mã hoá → Parameter Store Standard `SecureString`** (10.000 tham số
miễn phí). Đề nhấn "cost-effective" và không nhắc rotation → đây là đáp án.

**Parameter Store đọc được secret của Secrets Manager** qua tham chiếu
`/aws/reference/secretsmanager/<ten>` — lời giải cho "hợp nhất cách đọc cấu hình mà
không đổi code". Advanced tier là **con đường một chiều**: Standard → Advanced được,
ngược lại thì không (cắt 8 KB xuống 4 KB sẽ mất dữ liệu), phải xoá và tạo lại.

---

## 10. ACM — chứng chỉ và hai cái bẫy region

ACM cấp chứng chỉ public **miễn phí và tự động gia hạn**. Hai chữ "tự động" chỉ
đúng với **DNS validation** (một bản ghi CNAME); **email validation** thì mỗi lần
gia hạn lại phải bấm link trong email.

**Dùng được ở đâu:** CloudFront, ALB, NLB, API Gateway, App Runner, Amplify,
Elastic Beanstalk (qua ELB), Nitro Enclaves. Trước 06/2025 nó **không** cài được
lên EC2 hay server on-prem vì private key không rời khỏi ACM.

Từ 06/2025 có **exportable public certificate**: lấy được cả private key, nhưng phải
**bật cờ export ngay lúc yêu cầu** (chứng chỉ cũ không export được, cờ không đổi sau khi
cấp), **có phí** ($15/FQDN, $149/wildcard, tính lúc cấp và lúc gia hạn), **hiệu lực 395
ngày**. Chứng chỉ public không-export vẫn miễn phí như cũ.

**Bẫy region.** (1) **Chứng chỉ phải cùng region với resource dùng nó** — cert ở region
khác thì **không hiện trong dropdown**, triệu chứng thường gặp nhất. (2) **CloudFront
luôn đòi chứng chỉ ở `us-east-1`**: nó là dịch vụ global nhưng control plane nằm ở
`us-east-1`, cấu hình distribution được đọc từ đó rồi đẩy ra edge — cùng lý do, WAF cho
CloudFront phải tạo ở scope `CLOUDFRONT`. (3) Ít ai nói: **gia hạn thất bại vì bản ghi
CNAME validation đã bị xoá** — ACM thử gia hạn từ **60 ngày trước hạn** và cần bản ghi
đó còn nguyên; dọn Route 53 "cho gọn" là cách phổ biến nhất để một hệ thống đang chạy
tốt tự hết hạn chứng chỉ sau 11 tháng.

**ACM Private CA** là dịch vụ khác, có phí (~$400/CA/tháng + phí mỗi chứng chỉ), dùng
cho mTLS nội bộ; chứng chỉ private **export được** từ đầu.

---

## 11. WAF và Shield

### AWS WAF — tường lửa tầng 7

Web ACL gắn được vào **CloudFront, ALB, API Gateway (REST), AppSync, Cognito user
pool, App Runner, Verified Access**. **Không gắn được vào NLB** — NLB ở L4, không
thấy HTTP. Đề rất hay đưa NLB làm mồi.

Cơ chế: rule chạy **theo priority tăng dần**, **hành động terminating đầu tiên thắng**
(`Allow` và `Block` terminating; `Count` và `CAPTCHA`/`Challenge` thì không). Hết rule
mà chưa ai quyết → **default action**. Vì thế thứ tự rule là thiết kế: đặt allow-list IP
nội bộ ở priority thấp sẽ khiến managed rule group phía sau không bao giờ soi traffic
nội bộ.

- **WCU**: 1.500 mỗi web ACL (nâng được). Mọi managed rule group đều ăn WCU — bật 4–5
  group là hết chỗ; regex và JSON body tốn nhiều.
- **Rate-based rule**: cửa sổ trượt **5 phút**, đánh giá lại khoảng mỗi 30 giây →
  **luôn có độ trễ**, không chặn được burst tức thời. Ngưỡng tối thiểu 10 request/5 phút.
- **Body được soi**: mặc định **8 KB**, nâng tới 64 KB tuỳ resource; phần vượt **không
  được kiểm tra** — bạn chọn `CONTINUE` hoặc `MATCH`.
- Giá: $5/web ACL/tháng + $1/rule/tháng + $0,60 / triệu request.

### Shield Standard vs Advanced

**Shield Standard** miễn phí, tự động, cho mọi khách hàng. Chống DDoS **L3/L4**.
Với CloudFront, Route 53 và Global Accelerator, khả năng hấp thụ gần như không
giới hạn vì tấn công bị chặn ở edge — đó là lý do "đưa web ra sau CloudFront" tự
nó đã là biện pháp chống DDoS, không cần mua gì.

**Shield Advanced**: **$3.000/tháng cho cả tổ chức**, cam kết 1 năm, cộng phí data
transfer. Đổi lại: **DDoS cost protection** (hoàn credit cho chi phí scale-out do tấn
công — đề nói "không muốn trả tiền cho traffic tấn công" thì là đây); **Shield Response
Team** 24/7 viết rule mitigation thay bạn; **WAF miễn phí** trên resource được bảo vệ;
phát hiện dựa trên **health check** Route 53 nên ít false positive; mitigation tự động
cho **L7** (vẫn phải có WAF gắn vào); và bảo vệ được cả **Elastic IP**.

**AWS Firewall Manager** là lớp trên: áp một chính sách WAF / Shield Advanced /
Security Group / Network Firewall xuống **toàn bộ account trong Organizations**,
kể cả resource tạo sau này. Cần Organizations + AWS Config. Từ khoá đề:
"centrally, across all accounts, including new resources".

---

## 12. Sáu dịch vụ phát hiện — mỗi cái trả lời một câu hỏi khác nhau

| Dịch vụ | Nó trả lời câu hỏi gì | Nguồn dữ liệu |
|---|---|---|
| **GuardDuty** | *"Có ai đang tấn công tôi hoặc đã chiếm được thứ gì không?"* | CloudTrail management event, VPC Flow Logs, DNS log — đọc ngoài luồng, không cần bật gì |
| **Inspector** | *"Phần mềm tôi đang chạy có CVE nào không?"* | EC2 (qua SSM Agent hoặc quét snapshot), image ECR, code Lambda và layer |
| **Macie** | *"Trong S3 của tôi có dữ liệu nhạy cảm không?"* | object trong S3, chỉ S3 |
| **Detective** | *"Finding này bắt nguồn từ đâu, chuỗi sự kiện thế nào?"* | đồ thị dựng từ CloudTrail + VPC Flow + finding GuardDuty |
| **Security Hub** | *"Tôi đang thế nào so với CIS/PCI/FSBP, và mọi finding nằm ở đâu?"* | tổng hợp finding, chuẩn hoá về ASFF |
| **IAM Access Analyzer** | *"Resource nào đang mở ra ngoài? Quyền nào chưa từng dùng?"* | phân tích hình thức trên policy, không phải log |

**GuardDuty vs Inspector.** GuardDuty phát hiện **hành vi đang diễn ra** (instance
đang đào bitcoin, credential gọi API từ IP lạ, DNS query tới domain C&C). Inspector
phát hiện **lỗ hổng chưa bị khai thác**. Từ khoá: "compromised / unusual /
malicious" → GuardDuty; "vulnerability / CVE / patch level" → Inspector.

**Detective vs Security Hub.** Security Hub là **bảng tổng hợp** (rộng, nông).
Detective là **kính lúp** (hẹp, sâu) — bạn vào Detective *sau khi* đã có finding.
Từ khoá "root cause / investigate / visualize relationships" → Detective.

**GuardDuty vs CloudTrail.** CloudTrail là *log thô*, ghi mọi thứ nhưng không nói cái gì
bất thường; GuardDuty *đọc* CloudTrail và kết luận. "Ai đã xoá bucket" → CloudTrail;
"phát hiện hoạt động bất thường tự động" → GuardDuty.

Chi tiết vận hành: GuardDuty có **30 ngày dùng thử miễn phí**, severity 1,0–8,9, đẩy
finding sang EventBridge để tự động hoá; các *protection plan* tính phí riêng (S3, EKS
audit + runtime, Runtime Monitoring EC2/ECS/EKS, Malware cho EBS và S3, RDS login,
Lambda network). Inspector quét **liên tục và event-driven** — push image lên ECR là
quét ngay, CVE mới công bố là quét lại. Macie tính phí theo dung lượng quét. Cả sáu đều
hỗ trợ **delegated administrator** qua Organizations.

---

## 13. CloudHSM vs KMS

| | KMS | CloudHSM |
|---|---|---|
| Mô hình thuê | multi-tenant (AWS quản) | **single-tenant**, cluster trong VPC của bạn |
| Ai có quyền cao nhất trên khoá | AWS vận hành, bạn kiểm soát qua policy | **chỉ bạn** — AWS không có đường vào |
| Chuẩn | HSM đạt FIPS 140-3 L3 | **FIPS 140-3 L3**, bạn là tenant duy nhất |
| Giao diện | API AWS (SigV4, IAM) | **PKCS#11, JCE, OpenSSL engine, CNG/KSP** |
| Xuất khoá ra ngoài | không | **có** (wrap key) |
| Tích hợp dịch vụ AWS | gần như toàn bộ | rất ít, phải qua custom key store |
| Vận hành | không có | cluster, user HSM, quorum, HA đều của bạn |
| Giá | $1/khoá/tháng | tính theo **giờ HSM**, đắt hơn hẳn |

Chọn CloudHSM chỉ khi có một trong bốn lý do, và đề luôn nêu thẳng: quy định bắt buộc
**bạn là người duy nhất** chạm được vào khoá; cần **xuất khoá** ra khỏi AWS; cần giao
diện KMS không có (chạy CA riêng, ký code PKCS#11, offload SSL); hoặc cần single-tenant
về phần cứng. Không có lý do nào trong bốn cái đó thì **KMS luôn đúng**. HA của CloudHSM
cần **tối thiểu 2 HSM ở 2 AZ**; mất toàn bộ HSM mà không backup là mất khoá vĩnh viễn.
**KMS custom key store** là cây cầu: CMK trong KMS, material trong cluster CloudHSM của
bạn — đánh đổi là **mất rotation tự động**.

---

## 14. Cognito — user pool vs identity pool

Hai dịch vụ khác nhau bị đặt chung một tên, và đề khai thác đúng chỗ đó.

**User pool = một identity provider hoàn chỉnh.** Nó *là* nơi lưu người dùng: đăng
ký, đăng nhập, xác thực email/SĐT, MFA, chính sách mật khẩu, hosted UI, federation
sang Google/Facebook/SAML/OIDC. Đầu ra là **JWT** (ID, access, refresh token).
Dùng token đó ở: API Gateway (Cognito authorizer / JWT authorizer), ALB (rule
authenticate-cognito), AppSync (`AMAZON_COGNITO_USER_POOLS`).

**Identity pool = máy đổi token lấy credential AWS.** Nó không lưu người dùng.
Đưa cho nó một token (từ user pool, Google, SAML, hoặc không đưa gì — *unauthenticated
identity*), nó gọi `sts:AssumeRoleWithWebIdentity` và trả **credential AWS tạm thời**.

Ý nghĩa kiến trúc: identity pool là thứ duy nhất cho phép **client gọi thẳng dịch vụ
AWS** mà không qua backend, và nó phân quyền theo từng người dùng nhờ policy variable —
`"Resource": "arn:aws:s3:::anh/${cognito-identity.amazonaws.com:sub}/*"` là một policy
phục vụ hàng triệu người dùng, mỗi người một prefix.

| Đề nói | Đáp án |
|---|---|
| "người dùng đăng nhập vào app web/mobile" | **user pool** |
| "bảo vệ API Gateway bằng token người dùng" | **user pool** authorizer |
| "app mobile upload thẳng lên S3, mỗi người một thư mục" | **identity pool** + policy variable |
| "nhân viên nội bộ vào Console nhiều account" | **không phải Cognito** — IAM Identity Center |

Dòng cuối là bẫy phổ biến nhất: Cognito dành cho **người dùng cuối của ứng dụng
bạn**, không dành cho **nhân viên của bạn**.

---

## Bảng số phải nhớ

| Thứ | Con số | Ghi chú |
|---|---|---|
| Managed policy / role | **20**, nâng lên 25 | tài liệu cũ ghi 10 — sai |
| Managed policy / user, / group | 10 → 20, và 10 cố định | |
| MFA cho root | **bắt buộc, mọi loại account** | hạn **35 ngày** |
| `AssumeRole` | 15 phút – 12 giờ, mặc định **1 giờ** | chaining: **trần 1 giờ** |
| `GetSessionToken` | 15 phút – **36 giờ** | root: tối đa 1 giờ |
| KMS mã hoá trực tiếp | **4 KB** | lớn hơn → envelope encryption |
| KMS customer managed key | **$1/tháng** + $0,03 / 10.000 request | |
| KMS rotation tự động | **90 – 2.560 ngày**, mặc định **365** | on-demand tối đa **10 lần** |
| KMS chờ xoá khoá | **7 – 30 ngày**, mặc định 30 | vô hiệu **ngay** khi lên lịch |
| Secrets Manager | **$0,40/secret/tháng**, **64 KB** | + $0,05 / 10.000 lời gọi |
| Parameter Store Standard | **miễn phí**, **4 KB**, **10.000** | 40 TPS dùng chung `Get*` |
| Parameter Store Advanced | $0,05/param/tháng, **8 KB**, 100.000 | một chiều |
| ACM cho CloudFront | phải ở **us-east-1** | |
| Shield Advanced | **$3.000/tháng/tổ chức**, cam kết 1 năm | + data transfer |
| WAF | $5/ACL + $1/rule + $0,60/triệu request | 1.500 WCU / web ACL |

---

## Bẫy đề thi

**1. "Role cần 12 managed policy — có vượt giới hạn 10 không?"**
Sai hấp dẫn: "vượt, phải gộp lại". Đúng: **không** — trần mặc định cho role là **20**,
nâng lên 25, duyệt tự động trong vài phút. Con số 10 chỉ còn đúng cho **user** và
**group**. Gần như mọi tài liệu ôn (và một trang docs của Identity Center tính đến
2026-08) vẫn chép con số cũ.

**2. "MFA cho root là khuyến nghị thôi."** Đúng: **bắt buộc trên mọi loại account** —
standalone, management, member — và phải đăng ký **trong 35 ngày** kể từ lần đăng nhập
console đầu tiên; sau hạn đó AWS chặn đăng nhập root cho tới khi bật MFA. Lựa chọn thay
thế đúng chuẩn cho account con là **xoá hẳn credential root** bằng centralized root
access của Organizations.

**3. "Gắn permission boundary là an toàn tuyệt đối."**
Đúng: nếu resource-based policy nêu **ARN của IAM user hoặc role session**
(`arn:aws:sts::...:assumed-role/R/s`) ở `Principal`, request **đi tắt qua implicit
deny của boundary**. Chỉ khi nêu **ARN của role** thì boundary mới bắt buộc Allow.
**Deny tường minh trong boundary vẫn chặn cả hai.** Vì sao: nêu đích danh một cá
thể được coi là chủ resource cấp quyền trực tiếp; nêu ARN role là cấp cho *lớp*
danh tính, mà lớp thì bị trần của role bó. Hệ quả: ai viết được bucket policy thì
phá được boundary — phải chặn quyền đó bằng SCP.

**4. "SCP `Allow *` nghĩa là account có toàn quyền."** Đúng: SCP **không bao giờ cấp
quyền**; `Allow *` chỉ nghĩa "cửa SCP không chặn". Cùng logic cho boundary và RCP.

**5. "Đã có `AdministratorAccess` mà vẫn AccessDenied."** Đúng: `Allow` không bao giờ
thắng `Deny`. Đi tìm Deny theo thứ tự SCP → boundary → resource policy → session policy.
Policy Simulator phân biệt `implicitDeny` (thiếu Allow) với `explicitDeny` (có người
cấm) — cách nhanh nhất để biết mình đang tìm gì.

**6. "Bật rotation cho CMK là dữ liệu cũ được khoá mới bảo vệ."** Đúng: rotation **chỉ
tạo material mới cho thao tác mã hoá từ đó trở đi**; dữ liệu cũ **không** được mã hoá
lại, material cũ giữ vĩnh viễn, key ID/ARN/alias/policy/grant không đổi. Muốn đổi thật
thì phải gọi `ReEncrypt`.

**7. "Identity policy ghi `kms:*` là dùng được khoá."** Đúng: KMS **luôn cần key
policy**; thiếu statement delegate cho IAM (`Principal: ...:root` + `kms:*`) thì identity
policy vô hiệu — cũng là cách người ta tự khoá mình ra khỏi khoá của chính mình.

**8. "Chia AWS managed key `aws/s3` cho account đối tác."** Đúng: AWS managed key
**không sửa được key policy** nên **không cross-account được**; mọi kịch bản chia sẻ đòi
**customer managed key**.

**9.** "Gắn WAF vào NLB để chặn SQL injection" — WAF ở **L7**, NLB ở **L4**, không gắn
được; phải đặt CloudFront hoặc ALB trước. **10.** "Certificate không hiện trong
CloudFront" — nguyên nhân thường gặp hơn "chờ validate" là cert không nằm ở
**us-east-1**. **11.** "Nhân viên đăng nhập nhiều AWS account → Cognito" — sai, đáp án
là **IAM Identity Center**; Cognito dành cho người dùng cuối của ứng dụng.

**12. "Inspector v2 agentless nên không cần cài gì."**
Đúng: quét EC2 mặc định dựa trên **SSM Agent** — đó *là* một agent, dù AMI của AWS
có sẵn. "Agentless" là **chế độ riêng** quét snapshot EBS. ECR và Lambda thì thật
sự không cần agent.

---

## Cây quyết định

**Cấp quyền cho thứ gọi API AWS.** Dịch vụ AWS → IAM **role** + instance profile / task
role, không bao giờ access key. Người, nhiều account → **IAM Identity Center**. Hệ thống
ngoài AWS (GitHub Actions, cluster on-prem) → **OIDC federation** vào role. Bên thứ ba
(SaaS) → cross-account role + **External ID**.

**Giới hạn quyền.** Cả account/OU → **SCP**. Phía resource, chặn cả kẻ ngoài org →
**RCP**. Một role/user, chống leo thang → **permission boundary**. Một phiên →
**session policy**.

**Mã hoá at rest.** Không yêu cầu gì đặc biệt → **AWS managed key** (miễn phí). Cần
audit / rotation theo ý mình / cross-account / tự xoá → **customer managed key**.
Ciphertext dùng chung nhiều region → **multi-Region key**. AWS tuyệt đối không được chạm
khoá, cần xuất khoá, hoặc cần PKCS#11 → **CloudHSM**; muốn cả hai → **custom key store**
(mất rotation tự động).

**Lưu bí mật.** Mật khẩu DB + rotation tự động, hoặc cross-account, hoặc đa region →
**Secrets Manager**. Config app, muốn miễn phí → **Parameter Store Standard**. Cần > 4 KB
hoặc policy hết hạn → **Advanced**.

**Chống tấn công web.** SQLi/XSS/geo-block/rate limit → **WAF**. DDoS L3/L4 không tốn
thêm → **Shield Standard** + CloudFront. Cần SRT và hoàn tiền chi phí tấn công →
**Shield Advanced**. Áp chính sách cho cả org → **Firewall Manager**.

**Biết mình có bị gì không.** "Ai đã làm gì" → CloudTrail. "Ai đang tấn công" →
**GuardDuty**. "Có CVE nào" → **Inspector**. "Có PII trong S3" → **Macie**. "Chuyện gì
dẫn tới finding này" → **Detective**. "Tổng quan tuân thủ" → **Security Hub**. "Resource
nào mở ra ngoài / quyền nào chưa dùng" → **IAM Access Analyzer**.

---

## Nối với thực hành

| Lab | Chạm vào mục nào |
|---|---|
| [`labs/w01-iam-foundations/`](../../learn-aws/labs/w01-iam-foundations/) | Mục 1–4: user, role, instance profile, bucket policy, IAM Access Analyzer. Sau khi `verify.sh` xanh, xoá statement `Principal: root` trong một policy để thấy implicit deny bằng mắt. |
| [`labs-self/w01-iam-foundations/`](../../learn-aws/labs-self/w01-iam-foundations/) | Bản tự viết. Chính hàng rào an toàn của bộ lab-self là một permission boundary — dựng nó là học mục 5. |
| [`labs/w09-security-deep/`](../../learn-aws/labs/w09-security-deep/) | Mục 8, 9, 12: GuardDuty detector, Parameter Store `SecureString`, S3 public access block. Chạy `aws kms describe-key --key-id alias/aws/ssm` để thấy key policy của AWS managed key không sửa được. |
| [`labs-self/w09-security-deep/`](../../learn-aws/labs-self/w09-security-deep/) | Bản tự viết. Tự tạo customer managed key rồi so quyền và chi phí với AWS managed key. |
| [`labs/w06-serverless-api/`](../../learn-aws/labs/w06-serverless-api/) | Mục 3, 4: Lambda execution role và `aws_lambda_permission` (resource-based policy) là hai hướng của cùng một câu hỏi. |
| [`labs-self/w06-serverless-api/`](../../learn-aws/labs-self/w06-serverless-api/) | Bản tự viết. |

Bài tập đáng làm nhất sau file này: trong lab w01, gắn permission boundary vào một role
rồi thử hai bucket policy — một nêu ARN role, một nêu ARN role session — và quan sát bẫy
số 3 xảy ra thật.

---

## Nguồn nói khác

Chỗ `aws-saa-c03/05-security-services.md` và `aws-saa-c03/B-bao-mat-compliance.md`
sai, cũ hoặc thiếu (kiểm chứng ngày 2026-08-21):

| Nguồn nói | Thực tế | Docs |
|---|---|---|
| Trần managed policy mỗi role là 10 (ngầm định khắp tài liệu ôn; trang IAM Identity Center vẫn ghi vậy) | **20 mặc định, nâng lên 25**, duyệt tự động. User 10 → 20, group 10 cố định. | [IAM and AWS STS quotas](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html) |
| "Root account: enable MFA (**recommended**)" | **Bắt buộc mọi loại account**, hạn **35 ngày** từ lần đăng nhập console đầu tiên. | [MFA for root user](https://docs.aws.amazon.com/IAM/latest/UserGuide/enable-mfa-for-root.html) · [thông báo 06/2025](https://aws.amazon.com/about-aws/whats-new/2025/06/aws-iam-mfa-root-users-across-all-account-types/) |
| "KMS Automatic Rotation: Every year (365 days)" | Chu kỳ **cấu hình 90–2.560 ngày**, mặc định 365; thêm **on-demand rotation** (≤10 lần/khoá); giá rotation **có trần ở lần thứ hai**. | [Automatic key rotation](https://docs.aws.amazon.com/kms/latest/developerguide/rotating-keys-enable.html) |
| "Rotation: **Only for Customer Managed Keys**" | AWS managed key **cũng rotate**, hằng năm và bắt buộc. Đúng hơn: chỉ CMK mới *cấu hình được* rotation. | như trên |
| "ACM: **Cannot export** public certificates" | Từ **06/2025** có exportable public certificate: $15/FQDN, $149/wildcard, **395 ngày**, phải bật cờ export **ngay lúc yêu cầu**. | [ACM exportable certificates](https://aws.amazon.com/blogs/aws/aws-certificate-manager-introduces-exportable-public-ssl-tls-certificates-to-use-anywhere/) |
| "Inspector v2: **Agentless**, no agent needed (**uses SSM**)" | Mâu thuẫn nội tại — SSM Agent *là* agent. Quét EC2 mặc định dùng SSM Agent; "agentless" là chế độ riêng quét snapshot EBS. | [Inspector scanning](https://docs.aws.amazon.com/inspector/latest/user/scanning-resources.html) |
| Bảng "Secrets Manager vs Parameter Store" chỉ 4 dòng, thiếu kích thước và giá API | Kích thước là tiêu chí quyết định thật (64 / 4 / 8 KB); Advanced tính **$0,05 mỗi tham số mỗi tháng** chứ không phải phí cố định; Standard giới hạn **40 TPS** dùng chung — chỗ này làm sập ứng dụng ở quy mô lớn. | [SSM quotas](https://docs.aws.amazon.com/general/latest/gr/ssm.html) · [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) |
| "User Pools = Authentication, Identity Pools = **Authorization**" | Identity pool **đổi token lấy credential AWS tạm** qua STS; phân quyền vẫn do IAM role làm. Gọi là "authorization" khiến người học tưởng nó thay IAM policy. | [Cognito identity pools](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-identity.html) |
| "Shield Advanced: $3,000/month" | Đúng nhưng thiếu ba chi tiết ra thi: tính cho **cả tổ chức**, **cam kết 1 năm**, **cộng phí data transfer**; đổi lại WAF miễn phí trên resource được bảo vệ. | [Shield pricing](https://aws.amazon.com/shield/pricing/) |

---

## Ngoài phạm vi

- **AWS Network Firewall** — firewall stateful cấp VPC, luật Suricata.
  [docs](https://docs.aws.amazon.com/network-firewall/)
- **AWS Directory Service** — nhận diện thôi: lift-and-shift Windows → Managed Microsoft
  AD; proxy về AD on-prem, không cache → AD Connector.
  [docs](https://docs.aws.amazon.com/directoryservice/)
- **Verified Access / Verified Permissions / Cedar**, **IAM Roles Anywhere**,
  **AWS Signer**, **Nitro Enclaves**, **Payment Cryptography** — mức Specialty.
  [docs](https://docs.aws.amazon.com/verified-access/)
- **AWS Artifact** — nơi tải báo cáo SOC/ISO/PCI. "Khách hàng đòi báo cáo tuân thủ" →
  Artifact.

---

## Tự kiểm tra

**1.** Một role có `AdministratorAccess`. Bucket policy của `X` không nhắc gì tới
role đó. SCP của OU chỉ `Allow` các action `ec2:*`. Role gọi `s3:GetObject` trên
`X`. Kết quả và vì sao?

<details><summary>Đáp án</summary>

**Deny.** SCP không `Allow` cho `s3:*` → implicit deny ở cửa SCP, request dừng ngay,
không cần xét identity policy. Điểm phải nói được: SCP không cấp quyền nhưng **thiếu
Allow trong SCP là đủ để chặn**; Simulator hiện `implicitDeny`.

</details>

**2.** Cùng account. Bucket policy của `Y` có
`"Principal": {"AWS": "arn:aws:iam::111122223333:role/AppRole"}` với
`Allow s3:GetObject`. `AppRole` không có identity policy nào cho S3, và có
permission boundary chỉ cho `dynamodb:*`. Kết quả?

<details><summary>Đáp án</summary>

**Deny.** Resource policy nêu **ARN của role**, nên boundary **vẫn phải Allow
tường minh** — mà nó chỉ cho `dynamodb:*`. Nếu đổi thành
`arn:aws:sts::111122223333:assumed-role/AppRole/<session>` thì kết quả là
**Allow**: nêu đích danh role session đi tắt qua implicit deny của boundary. Nếu
boundary có `Deny s3:*` tường minh thì cả hai đều Deny.

</details>

**3.** Bạn bật rotation cho CMK chu kỳ 90 ngày. Sáu tháng sau attacker lấy được
key material **phiên bản đầu tiên**. Họ giải mã được những gì?

<details><summary>Đáp án</summary>

**Toàn bộ ciphertext tạo trong 90 ngày đầu** — và chỉ chừng đó. Rotation tạo material
mới cho thao tác mã hoá *từ đó trở đi*; dữ liệu cũ không được mã hoá lại nên vẫn nằm
dưới material cũ. Kết luận: rotation KMS **không phải biện pháp phục hồi sau lộ khoá**,
nó chỉ giới hạn bán kính nổ theo thời gian; muốn dữ liệu cũ an toàn phải `ReEncrypt`.

</details>

**4.** 200 dự án, mỗi nhóm dev chỉ thao tác EC2 của dự án mình, yêu cầu ít công
quản trị nhất. Thiết kế, và hai biện pháp bảo vệ bắt buộc kèm theo?

<details><summary>Đáp án</summary>

**ABAC**: một policy so `aws:ResourceTag/du-an` với `${aws:PrincipalTag/du-an}`.
Thêm dự án = gắn tag, không đụng IAM.

Hai biện pháp bắt buộc: (1) **cấm tự sửa tag của mình** — `Deny iam:TagRole` /
`iam:UntagRole` / `iam:TagUser` trên chính principal, nếu không ai cũng tự gắn tag
dự án khác; (2) **bắt buộc tag lúc tạo resource** — `aws:RequestTag/du-an` +
`aws:TagKeys` với `ForAllValues:StringEquals`, kèm `Null` check vì `ForAllValues`
trả true khi key vắng mặt hoàn toàn. Principal từ IdP ngoài thì tag đó là
**session tag** đẩy qua SAML.

</details>

**5.** Bạn thuê SaaS giám sát chi phí và tạo role cho họ assume. Mô tả tấn công
confused deputy ở đây và cơ chế External ID dùng để chặn.

<details><summary>Đáp án</summary>

SaaS phục vụ hàng nghìn khách bằng **cùng một account AWS**, trust policy của bạn tin
`Principal = account SaaS`. Khách hàng khác biết ARN role của bạn chỉ cần bảo SaaS "hãy
đọc role này" — SaaS dùng credential *của chính nó*, trust policy gật đầu vì đúng
account. Bên đáng tin bị lừa dùng quyền của mình cho bên không đáng tin.

**External ID**: chuỗi bí mật SaaS sinh riêng cho từng khách, đưa vào
`Condition: StringEquals sts:ExternalId`; khách khác không biết chuỗi của bạn nên không
sai khiến được. Bản tương đương cho dịch vụ AWS gọi thay bạn là `aws:SourceAccount` /
`aws:SourceArn`.

</details>

**6.** "App mobile cho mỗi người dùng upload ảnh lên S3 vào thư mục riêng, không
qua backend." Chọn gì, cơ chế phân tách nằm ở đâu?

<details><summary>Đáp án</summary>

**User pool để đăng nhập + identity pool để đổi lấy credential AWS tạm.** Phân
tách nằm ở **policy variable trong IAM role** của identity pool:
`arn:aws:s3:::bucket/${cognito-identity.amazonaws.com:sub}/*` — một policy phục vụ
mọi người dùng, STS thay biến bằng identity ID thật lúc đánh giá.

Sai thường gặp: chọn user pool rồi dừng — JWT của user pool **không phải**
credential AWS, S3 không hiểu nó.

</details>
