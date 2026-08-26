# Labs — 12 tuần thực hành

Mỗi lab bám đúng một tuần trong [`../aws-saa-plan.md`](../aws-saa-plan.md).

---

## Trước khi bắt đầu

```bash
# Một lần duy nhất
../scripts/setup-tools.sh          # Terraform + Ansible + AWS CLI + session-manager-plugin
aws configure --profile learn      # region: us-east-1, output: json

# Mỗi phiên làm việc
source ../env.sh                   # PATH + locale + AWS_PROFILE + AWS_REGION
```

> `env.sh` cũng sửa một vấn đề riêng của máy này: shell đang set `LC_ALL=en_US.UTF-8`
> nhưng WSL không có locale đó, và **Ansible từ chối chạy** nếu locale không tồn tại.
> Quên `source env.sh` thì Ansible báo *"could not initialize the preferred locale"*.

---

## Vòng đời một buổi lab

```bash
cd wXX-ten-lab

cd terraform
terraform init
terraform apply           # ĐỌC output "chi_phi" TRƯỚC KHI gõ yes

cd ../ansible
ansible-playbook site.yml

cd ..
./verify.sh               # kiểm chứng khách quan, không phải cảm giác

cd terraform
terraform destroy         # CHƯA DESTROY THÌ BUỔI LAB CHƯA XONG
```

Cuối ngày:

```bash
../scripts/find-orphans.sh      # còn gì đang đốt tiền không
../scripts/cost-check.sh        # hôm nay tiêu bao nhiêu
```

---

## Bảng lab

| Tuần | Lab | Chi phí khi chạy | Để quên 1 tháng | Trọng tâm |
|---|---|---|---|---|
| 1 | [IAM foundations](w01-iam-foundations/) | **$0** | $0 | Identity/resource/trust policy, Policy Simulator |
| 2 | [VPC networking](w02-vpc-networking/) | **$0,04/giờ** | **~$30** | Subnet, endpoint, SG vs NACL, SSM không SSH |
| 3 | [EC2 · ALB · ASG](w03-ec2-alb-asg/) | **$0,053/giờ** | **~$39** | Self-healing, health check, launch template |
| 4 | [S3 · CloudFront](w04-s3-cloudfront/) | ~$0 | ~$0 | OAC, lifecycle, versioning, delete marker |
| 5 | [Databases](w05-databases/) | $0 · **$0,019/giờ** nếu bật RDS | ~$14 | Query vs Scan, GSI, TTL, Streams |
| 6 | [Serverless API](w06-serverless-api/) | **$0** | $0 | API GW → Lambda → DynamoDB, cold start |
| 7 | [Decoupling](w07-decoupling/) | **$0** | $0 | SNS fanout, DLQ, visibility timeout, Step Functions |
| 8 | [DNS · CDN · edge](w08-dns-cdn-edge/) | ~$0 · **$1/tháng** nếu bật Route 53 | $1 | Cache key, CloudFront Functions, routing policy |
| 9 | [Security deep](w09-security-deep/) | **$0** | $0 | AssumeRole, permission boundary, explicit Deny |
| 10 | [Observability · IaC](w10-observability-iac/) | **$0** | $0 | Alarm thật, p99, Logs Insights, remote state |
| 11 | [DR · hybrid](w11-dr-hybrid/) | **$0** | $0 | 4 chiến lược DR, 7R, hybrid — **tài liệu, không code** |
| 12 | [Exam review](w12-exam-review/) | **$0** | $0 | 10 bảng so sánh + thi thử — **tài liệu** |

**Tổng nếu làm đúng quy trình: dưới $2** cho cả 12 tuần.
Con số đó chỉ đúng nếu bạn `terraform destroy` sau mỗi buổi.

### Ba lab tốn tiền — đặt hẹn giờ điện thoại

- **Tuần 3** (~$0,053/giờ) — ALB tính tiền từ giây đầu, không có bậc miễn phí
- **Tuần 2** (~$0,04/giờ) — 3 Interface Endpoint cho SSM
- **Tuần 5 nếu bật RDS** (~$0,019/giờ) — bật 2 tiếng, lấy $20 credit, xoá

