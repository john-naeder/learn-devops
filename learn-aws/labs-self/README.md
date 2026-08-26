# Lab tự thực hành — 12 tuần, không có lời giải

> Bộ này là **đề bài**, không phải hướng dẫn. Bạn tự viết Terraform từ file
> trống. Bạn sẽ viết sai. Hàng rào trong [`_boundary/`](_boundary/) là thứ giữ
> cho những cái sai đó không thành hoá đơn.

Luật ràng buộc toàn bộ: [`CONVENTIONS.md`](CONVENTIONS.md).

---

## Vì sao lab tự viết khác lab có lời giải

[`../labs/`](../labs/) cho bạn Terraform viết sẵn. Chạy `apply`, chạy
`verify.sh`, xanh hết, sang tuần sau. Bạn học được cách **đọc** một kiến trúc.

Đó là một kỹ năng thật. Nhưng nó không phải kỹ năng đề SAA kiểm tra, và cũng
không phải kỹ năng người phỏng vấn hỏi. Cả hai đều hỏi cùng một câu:

> *Cho bối cảnh này, giải pháp nào tốt nhất — và vì sao không phải ba cái kia?*

Đọc code người khác không luyện được câu đó. Chỉ có ngồi trước một file trống,
tự chọn dịch vụ, chọn sai, thấy nó sai, rồi chọn lại — mới luyện được.

Nên bộ này cung cấp đúng bốn thứ, và **không bao giờ** cung cấp lời giải:

| | Là gì | Vì sao có |
|---|---|---|
| **Đề bài** (`README.md`) | bối cảnh nghiệp vụ + yêu cầu kiểm chứng được | mô tả **kết quả cần đạt**, không mô tả resource cần tạo |
| **Hợp đồng output** | tên output Terraform bắt buộc | để chấm được mà không cần biết bạn giải kiểu gì |
| **`verify.sh`** | trọng tài khách quan, hỏi thẳng AWS | "cảm giác xong rồi" không phải bằng chứng |
| **Hàng rào** | boundary + budget + kỷ luật | sai cỡ nào cũng không cháy ví |

`HINTS.md` có ba tầng gợi ý, mỗi tầng trong một `<details>`. Mở tầng 1 khi ngồi
15 phút không ra. Tầng 3 là tầng sâu nhất và **vẫn không có đáp án** — tối đa
3 dòng HCL, chỉ để minh hoạ cú pháp lạ.

### Luật "không lời giải" — và vì sao nó đáng giữ

Trong repo này sẽ không bao giờ có `main.tf` mẫu cho `labs-self/`. Không phải
để làm khó. Ba lý do:

1. **Đọc lời giải tạo cảm giác hiểu mà không tạo khả năng làm.** Bạn gật gù
   với một đoạn HCL rồi tuần sau không viết lại được. Hiện tượng này có tên
   trong nghiên cứu học tập, và nó là lý do đọc đáp án trước khi thi thử luôn
   phản tác dụng.
2. **Đề SAA hỏi "cái nào TỐT NHẤT", không hỏi "cái nào chạy được".** Một lời
   giải mẫu chỉ trưng ra một lựa chọn. Tự vật lộn rồi đọc
   [`DOI-CHIEU.md`](CONVENTIONS.md) mục "Ba cách khác để giải bài này" mới cho
   bạn cái bảng so sánh — và đó mới là thứ ra thi.
3. **`verify.sh` chấm hành vi thật, không chấm code.** Nó gọi AWS API hỏi
   trạng thái thật, không `grep` file `.tf`. Bạn giải bằng cách khác vẫn đạt.
   Có lời giải mẫu là ngầm nói "chỉ có một cách đúng" — sai với cả thực tế lẫn
   đề thi.

Khi bí thật sự, thứ tự đúng là: đề bài → HINTS tầng 1 → tài liệu AWS →
HINTS tầng 2 → [`../labs/wXX-*/`](../labs/) (lab có lời giải của **cùng tuần**,
chủ đề gần nhưng đề bài khác) → HINTS tầng 3.

