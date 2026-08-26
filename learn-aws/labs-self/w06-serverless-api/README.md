# Tuần 6 — API không có máy chủ nào  (tự viết)

`Domain 3 · Performance (24%)` `Domain 4 · Cost (20%)` `Domain 1 · Security (30%)`

| | |
|---|---|
| **Chi phí khi chạy** | **~$0,000/giờ** — không thành phần nào tính theo giờ |
| **Quên 1 tháng** | **< $0,01**, *nếu* bạn làm đúng yêu cầu 10 |
| **Thời gian** | ~4 giờ. Phần đau nhất không phải code, mà là hai chữ `permissions_boundary` |
| **Điều kiện** | nên xong `w01-iam-foundations` (bạn sẽ viết một trust policy và một identity policy) và `w05-databases` (kho dữ liệu là cái bạn đã dựng tuần trước) |

> Đây là lab đầu tiên trong bộ mà **hàng rào sẽ chặn bạn ngay ở dòng thứ ba**,
> và nếu không đọc mục "Hàng rào của lab này" trước thì bạn sẽ mất một tiếng
> nhìn một thông điệp `AccessDenied` không nói gì có nghĩa. Đọc mục đó **trước**
> khi mở editor.

---

## Bối cảnh

Phòng marketing dán link chiến dịch vào tin nhắn SMS và mã QR. Link dài 180 ký
tự, tin nhắn thì giới hạn 160, và mã QR thì càng dài càng khó quét. Họ muốn một
dịch vụ rút gọn link nội bộ.

Ba phía, ba câu, và cả ba đều là ràng buộc kiến trúc:

- **Đội vận hành** đã từ chối một lần rồi: "Chúng tôi không trực một máy chủ
  24/7 cho một dịch vụ chạy vài chục request mỗi phút. Nếu phải vá hệ điều hành
  cho nó thì đừng làm."
- **Đội tài chính**: "Không có gì tính tiền khi không ai dùng. Và tôi muốn biết
  trước điều gì xảy ra nếu có ai đó gọi vào nó một triệu lần trong một đêm."
- **Đội bảo mật** vừa đọc báo cáo hậu sự cố ở một công ty khác: một hàm xử lý
  request web bị lỗi injection, và vì hàm đó chạy với quyền quá rộng nên kẻ tấn
  công đọc được **toàn bộ** kho dữ liệu chứ không chỉ một bản ghi. Quy định
  mới: **danh tính của một thành phần chỉ được làm đúng việc của thành phần
  đó** — không hơn một action nào.

---

## Yêu cầu

Bốn yêu cầu đầu là **hợp đồng HTTP**. Nó là một phần của đề bài, không phải gợi
ý — `verify.sh` gọi thật vào đúng những đường dẫn này.

1. **Tạo mã ngắn.**
   `POST {api_url}{duong_dan_tao}` với header `Content-Type: application/json`
   và thân `{"url": "https://..."}`
   → trả **201**, thân là JSON có trường **`ma`** (chuỗi, mã ngắn vừa tạo).

2. **Dùng mã ngắn.**
   `GET {api_url}/{ma}`
   → trả **301** hoặc **302**, header `Location` bằng **đúng** URL đã gửi ở
   bước 1.

3. **Dữ liệu bền.** Gọi lại bước 2 sau đó vẫn ra đúng `Location`, và bản ghi
   phải thật sự nằm trong một kho dữ liệu — không phải trong bộ nhớ của tiến
   trình đang chạy.

4. **PHỦ ĐỊNH — input sai phải trả mã lỗi ĐÚNG, không phải 500.**
   Cả ba trường hợp dưới đây đều phải trả **400**, thân là JSON có trường
   **`loi`**:
   - thân không có trường `url`
   - `url` không phải một địa chỉ `http://` hoặc `https://`
   - thân không phải JSON hợp lệ

   > `500` nghĩa là "code của tôi nổ và tôi không biết vì sao". `400` nghĩa là
   > "tôi đã lường trước tình huống này". Đây là khác biệt giữa một hàm và một
   > API, và nó là yêu cầu khó nhất của lab đối với người quen viết script.

5. **PHỦ ĐỊNH — mã không tồn tại trả 404**, không phải 500, và tuyệt đối không
   phải 302 tới một chỗ nào đó.

6. **PHỦ ĐỊNH — đường dẫn hoặc phương thức không khai báo trả 404 hoặc 405**,
   không phải 500.

