# Tuần 9 — Bảo mật chuyên sâu

> Tuần này trả lời một câu hỏi duy nhất, hỏi đi hỏi lại dưới 30% số câu của đề:
> **ai được chạm vào cái gì, dữ liệu được khoá bằng khoá của ai, và bạn biết được
> điều đó bằng cách nào.** Tuần 1 dạy bạn *quyền*. Tuần này dạy bạn *khoá*,
> *bí mật*, *lớp phòng thủ* và *bằng chứng*.

---

## Học xong bài này bạn phải trả lời được

1. Envelope encryption là gì, vì sao KMS bắt buộc phải dùng nó, và điều gì xảy ra
   với dữ liệu khi bạn xoá CMK?
2. Key policy và IAM policy — cái nào là điều kiện cần, cái nào là điều kiện đủ để
   một principal dùng được một KMS key?
3. Khi nào Secrets Manager đáng giá $0,40/tháng, khi nào Parameter Store là câu trả
   lời đúng của đề thi?
4. GuardDuty, Inspector, Macie, Detective, Config, Security Hub — mỗi cái phát hiện
   *loại* vấn đề nào? (Đây là bẫy chọn sai công cụ, ra thi rất nhiều.)
5. Config, CloudTrail và Security Hub khác nhau ở câu hỏi mà chúng trả lời như thế nào?
6. SCP chen vào đâu trong chuỗi đánh giá quyền, và vì sao nó không bao giờ *cấp* quyền?
7. Một request từ internet đi vào EC2 trong private subnet phải qua bao nhiêu lớp
   kiểm soát, theo thứ tự nào?
8. Dịch vụ nào mã hoá at-rest **mặc định**, dịch vụ nào bạn phải bật lúc tạo và
   **không sửa được về sau**?

---

## Bản đồ khái niệm

```
                    ┌──────────────── QUẢN TRỊ (ai được phép tồn tại) ─────────────┐
                    │  Organizations → OU → SCP        Control Tower               │
                    └───────────────────────────┬─────────────────────────────────┘
                                                │ giới hạn trần
                    ┌───────────────────────────▼─────────────────────────────────┐
   DANH TÍNH        │  IAM user/role/policy · permission boundary · STS AssumeRole │
                    └───────────────────────────┬─────────────────────────────────┘
                                                │ ai gọi được API nào
   ────────────────────────────────────────────┼──────────────────────────────────
                                                │
   BÍ MẬT & KHOÁ    ┌────────────────┐   ┌──────▼───────┐   ┌──────────────────┐
                    │ Secrets Manager│   │     KMS      │   │    CloudHSM      │
                    │ Parameter Store│──▶│ CMK, data key│──▶│ single-tenant HSM│
                    └────────────────┘   └──────┬───────┘   └──────────────────┘
                                                │ envelope encryption
   DỮ LIỆU          S3 · EBS · RDS · DynamoDB · EFS · SQS · SNS · Lambda env var
                                                │
   ────────────────────────────────────────────┼──────────────────────────────────
                                                │
   MẠNG (xếp lớp)   Route 53 ─▶ Shield ─▶ CloudFront+WAF ─▶ ALB+WAF ─▶ SG ─▶ NACL
                                          Network Firewall / GWLB ở giữa VPC
   ────────────────────────────────────────────┼──────────────────────────────────
                                                │
   PHÁT HIỆN        GuardDuty (mối đe doạ) · Inspector (lỗ hổng) · Macie (dữ liệu nhạy cảm)
   ĐIỀU TRA         Detective (nguyên nhân gốc)
   BẰNG CHỨNG       CloudTrail (ai làm gì) · Config (cấu hình ra sao) · Security Hub (gom lại)
```

Đọc bản đồ này theo chiều dọc: mỗi tầng giả định tầng trên đã đúng. Đó chính là
**defense in depth** — và cũng là lý do đề thi hay hỏi "thêm biện pháp nào nữa",
chứ không hỏi "biện pháp nào là đủ".

---

## 1. KMS — dịch vụ khoá, không phải dịch vụ mã hoá

Sai lầm đầu tiên của người mới: tưởng KMS mã hoá dữ liệu cho mình. Không. KMS
**giữ khoá** và **cho mượn khoá**; việc mã hoá 200 GB dữ liệu do S3, EBS hay code
của bạn làm. Lý do rất vật lý: KMS chỉ nhận tối đa **4 KB** cho một lời gọi
`Encrypt` trực tiếp. Muốn mã hoá nhiều hơn thì phải làm envelope encryption.

### Envelope encryption — giải kỹ vì đề thi hỏi thẳng

```
MÃ HOÁ
  1. Ứng dụng gọi kms:GenerateDataKey(KeyId=CMK)
  2. KMS trả về HAI thứ:
        - plaintext data key   (khoá AES-256 dạng rõ, dùng ngay)
        - encrypted data key   (chính khoá đó, đã mã hoá bằng CMK)
  3. Ứng dụng dùng plaintext data key mã hoá dữ liệu — ngay tại chỗ, không qua mạng
  4. Ứng dụng XOÁ plaintext data key khỏi bộ nhớ
  5. Lưu: [encrypted data key] + [ciphertext] cạnh nhau

GIẢI MÃ
  1. Đọc encrypted data key ra
  2. Gọi kms:Decrypt(encrypted data key)  → KMS trả plaintext data key
  3. Dùng nó giải mã dữ liệu
  4. Xoá plaintext data key
```

Bốn hệ quả cần thuộc, vì mỗi cái là một câu hỏi:

| Hệ quả | Vì sao |
|---|---|
| Dữ liệu lớn bao nhiêu cũng mã hoá được | Chỉ có khoá 32 byte đi qua mạng, không phải dữ liệu |
| Nhanh, không tốn băng thông | Mã hoá xảy ra tại chỗ, KMS chỉ tham gia một lần cho mỗi data key |
| **Xoá CMK = mất dữ liệu vĩnh viễn** | Không giải mã được data key thì không giải mã được dữ liệu |
| Quyền `kms:Decrypt` là quyền đọc dữ liệu | Ai giải mã được data key là đọc được mọi thứ |