### Một lab NÊN giữ chạy

**Tuần 6** — nằm trọn trong hạn mức always free và là hiện vật mang đi phỏng vấn.

---

## Cấu trúc mỗi lab

```
wXX-ten-lab/
├── README.md          mục tiêu, chi phí, kiến thức thi, checklist
├── verify.sh          kiểm chứng khách quan từ bên ngoài
├── terraform/         hạ tầng
│   ├── versions.tf    khoá phiên bản provider
│   ├── providers.tf   default_tags Project=learn
│   ├── variables.tf   biến + validation chặn lựa chọn đắt tiền
│   ├── main.tf
│   └── outputs.tf     luôn có output "chi_phi"
└── ansible/           vận hành
    ├── ansible.cfg
    ├── inventory/
    └── site.yml
```

---

## Terraform và Ansible làm gì

Ranh giới trong repo này rõ ràng và cố ý:

| | Terraform | Ansible |
|---|---|---|
| Trả lời câu hỏi | **Hạ tầng nào tồn tại?** | **Nó đang hoạt động ra sao?** |
| Tần suất chạy | Dựng một lần, hiếm khi đổi | Nhiều lần mỗi ngày |
| Có state | Có — biết cái gì đang tồn tại | Không — mô tả trạng thái mong muốn |

**Ansible làm hai vai tuỳ tuần:**

| Vai | Tuần | Cụ thể |
|---|---|---|
| **Config management trên EC2** | 2, 3 | Cấu hình OS qua **SSM, không dùng SSH** |
| **Vận hành / kiểm chứng** | 1, 4–10 | Chạy test, đo đạc, gây sự cố có kiểm soát, audit |

Các tuần serverless không có OS nào để cấu hình. Thay vì bịa ra playbook giả để cho đủ bộ,
Ansible ở đó làm đúng việc một kỹ sư vận hành làm sau mỗi lần deploy: **kiểm thử, đo, và
gây sự cố có chủ đích để xem hệ thống phản ứng**.

### Vào EC2 không cần SSH

Tuần 2 và 3 dùng connection plugin `amazon.aws.aws_ssm`:

```yaml
ansible_connection: amazon.aws.aws_ssm
```

Không SSH key, không bastion, không public IP, **security group không mở port inbound nào**.
Lệnh đi qua Systems Manager: SSM Agent trên máy **chủ động gọi ra**, nên không cần mở gì cả.
Đây vừa là cách rẻ nhất, vừa là cách an toàn nhất, và là đáp án đúng cho câu hỏi thi
*"truy cập instance private mà không mở SSH"*.

Inventory là **động** (`amazon.aws.aws_ec2`) — Ansible hỏi thẳng AWS xem có máy nào,
lọc theo tag `Project=learn`. Cần thiết ở tuần 3 vì ASG tạo và huỷ máy liên tục.

---

## Guardrail chi phí nhúng trong code

Không phải trang trí — đây là thứ giữ cho hoá đơn dưới $2.

**1. Mọi resource tự có tag**

```hcl
provider "aws" {
  default_tags {
    tags = { Project = "learn", Lab = "wXX-...", ManagedBy = "terraform" }
  }
}
```

Nhờ đó Tag Editor, `find-orphans.sh` và dynamic inventory của Ansible đều tìm được đồ của bạn.

**2. Validation chặn lựa chọn đắt tiền**

```hcl
variable "instance_type" {
  default = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small", "t4g.micro", "t4g.small"], var.instance_type)
    error_message = "Chỉ dùng instance rẻ trong lab."
  }
}
```

**3. Tài nguyên nguy hiểm mặc định TẮT**

| Biến | Mặc định | Giá nếu bật |
|---|---|---|
| `enable_nat` | `false` | ~$33/tháng |
| `enable_rds` | `false` | ~$14/tháng |
| `enable_route53` | `false` | ~$1/tháng |
| `enable_crr` | `false` | nhân đôi lưu trữ + bucket dễ bị quên |
| `enable_guardduty` | `false` | vài đô/tháng sau 30 ngày |
| `bat_lich` (EventBridge) | `false` | log rác |