---

## Thiết lập lần đầu

Làm một lần, khoảng 15 phút, **trước** buổi lab đầu tiên.

```bash
# 1. Công cụ (nếu chưa làm ở ../labs/)
../scripts/setup-tools.sh
aws configure --profile learn          # region: us-east-1, output: json

# 2. Dựng hàng rào — bằng profile ADMIN, một lần duy nhất
source ../env.sh
cd _boundary
terraform init
terraform apply -var 'notify_email=ban@example.com'

# 3. Tạo profile lab-builder
terraform output -raw aws_config_profile     # rồi dán vào ~/.aws/config

# 4. Xác nhận mail đăng ký ngân sách trong hộp thư
#    Budget chưa xác nhận thì cảnh báo không bao giờ tới.

# 5. Kiểm tra
export AWS_PROFILE=lab-builder
./guard.sh
```

Chi tiết, và phần lý thuyết đi kèm: [`_boundary/README.md`](_boundary/README.md).

---

## Quy trình một buổi lab

```bash
source ../env.sh                  # PATH + locale + AWS_REGION
export AWS_PROFILE=lab-builder    # KHÔNG phải learn
./_boundary/guard.sh              # 10 giây. Không bỏ qua.

cd wXX-ten-lab
$EDITOR README.md                 # đọc đề, đọc Hợp đồng output, đọc Hàng rào

cd terraform
$EDITOR main.tf                   # file trống. Đây là phần chính của buổi lab.
terraform init
terraform plan                    # ĐỌC. Đây là lúc bắt lỗi rẻ nhất.
terraform apply                   # đọc output chi_phi TRƯỚC KHI gõ yes

cd ..
./verify.sh                       # trọng tài. Sửa tới khi xanh hết.
$EDITOR DOI-CHIEU.md              # đọc SAU khi xanh — nối tay với đầu

cd terraform
terraform destroy                 # CHƯA DESTROY THÌ BUỔI LAB CHƯA XONG
```

Cuối buổi:

```bash
../scripts/find-orphans.sh        # còn gì đang đốt tiền không
./_lib/cleanup.sh                 # liệt kê tàn dư theo tag (không xoá gì)
```

---

## Ba tầng hàng rào

Không tầng nào một mình đủ. Mỗi tầng bắt đúng loại sai lầm mà hai tầng kia
bỏ lọt.

| Tầng | Cơ chế | Bắt được gì | Bỏ lọt gì | Độ trễ |
|---|---|---|---|---|
| **1. Permission boundary** | AWS từ chối API call ngay tại tầng dịch vụ | tạo NAT Gateway, EKS, `m5.24xlarge`, đi lạc region | tiền theo byte/request, đồ tạo trước khi có rào, root | **tức thì** |
| **2. Ngân sách** | AWS Budgets $5/tháng, cảnh báo 50/80/100% + dự báo | data transfer, log ingest, tài nguyên rẻ chạy quên tắt | không tự tắt gì — chỉ gửi mail | vài giờ |
| **3. Kỷ luật** | `guard.sh` trước, `terraform destroy` sau | "quên tắt" — nguyên nhân đốt tiền số 1 | thứ bạn quên chạy | do bạn |

Tầng 1 là tầng duy nhất **không cần bạn nhớ gì**. Nó chặn trước khi tài nguyên
kịp tồn tại. Nhưng nó cũng là tầng có nhiều lỗ nhất, và
[`_boundary/README.md` mục 7](_boundary/README.md) liệt kê thẳng thắn từng lỗ.

Tầng 3 nghe có vẻ yếu nhất, nhưng nó là tầng cứu bạn nhiều tiền nhất trong
thực tế. Một `t3.micro` boundary cho phép chạy 30 ngày là **$7,5**; thêm một
ALB quên xoá là **$39**. Không cơ chế kỹ thuật nào chặn được — chỉ có
`terraform destroy`.