Hệ quả thứ ba giải thích vì sao KMS bắt bạn chờ **7–30 ngày** mới thực sự xoá một
key (`ScheduleKeyDeletion`). Không có nút xoá ngay. Đó là chủ ý.

**Encryption context** là map key-value gắn vào lời gọi mã hoá; muốn giải mã phải
đưa lại **đúng y hệt**. Nó không bí mật (hiện trong CloudTrail) nhưng dùng được làm
điều kiện trong key policy — ví dụ "khoá này chỉ giải mã được cho bucket X".

### Ba loại khoá — bảng phải thuộc

| | AWS owned key | AWS managed key | Customer managed key (CMK) |
|---|---|---|---|
| Nằm trong account bạn? | **Không** | Có, tên `aws/<service>` | Có, bạn tự đặt tên |
| Thấy trong console? | Không | Có, chỉ đọc | Có, sửa được |
| Key policy | AWS giữ | AWS giữ, bạn **không sửa được** | **Bạn viết** |
| Xoay vòng | AWS quyết định | Tự động, **mỗi 365 ngày**, không tắt được | Bật/tắt được, mặc định **365 ngày**, đặt được 90–2560 ngày |
| Chi phí lưu khoá | Miễn phí | Miễn phí | **~$1/khoá/tháng** + phí API |
| Cross-account | Không | Không | **Có** |
| Audit trong CloudTrail | Không | Có | Có |
| Xoá được | Không | Không | Có (chờ 7–30 ngày) |

Cách đề thi phân biệt: hễ yêu cầu có chữ **"kiểm soát", "audit", "cross-account",
"tự quản lý vòng đời khoá", "import key material"** → CMK. Hễ chỉ nói "mã hoá dữ
liệu" và nhấn mạnh **"chi phí thấp nhất / ít quản lý nhất"** → AWS managed key.

### Key policy vs IAM policy — chỗ dễ sai nhất của KMS

KMS là ngoại lệ trong toàn bộ AWS: **mọi KMS key bắt buộc có một resource policy**
(gọi là key policy), và nó không thể rỗng.

Quy tắc:

> Một principal dùng được KMS key **chỉ khi** key policy cho phép.
> IAM policy một mình **không bao giờ đủ**.

Key policy mặc định chứa một statement kiểu:

```json
{
  "Sid": "Enable IAM User Permissions",
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::111122223333:root" },
  "Action": "kms:*",
  "Resource": "*"
}
```

Câu này nghĩa là: *"uỷ quyền cho hệ thống IAM của account 111122223333 quyết định"*.
Có nó thì IAM policy mới có tác dụng. **Xoá nó đi là bạn tự khoá mình ra khỏi khoá**
— và không có cách nào tự sửa, phải mở ticket với AWS Support. Đây là một trong số
rất ít thao tác trong AWS thực sự không hoàn tác được.

### Grant — quyền tạm thời, hạt mịn

Key policy và IAM policy là quyền tĩnh. **Grant** là quyền động:

- Cấp một tập hành động hẹp (`Encrypt`, `Decrypt`, `GenerateDataKey`) cho một
  principal cụ thể, trong một hoàn cảnh cụ thể.
- Được các dịch vụ AWS dùng nội bộ: khi bạn tạo EBS volume mã hoá, EC2 xin một grant
  để dùng khoá của bạn, thay vì bạn phải sửa key policy.
- **Thu hồi được ngay** (`RetireGrant`, `RevokeGrant`) mà không phải sửa policy.
- Giới hạn được bằng grant constraint theo encryption context.

Nhận diện trong đề: *"cấp quyền tạm thời cho một dịch vụ dùng khoá mà không sửa key
policy"* → grant.

### Multi-Region key

Mặc định **KMS key là tài nguyên của một region**. Ciphertext mã hoá bằng khoá ở
`us-east-1` không giải mã được ở `us-west-2` — kể cả cùng account.

Đó là lý do khi copy một EBS snapshot mã hoá sang region khác, bạn **phải chỉ định
khoá đích**; AWS giải mã rồi mã hoá lại bằng khoá của region kia.

**Multi-Region key** là ngoại lệ có chủ ý: bạn tạo một primary key rồi *replicate*
nó sang region khác. Các bản sao dùng **cùng key material và cùng key ID**
(tiền tố `mrk-`), nên ciphertext tạo ở region này giải mã được ở region kia mà không
cần gọi chéo region.

Dùng khi: DynamoDB Global Tables, client-side encryption cho ứng dụng multi-Region,
DR cần giải mã backup ở region phụ mà không phụ thuộc region chính còn sống.

**Không dùng khi:** chỉ cần mã hoá bình thường. Multi-Region key nới lỏng ranh giới
cách ly của region — mà cách ly region chính là thứ khiến region đáng tin.

### Khi nào cần CloudHSM

| | KMS | CloudHSM |
|---|---|---|
| Mô hình | Multi-tenant, managed | **Single-tenant**, cluster HSM của riêng bạn |
| Chứng nhận FIPS | 140-3 Level 3 | 140-3 Level 3 |
| Ai kiểm soát user của HSM | AWS | **Bạn** — AWS không có quyền truy cập |
| Tích hợp sẵn với dịch vụ AWS | **Có, gần như tất cả** | Không trực tiếp |
| Vận hành | Không có gì để vận hành | Bạn quản cluster, backup, quorum |
| Chi phí | Rất thấp | Tính theo giờ mỗi HSM, đắt hơn nhiều |