Muốn bật phải sửa tay và đọc dòng comment ghi giá. **Đó là cố ý.**

**4. Output `chi_phi` ở mọi lab**

```
~$0,0530/giờ (ALB $0,0225 + 2 x EC2 $0,0104 + 2 x IPv4 $0,005).
Lab 3 tiếng ~$0,16. QUÊN 1 THÁNG ~$39.
```

Đọc dòng này trước khi gõ `yes`.

**5. Log retention luôn tường minh**

CloudWatch log group mặc định giữ log **vĩnh viễn**. Mọi log group trong repo đều khai báo
`retention_in_days`. Quét toàn account: `../scripts/set-log-retention.sh 7`

---

## Script dùng chung

| Script | Việc |
|---|---|
| [`setup-tools.sh`](../scripts/setup-tools.sh) | Cài Terraform, Ansible, AWS CLI, session-manager-plugin — **không cần sudo** |
| [`cost-check.sh`](../scripts/cost-check.sh) | Chi tiêu N ngày gần nhất, tách theo service |
| [`find-orphans.sh`](../scripts/find-orphans.sh) | Quét tài nguyên bị bỏ quên. `--all` quét **mọi region** |
| [`set-log-retention.sh`](../scripts/set-log-retention.sh) | Ép retention cho mọi log group |
| [`check-labs.sh`](../scripts/check-labs.sh) | Validate toàn bộ repo — **không cần credential AWS** |

`check-labs.sh` kiểm tra `terraform validate` + `fmt`, `ansible-playbook --syntax-check`,
`bash -n`, và **FQCN của mọi module Ansible có thật sự tồn tại** trong collection đã cài.
Mục cuối bắt được một lỗi thật khi viết repo này: `s3_sync` nằm ở `community.aws`
chứ không phải `amazon.aws`, và `--syntax-check` không phát hiện ra.

---

## Khi có sự cố

| Triệu chứng | Nguyên nhân thường gặp |
|---|---|
| `ansible: could not initialize the preferred locale` | Quên `source ../env.sh` |
| Inventory rỗng, "Could not match supplied host pattern" | Chưa có credential, hoặc chưa `terraform apply`. Chạy `ansible-inventory -vvv --list` để thấy lý do thật |
| `aws_ssm` connection treo | Máy chưa đăng ký với SSM. Đợi ~90 giây sau boot; kiểm tra `verify.sh` |
| API trả 500 mà **log Lambda trống trơn** | Thiếu `aws_lambda_permission` — hàm chưa từng được gọi |
| `terraform destroy` báo bucket không rỗng | Bucket có versioning. Xoá hết version, hoặc dùng `force_destroy` |
| Alarm kẹt ở ALARM mãi | `treat_missing_data` sai — xem tuần 10 |
| Hoá đơn bất ngờ | `./scripts/find-orphans.sh --all` — thủ phạm thường ở region bạn quên |

---

## Tám quy tắc giữ hoá đơn bằng không

Trích từ [plan gốc](../aws-saa-plan.md#8-tám-quy-tắc-giữ-hóa-đơn-bằng-không):

1. **Một region duy nhất** — `us-east-1`
2. **Không dọn dẹp thì buổi lab chưa xong** — kể cả khi đã 1 giờ sáng
3. **Tag `Project=learn` cho mọi thứ** — đã tự động qua `default_tags`
4. **Mở Cost Explorer mỗi sáng, 30 giây** — `./scripts/cost-check.sh`
5. **Thấy Gateway, Cluster, Dedicated, Multi-AZ, Provisioned — tra giá trước khi Create**
6. **Không để EC2 chạy qua đêm**
7. **Retention 7 ngày cho mọi log group** — mặc định là vĩnh viễn
8. **Ưu tiên IaC hơn click chuột** — `terraform destroy` là nút dọn dẹp đáng tin cậy duy nhất
