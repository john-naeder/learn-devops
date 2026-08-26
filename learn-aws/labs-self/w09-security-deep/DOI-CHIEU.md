# Đối chiếu — tuần 9

> Đọc file này **sau khi** `./verify.sh` xanh hết. Đọc trước là tự lấy mất bài học.

Đây là miền nặng nhất của đề thi (30%), và phần lớn câu hỏi gắn nhãn "security"
thực chất là câu hỏi **logic đánh giá quyền** trá hình. Nếu bạn chỉ đọc kỹ một
file trong cả bộ lab tự viết, đọc mục kế tiếp.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong lab | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1. Vào bằng phiên tạm thời | **STS `AssumeRole`**, credential tạm thời, `MaxSessionDuration` | [`docs/aws/w09-security-deep.md`](../../../docs/aws/w09-security-deep.md) §8 · [sổ tay bảo mật](../../../docs/notebook/05-security.md) |
| 2. Mượn phải có mật khẩu ngữ cảnh | **External ID**, chống **confused deputy** | [`w09`](../../../docs/aws/w09-security-deep.md) §8 |
| 3. Làm đúng việc mình, không hơn | **Least privilege**, **implicit deny** | [`w09`](../../../docs/aws/w09-security-deep.md) §8 |
| 4. Bảng lương: không ai đọc được | **Resource-based policy**, **explicit Deny thắng mọi Allow** | [`w09`](../../../docs/aws/w09-security-deep.md) §8 |
| 5. Đúng một cửa phá kính | điều kiện `aws:PrincipalArn`, **break-glass account** | [`w09`](../../../docs/aws/w09-security-deep.md) §8 |
| 6. Bí mật ở nơi mã hoá và miễn phí | **Parameter Store SecureString** vs **Secrets Manager**, khoá AWS-managed | [`w09`](../../../docs/aws/w09-security-deep.md) §1, §2 · [bảng so sánh](../../../docs/notebook/22-bang-so-sanh.md) |
| 7. Tự viết một trần quyền | **Permission boundary**, `simulate-custom-policy` | [`w09`](../../../docs/aws/w09-security-deep.md) §8 · [`_boundary/README.md`](../_boundary/README.md) |
| Cả lab | vì sao role tốt hơn access key | [`docs/aws/w01-iam-foundations.md`](../../../docs/aws/w01-iam-foundations.md) |

---

## Luồng đánh giá quyền — bản đầy đủ, phải thuộc

Mọi câu hỏi IAM trong đề thi đều giải được bằng sơ đồ này, chạy từ trên xuống:

```
1. Có explicit DENY ở BẤT KỲ policy nào?      -> TỪ CHỐI. Dừng. Không gì cứu được.
2. SCP (nếu account nằm trong Organizations)  -> không Allow thì từ chối.
3. Resource control policy (RCP), nếu có      -> không Allow thì từ chối.
4. Session policy (nếu phiên có kèm)          -> không Allow thì từ chối.
5. Permission boundary (nếu principal có)     -> không Allow thì từ chối.
6. Identity policy HOẶC resource policy Allow -> CHO PHÉP.
7. Còn lại                                     -> TỪ CHỐI (implicit deny).
```

Ba câu phải nói được thành lời, vì đề thi hỏi thẳng cả ba:

**a. Explicit Deny thắng mọi Allow, ở bất kỳ tầng nào.** Bạn vừa chứng minh nó
bằng tay: danh tính đang chạy `terraform apply` có `AdministratorAccess`, mà vẫn
không đọc nổi `bi-mat/thu.txt`. Không có "quyền cao hơn" nào lật được một Deny.
Đây cũng là lý do một Deny viết rộng tay là sự cố production: nó chặn cả người
viết ra nó, và không ai có quyền nào để tự gỡ ngoài việc sửa chính policy đó.

**b. Permission boundary là TRẦN, không phải quyền.** Công thức:

```
quyền hiệu dụng = identity policy  ∩  permission boundary
                  (cái được cấp)      (cái tối đa được phép)
```