Chọn CloudHSM khi và chỉ khi có **yêu cầu pháp lý về HSM đơn thuê bao (single-tenant)
mà bạn phải là người duy nhất giữ quyền**, hoặc cần thư viện PKCS#11/JCE/CNG để
offload SSL, hoặc làm CA riêng. Mọi trường hợp khác: KMS.

Đường lai giữa hai thứ: **KMS custom key store** — KMS làm mặt tiền tích hợp, khoá
thật nằm trong cluster CloudHSM của bạn.

> Ghi chú cập nhật: KMS nay đã được chứng nhận FIPS 140-3 Level 3 tổng thể. Lập luận
> kinh điển "cần Level 3 thì phải dùng CloudHSM" đã yếu đi ngoài đời thật. Trong
> phòng thi, từ khoá quyết định vẫn là **single-tenant / dedicated HSM / bạn kiểm
> soát hoàn toàn key material**.

---

## 2. Bí mật: Secrets Manager vs SSM Parameter Store

Hai dịch vụ này chồng lấn tới 80%. Đề thi ép bạn chọn bằng đúng phần 20% khác nhau.

| | SSM Parameter Store | Secrets Manager |
|---|---|---|
| Chi phí | **Standard: miễn phí.** Advanced: tính phí theo tham số | **$0,40/secret/tháng** + $0,05/10.000 lời gọi API |
| Kích thước giá trị | 4 KB (standard) / 8 KB (advanced) | **64 KB** |
| Số lượng | 10.000 (standard) / 100.000 (advanced) mỗi region | Không giới hạn thực tế |
| **Tự động xoay vòng** | **Không có** | **Có** — Lambda rotation, tích hợp sẵn RDS/Aurora/Redshift/DocumentDB |
| Chia sẻ cross-account | Chỉ tham số Advanced | **Có**, qua resource policy |
| Mã hoá | Tuỳ chọn: `String`, `StringList`, **`SecureString`** (KMS) | **Luôn mã hoá** bằng KMS |
| Phân cấp | Có, dạng đường dẫn `/app/prod/db/pass` | Có, nhưng phẳng hơn |
| Lịch sử phiên bản | Có | Có, kèm nhãn `AWSCURRENT` / `AWSPREVIOUS` |
| Tích hợp CloudFormation | Dynamic reference | Dynamic reference, và **sinh mật khẩu ngẫu nhiên lúc tạo stack** |

**Khác biệt quyết định — thuộc một câu này là đủ:**

> Tự động xoay vòng credential mà không sửa code → **Secrets Manager**.
> Mọi thứ còn lại, đặc biệt khi đề nói "chi phí thấp nhất" → **Parameter Store**.

Hai chi tiết hay bị bỏ qua:

- `AWSPREVIOUS` tồn tại để giải bài toán kinh điển của rotation: giữa lúc đổi mật
  khẩu và lúc mọi client nhận mật khẩu mới có một khoảng thời gian. Rotation của
  Secrets Manager theo chiến lược bốn bước `createSecret → setSecret → testSecret →
  finishSecret`, và với RDS có kiểu **alternating users** (hai user luân phiên) để
  không bao giờ có downtime.
- Parameter Store **đọc được secret của Secrets Manager** qua đường dẫn
  `/aws/reference/secretsmanager/<ten-secret>`. Nghĩa là code chỉ cần biết một API.

**Lỗi vận hành tốn thời gian nhất:** đọc `SecureString` cần **cả** `ssm:GetParameter`
**và** `kms:Decrypt`. Thiếu quyền KMS thì lỗi trả về là `AccessDeniedException` chung
chung, không nói gì tới KMS. Bạn đã gặp đúng lỗi này trong lab tuần 9.

---

## 3. Mã hoá at-rest và in-transit trên các dịch vụ chính

Bảng này ra thi ở dạng "dịch vụ nào có thể/không thể bật mã hoá sau khi đã tạo".

| Dịch vụ | At-rest | Bật sau khi tạo được không? | In-transit |
|---|---|---|---|
| **S3** | SSE-S3 **mặc định bật** cho mọi object mới; chọn thêm SSE-KMS, DSSE-KMS, SSE-C, client-side | Được (đổi bất cứ lúc nào, object cũ giữ nguyên cho tới khi ghi lại) | HTTPS; ép bằng bucket policy điều kiện `aws:SecureTransport = false` → Deny |
| **EBS** | KMS; bật được **"encryption by default"** cho cả region | **Không.** Volume đã tạo thì không mã hoá được. Đường vòng: snapshot → copy snapshot kèm mã hoá → tạo volume mới | Tự động giữa EC2 và volume mã hoá |
| **RDS** | KMS, **chọn lúc tạo instance** | **Không.** Đường vòng: snapshot → copy snapshot kèm mã hoá → restore | TLS, dùng CA bundle của AWS |
| **DynamoDB** | **Luôn mã hoá**, mặc định AWS owned key; đổi sang AWS managed hoặc CMK được | Đổi loại khoá được | HTTPS |
| **EFS** | KMS, **chọn lúc tạo file system** | Không | TLS qua `amazon-efs-utils` với tuỳ chọn `-o tls` |
| **SQS / SNS** | SSE bằng KMS | Bật/tắt được | HTTPS |
| **Lambda** | Biến môi trường mã hoá bằng KMS lúc lưu | Được | HTTPS |
| **CloudWatch Logs** | Mã hoá mặc định; gắn CMK cho log group được | Được | HTTPS |

Hai câu hỏi mẫu bạn sẽ gặp gần như nguyên văn:

- *"Database RDS đang chạy chưa mã hoá, cần mã hoá với downtime tối thiểu"* →
  snapshot, copy snapshot có mã hoá, restore, đổi endpoint. Không có nút bật tại chỗ.
- *"Bắt buộc mọi truy cập vào bucket phải qua HTTPS"* → bucket policy `Deny` khi
  `aws:SecureTransport` là `false`. Không phải Block Public Access, không phải ACL.