7. **PHỦ ĐỊNH — danh tính của phần xử lý chỉ làm được đúng việc của nó.**
   `verify.sh` hỏi thẳng AWS bằng policy simulator:
   - ghi một bản ghi vào **đúng bảng của bạn** → được
   - đọc một bản ghi từ **đúng bảng của bạn** → được
   - **đọc toàn bộ bảng** → **bị từ chối**
   - **xoá bảng** → **bị từ chối**
   - ghi vào **một bảng khác** → **bị từ chối**
   - đọc một kho object bất kỳ → **bị từ chối**

8. **Danh tính đó mang trần quyền của bộ lab.** Xem mục Hàng rào — đây là thứ
   sẽ chặn bạn trước tiên, và nó cũng là bài học Domain 1 của tuần này.

9. **Không thiết bị mạng nào tính tiền theo giờ.** Phần xử lý phải đọc/ghi được
   kho dữ liệu mà không cần bất cứ thứ gì có giá $/giờ đứng giữa.

10. **Log không giữ vĩnh viễn.** Nơi ghi log của phần xử lý phải có hạn giữ
    **không quá 7 ngày**.
    > Mặc định của AWS là **giữ mãi mãi**. Một hàm lỗi lặp vô hạn ăn hết 5 GB
    > miễn phí trong một đêm, rồi tính $0,50/GB nạp vào — và bạn vẫn trả tiền
    > lưu trữ cho đống log đó nhiều năm sau. Đây là câu trả lời cho câu hỏi thứ
    > hai của đội tài chính.

11. **Có trần chống hoá đơn.** API phải đặt **trần tốc độ request không quá 100
    request/giây**, và kho dữ liệu phải ở chế độ không phát sinh phí khi rảnh.
    > Trần mặc định của API Gateway là **10.000 request/giây trên toàn tài
    > khoản**. Đó là con số bạn *chịu được* nếu một vòng lặp lỗi gọi vào API của
    > mình cả đêm — hãy tự nhân nó ra tiền trước khi bỏ qua yêu cầu này.

---

## Hợp đồng output

| Output | Kiểu | `verify.sh` dùng để |
|---|---|---|
| `api_url` | string | gốc địa chỉ API, có `https://`, **không có dấu `/` ở cuối** |
| `api_id` | string | tra cấu hình stage để kiểm tra trần tốc độ |
| `duong_dan_tao` | string | đường dẫn tạo mã, **bắt đầu bằng `/`**, ví dụ `/rutgon` |
| `function_name` | string | tra cấu hình phần xử lý và nơi ghi log |
| `role_arn` | string | ARN danh tính của phần xử lý — dùng cho toàn bộ yêu cầu 7 và 8 |
| `table_name` | string | dựng ARN bảng cho policy simulator; xác nhận dữ liệu đã ghi thật |
| `chi_phi` | string | in ra trước khi gõ `yes` |

---

## Hàng rào của lab này

### Đọc mục này TRƯỚC khi viết dòng Terraform đầu tiên

Boundary có một statement tên `DenyPrincipalWithoutBoundary`. Nó từ chối
`iam:CreateRole` **khi khoá điều kiện `iam:PermissionsBoundary` khác đúng ARN
của boundary**. Nói bằng tiếng Việt:

> **Mọi IAM role bạn tạo trong bộ lab này đều BẮT BUỘC phải khai
> `permissions_boundary`. Thiếu nó là `AccessDenied`, không có ngoại lệ.**

Lab tuần 6 là lab đầu tiên mà bạn *bắt buộc* phải tạo một IAM role — phần xử lý
cần một danh tính để nói chuyện với kho dữ liệu. Nên đây là lab đầu tiên bạn va
vào statement này.

Lấy ARN boundary:

```bash
terraform -chdir=../_boundary output -raw lab_boundary_arn
# arn:aws:iam::<account-id>:policy/labs-self-boundary
```

Không có state của `_boundary` trong tay thì hỏi thẳng AWS:

```bash
aws iam list-policies --profile lab-builder --scope Local \
  --query 'Policies[?PolicyName==`labs-self-boundary`].Arn' --output text
```

Trong Terraform, thuộc tính tên là `permissions_boundary`, đặt trên chính
resource role.

Thông điệp lỗi khi thiếu nó trông như thế này, và nó **không** nhắc chữ nào tới
`permissions_boundary` của *bạn*:

```
Error: creating IAM Role (self-w06-...): AccessDenied: User:
arn:aws:sts::123:assumed-role/lab-builder/... is not authorized to perform:
iam:CreateRole on resource: ... with an explicit deny in a permissions
boundary policy
```

Từ khoá `explicit deny in a permissions boundary policy` → **hàng rào**, không
phải bug của bạn. Xem `_boundary/README.md` mục 5.