Role chỉ có boundary mà không có identity policy thì **không làm được gì cả** —
phép giao với tập rỗng là tập rỗng. Đây là câu hỏi thi kinh điển và cũng là hiểu
lầm phổ biến nhất về boundary. `verify.sh` mô phỏng đúng phép giao đó: nó cho
identity policy là `Allow * on *` (kịch bản "kỹ sư mới gắn `AdministratorAccess`
cho nhanh" trong Bối cảnh) rồi giao với trần bạn viết.

**c. Nuance ít nơi nói tới — resource-based policy đi tắt qua boundary.**
Khi một **resource-based policy nêu thẳng principal**, allow đó có thể **bỏ qua**
permission boundary và session policy của principal. Nhưng chỉ trong hai trong ba
trường hợp:

| Resource-based policy nêu ARN của | Boundary/session policy có còn bóp không |
|---|---|
| **IAM user** — `arn:aws:iam::123:user/anna` | **Không.** Allow đi thẳng |
| **Phiên của role** — `arn:aws:sts::123:assumed-role/Ops/phien-01` | **Không.** Allow đi thẳng |
| **Role** — `arn:aws:iam::123:role/Ops` | **Có.** Boundary vẫn chặn được |

Nói cách khác: nêu **role** thì trần vẫn đứng, nêu **user hoặc phiên** thì trần
bị đi vòng. Lý do hợp lý hơn nó nghe: boundary là công cụ để **uỷ quyền tạo danh
tính** — nó giới hạn cái mà *identity policy* cấp. Khi chủ sở hữu tài nguyên chủ
động nêu đích danh một danh tính cụ thể, đó là một quyết định của phía tài
nguyên, không phải một quyền do đội ứng dụng tự cấp cho mình.

Hệ quả thực tế phải nhớ: **boundary không phải hàng rào chống rò rỉ dữ liệu.**
Nếu ai đó viết một bucket policy nêu đích danh phiên của một role, boundary của
role đó không cứu bạn. Thứ chặn được ở tầng đó là **explicit Deny** trong chính
resource policy (bạn vừa làm), hoặc **SCP/RCP** ở tầng tổ chức — hai thứ này thì
resource-based policy **không** đi vòng được.

Và ngược lại, một Deny trong resource policy thì luôn thắng, không có ngoại lệ
nào. Đó là lý do lời giải của yêu cầu 4 phải là Deny ở phía kho, chứ không phải
"bỏ bớt quyền của từng danh tính".

### Ba tầng trần quyền — bảng phân biệt

| | Permission boundary | Session policy | SCP |
|---|---|---|---|
| Gắn vào | user, role | truyền lúc `AssumeRole`/`GetFederationToken` | account hoặc OU |
| Sống bao lâu | tới khi gỡ | đúng một phiên | tới khi đổi |
| Cần Organizations | không | không | **có** |
| Chặn được root | không | không | **có** |
| Một mình có cấp quyền | **không** | **không** | **không** |
| Ai viết | đội nền tảng / bảo mật | ứng dụng phát hành phiên | quản trị viên tổ chức |
| Resource policy đi vòng được | có (xem bảng trên) | có (xem bảng trên) | **không** |

Cả ba đều là **trần**. Không cái nào cấp quyền. Đề thi rất thích trộn ba cái này
trong bốn lựa chọn của cùng một câu.

---

## Ba cách khác để giải bài này

Đề SAA hỏi *"giải pháp NÀO TỐT NHẤT"*, không hỏi *"giải pháp nào chạy được"*.
Ba cách dưới đây đều chạy được.

### Cách A — SCP trong AWS Organizations thay cho Deny ở phía kho

Đưa account vào một OU, viết một SCP `Deny s3:GetObject` trên tiền tố `bi-mat/`.

**Tốt hơn khi:** bạn có **nhiều account** và quy tắc phải đúng ở mọi account,
mọi region, mãi mãi; bạn cần chặn cả **root** của account con; quy tắc là **luật
tổ chức** chứ không phải quyết định của chủ sở hữu một kho dữ liệu cụ thể (ví dụ:
"không account nào được tắt CloudTrail", "không account nào được rời region EU").
Quan trọng: SCP **không thể bị resource-based policy đi vòng**, khác với boundary.

**Tệ hơn khi:** — và đây là bài này — bạn có **một** account, và quy tắc gắn với
**một** kho dữ liệu cụ thể. Dùng SCP ở đây là đặt một quy tắc hạt mịn vào một
công cụ hạt thô: mỗi lần thêm một kho dữ liệu, bạn phải sửa luật ở tầng tổ chức
và chờ đội quản trị duyệt. SCP cũng không nêu được ngoại lệ theo kiểu "trừ đúng
role phá kính này" một cách gọn gàng như resource policy. Và Organizations là
một cấu trúc bạn phải dựng và vận hành mãi mãi.

**Đề thi hỏi thế nào:** từ khoá `all accounts in the organization`,
`prevent member accounts from`, `even the root user` → SCP. Từ khoá
`this specific bucket`, `regardless of which principal`, `data owner` →
resource-based policy. Bẫy hay gặp: đề nói "một account duy nhất" rồi đưa SCP vào
làm đáp án nhiễu — SCP cần Organizations, và một account đơn lẻ thì không có.

### Cách B — mã hoá bằng KMS customer managed key và khoá ở key policy

Mã hoá `bi-mat/` bằng một CMK riêng. Key policy chỉ cho vai phá kính
`kms:Decrypt`. Ai lấy được object cũng chỉ nhận về một khối byte vô nghĩa.

**Tốt hơn khi:** bạn cần **hai lớp khoá độc lập** (mất kiểm soát bucket policy
vẫn còn key policy đỡ); cần dấu vết giải mã **riêng biệt** trong CloudTrail cho
audit; cần chia sẻ **cross-account** có kiểm soát; cần **rotation** khoá theo
chính sách tuân thủ; hoặc cần thu hồi truy cập **tức thì với toàn bộ dữ liệu đã
mã hoá** bằng một thao tác (vô hiệu hoá khoá) thay vì sửa policy từng nơi.

**Tệ hơn khi:** — và đây là bài này — nó tốn **$1/tháng mỗi khoá** cộng $0,03
mỗi 10.000 lệnh gọi, và nó **không** trả lời được câu hỏi của đề bài. Đề nói
"không ai được đọc nó"; CMK làm cho việc đọc trở nên vô nghĩa chứ không làm cho
`GetObject` bị từ chối. Object vẫn tải về được, vẫn nằm trong laptop ai đó, và
người viết key policy vẫn phải liệt kê chính xác các principal — tức là bạn vẫn
phải giải đúng bài toán cũ, chỉ thêm một hoá đơn.

**Đề thi hỏi thế nào:** từ khoá `must control the encryption key`,
`rotate keys annually`, `audit every decryption`, `revoke access to all objects
at once` → CMK. Từ khoá `deny access`, `no one should be able to retrieve`,
`least cost` → resource policy Deny. Và nhớ: mã hoá at-rest trả lời câu hỏi
"nếu đĩa bị lấy đi", không trả lời câu hỏi "ai được gọi API".

### Cách C — tách bảng lương sang một account riêng

Dữ liệu nhạy cảm nằm ở account khác. Muốn đọc thì phải `AssumeRole` cross-account,
và ranh giới là **ranh giới account** chứ không phải một dòng trong policy.

**Tốt hơn khi:** đây là **cách đúng trong tổ chức thật** ở quy mô lớn. Ranh giới
account là ranh giới bảo mật mạnh nhất AWS cung cấp: một sai sót IAM ở account
vận hành không thể chạm tới dữ liệu ở account tài chính, vì hai bên không chia sẻ
mặt phẳng quyền. Nó cũng tách hoá đơn, tách quota, tách bán kính vụ nổ, và cho
phép áp SCP khác nhau cho từng nhánh.

**Tệ hơn khi:** — bài này — bạn phải dựng Organizations, quản lý nhiều account,
và mọi truy cập hợp lệ trở nên phức tạp hơn (role chaining, trust policy hai
chiều, giới hạn 1 giờ của role chaining). Với một kho dữ liệu và hai khu, đây là
kiến trúc lớn hơn vấn đề vài bậc.

**Đề thi hỏi thế nào:** từ khoá `strong isolation`, `separate billing`,
`blast radius`, `different compliance requirements` → tách account. Từ khoá
`single account`, `minimal operational overhead` → policy trong cùng account.
Quy tắc thực dụng của AWS: ranh giới account cho **loại workload khác nhau**,
policy cho **hạt mịn trong cùng một workload**.

---

## Nếu đề thi hỏi

<details><summary>Câu 1. Một role được attach `AdministratorAccess`, đồng thời có permission boundary chỉ cho phép `s3:*` và `cloudwatch:*`. Role đó gọi `ec2:DescribeInstances`. Kết quả?</summary>

**A.** Được phép, vì `AdministratorAccess` cho phép mọi thứ.
**B.** Bị từ chối, vì permission boundary không cho phép `ec2:*`.
**C.** Được phép, vì permission boundary chỉ áp dụng cho hành động ghi.
**D.** Bị từ chối, vì không có resource-based policy nào nhắc tới EC2.

**Đáp án: B.**

- **A sai** — đây là hiểu lầm số một về boundary. Quyền hiệu dụng là **phép giao**
  của identity policy và boundary. `AdministratorAccess ∩ {s3, cloudwatch}` =
  `{s3, cloudwatch}`. `ec2:DescribeInstances` không nằm trong đó.
- **C sai** — boundary không phân biệt đọc/ghi. Nó áp cho **mọi** API call của
  principal mang nó.
- **D sai** — không có bucket policy nào tham gia vào một lệnh gọi EC2. Đáp án
  này bẫy người đọc lướt thấy chữ "policy" là gật.

</details>

<details><summary>Câu 2. Cùng role như trên (boundary chỉ cho `s3:*` và `cloudwatch:*`). Một bucket ở account khác có bucket policy `Allow` `s3:GetObject` cho principal `arn:aws:sts::111122223333:assumed-role/DataRole/phien-abc`. Role đó gọi `s3:GetObject` lên bucket đó bằng phiên tên `phien-abc`. Điều gì đúng?</summary>

**A.** Bị từ chối, vì permission boundary không nêu bucket đó.
**B.** Được phép — resource-based policy nêu thẳng ARN của **phiên**, nên boundary không được đánh giá cho allow này.
**C.** Bị từ chối, vì cross-account luôn cần cả hai phía cho phép.
**D.** Được phép, nhưng chỉ khi phiên có kèm session policy cho `s3:GetObject`.

**Đáp án: B.** Đây là nuance ở mục trên. Khi resource-based policy nêu **ARN của
IAM user hoặc ARN của phiên role**, allow đó đi tắt qua permission boundary và
session policy.

- **A sai** — boundary thực ra *có* cho `s3:*`, nhưng kể cả nếu không thì kết quả
  vẫn là được phép, vì đường đi tắt.
- **C sai** — nguyên tắc "cả hai phía phải cho phép" đúng cho cross-account, và ở
  đây phía tài nguyên đã cho phép; phía identity trong account gọi cũng cần allow.
  Câu này nhắm vào tầng boundary, và đáp án C nói một nguyên tắc đúng nhưng không
  trả lời câu hỏi được hỏi.
- **D sai** — session policy cũng bị đi vòng trong đúng trường hợp này.

**Đổi một chữ là đổi đáp án:** nếu bucket policy nêu `arn:aws:iam::111122223333:role/DataRole`
(ARN **role**, không phải ARN **phiên**), thì boundary **được** đánh giá bình
thường. Đây là kiểu chi tiết mà đề SAA dùng để tách người đọc kỹ khỏi người đoán.

</details>

<details><summary>Câu 3. Công ty thuê một đội vận hành bên ngoài. Đội đó có nhiều khách hàng và dùng chung một AWS account cho tất cả. Cách nào NGĂN được việc đội đó vô tình (hoặc bị lừa) dùng quyền của khách hàng A khi đang làm việc cho khách hàng B?</summary>

**A.** Yêu cầu đội vận hành tạo một IAM user riêng cho mỗi khách hàng.
**B.** Thêm điều kiện `sts:ExternalId` vào trust policy, mỗi khách hàng một giá trị bí mật riêng.
**C.** Giới hạn `MaxSessionDuration` xuống 1 giờ.
**D.** Bật MFA cho mọi lệnh `AssumeRole`.

**Đáp án: B.** Đây là **confused deputy**: đội vận hành là "deputy" được nhiều
bên tin tưởng, và kẻ tấn công lợi dụng chính sự tin tưởng đó. External ID là một
giá trị **chỉ hai bên biết**, nên chỉ dùng account ID của bên kia là chưa đủ —
account ID không phải bí mật, ai cũng tra được.

- **A sai** — user dài hạn thay vì role tạm thời là đi lùi. Và nó không ngăn được
  việc account của đội vận hành bị lừa gọi nhầm role.
- **C sai** — phiên ngắn hơn giảm thời gian một credential bị lộ còn dùng được,
  nhưng không ngăn được việc gọi nhầm ngay từ đầu.
- **D sai** — MFA tốt cho người, nhưng đội vận hành gọi bằng tự động hoá. MFA
  không trả lời câu hỏi "vai này đang được mượn nhân danh khách hàng nào".

</details>

<details><summary>Câu 4. Ứng dụng cần lưu mật khẩu database và tự đổi nó 30 ngày một lần mà không sửa code. Yêu cầu thêm: chi phí thấp nhất có thể trong khi vẫn đáp ứng điều trên. Chọn gì?</summary>

**A.** SSM Parameter Store SecureString, viết một Lambda chạy theo lịch để đổi mật khẩu.
**B.** Secrets Manager với rotation tự động.
**C.** SSM Parameter Store Advanced.
**D.** Biến môi trường của hàm, mã hoá bằng KMS.

**Đáp án: B.** Từ khoá quyết định là **tự đổi định kỳ mà không sửa code**. Đó
đúng là tính năng mà $0,40/secret/tháng mua được, và nó tích hợp sẵn với RDS.

- **A sai** — chạy được, và rẻ hơn về mặt hoá đơn AWS. Nhưng bạn vừa nhận nuôi
  một Lambda: viết, kiểm thử, xử lý lỗi giữa chừng, vá bảo mật, trực khi nó hỏng
  lúc 3 giờ sáng. Đề SAA gọi đó là **operational overhead**, và khi đề nói "không
  sửa code / ít vận hành nhất" thì tự viết rotation luôn là đáp án sai.
- **C sai** — bậc Advanced mua **kích thước tham số lớn hơn và số lượng nhiều
  hơn** ($0,05/tham số/tháng), không mua rotation.
- **D sai** — mật khẩu nằm trong cấu hình hàm, đổi mật khẩu là deploy lại, và bất
  kỳ ai đọc được cấu hình hàm đều thấy nó. Đây là đáp án nhiễu kinh điển.

Đảo lại đề — bỏ chữ "tự đổi" đi và thêm "chi phí thấp nhất" — thì đáp án lập tức
thành Parameter Store SecureString, đúng như lab này chọn.

</details>

<details><summary>Câu 5. Một role không có identity policy nào, chỉ có một permission boundary cho phép `s3:*`. Role đó gọi `s3:ListBucket`. Kết quả?</summary>

**A.** Được phép — boundary cho phép `s3:*`.
**B.** Bị từ chối — boundary không cấp quyền, và không có identity policy nào Allow.
**C.** Được phép nếu bucket nằm cùng account.
**D.** Lỗi cấu hình — AWS không cho tạo role không có identity policy.

**Đáp án: B.** Boundary là **trần**, không phải nguồn quyền.
`∅ ∩ {s3:*} = ∅`.

- **A sai** — đây chính là hiểu lầm mà câu hỏi nhắm tới.
- **C sai** — cùng account không thay đổi gì; vẫn cần một Allow ở đâu đó (identity
  policy hoặc resource policy).
- **D sai** — tạo role không có policy nào là hợp lệ hoàn toàn. Nó chỉ vô dụng.

Biến thể hay gặp: nếu bucket đó có **resource-based policy** Allow cho ARN của
role này, kết quả đổi thành *được phép* — resource policy cấp được quyền, còn
boundary thì không. Nhưng lúc đó boundary vẫn được đánh giá (vì policy nêu ARN
**role**), nên nếu boundary không cho `s3:*` thì lại bị chặn. Xem bảng nuance.

</details>

<details><summary>Câu 6. Đội bảo mật muốn cho đội ứng dụng tự tạo IAM role cho hàm của họ, nhưng phải đảm bảo không role nào tự tạo có thể vượt quá một tập quyền cho trước. Cách nào ĐÚNG?</summary>

**A.** Cấp cho đội ứng dụng quyền `iam:CreateRole` kèm điều kiện `iam:PermissionsBoundary` bằng ARN của một boundary do đội bảo mật viết.
**B.** Cấp `iam:CreateRole` rồi review thủ công hằng tuần.
**C.** Viết một SCP chặn `iam:CreateRole` và bắt đội ứng dụng mở ticket.
**D.** Cấp `iam:CreateRole` và dùng AWS Config rule để phát hiện role vượt quyền.

**Đáp án: A.** Đây là mẫu **delegated role creation with permissions boundary**,
và bạn đang sống bên trong nó: `labs-self-boundary` dùng đúng điều kiện đó
(`DenyPrincipalWithoutBoundary`) để bắt mọi role bạn tạo phải mang chính nó.

- **B sai** — phát hiện sau khi việc đã xảy ra, và phụ thuộc vào con người.
- **C sai** — chặn được thật, nhưng nó xoá bỏ khả năng tự phục vụ của đội ứng
  dụng. Đề nói "cho đội ứng dụng **tự** tạo".
- **D sai** — Config là **detective control**, không phải **preventive control**.
  Nó báo cho bạn biết chuyện xấu đã xảy ra. Phân biệt hai loại control này là một
  trục hỏi thường xuyên của Domain 1.

</details>

---

## Chỗ dễ hiểu sai

**"verify.sh xanh nghĩa là hệ thống của tôi an toàn."**
Không. Nó nghĩa là bảy điều cụ thể đúng vào lúc chấm. Bốn thứ lab không chạm tới,
và cả bốn đều là chuyện production thật:

- **Không có dấu vết.** Đề bài nói "việc mở phải để lại dấu vết", và bạn chưa làm
  gì cho việc đó. Trong production, vai phá kính phải đi kèm: CloudTrail bật sẵn,
  một EventBridge rule bắt sự kiện `AssumeRole` lên vai đó, và một cảnh báo tới
  người trực **ngay khi** nó được mượn. Cửa phá kính không có chuông báo thì chỉ
  là một cửa sau. Đó là bài tuần 10.

- **Deny theo tên là Deny mong manh.** Điều kiện `aws:PrincipalArn` của bạn khớp
  theo **tên role**. Ai xoá role rồi tạo lại đúng tên đó sẽ kế thừa luôn quyền
  phá kính. Cách bền hơn là khớp theo `aws:userId` với **unique ID** của role
  (`AROA...`) — ID này không tái sử dụng. Đổi lại, policy khó đọc hơn và phải
  cập nhật khi role được tạo lại có chủ ý.

- **`MaxSessionDuration = 1 giờ` không phải giới hạn cứng.** Nó giới hạn **một**
  phiên. Không có gì cấm bên kia gọi `AssumeRole` lại mỗi 55 phút, mãi mãi. Nếu
  bạn cần thu hồi thật thì phải sửa trust policy, gỡ quyền, hoặc dùng
  `aws:TokenIssueTime` — phiên ngắn là để **giảm thiệt hại khi credential rò**,
  không phải để giới hạn tổng thời gian truy cập.

- **Bí mật trong Terraform state.** Nếu bạn viết giá trị `SecureString` thẳng
  trong `main.tf`, nó nằm trong Git dưới dạng plaintext và nằm trong
  `terraform.tfstate` dưới dạng plaintext. Mã hoá ở phía AWS không cứu được điều
  đó. Cách làm thật: tạo tham số rỗng bằng IaC rồi đặt giá trị ngoài băng, hoặc
  đọc từ một nguồn bí mật có sẵn. Bài tuần 10 đưa state lên S3 — và đó là lúc
  câu hỏi "state mã hoá chưa" trở thành câu hỏi bắt buộc.

**Một chỗ nữa: "explicit Deny thắng tất cả" cắt cả hai chiều.**
Bạn vừa dùng nó làm vũ khí. Trong production nó cũng là nguyên nhân sự cố phổ
biến: một Deny viết rộng tay trong SCP hoặc bucket policy sẽ chặn cả đội đang
trực, và cách sửa duy nhất là sửa chính policy đó — thứ mà có thể chính bạn vừa
tự chặn quyền sửa. Quy tắc thực dụng: **Deny càng rộng thì càng phải có một
đường thoát được nghĩ trước**, và đường thoát đó phải được thử ít nhất một lần
trước khi bạn cần tới nó.