---

## 4. ACM — chứng chỉ và cái bẫy region

ACM cấp **chứng chỉ public miễn phí**, tự động gia hạn nếu bạn dùng DNS validation
(thêm một CNAME vào Route 53 rồi quên nó đi).

Ba giới hạn ra thi:

1. **Chứng chỉ ACM phải nằm cùng region với tài nguyên dùng nó.** ALB ở `ap-southeast-1`
   thì cần chứng chỉ ở `ap-southeast-1`.
2. **CloudFront là ngoại lệ: chứng chỉ bắt buộc ở `us-east-1`.** CloudFront là dịch
   vụ global, control plane của nó nằm ở N. Virginia. Cùng lý do với WAF scope
   `CLOUDFRONT` và Route 53. Đây là câu hỏi bẫy kinh điển.
3. **Không lấy được private key của chứng chỉ public ra.** Nên không cài được nó
   lên nginx tự quản trên EC2. Muốn TLS trên EC2 tự quản: mua/xin chứng chỉ ở nơi
   khác, hoặc dùng ACM Private CA (dịch vụ tính phí, tách biệt).

ACM dùng được với: CloudFront, ALB, NLB (TLS listener), API Gateway, App Runner,
Elastic Beanstalk. Không dùng trực tiếp cho EC2.

---

## 5. Tầng biên: WAF, Shield, Network Firewall

### AWS WAF — tường lửa tầng 7

Bốn khái niệm, đúng theo thứ tự lồng nhau:

```
Web ACL  ──gắn vào──▶ CloudFront | ALB | API Gateway (REST) | AppSync | Cognito user pool
   │
   ├── Rule (do bạn viết)          : IP set, geo match, chuỗi/regex, kích thước, SQLi, XSS
   ├── Rule group (tái sử dụng)    : của bạn, AWS Managed Rules, hoặc Marketplace
   └── Rate-based rule             : đếm request theo khoá gộp trong một cửa sổ thời gian
```

- **Action** của mỗi rule: `Allow`, `Block`, `Count`, `CAPTCHA`, `Challenge`.
  `Count` là chế độ chạy thử — bật rule mới ở `Count` trước để xem nó sẽ chặn nhầm
  cái gì, đây là câu trả lời cho *"triển khai rule mới mà không rủi ro"*.
- **AWS Managed Rules**: bộ rule do AWS duy trì (Core rule set, Known bad inputs,
  SQL database, Linux/POSIX, Anonymous IP list, Bot Control, Account Takeover
  Prevention). Nhận diện trong đề: *"bảo vệ khỏi OWASP Top 10 với ít công sức nhất"*
  → managed rule group, không phải tự viết rule.
- **Rate-based rule**: giới hạn từ 10 đến 2.000.000.000 request; cửa sổ đánh giá
  chọn được **60, 120, 300 hoặc 600 giây**, mặc định **300**. Gộp theo IP nguồn,
  theo header, theo cookie, hoặc theo khoá tuỳ chỉnh. Đây là câu trả lời cho
  *"chặn brute force đăng nhập"* và *"một client gọi API quá nhiều"*.
- **WAF không gắn được vào NLB.** NLB làm việc ở tầng 4, nó không nhìn thấy HTTP.
  Muốn WAF trước một dịch vụ sau NLB: đặt CloudFront hoặc ALB vào đường đi.

### Shield Standard vs Shield Advanced

| | Shield Standard | Shield Advanced |
|---|---|---|
| Chi phí | **Miễn phí, tự động, cho mọi khách hàng** | **$3.000/tháng**, cam kết **1 năm**, cộng phí data transfer |
| Chống gì | DDoS phổ biến ở tầng 3/4 (SYN flood, UDP reflection) | Thêm tầng 7, tấn công quy mô lớn, phát hiện theo health check |
| Đội hỗ trợ | Không | **Shield Response Team (SRT)** 24/7 |
| Bảo vệ hoá đơn | Không | **Cost protection** — hoàn credit cho phần scale do bị tấn công |
| WAF | Trả riêng | Bao gồm phí WAF cho tài nguyên được bảo vệ |
| Phạm vi | Mọi tài nguyên AWS | Chỉ định cụ thể: CloudFront, Route 53, Global Accelerator, ALB, EIP |

Nhận diện: đề nhắc **"SLA", "đội ứng cứu", "hoàn tiền khi bị tấn công",
"ứng dụng chịu rủi ro DDoS cao"** → Advanced. Đề chỉ nói "bảo vệ DDoS cơ bản" →
Standard, và câu trả lời đúng thường là *"không cần làm gì, đã có sẵn"*.

### AWS Network Firewall

Tường lửa **stateful ở mức VPC**, dùng cú pháp rule của Suricata. Khác với SG/NACL
ở chỗ nó hiểu giao thức tầng cao: lọc theo domain name (SNI), phát hiện xâm nhập
(IPS), lọc theo chữ ký.

Triển khai: tạo firewall endpoint trong một subnet riêng, rồi **sửa route table** để
lái traffic đi qua nó. Đây là mẫu "inspection subnet". Chi phí theo giờ endpoint +
theo GB xử lý — không rẻ.

Nhận diện: *"lọc theo tên miền", "chặn traffic ra tới domain không cho phép",
"IPS/IDS cho toàn VPC"* → Network Firewall. Nếu đề nhắc **thiết bị của hãng thứ ba**
(Palo Alto, Fortinet) thì đáp án là **Gateway Load Balancer**, không phải Network Firewall.

### Xếp lớp — thứ tự một request đi qua