**Đây không phải phiền toái thừa.** Đó đúng là cách một tổ chức thật uỷ quyền
cho đội ứng dụng tự tạo role mà không sợ leo thang đặc quyền: đội nền tảng viết
boundary một lần, đội ứng dụng tự do trong trần đó. Bạn đang gõ tay một mẫu
thiết kế có tên riêng trong đề thi.

### Bẫy tên — `AccessDenied` nói dối

`DenyCredentialEscalation` dùng `NotResource` trên `role/self-w*`. Hệ quả cụ thể
cho tuần này: role tên `w06-lambda-exec` (thiếu tiền tố `self-`) vẫn **tạo**
được, nhưng lần đầu tiên bạn sửa trust policy của nó rồi apply lại,
`iam:UpdateAssumeRolePolicy` sẽ bị Deny — **và thông điệp vẫn nói "permissions
boundary"**, nghe như kiến trúc sai trong khi thật ra chỉ là **sai tên**.

Quy tắc: gặp `AccessDenied` nhắc boundary khi đang đụng IAM → **kiểm tra tên
trước, kiểm tra kiến trúc sau.**

### Trần chi phí

| Thành phần | Giá | Nếu quên 1 tháng |
|---|---|---|
| Phần xử lý (Lambda) | 1 triệu request + 400.000 GB-giây **miễn phí vĩnh viễn** | $0 |
| API HTTP | 1 triệu request/tháng miễn phí **12 tháng đầu**, sau đó $1,00/triệu | $0 |
| Kho dữ liệu | như tuần 5 — 25 GB và 25/25 capacity miễn phí vĩnh viễn | $0 |
| Log | 5 GB nạp + 5 GB lưu miễn phí/tháng, sau đó $0,50/GB nạp | **$0 nếu có hạn giữ; không giới hạn nếu không** |
| **Tổng** | **~$0,000/giờ** | **< $0,01** |

Lab này **giữ lại được**. Nó nằm gọn trong hạn mức miễn phí, nó là thứ bỏ vào
CV được, và tuần 4 + tuần 6 ghép lại là một ứng dụng full-stack chạy trên AWS
gần như không tốn gì. Nhưng "giữ lại" chỉ an toàn khi yêu cầu 10 và 11 đã xanh
— chúng chính là hai cái cầu dao.

### Boundary chặn gì, vì sao

| Boundary chặn | Vì sao, và bạn gặp nó lúc nào |
|---|---|
| `iam:CreateRole` không kèm boundary | xem trên. Đây là thứ chặn bạn đầu tiên |
| `iam:CreateAccessKey`, `iam:CreateLoginProfile` | chặn **tuyệt đối**, không theo tên. Nếu bạn thấy mình định tạo access key cho phần xử lý, dừng lại: bạn đang chọn **user** ở chỗ đáng lẽ chọn **role**. Một hàm Lambda nhận credential tạm thời qua execution role, không cần và không được có access key |
| `lambda:PutProvisionedConcurrencyConfig` | provisioned concurrency tính tiền **cả khi không có request nào** — trái thẳng với yêu cầu của đội tài chính. Cách giảm cold start mà lab cho phép: giảm kích thước gói, khởi tạo client **ngoài** hàm xử lý, chọn runtime khởi động nhanh |
| `ec2:CreateNatGateway`, `ec2:AllocateAddress` | liên quan trực tiếp tới yêu cầu 9. Nếu bạn đặt phần xử lý vào một mạng riêng, nó **mất** đường ra internet và mất luôn đường tới các endpoint dịch vụ AWS công cộng — lối thoát duy nhất là NAT Gateway ($33/tháng, bị chặn) hoặc VPC endpoint (miễn phí với loại Gateway). Bài này không cần mạng riêng chút nào; hiểu **vì sao không cần** là một câu hỏi thi |
| `kinesis:CreateStream` | như tuần 5 |
| mọi API ngoài `us-east-1` | như mọi tuần |

**Gặp lỗi — boundary hay bug?**

- `AccessDenied ... iam:CreateRole ... explicit deny in a permissions boundary`
  → **boundary.** Thiếu `permissions_boundary`. Xem trên.
- API trả `500` và log của phần xử lý **trống hoàn toàn**
  → **không phải boundary.** Đây là API Gateway không gọi được phần xử lý:
  thiếu quyền cho phép dịch vụ API gọi hàm (một **resource policy** trên hàm,
  hướng ngược lại với execution role). Hai hướng quyền này là mục 8 của
  `docs/aws/w06-serverless-api.md`, và nhầm lẫn giữa chúng là bẫy tuần này.
- API trả `500` và log có `AccessDeniedException ... dynamodb:PutItem`
  → **bug của bạn**: identity policy của execution role chưa cho action đó, hoặc
  cho trên sai ARN. Từ khoá phân biệt: `no identity-based policy allows`.
