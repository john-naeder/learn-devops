# Hàng rào an toàn

`Domain 1 · Design Secure Architectures (30% đề)`

Thư mục này dựng ba thứ, **apply một lần duy nhất** bằng profile admin, rồi
không đụng vào nữa trong suốt 12 tuần:

| | Là gì | Chặn được gì |
|---|---|---|
| `aws_iam_policy.lab_boundary` | permission boundary | AWS **từ chối API call** vượt rào, ngay tại tầng dịch vụ |
| `aws_iam_role.lab_builder` | role bạn assume mỗi buổi lab | admin trên giấy tờ, bị boundary bóp lại |
| `aws_budgets_budget.lab` | ngân sách $5/tháng | bắt cái boundary bỏ lọt, muộn hơn nhưng bắt được |

Đọc hết file này trước khi apply. Nó dài, nhưng nó vừa là hàng rào vừa là bài
học tuần 9 — và tuần 9 là miền nặng nhất của đề thi.

---

## 1. Permission boundary là gì

Một permission boundary là **trần quyền**, không phải quyền.

Đây là câu dễ hiểu sai nhất trong cả Domain 1, nên nói lại bằng công thức:

```
quyền hiệu dụng  =  identity policy   ∩   permission boundary
                    (cái được cấp)        (cái tối đa được phép)
```

Hệ quả của phép giao:

- Gắn boundary vào một role **không có** identity policy nào → role đó **không
  làm được gì cả**. Boundary một mình không cấp quyền.
- Gắn `AdministratorAccess` vào role rồi thêm boundary chặn `ec2:RunInstances`
  → role đó **không launch được EC2**, dù nó là admin.

Role `lab-builder` chính là trường hợp thứ hai: identity policy là
`AdministratorAccess` (mở toang), boundary là file `main.tf` trong thư mục này
(bóp lại). Bỏ `AdministratorAccess` đi thì role thành vô dụng — thử tưởng
tượng điều đó trước khi đọc tiếp, đề thi rất thích hỏi kiểu này.

### Khác gì identity policy

| | Identity policy | Permission boundary |
|---|---|---|
| Trả lời câu hỏi | "Danh tính này **được** làm gì?" | "Danh tính này **tối đa** được làm gì?" |
| Một mình có cấp quyền không | **Có** | **Không** |
| Gắn vào | user, group, role | user, role (**không** gắn được vào group) |
| Ai thường viết | đội ứng dụng | đội bảo mật / nền tảng |
| Trong repo này | `AdministratorAccess` | `labs-self-boundary` |

### Khác gì SCP

Service Control Policy là hàng rào của **AWS Organizations**, áp lên cả một
account hoặc cả một OU.

| | Permission boundary | SCP |
|---|---|---|
| Phạm vi | **một** user hoặc **một** role | **toàn bộ** account / OU |
| Cần Organizations không | Không | **Có** |
| Áp lên root account không | Không áp được | **Có** — SCP chặn được cả root |
| Ai gắn | ai có quyền IAM trong account | quản trị viên tổ chức, từ management account |
| Một mình có cấp quyền không | Không | Không |

Cả hai đều là **trần**, không phải nguồn quyền. Khác nhau ở phạm vi và ở việc
SCP đứng cao hơn — nó chặn được cả root, còn boundary thì không.

> **Vì sao repo này dùng boundary chứ không dùng SCP:** SCP đòi hỏi
> AWS Organizations, mà account học tập thường là account đơn lẻ. Boundary
> làm được 90% việc mà không cần dựng tổ chức. Cái 10% còn lại là chỗ đau:
> **boundary không chặn được root**. Xem mục 7.

### Thứ tự đánh giá quyền — có thêm boundary

Nhớ sơ đồ này, đề thi hỏi liên tục:

```
1. Có explicit DENY ở BẤT KỲ đâu?            -> TỪ CHỐI. Dừng. Không gì cứu được.
2. SCP có cho phép không?                     -> Không thì từ chối.
3. Permission boundary có cho phép không?     -> Không thì từ chối.   <-- tầng này
4. Có explicit ALLOW ở identity policy
   hoặc resource policy?                      -> Có thì cho phép.
5. Còn lại                                    -> TỪ CHỐI (implicit deny).
```

Bước 3 chính là thứ bạn sắp dựng. Khi làm bài mà gặp `AccessDenied` khó hiểu,
chạy ngược sơ đồ này từ trên xuống.