```
Client
  │
  ├─ Route 53          DNS, health check           (Shield Standard bảo vệ sẵn)
  │
  ├─ CloudFront        edge, TLS terminate         + WAF (scope CLOUDFRONT, cert us-east-1)
  │                                                 + Shield Advanced (tuỳ chọn)
  ├─ ALB               tầng 7, target group        + WAF (scope REGIONAL)
  │
  ├─ Security Group    stateful, chỉ ALLOW         ← gắn vào ENI
  │
  ├─ Network ACL       stateless, có DENY          ← gắn vào subnet
  │
  ├─ Network Firewall  stateful, IPS, lọc domain   ← nằm trên route table
  │
  └─ EC2 / ECS / Lambda
        └─ IAM role của instance quyết định nó gọi được API nào
        └─ KMS quyết định nó đọc được dữ liệu nào
```

**Nguyên tắc defense in depth** rút ra từ hình trên: không lớp nào được giả định là
hoàn hảo. Câu hỏi SAA gần như không bao giờ có đáp án "chỉ cần một biện pháp". Khi
hai đáp án đều đúng về kỹ thuật, đáp án nào **thêm một lớp mà không phá lớp khác**
thường là đáp án được chấm.

Hệ quả thực tế: một EC2 trong private subnet vẫn phải có SG chặt, vẫn phải có IAM
role tối thiểu quyền, vẫn phải mã hoá EBS — dù nó "không ra internet được".

> **AWS Firewall Manager** quản lý tập trung web ACL, SG và rule Network Firewall cho
> cả Organization. Biết nó tồn tại và giải bài toán "áp một chính sách cho mọi account"
> là đủ cho SAA.

---

## 6. Phát hiện và điều tra — bảng phân biệt hay ra bẫy nhất

| Dịch vụ | Trả lời câu hỏi | Nguồn dữ liệu | Từ khoá nhận diện trong đề |
|---|---|---|---|
| **GuardDuty** | *Có ai đang tấn công tôi không?* | CloudTrail, VPC Flow Logs, DNS logs, EKS audit log, RDS login, S3 data event — **không cần agent** | hành vi bất thường, IP độc hại, crypto mining, credential bị lộ, port scan |
| **Inspector** | *Máy của tôi có lỗ hổng không?* | EC2, container image trong ECR, Lambda function/layer | CVE, quét lỗ hổng phần mềm, vá lỗi, network reachability |
| **Macie** | *Dữ liệu nhạy cảm nằm ở đâu trong S3?* | Object trong S3 | PII, số thẻ tín dụng, GDPR, phân loại dữ liệu |
| **Detective** | *Vì sao chuyện này xảy ra?* | Dựng behavior graph từ CloudTrail + Flow Logs + finding của GuardDuty | điều tra, phân tích nguyên nhân gốc, dựng lại dòng thời gian |
| **Security Hub** | *Tình hình an ninh tổng thể ra sao?* | Gom finding từ tất cả các dịch vụ trên, chuẩn hoá về định dạng ASFF | bảng điều khiển chung, CIS Benchmark, AWS FSBP, PCI DSS, điểm tuân thủ |

Ba cặp hay nhầm nhất:

1. **GuardDuty vs Inspector.** GuardDuty phát hiện *hành vi đang diễn ra*. Inspector
   tìm *lỗ hổng đang tồn tại*. Máy chưa bị tấn công vẫn có CVE — đó là việc của Inspector.
2. **GuardDuty vs Detective.** GuardDuty **báo có chuyện**. Detective **điều tra chuyện đó**.
   Detective không sinh finding mới; nó chỉ trả lời "chuỗi sự kiện dẫn tới đây là gì".
3. **Macie vs Config.** Macie nhìn vào **nội dung** của object. Config nhìn vào
   **cấu hình** của tài nguyên. "Bucket có public không" là Config; "trong bucket có
   số CMND không" là Macie.

Cả GuardDuty, Inspector, Macie, Detective và Security Hub đều bật được ở mức
**Organization** với một delegated administrator account. Đó là đáp án cho
*"giám sát tập trung cho hàng trăm account"*.

---

## 7. Bằng chứng và tuân thủ: CloudTrail, Config, Security Hub

Ba dịch vụ này bị nhầm lẫn nhiều nhất vì đều "ghi lại thứ gì đó".

| | CloudTrail | AWS Config | Security Hub |
|---|---|---|---|
| Câu hỏi trả lời | **Ai đã làm gì, lúc nào, từ đâu** | **Tài nguyên đang/đã trông như thế nào, có đúng chuẩn không** | **Tổng hợp mọi finding về một chỗ** |
| Đơn vị dữ liệu | API call (event) | Configuration item (ảnh chụp cấu hình) | Finding (ASFF) |
| Trả lời được "ai xoá cái này" | **Có** | Không (chỉ biết nó biến mất) | Không |
| Trả lời được "bucket này có bao giờ public không" | Khó | **Có** — timeline cấu hình | Không |

### CloudTrail

- **Management event**: thao tác lên control plane (`RunInstances`, `CreateBucket`,
  `AssumeRole`). Ghi mặc định, **miễn phí một bản**.
- **Data event**: thao tác lên dữ liệu (`s3:GetObject`, `lambda:Invoke`,
  `dynamodb:PutItem`). **Không** ghi mặc định, **tính phí theo số event**, khối lượng
  rất lớn. Bật khi cần điều tra ai đọc file nào.
- **Insights event**: CloudTrail tự học nhịp gọi API bình thường của bạn rồi cảnh báo
  khi có đột biến (ví dụ số lời gọi `DeleteBucket` tăng vọt). Tính phí riêng.
- **Event history**: 90 ngày gần nhất, miễn phí, chỉ management event, **theo từng
  region**. Muốn giữ lâu hơn hoặc phân tích thì phải tạo **trail** đẩy vào S3.
- **Trail multi-region**: một trail bắt sự kiện ở *mọi* region. Nên bật — nếu không,
  kẻ tấn công tạo tài nguyên ở region bạn không ngó tới và bạn không có log.