> **Không bao giờ tắt boundary để làm bài.** Nếu một lab cần thứ boundary
> chặn, lab đó thiết kế sai — đổi đề bài, không đổi hàng rào.

---

## Bảng 12 lab

Chi phí bám [`../aws-saa-plan.md`](../aws-saa-plan.md) và
[`../labs/README.md`](../labs/README.md). Cột **quên 1 tháng** là số bạn nên
nhìn trước khi gõ `yes`.

| Tuần | Lab | Domain | Chạy | Quên 1 tháng | Trọng tâm |
|---|---|---|---|---|---|
| 1 | IAM foundations | D1 Security · D4 Cost | **$0** | $0 | identity / resource / trust policy, Policy Simulator, role vs user |
| 2 | VPC networking | D1 + D2 | **$0,04/giờ** | **~$30** | subnet, route table, SG vs NACL, Gateway vs Interface Endpoint, SSM không SSH |
| 3 | EC2 · ALB · ASG | D2 + D3 | **$0,053/giờ** | **~$39** | launch template, health check, self-healing, target tracking |
| 4 | S3 · CloudFront | D1 + D3 + D4 | ~$0 | ~$0 | OAC, storage class, lifecycle, versioning, delete marker, presigned URL |
| 5 | Databases | D2 + D3 | $0 · **$0,019/giờ** nếu bật RDS | **~$14** | Query vs Scan, GSI vs LSI, TTL, Streams, Multi-AZ vs Read Replica |
| 6 | Serverless API | D2 + D3 + D4 | **$0** | $0 | API GW → Lambda → DynamoDB, cold start, IAM tối thiểu quyền |
| 7 | Decoupling | D2 Resilient | **$0** | $0 | SNS fanout, DLQ, visibility timeout, SQS vs Kinesis, Step Functions |
| 8 | DNS · CDN · edge | D3 Performance | ~$0 · **$1/tháng** nếu bật Route 53 | **$1** | cache key, TTL, invalidation, CloudFront Functions, 7 routing policy |
| 9 | Security deep | D1 · 30% đề | **$0** | $0 | AssumeRole, **permission boundary**, explicit Deny, KMS, Parameter Store |
| 10 | Observability · IaC | D2 + D4 | **$0** | $0 | alarm thật, p99, Logs Insights, `treat_missing_data`, remote state |
| 11 | DR · hybrid | D2 Resilient | **$0/giờ** · *(tuỳ chọn $0,50/tháng)* | $0,50 | chọn **một** trong 4 chiến lược DR rồi chứng minh hạ tầng khớp con số RTO/RPO đã cam kết; versioning, replication, PITR, runbook sống sót cùng sự cố |
| 12 | Exam review | cả 4 domain | **$0** | $0 | tự viết 10 bảng so sánh + ngân hàng câu hỏi thành **dữ liệu máy chấm được**; Query vs Scan, GSI, phân bổ đúng trọng số 4 miền |

**Tổng nếu làm đúng quy trình: dưới $2** cho cả 12 tuần. Con số đó chỉ đúng
nếu bạn `terraform destroy` sau mỗi buổi.

### Ba lab tốn tiền — đặt hẹn giờ điện thoại

- **Tuần 3** (~$0,053/giờ) — ALB tính tiền từ giây đầu, không có bậc miễn phí
- **Tuần 2** (~$0,04/giờ) — Interface Endpoint cho SSM, $0,01/giờ mỗi AZ
- **Tuần 5 nếu bật RDS** (~$0,019/giờ) — bật 2 tiếng, làm xong, xoá ngay

### Một lab nên giữ chạy

**Tuần 6** — nằm trọn trong hạn mức always free và là hiện vật mang đi phỏng vấn.

---

## Quy ước tag và đặt tên

Không phải trang trí. `verify.sh`, `_lib/cleanup.sh`, `find-orphans.sh` và
dynamic inventory của Ansible đều dựa vào đây để tìm đồ của bạn.

### Tag — bắt buộc, đã tự động

`providers.tf` cho sẵn của mỗi lab đã có:

```hcl
default_tags {
  tags = {
    owner = "labs-self"
    lab   = "wXX"
  }
}
```

`default_tags` gắn tag vào **mọi** resource provider tạo ra, không cần nhớ ở
từng resource.

| Tag | Giá trị | Dùng để |
|---|---|---|
| `owner` | `labs-self` | phân biệt đồ của bộ lab này với `../labs/` (dùng `Project=learn`) |
| `lab` | `wXX` | lọc theo tuần: `./_lib/cleanup.sh --lab w03` |

> Tài nguyên trong [`_boundary/`](_boundary/) mang `owner = "labs-self-infra"` —
> **khác chuỗi**, cố ý. Tag filter của AWS so khớp chính xác, nên `cleanup.sh`
> không bao giờ xoá nhầm chính cái hàng rào đang canh nó.

### Đặt tên

Prefix `self-wXX-` cho mọi resource có tên:

```
self-w03-alb          self-w04-assets-<hậu tố ngẫu nhiên>
self-w03-asg          self-w06-api
```

Ba lý do: nhìn console biết ngay của tuần nào; không đụng tên với `../labs/`;
và S3 bucket cần tên duy nhất toàn cầu nên phải có hậu tố ngẫu nhiên
(`random_id` hoặc account id).

### Quy tắc khác, đã ràng buộc trong `CONVENTIONS.md`

- Region cố định **`us-east-1`**. Boundary từ chối mọi region khác.
- Profile **`lab-builder`**, không phải `learn`.
- Mọi lab destroy sạch bằng **một** lệnh `terraform destroy`. Chỗ nào cần xử
  lý thêm (bucket có version, ENI treo) thì đề bài phải nêu ở mục Dọn dẹp.
- Mọi CloudWatch log group phải khai báo `retention_in_days`. Mặc định của AWS
  là **giữ vĩnh viễn**.
- Mọi `aws_iam_role` phải có `permissions_boundary` — hàng rào từ chối tạo
  danh tính không mang boundary. Xem
  [`_boundary/README.md` mục 6a](_boundary/README.md).

---

## Hợp đồng output là gì, và vì sao có nó

Mỗi lab có một bảng trong `README.md`:

| Output | Kiểu | `verify.sh` dùng để |
|---|---|---|
| `bucket_name` | string | gọi `s3api get-bucket-encryption` kiểm tra mã hoá |
| `alb_dns_name` | string | `curl` thật, đếm số instance trả lời |

Đây là **giao diện**, không phải gợi ý. Thiếu một output là `verify.sh` không
chấm được và sẽ dừng với thông báo *"chưa apply / thiếu output `<tên>`"*.

Vì sao thiết kế như vậy:

- **Tách chấm điểm khỏi cách giải.** `verify.sh` không biết bạn dùng
  `aws_lb` hay `aws_alb`, một module hay năm resource rời. Nó chỉ biết
  `alb_dns_name` rồi đi hỏi thẳng AWS. Bạn giải kiểu khác vẫn đạt.
- **Đó là cách hệ thống thật ghép với nhau.** Output của một Terraform module
  chính là API của module đó. Remote state ở tuần 10 đọc đúng những output này.
- **Nó buộc bạn nghĩ về giao diện trước.** Biết trước cần lộ ra cái gì là một
  nửa của thiết kế.

Ngoài ra mọi lab đều có output **`chi_phi`** — một chuỗi ghi giá mỗi giờ và
giá nếu quên một tháng. Đọc dòng đó trước khi gõ `yes`.

---

## Dùng cùng `docs/`

Ba thư mục, ba vai khác nhau. Đừng đọc nhầm thứ tự.

| Nơi | Là gì | Đọc khi nào |
|---|---|---|
| [`../../docs/aws/wXX-*.md`](../../docs/aws/) | lý thuyết SAA của tuần đó | **trước** khi mở đề bài |
| `labs-self/wXX-*/` | đề bài, tự giải | trong buổi lab |
| [`../../docs/notebook/`](../../docs/notebook/) | sổ tay ngắn theo chủ đề, tra nhanh | trong lúc làm, và khi ôn |