- API trả `403` với body `{"message":"Forbidden"}`
  → đường dẫn hoặc phương thức chưa được khai báo trong API, hoặc bạn gọi nhầm
  stage. Không phải boundary.
- `terraform apply` treo rất lâu ở phần xử lý → gói triển khai quá lớn. Không
  phải boundary.

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh toàn bộ, gồm cả **chín** check phủ định
- [ ] Giải thích được **hai hướng quyền** của phần xử lý: cái gì cho phép *nó*
      gọi kho dữ liệu, và cái gì cho phép *API* gọi nó. Vẽ được hai mũi tên
      ngược chiều nhau
- [ ] Trả lời được: vì sao yêu cầu 7 chặn `Scan` mà vẫn cho `GetItem`? Nếu bạn
      cấp `dynamodb:*` trên đúng một bảng thì đã đủ chưa, và thiếu gì so với
      nguyên tắc quyền tối thiểu?
- [ ] Ghi lại con số **cold start** mà `verify.sh` in ra, và giải thích nó bằng
      ba thứ: kích thước gói triển khai, chỗ bạn khởi tạo client, và bộ nhớ cấp
      cho hàm (bộ nhớ ảnh hưởng tới cả **CPU** — đây là chỗ nhiều người bất ngờ)
- [ ] Trả lời được: hàm của bạn **không** nằm trong mạng riêng nào mà vẫn gọi
      được kho dữ liệu. Nó đi đường nào? Nếu bạn đặt nó vào mạng riêng thì phải
      thêm gì, tốn bao nhiêu, và được gì?
- [ ] Trả lời được: nếu một người dùng gọi `POST` hai lần với **cùng một URL**,
      hệ thống của bạn tạo một mã hay hai mã? Cách nào đúng hơn, và cách nào
      tốn ít hơn?
- [ ] Trả lời được: API của bạn hiện **ai gọi cũng được**. Trong production thì
      thêm gì? Kể được ít nhất ba cơ chế và nói được cái nào dùng khi nào

---

## Quy trình

```bash
source ../../env.sh
../guard.sh

# Lấy ARN boundary TRƯỚC KHI viết role — đây là thứ chặn bạn đầu tiên
terraform -chdir=../_boundary output -raw lab_boundary_arn

cd terraform
terraform init
terraform apply                 # đọc chi_phi trước khi gõ yes

cd .. && ./verify.sh            # gọi HTTP thật, ~1 phút

$PAGER DOI-CHIEU.md
```

**Lab này không bắt buộc destroy** — nó nằm trong hạn mức miễn phí và là xương
sống cho phần capstone. Nếu giữ lại:

```bash
../../scripts/set-log-retention.sh 7    # nghi thức sau MỌI lab có Lambda
```

Nếu dọn:

```bash
cd terraform && terraform destroy
```

---

## Dọn dẹp

`terraform destroy` xoá được mọi thứ trong một lần. Ba chỗ nên kiểm tra lại, và
cả ba đều là những thứ **sống lâu hơn** resource sinh ra chúng:

```bash
# 1. Log group — Terraform CHỈ xoá nó nếu bạn khai nó tường minh.
#    Nếu bạn để Lambda tự tạo log group thì nó ở lại sau destroy, giữ log mãi
#    mãi, và không tag nào của bạn dính vào nó. Đây là "rác vô hình" phổ biến
#    nhất của mọi dự án serverless.
aws logs describe-log-groups --profile lab-builder \
  --log-group-name-prefix /aws/lambda/self-w06 \
  --query 'logGroups[].[logGroupName,retentionInDays,storedBytes]' --output table

# 2. IAM role và policy
aws iam list-roles --profile lab-builder \
  --query 'Roles[?starts_with(RoleName, `self-w06`)].[RoleName,PermissionsBoundary.PermissionsBoundaryArn]' \
  --output table

# 3. Bảng và bản sao lưu của nó
aws dynamodb list-tables --profile lab-builder \
  --query 'TableNames[?starts_with(@, `self-w06`)]' --output table

../../scripts/find-orphans.sh
```

Nếu log group còn lại mà bạn không định giữ:

```bash
aws logs delete-log-group --profile lab-builder \
  --log-group-name /aws/lambda/<ten-ham>
```

**Bài học ẩn trong lệnh số 1:** Terraform chỉ quản lý thứ nó tạo ra. Mọi tài
nguyên do **AWS tự sinh ra như tác dụng phụ** — log group của Lambda,
service-linked role, ENI của Lambda-trong-VPC — đều nằm ngoài state và ở lại
sau `destroy`. Nhận ra nhóm này là một kỹ năng vận hành thật, không chỉ là mẹo
dọn lab.