---

## 2. Boundary này chặn cụ thể những gì

Cách viết: một `Allow *` mở toang, rồi một chuỗi `Deny` bóp lại. Trong IAM,
**explicit Deny thắng mọi Allow**, kể cả `AdministratorAccess`, nên thứ tự các
statement không quan trọng — chỉ nội dung mới quan trọng.

Chọn kiểu "Allow rộng rồi Deny hẹp" thay vì liệt kê Allow là **cố ý**: 12 lab
đụng vào hàng chục dịch vụ, liệt kê Allow sẽ chặn nhầm liên tục và bạn sẽ mất
buổi lab để gỡ hàng rào thay vì học kiến trúc.

| Sid | Chặn gì | Vì sao |
|---|---|---|
| `DenyOutsideAllowedRegions` | mọi API ngoài `us-east-1` (trừ dịch vụ global) | tài nguyên bỏ quên ở region không bao giờ mở lại là cách đốt credit phổ biến nhất |
| `DenyExpensiveInstanceTypes` | `ec2:RunInstances` với type ngoài `t2.micro`, `t3.micro`, `t3.small`, `t4g.micro`, `t4g.small` | gõ nhầm `m5.24xlarge` là $6/giờ |
| `DenyExpensiveDbClass` | RDS ngoài `db.t3.micro`, `db.t4g.micro`; và **mọi** `CreateDBCluster` | Aurora không có instance nhỏ rẻ; xem mục 6 |
| `DenyRdsMultiAz` | RDS Multi-AZ | nhân đôi hoá đơn, không dạy thêm gì so với một sơ đồ |
| `DenyRunawayAutoScaling` | ASG có `MaxSize` > 4 | tuần 3 dùng max 3; số lượng là thứ duy nhất chặn được ở đây (mục 7) |
| `DenyMoneyBurners` | NAT Gateway, Elastic IP, Transit Gateway, Client VPN, Site-to-Site VPN, Direct Connect, Global Accelerator, EKS, Redshift, EMR, SageMaker, OpenSearch, MSK, Amazon MQ, FSx, Transfer Family, Storage Gateway, Network Firewall, WAF WebACL, Macie, Detective, WorkSpaces, MWAA, Shield Advanced, Dedicated Host, Spot Fleet, Capacity Reservation, mua Reserved Instance / Savings Plan, đăng ký domain, Kinesis provisioned shard, ElastiCache, Lambda provisioned concurrency | xem bảng bẫy tiền trong [`aws-saa-plan.md`](../../aws-saa-plan.md#2-bảng-bẫy-tiền) — mỗi dòng trong `main.tf` có ghi giá |

### Bốn statement tự bảo vệ

Một hàng rào mà người bị nhốt tự tháo được thì không phải hàng rào, chỉ là một
lời nhắc. Bốn đường thoát bị bịt:

| Đường thoát | Statement | Cách bịt |
|---|---|---|
| Sửa nội dung chính policy boundary | `ProtectBoundaryItself` | Deny `CreatePolicyVersion` / `SetDefaultPolicyVersion` / `DeletePolicy` **trên đúng ARN của nó** |
| Xoá role hoặc sửa trust policy của nó | `ProtectBuilderRole` | Deny các action IAM ghi trên ARN role `lab-builder` |
| Gỡ boundary khỏi role/user | `DenyRemovingAnyBoundary` | Deny `iam:DeleteRolePermissionsBoundary`, `iam:DeleteUserPermissionsBoundary` |
| Tạo danh tính MỚI không boundary rồi assume sang | `DenyPrincipalWithoutBoundary` | Deny `iam:CreateUser` / `iam:CreateRole` khi khoá điều kiện `iam:PermissionsBoundary` khác ARN này |
| Cướp credential của một danh tính SẴN CÓ | `DenyCredentialEscalation` | Deny `iam:UpdateAssumeRolePolicy`, `iam:AttachUserPolicy`, `iam:PutUserPolicy`, `iam:AddUserToGroup` bằng `NotResource` — chỉ được đụng vào `self-w*` |
| Đúc access key / mật khẩu console | `DenyLongLivedCredentials` | Deny `iam:CreateAccessKey`, `iam:CreateLoginProfile` (và `Update*`) trên `*` — không có ngoại lệ |
| Đổi luật ở tầng cao hơn, hoặc gỡ ngân sách | `DenyOrgAndAccount`, `DenyBudgetTampering` | Deny `organizations:*`, `account:*`, và các action sửa/xoá budget |

> **Đường thoát thứ ba là cái tinh vi nhất.** Không có nó, role admin bị nhốt
> chỉ cần `iam:CreateRole` một role mới không boundary, gắn `AdministratorAccess`,
> rồi `sts:AssumeRole` sang — và toàn bộ hàng rào bốc hơi trong ba lệnh. Đây
> chính là dạng câu hỏi "privilege escalation" mà đề SAA và mọi bài audit IAM
> thật đều soi.

**Hệ quả bạn gặp ngay:** mỗi `aws_iam_role` bạn viết trong lab **bắt buộc** có
`permissions_boundary`. Thiếu là `AccessDenied`. Đó là hàng rào làm đúng việc,
không phải bug — xem mục 6.

`iam:CreateServiceLinkedRole` **cố ý** không bị chặn: ALB và Auto Scaling cần
service-linked role, và AWS không cho gắn boundary vào loại role đó.

---

## 3. Apply

Làm một lần, bằng profile **admin** (`learn`), trước buổi lab đầu tiên.

```bash
source ../../env.sh                    # PATH + locale
cd _boundary

terraform init
terraform apply -var 'notify_email=ban@example.com'
```

Đọc `terraform plan` trước khi gõ `yes`. Ba resource, không tốn tiền: IAM
policy, IAM role và AWS Budgets đều miễn phí.

Ngay sau khi apply:

1. **Mở hộp thư và xác nhận đăng ký ngân sách** nếu AWS gửi mail. Budget chưa
   xác nhận thì cảnh báo không bao giờ tới, và bạn sẽ tưởng mình có lưới an toàn.
2. Lấy khối cấu hình profile:

```bash
terraform output -raw aws_config_profile
```

3. Dán nguyên khối đó vào cuối `~/.aws/config`:

```ini
[profile lab-builder]
role_arn       = arn:aws:iam::<account-id>:role/lab-builder
source_profile = learn
region         = us-east-1
output         = json
```

`source_profile = learn` nghĩa là: AWS CLI dùng credential của `learn` để gọi
`sts:AssumeRole` lên `lab-builder`, rồi dùng credential tạm thời trả về. Bạn
không cần lưu thêm access key nào — và đó chính là lý do role tốt hơn user.

### Nếu apply bằng SSO / IAM Identity Center

Trust policy mặc định suy ra từ danh tính đang chạy `apply`. Với SSO, ARN thật
nằm dưới đường dẫn `/aws-reserved/sso.amazonaws.com/...` nên phép suy ra sẽ
sai. Khai báo tay:

```bash
terraform apply \
  -var 'notify_email=ban@example.com' \
  -var 'trusted_principal_arns=["arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_Admin_abc"]'
```

---

## 4. Xác nhận đang dùng đúng role

```bash
export AWS_PROFILE=lab-builder
aws sts get-caller-identity
```

Đọc `Arn` trả về:

| ARN trả về | Nghĩa là | Làm gì |
|---|---|---|
| `arn:aws:sts::…:assumed-role/lab-builder/botocore-session-…` | **Đúng** | làm bài |
| `arn:aws:iam::…:user/…` | đang là IAM user, nhiều khả năng là admin | `export AWS_PROFILE=lab-builder` |
| `arn:aws:iam::…:root` | **BÁO ĐỘNG ĐỎ** | dừng lại, đăng xuất root, đọc mục 7 |

Đừng làm bằng mắt. Chạy:

```bash
./guard.sh
```

`guard.sh` kiểm tra sáu thứ và `exit 1` nếu hỏng: danh tính, region, boundary
còn gắn không, ngân sách còn sống không, tài nguyên đang tốn tiền, chi tiêu
tháng này. Trong đó có một **bằng chứng sống** chứ không phải tra sổ sách — nó
gọi thử một API chỉ-đọc ở `us-west-2` và **yêu cầu lệnh đó phải thất bại**.
Nếu lệnh chạy được, hàng rào đang thủng dù mọi dòng khác báo xanh.

Chạy `guard.sh` trước **mỗi** buổi lab. Mười giây.

---

## 5. Đọc lỗi AccessDenied

Bạn sẽ gặp `AccessDenied` thường xuyên. Phân biệt hai loại trước khi sửa code:

**Hàng rào chặn** — thông điệp nhắc tới permissions boundary:

```
User: arn:aws:sts::123:assumed-role/lab-builder/... is not authorized to
perform: ec2:CreateNatGateway ... with an explicit deny in a permissions
boundary policy
```

Từ khoá: `explicit deny in a permissions boundary policy`.
→ **Đừng sửa policy của bạn.** Bài đang đi sai hướng. Có một cách rẻ hơn để
đạt cùng kết quả, và tìm ra cách đó chính là bài học. Ví dụ: cần private
subnet đọc S3 mà bị chặn NAT Gateway → đáp án là **S3 Gateway Endpoint**,
miễn phí, và đó cũng là đáp án của đề thi.

**Bài của bạn sai** — thông điệp nhắc tới policy bạn tự viết, hoặc không nhắc
tới boundary:

```
... is not authorized to perform: s3:GetObject on resource: ...
because no identity-based policy allows the s3:GetObject action
```

Từ khoá: `no identity-based policy allows`.
→ Sửa policy trong `main.tf` của bạn.

Không chắc thì hỏi thẳng AWS:

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$(aws sts get-caller-identity --query Arn --output text)" \
  --action-names ec2:CreateNatGateway \
  --resource-arns '*'
```

Kết quả `explicitDeny` = hàng rào. `implicitDeny` = chưa ai cho phép.

> **Không bao giờ** tắt boundary để làm bài. Nếu một lab thật sự cần thứ
> boundary chặn thì lab đó thiết kế sai — đổi đề bài, không đổi hàng rào.

---

## 6. Xung đột đã biết với 12 lab

Ba chỗ hàng rào cố tình chặn thứ mà một cách giải "tự nhiên" sẽ dùng tới. Đây
là **thiết kế**, không phải sót:

### a. Mọi IAM role bạn tạo phải mang boundary

Tuần 1, 6, 9, 10 đều tạo IAM role (role cho EC2, execution role cho Lambda,
role để `AssumeRole`). `DenyPrincipalWithoutBoundary` từ chối tạo role không
boundary. Trong Terraform:

```hcl
permissions_boundary = "arn:aws:iam::<account-id>:policy/labs-self-boundary"
```

Lấy ARN: `terraform -chdir=../_boundary output -raw lab_boundary_arn`

Đây không phải phiền toái thừa — đó đúng là cách một tổ chức thật uỷ quyền cho
đội ứng dụng tự tạo role mà không sợ leo thang đặc quyền. Bạn đang gõ tay một
mẫu thiết kế có tên trong đề thi.

### b. Tuần 9 không tạo được role với boundary khác

Bài "gắn permission boundary cho một role rồi chứng minh nó chặn cả quyền
admin" sẽ đụng hàng rào nếu bạn định tạo role mang một boundary tự viết.

Hai cách làm bài mà không cần gỡ hàng rào, cả hai đều **dạy nhiều hơn**:

1. **Policy Simulator với boundary giả định** — hoàn toàn chỉ-đọc, không tạo gì:

   ```bash
   aws iam simulate-custom-policy \
     --policy-input-list file://identity.json \
     --permissions-boundary-policy-input-list file://boundary.json \
     --action-names ec2:RunInstances s3:GetObject
   ```

   Bạn thấy được phép giao của hai policy mà không tạo một danh tính nào.

2. **Quan sát trên chính `lab-builder`** — nó đang là `AdministratorAccess` bị
   boundary bóp. Chứng minh bằng `simulate-principal-policy`: `iam:*` cho
   `allowed` nhưng `ec2:CreateNatGateway` cho `explicitDeny`. Đối tượng thí
   nghiệm là chính bạn.

### b'. Tên phải bắt đầu bằng `self-wXX-` khi bạn đụng vào IAM

`DenyCredentialEscalation` dùng `NotResource` theo tiền tố tên — đúng như
`CONVENTIONS.md` đã báo trước ("Boundary có điều kiện dựa trên prefix").

Hệ quả: nếu bạn đặt tên role là `w09-cross-account` thay vì
`self-w09-cross-account`, thì `iam:UpdateAssumeRolePolicy` lên role đó sẽ bị
Deny — và thông điệp lỗi vẫn nói "permissions boundary", nghe như bài đi sai
hướng dù thật ra chỉ là **sai tên**.

Gặp `AccessDenied` nhắc tới boundary khi đang đụng IAM: kiểm tra tên trước khi
kiểm tra kiến trúc.

### c. Không có region thứ hai — nên không có cross-region replication

Kế hoạch gốc cho phép mở region thứ hai ở tuần 4 và 11 để làm CRR.
`CONVENTIONS.md` của `labs-self/` thì cố định **một** region, và
`DenyOutsideAllowedRegions` thực thi đúng luật đó.

Cách xử lý, theo thứ tự ưu tiên:

1. Đề bài dùng **SRR** (same-region replication) — dạy đúng cơ chế
   replication, đúng IAM role, đúng delete-marker, mà không mở region thứ hai.
2. Phần "cross-region" học bằng sơ đồ và bảng RTO/RPO — đó cũng là phần đề thi
   thật sự hỏi.
3. Chỉ khi thật sự cần: admin apply lại với
   `-var 'allowed_regions=["us-east-1","us-west-2"]'`, làm xong **apply lại
   ngay** để đóng region về một. Biến này giới hạn tối đa 2 region, cố ý.

### d. Aurora, DocumentDB, Neptune bị chặn hoàn toàn

`rds:CreateDBCluster` không mang khoá điều kiện `rds:DatabaseClass`. Với toán
tử phủ định `StringNotEquals`, **khoá vắng mặt làm điều kiện đúng**, nên Deny
áp dụng cho mọi request tạo cluster.

Đây là kết quả mong muốn — kế hoạch tuần 5 đã cấm Aurora vì không có instance
nhỏ rẻ — nhưng nó là một **hành vi của IAM đáng nhớ hơn là một mẹo**: toán tử
phủ định cộng khoá vắng mặt bằng Deny. Đề thi có hỏi dạng này.

---

## 7. Boundary KHÔNG bảo vệ được gì

Mục thành thật. Đọc kỹ, vì đây là danh sách những thứ vẫn có thể lấy tiền của
bạn dù mọi dòng trong `guard.sh` đều xanh.

### a. Root account — hàng rào bằng không

Permission boundary **không áp lên root**. SCP thì áp được, nhưng SCP cần
Organizations. Đăng nhập root là mọi thứ trong thư mục này biến mất.

→ Bật MFA cho root, rồi cất root đi. `guard.sh` sẽ hét lên nếu thấy `:root`.

### b. Tiền theo lượng dữ liệu và theo số request

Boundary hoạt động trên **API call**, không trên **byte**. Nó chặn được
"tạo NAT Gateway", nhưng không chặn được:

| Khoản | Ví dụ đau thật |
|---|---|
| Data transfer out | 100 GB ra internet ≈ $9 |
| Data transfer qua AZ | vòng lặp giữa hai AZ chạy cả đêm |
| Request-based | S3 `PUT` × vài triệu, DynamoDB on-demand, API Gateway |
| CloudWatch Logs ingest | một Lambda lỗi lặp vô hạn ăn hết 5 GB free rồi tính $0,50/GB |
| Vòng lặp đệ quy | Lambda ghi S3 → S3 event gọi lại Lambda → lặp mãi |

→ Ngân sách bắt được nhóm này, nhưng chỉ sau vài giờ. Đó là lý do cảnh báo
**FORECASTED** quan trọng hơn cảnh báo ACTUAL. Và đó cũng là lý do mọi log
group phải có `retention_in_days`: `../../scripts/set-log-retention.sh 7`

### c. Thứ đã tạo TRƯỚC khi có boundary

Boundary chặn API call **từ lúc này trở đi**. Cái NAT Gateway bạn bấm tay
trong console tháng trước vẫn đang chạy, vẫn tính tiền, và không statement nào
ở đây động tới nó.

→ Ngay sau khi apply, chạy một lần:

```bash
../../scripts/find-orphans.sh --all      # quét MỌI region, chậm nhưng cần
```

### d. Tài nguyên rẻ chạy quên tắt

Boundary cho phép `t3.micro` vì lab cần nó. `t3.micro` là $0,0104/giờ — rẻ.
Chạy 30 ngày là **$7,5**. Nhân với một ALB quên xoá là **$39**.

→ Không có cơ chế kỹ thuật nào cứu được chỗ này. Chỉ có kỷ luật:
`terraform destroy` sau mỗi buổi. Chưa destroy thì buổi lab chưa xong.

### e. Instance type mà Auto Scaling Group launch

Đây là lỗ hổng tinh vi nhất, và nó đáng để hiểu.

Khi ASG scale out, **không phải bạn** gọi `ec2:RunInstances` — mà là
service-linked role `AWSServiceRoleForAutoScaling` gọi. Role đó thuộc về AWS,
không mang boundary của bạn, nên `DenyExpensiveInstanceTypes` **không chạm tới
nó**. Launch template ghi `m5.24xlarge` thì ASG launch `m5.24xlarge`.

Bài học chung, đáng nhớ hơn cả cái lỗ: **permission boundary chỉ áp lên chính
principal mang nó**. Mọi thứ AWS làm "thay mặt bạn" qua service-linked role
đều nằm ngoài. Điều tương tự đúng với CloudFormation service role, với
CodeBuild role, với Lambda execution role.

→ Chặn được thứ chặn được: `DenyRunawayAutoScaling` giới hạn `MaxSize` ≤ 4,
nên thiệt hại có trần. Phần còn lại do `variable` validation trong Terraform
của chính bạn, và do bạn đọc `terraform plan` trước khi gõ `yes`.

### f. Bản thân AWS Budgets

Ngân sách là **cảnh báo**, không phải cầu dao. AWS không tự tắt tài nguyên khi
vượt trần. Mail báo 100% nghĩa là tiền đã mất rồi.

---

## 8. Gỡ bỏ hoàn toàn

Khi học xong 12 tuần, hoặc khi muốn dựng lại từ đầu.

**Thứ tự quan trọng.** Không gỡ được boundary khi vẫn còn role đang dùng nó,
và không xoá được role khi vẫn còn policy đang gắn.

```bash
# 0. Dọn sạch tài nguyên lab TRƯỚC. Gỡ hàng rào khi còn đồ đang chạy là
#    mất luôn thứ đang canh chúng.
../_lib/cleanup.sh                       # liệt kê
../../scripts/find-orphans.sh --all      # quét mọi region

# 1. Quay về profile admin — lab-builder không tự xoá được chính nó
export AWS_PROFILE=learn

# 2. Terraform gỡ đúng thứ tự phụ thuộc
cd _boundary
terraform destroy

# 3. Xoá profile khỏi ~/.aws/config
#    (mở file, xoá khối [profile lab-builder])
```

Nếu `terraform destroy` báo lỗi vì state đã mất, gỡ tay — vẫn theo thứ tự đó:

```bash
ACC=$(aws sts get-caller-identity --profile learn --query Account --output text)

aws iam delete-role-permissions-boundary --profile learn --role-name lab-builder
aws iam detach-role-policy --profile learn --role-name lab-builder \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
aws iam delete-role --profile learn --role-name lab-builder
aws iam delete-policy --profile learn \
    --policy-arn "arn:aws:iam::${ACC}:policy/labs-self-boundary"
aws budgets delete-budget --profile learn \
    --account-id "$ACC" --budget-name labs-self-budget
```

Lưu ý ba điều:

- Mọi lệnh trên đều **phải** chạy bằng profile `learn`. Boundary tự chặn chính
  nó khỏi bị sửa từ `lab-builder` — đó là điểm mạnh của nó, và cũng là lý do
  bạn không thể gỡ nó "từ bên trong".
- `delete-policy` chỉ thành công khi policy không còn gắn vào **bất kỳ** danh
  tính nào, kể cả tư cách boundary. Kiểm tra:
  `aws iam list-entities-for-policy --policy-arn ...`
- Nếu bạn đã tạo IAM role trong các lab với boundary này, gỡ boundary khỏi
  chúng trước, hoặc xoá chúng đi.

Kiểm tra đã sạch:

```bash
aws iam get-role --profile learn --role-name lab-builder          # phải: NoSuchEntity
aws iam list-policies --profile learn --scope Local \
    --query 'Policies[?PolicyName==`labs-self-boundary`]'          # phải: []
```

---

## Đọc thêm

- [`../CONVENTIONS.md`](../CONVENTIONS.md) — luật của bộ lab tự viết
- [`../../aws-saa-plan.md#2-bảng-bẫy-tiền`](../../aws-saa-plan.md) — giá từng dịch vụ
- [`../../../docs/notebook/05-security.md`](../../../docs/notebook/05-security.md) — sổ tay IAM
- [`../../../docs/aws/w09-security-deep.md`](../../../docs/aws/w09-security-deep.md) — lý thuyết tuần 9