Vòng khép kín cho một tuần:

```
docs/aws/wXX-*.md          đọc lý thuyết, hiểu khái niệm
       ↓
labs-self/wXX-*/README.md  đọc đề, tự viết terraform
       ↓
./verify.sh                xanh hết
       ↓
DOI-CHIEU.md               ánh xạ việc vừa làm → ngôn ngữ đề thi,
                           + ba cách khác để giải, + câu hỏi SAA thật
       ↓
docs/notebook/*.md         ghi lại thứ mình vừa hiểu, bằng lời của mình
```

`DOI-CHIEU.md` đọc **sau** khi verify xanh, không đọc trước — nó có mục "Ba
cách khác để giải bài này", và biết trước ba cách thì bạn không còn phải chọn.

Sổ tay hiện có:
[`00-nen-tang`](../../docs/notebook/00-nen-tang.md) ·
[`01-compute`](../../docs/notebook/01-compute.md) ·
[`03-database`](../../docs/notebook/03-database.md) ·
[`05-security`](../../docs/notebook/05-security.md) ·
[`10-chi-phi`](../../docs/notebook/10-chi-phi.md) ·
[`20-cay-quyet-dinh`](../../docs/notebook/20-cay-quyet-dinh.md)

---

## Bố cục thư mục

```
labs-self/
├── CONVENTIONS.md      luật viết lab — đọc trước khi sửa bất cứ gì
├── README.md           file này
├── _boundary/          hàng rào. apply MỘT LẦN bằng profile learn
│   ├── main.tf         boundary + role lab-builder + budget
│   ├── guard.sh        chạy TRƯỚC mỗi buổi lab
│   └── README.md       permission boundary vs SCP vs identity policy
├── _lib/
│   ├── check.sh        thư viện chấm điểm dùng chung cho 12 verify.sh
│   └── cleanup.sh      dọn tàn dư theo tag (dry-run mặc định)
└── wXX-ten-lab/
    ├── README.md       đề bài
    ├── HINTS.md        gợi ý 3 tầng
    ├── DOI-CHIEU.md    nối lab với lý thuyết SAA — đọc SAU khi verify xanh
    ├── verify.sh       trọng tài
    └── terraform/
        ├── versions.tf   cho sẵn
        ├── providers.tf  cho sẵn (profile + region + default_tags)
        └── main.tf       TRỐNG — phần việc của bạn
```

---

## Khi có sự cố

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| `AccessDenied` … `explicit deny in a permissions boundary policy` | hàng rào chặn — **bài đang đi sai hướng**, có cách rẻ hơn. Xem [`_boundary/README.md` mục 5](_boundary/README.md) |
| `AccessDenied` … `no identity-based policy allows` | policy bạn tự viết thiếu — sửa `main.tf` của bạn |
| `AccessDenied` khi tạo `aws_iam_role` | thiếu `permissions_boundary` trên role đó |
| `AccessDenied` khi sửa trust policy / gắn policy cho user | tên resource chưa có prefix `self-wXX-` — boundary có điều kiện theo prefix |
| `AccessDenied` khi tạo access key | chặn tuyệt đối, không có ngoại lệ. Bạn đang chọn **user** ở chỗ nên chọn **role** |
| `verify.sh`: *chưa apply / thiếu output `<tên>`* | chưa `apply`, hoặc chưa khai báo output trong Hợp đồng output |
| `ansible: could not initialize the preferred locale` | quên `source ../env.sh` |
| `terraform destroy` báo bucket không rỗng | bucket có versioning — xoá hết version, hoặc `force_destroy` |
| Hoá đơn bất ngờ | `../scripts/find-orphans.sh --all` — thủ phạm thường ở region bạn quên |
| `guard.sh` báo BÁO ĐỘNG ĐỎ | bạn đang là root. **Mọi hàng rào đều vô hiệu.** Dừng lại |