- **Organization trail**: một trail cho toàn bộ Organization, member account không tắt được.
- Gửi song song sang **CloudWatch Logs** để đặt metric filter + alarm (ví dụ cảnh báo
  khi có ai gọi `DeleteTrail` hoặc dùng root account).
- Tính toàn vẹn: bật **log file validation** để có file digest ký số, chứng minh log
  không bị sửa.

Mẫu câu hỏi: *"Có người xoá mất một security group tuần trước, làm sao biết ai làm?"*
→ CloudTrail. Nếu đề nói "hơn 90 ngày trước" thì đáp án phải là trail đã đẩy vào S3,
không phải Event history.

### AWS Config

- **Configuration recorder** ghi lại mọi thay đổi cấu hình thành configuration item,
  đẩy vào một S3 bucket.
- **Config rule** đánh giá cấu hình đó là `COMPLIANT` hay `NON_COMPLIANT`. Có rule
  managed sẵn (hàng trăm cái) và rule tự viết bằng Lambda hoặc Guard. Kích hoạt theo
  **thay đổi cấu hình** hoặc **định kỳ**.
- **Conformance pack**: một gói gồm nhiều rule + hành động remediation, triển khai và
  gỡ như một khối, deploy được cho cả Organization. Đây là đáp án cho *"áp một bộ
  chuẩn tuân thủ lên tất cả account"*.
- **Remediation**: gắn một SSM Automation document vào rule, chạy thủ công hoặc
  **tự động** khi phát hiện vi phạm. Ví dụ: bucket bị bật public → tự bật lại Block
  Public Access.
- **Aggregator**: gom kết quả từ nhiều account và region về một bảng.

**Cảnh báo chi phí:** Config tính tiền theo **số configuration item được ghi** và
**số lần đánh giá rule**. Bật ghi mọi loại tài nguyên trong một account có nhiều thay
đổi là cách đốt tiền âm thầm. Trong lộ trình 12 tuần này, học Config bằng tài liệu.

### Security Hub

Không tự phát hiện gì. Nó **gom** finding từ GuardDuty, Inspector, Macie, Config,
IAM Access Analyzer, Firewall Manager và các sản phẩm bên thứ ba, chuẩn hoá về định
dạng chung (ASFF), rồi chấm điểm theo các **security standard**: AWS Foundational
Security Best Practices, CIS AWS Foundations Benchmark, PCI DSS, NIST.

Nhận diện: *"một bảng điều khiển duy nhất cho tình trạng bảo mật của nhiều account"*
→ Security Hub.

---

## 8. Organizations và SCP — nhắc lại logic đánh giá quyền

Cấu trúc: **management account** → **root** → **OU** (lồng nhau được) → **member account**.

**Service Control Policy** là guardrail gắn vào root, OU hoặc account.

Ba luật của SCP, thuộc lòng:

1. **SCP không bao giờ cấp quyền.** Nó chỉ đặt trần. Một account có SCP `Allow: s3:*`
   mà không có IAM policy nào thì vẫn không làm được gì.
2. **SCP không áp lên management account.** Đây là lý do bạn không đặt workload vào
   management account.
3. **SCP không áp lên service-linked role.**

Chuỗi đánh giá đầy đủ — vẽ lại được từ trí nhớ là ăn nhiều điểm Domain 1:

```
Request tới
   │
   ▼
1. Có EXPLICIT DENY ở BẤT KỲ policy nào?  ──CÓ──▶ TỪ CHỐI. Hết. Không gì cứu được.
   │ không
   ▼
2. SCP của Organizations có cho phép?      ──KHÔNG──▶ TỪ CHỐI
   │ có
   ▼
3. Permission boundary có cho phép?        ──KHÔNG──▶ TỪ CHỐI
   │ có (hoặc không gắn boundary)
   ▼
4. Session policy có cho phép?             ──KHÔNG──▶ TỪ CHỐI
   │ có (hoặc không có session policy)
   ▼
5. Identity policy HOẶC resource policy có ALLOW?  ──CÓ──▶ CHO PHÉP
   │ không
   ▼
   TỪ CHỐI  (implicit deny — mặc định của IAM luôn là từ chối)
```

Đọc theo lối bạn đã quen: bước 1–4 là các bộ lọc **giao nhau** (AND, thu hẹp dần),
bước 5 là bộ **hợp** (OR, nới ra). Ba khái niệm hạn chế — SCP, permission boundary,
session policy — không cái nào cấp quyền; cả ba chỉ cắt bớt.

Hai thứ đi kèm cần biết ở mức nhận diện:

- **AWS Control Tower**: dựng sẵn một landing zone nhiều account theo best practice
  (Organizations + SCP + Config + CloudTrail + IAM Identity Center) bằng vài cú click.
  Nhận diện: *"thiết lập môi trường multi-account tuân thủ, nhanh nhất, ít thao tác nhất"*.
- **IAM Identity Center**: nguồn danh tính tập trung, gán permission set cho user trên
  nhiều account, cấp credential tạm thời. Thay thế cho việc tạo IAM user ở từng account.

---

## Bảng quyết định

| Tình huống trong đề | Chọn | Không chọn — vì sao |
|---|---|---|
| Mã hoá dữ liệu, "chi phí thấp nhất, ít quản lý nhất" | AWS managed key | CMK tốn ~$1/tháng và không cần thiết |
| Cần audit mọi lần dùng khoá, cần cross-account, cần tự đặt lịch xoay vòng | **CMK** | AWS managed key không sửa được key policy |
| Lưu mật khẩu DB, "tự động đổi định kỳ, không sửa code" | **Secrets Manager** | Parameter Store không có rotation |
| Lưu cấu hình hoặc secret, "chi phí thấp nhất" | **Parameter Store SecureString** | Secrets Manager tốn $0,40/secret/tháng |
| Chặn SQL injection cho ứng dụng sau ALB | **WAF + AWS Managed Rules** | Shield không lọc nội dung HTTP |
| Chặn brute force đăng nhập | **WAF rate-based rule** | NACL không đếm được request |
| "Cần SLA và đội ứng cứu DDoS, hoàn tiền chi phí scale" | **Shield Advanced** | Standard không có SRT lẫn cost protection |
| "Chặn EC2 gọi ra domain không nằm trong allowlist" | **Network Firewall** | SG/NACL chỉ biết IP và port |
| "Phát hiện instance đang đào coin" | **GuardDuty** | Inspector chỉ quét lỗ hổng |
| "Tìm CVE trong container image" | **Inspector** | GuardDuty không quét phần mềm |
| "Điều tra chuỗi sự kiện dẫn tới finding" | **Detective** | Security Hub chỉ gom, không dựng graph |
| "Ai đã xoá tài nguyên này tháng trước" | **CloudTrail** | Config biết nó mất, không biết ai làm |
| "Bucket này có từng bị bật public không" | **AWS Config** | CloudTrail có event nhưng phải tự ghép lại |
| "Bắt mọi account tuân thủ CIS Benchmark, báo cáo một chỗ" | **Security Hub** + Config conformance pack | GuardDuty không làm compliance |
| "Cấm mọi account trong OU tắt CloudTrail, kể cả admin" | **SCP với Deny** | IAM policy sửa được bởi chính admin đó |
| "Uỷ quyền cho developer tự tạo role mà không leo thang thành admin" | **Permission boundary** | SCP áp cho cả account, quá rộng |
| Chứng chỉ TLS cho CloudFront | **ACM ở us-east-1** | Chứng chỉ region khác sẽ không chọn được |

---

## Số phải thuộc

| Con số | Nội dung |
|---|---|
| **4 KB** | Giới hạn dữ liệu cho một lời gọi `kms:Encrypt` trực tiếp — lý do tồn tại của envelope encryption |
| **365 ngày** | Chu kỳ xoay vòng mặc định của KMS; AWS managed key cố định 365 ngày, CMK đặt được 90–2560 ngày |
| **7–30 ngày** | Thời gian chờ bắt buộc trước khi KMS thực sự xoá một key |
| **~$1/tháng** | Chi phí lưu một customer managed key *(kiểm tra lại trang pricing trước khi tin)* |
| **$0,40/secret/tháng** | Secrets Manager, cộng $0,05 cho mỗi 10.000 lời gọi API |
| **64 KB** | Kích thước tối đa một secret trong Secrets Manager |
| **4 KB / 8 KB** | Kích thước tối đa tham số Parameter Store: standard / advanced |
| **10.000 / 100.000** | Số tham số tối đa mỗi region: standard / advanced |
| **$3.000/tháng** | Shield Advanced, cam kết **1 năm** *(kiểm tra lại trang pricing)* |
| **60/120/300/600 giây** | Cửa sổ đánh giá của WAF rate-based rule; mặc định 300 |
| **us-east-1** | Region bắt buộc cho chứng chỉ ACM dùng với CloudFront |
| **90 ngày** | CloudTrail Event history giữ management event miễn phí |
| **FIPS 140-3 Level 3** | Mức chứng nhận của cả KMS và CloudHSM |

---

## Bẫy kinh điển

1. **"IAM policy cho phép `kms:Decrypt` là đủ."** Sai. Key policy phải cho phép trước.
   KMS là dịch vụ duy nhất mà resource policy là điều kiện *cần*.
2. **"Xoá CMK rồi vẫn khôi phục dữ liệu được từ backup."** Sai. Backup cũng được mã
   hoá bằng data key, mà data key được khoá bởi CMK đó.
3. **"KMS key dùng được ở mọi region."** Sai. Key là tài nguyên region. Muốn dùng
   xuyên region: multi-Region key, hoặc mã hoá lại lúc copy.
4. **"Parameter Store cũng xoay vòng được."** Không. Nó không có cơ chế rotation.
   Đây là khác biệt quyết định giữa hai dịch vụ.
5. **"Bật mã hoá cho RDS/EBS đang chạy."** Không có nút đó. Phải qua đường snapshot →
   copy có mã hoá → restore.
6. **"Gắn WAF vào NLB."** Không được. NLB ở tầng 4. Phải có CloudFront hoặc ALB.
7. **"Shield Standard phải bật."** Nó đã bật sẵn cho mọi khách hàng, miễn phí. Đáp án
   "không cần làm gì thêm" đôi khi là đáp án đúng.
8. **"GuardDuty cần cài agent."** Không. Nó đọc log có sẵn (CloudTrail, Flow Logs, DNS).
    Cái cần agent là CloudWatch Agent và SSM Agent.
9. **"Chứng chỉ ACM ở region của ALB dùng được cho CloudFront."** Không. CloudFront
    chỉ nhìn thấy chứng chỉ ở `us-east-1`.
10. **"SCP cấp quyền cho account con."** Không bao giờ. SCP chỉ cắt bớt. Quyền vẫn
    phải đến từ identity policy trong chính account đó.
11. **"Config biết ai đã thay đổi."** Config biết *cấu hình đã đổi thế nào*. Muốn biết
    *ai* thì phải xem CloudTrail.
12. **"Security Hub thay thế được GuardDuty."** Không. Security Hub không phát hiện gì
    cả, nó chỉ gom finding từ nơi khác.

---

## Nối với lab

[`labs/w09-security-deep/`](../../learn-aws/labs/w09-security-deep/) chạm vào bốn
khái niệm của bài này bằng cách **cho bạn nhìn thấy chúng chặn**:

| Thí nghiệm trong lab | Khái niệm ở bài này |
|---|---|
| `sts assume-role` thiếu external ID → `AccessDenied` | Trust policy, confused deputy |
| Role có `AdministratorAccess` nhưng boundary chỉ `s3:*`, `logs:*` | Bước 3 của chuỗi đánh giá quyền |
| Role admin không gọi được `cloudtrail:StopLogging` | Bước 1 — explicit deny thắng tất cả |
| Lambda đọc `SecureString` lúc chạy, không nhét vào env var | Parameter Store + `kms:Decrypt` |

Quan sát khi chạy `verify.sh`: ba giá trị `allowed`, `implicitDeny`, `explicitDeny`
mà Policy Simulator trả về ánh xạ **chính xác** vào sơ đồ 5 bước ở mục 8.
`implicitDeny` là rơi xuống đáy sơ đồ; `explicitDeny` là dừng ngay ở bước 1.

Hai việc lab **không** làm được và bạn phải học bằng tài liệu: bật GuardDuty đủ lâu
để thấy finding thật (tốn tiền sau 30 ngày dùng thử), và AWS Config (tính tiền theo
configuration item).

---

## Tự kiểm tra

<details>
<summary>1. Vì sao KMS không mã hoá trực tiếp một file 5 GB, dù về mặt toán học thì AES không quan tâm kích thước?</summary>

Vì `kms:Encrypt` nhận tối đa 4 KB payload, và vì toàn bộ dữ liệu sẽ phải đi qua mạng
tới KMS rồi quay về. Envelope encryption giữ dữ liệu tại chỗ và chỉ chuyển một khoá
32 byte qua mạng. Giới hạn là về kiến trúc dịch vụ và băng thông, không phải về thuật toán.
</details>

<details>
<summary>2. Bạn xoá statement "Enable IAM User Permissions" khỏi key policy của một CMK. Chuyện gì xảy ra và ai sửa được?</summary>

Không principal nào trong account còn dùng được khoá đó, kể cả admin và root, vì IAM
policy chỉ có hiệu lực khi key policy uỷ quyền cho IAM. Bạn cũng không sửa lại được
key policy. Cách duy nhất là mở ticket với AWS Support. Đây là lý do luôn giữ statement
đó và điều chỉnh quyền bằng IAM policy.
</details>

<details>
<summary>3. Đề nói: "lưu API key của một dịch vụ bên thứ ba, ngân sách rất chặt, không cần đổi key". Chọn gì và vì sao không chọn cái kia?</summary>

Parameter Store `SecureString`. Miễn phí ở tier standard, mã hoá bằng KMS, đủ cho
4 KB. Secrets Manager sai vì $0,40/secret/tháng mua một tính năng — rotation — mà đề
đã nói rõ là không cần.
</details>

<details>
<summary>4. Vì sao đặt workload vào management account của Organizations là ý tồi?</summary>

SCP không áp lên management account. Mọi guardrail bạn dựng cho tổ chức đều không bảo
vệ được nó. Một sai sót trong account đó không có lưới an toàn nào đỡ.
</details>

<details>
<summary>5. Bạn copy một EBS snapshot mã hoá từ us-east-1 sang eu-west-1. Khoá nào được dùng ở đích, và làm sao tránh việc mã hoá lại?</summary>

Mặc định AWS giải mã bằng khoá nguồn rồi mã hoá lại bằng một khoá của region đích mà
bạn chỉ định (KMS key là tài nguyên region). Muốn tránh: dùng multi-Region key —
bản sao ở region đích có cùng key material và key ID, nên ciphertext dùng chung được.
</details>

<details>
<summary>6. Đề yêu cầu "ngăn mọi người trong tổ chức tạo tài nguyên ngoài hai region cho phép". Cơ chế nào, và vì sao không phải IAM policy?</summary>

SCP với `Deny` kèm điều kiện `aws:RequestedRegion`. IAM policy sai vì admin của từng
account sửa được chính IAM policy của mình; SCP đứng ở tầng trên, account con không
gỡ được. Đây đúng nghĩa guardrail.
</details>

---

## Ngoài phạm vi

- **Resource Control Policy (RCP)** — loại policy mới của Organizations, đặt trần cho
  resource policy. [Docs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html)
- **KMS asymmetric key, HMAC key, key material import (BYOK)** — SAA chỉ hỏi symmetric.
  [Docs](https://docs.aws.amazon.com/kms/latest/developerguide/symm-asymm-choose.html)
- **ACM exportable public certificate** — tính năng mới, phá vỡ luật "không lấy được
  private key". [Docs](https://docs.aws.amazon.com/acm/latest/userguide/export-public-certificate.html)
- **AWS Verified Access, AWS Audit Manager, AWS Artifact** — biết tên là đủ.
- **Cognito user pool vs identity pool** — trong phạm vi SAA nhưng đã học ở tuần 6.
- **Nitro Enclaves, custom key store, cấu hình cluster CloudHSM** — mức Specialty.

---

## Nguồn

- [AWS Certified Solutions Architect – Associate (SAA-C03) Exam Guide, v1.1](https://d1.awsstatic.com/training-and-certification/docs-sa-assoc/AWS-Certified-Solutions-Architect-Associate_Exam-Guide.pdf)
- [AWS KMS FAQs — envelope encryption và giới hạn 4 KB](https://aws.amazon.com/kms/faqs/)
- [AWS KMS — Automatic key rotation](https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html)
- [AWS KMS is now FIPS 140-3 Security Level 3 (AWS Security Blog)](https://aws.amazon.com/blogs/security/aws-kms-now-fips-140-2-level-3-what-does-this-mean-for-you/)
- [AWS Systems Manager Parameter Store — parameter tiers](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [AWS Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/)
- [AWS Shield pricing](https://aws.amazon.com/shield/pricing/)
- [AWS WAF — rate-based rule statement (evaluation window)](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based.html)
- [AWS Certificate Manager FAQs — region và CloudFront](https://aws.amazon.com/certificate-manager/faqs/)
- [Amazon Inspector features](https://aws.amazon.com/inspector/features/)
- [Working with CloudTrail event history](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/view-cloudtrail-events.html)
- [AWS Organizations — service control policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
