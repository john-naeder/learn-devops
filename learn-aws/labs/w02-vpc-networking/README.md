# Tuần 2 — VPC, xương sống của mọi câu hỏi

`Domain 1 · Security` `Domain 2 · Resilient`

| | |
|---|---|
| **Chi phí** | **~$0,04/giờ** → lab 3 tiếng ≈ **$0,12** |
| **Để quên 1 tháng** | **~$30** ← lý do phải destroy |
| **Thời gian** | ~3 giờ |
| **Dọn dẹp** | `cd terraform && terraform destroy` |

> ⚠️ Đây là lab **thứ hai** tốn tiền nhất cả khóa (sau tuần 3). Đặt hẹn giờ điện thoại
> ngay khi `apply` xong.

---

## Vì sao lab này tốn tiền, và vì sao vẫn nên trả

Plan yêu cầu: *"Launch một `t3.micro` ở private subnet và kết nối vào bằng SSM Session
Manager — không cần bastion, không cần public IP, không cần SSH key."*

Nghe thì miễn phí. Thực tế không phải. SSM Agent trên máy phải nói chuyện được với ba
endpoint dịch vụ (`ssm`, `ssmmessages`, `ec2messages`). Từ một private subnet không có
đường ra, chỉ có hai cách:

| Cách | Giá/giờ | Giá/tháng | Lab 3 tiếng |
|---|---|---|---|
| NAT Gateway | $0,045 | ~$33 | $0,14 |
| **3 Interface Endpoint** | **$0,03** | ~$65 | **$0,09** |

Lab này chọn Interface Endpoint, và **chỉ đặt ở một AZ** để giảm nửa chi phí.

Đây không phải chi tiết vặt — nó là **nguyên văn một câu hỏi thi**. Ba khái niệm bị trộn
lẫn liên tục trong đề SAA:

| | Cơ chế | Giá |
|---|---|---|
| **Gateway Endpoint** (S3, DynamoDB) | Chèn route vào route table | **MIỄN PHÍ** |
| **Interface Endpoint** (mọi dịch vụ khác) | Tạo ENI trong subnet | $0,01/giờ/AZ |
| **NAT Gateway** | Dịch địa chỉ ra internet | $0,045/giờ + $0,045/GB |

Thấy đề hỏi *"private subnet gọi S3, chi phí thấp nhất"* → **Gateway Endpoint**.
Không bao giờ là NAT Gateway.

---

## Chạy

```bash
source ../../env.sh
cd terraform
terraform init
terraform apply                    # đọc output "chi_phi_moi_gio" trước khi gõ yes

# Đợi ~90 giây cho SSM Agent đăng ký, rồi:
cd .. && ./verify.sh               # kiểm chứng từ NGOÀI

cd ansible
ansible-inventory --graph          # xem AWS trả về máy nào
ansible-playbook site.yml          # kiểm chứng từ TRONG máy
```

Vào thẳng máy bằng tay:

```bash
cd terraform && eval "$(terraform output -raw ssm_session_command)"
```

---

## Hạ tầng

```
VPC 10.0.0.0/16
│
├── public  10.0.0.0/24  (us-east-1a)  ─┐
├── public  10.0.1.0/24  (us-east-1b)  ─┴─→ route 0.0.0.0/0 → Internet Gateway
│
├── private 10.0.10.0/24 (us-east-1a)  ─┐  KHÔNG có route ra internet
├── private 10.0.11.0/24 (us-east-1b)  ─┘
│
├── S3 + DynamoDB Gateway Endpoint      MIỄN PHÍ
├── ssm/ssmmessages/ec2messages         ~$0,03/giờ  ← chỗ tốn tiền
│   (Interface Endpoint, chỉ 1 AZ)
├── NACL chặn port 8080                 sinh REJECT cho Flow Logs
└── Flow Logs → CloudWatch (giữ 1 ngày)

EC2 t3.micro trong private subnet:
  không public IP · không SSH key · SG không có rule inbound nào · IMDSv2 bắt buộc
```

---

## Bốn thứ playbook chứng minh cho bạn thấy

Ansible ở đây **không dựng hạ tầng** — Terraform làm rồi. Nó vào trong máy và kiểm chứng:

1. **Không ra được internet.** `curl https://example.com` phải thất bại. Nếu thành công
   nghĩa là bạn lỡ bật NAT ở đâu đó và đang đốt $33/tháng — playbook sẽ hét lên.
2. **Vẫn đọc được S3.** `aws s3 cp` thành công qua Gateway Endpoint. Không internet mà
   vẫn tới được S3 — đây là ý chính của cả tuần.
3. **IMDSv2 được ép buộc.** IMDSv1 trả `401`, IMDSv2 trả instance ID.
4. **Sinh traffic bị NACL chặn** để bạn tìm được bản ghi `REJECT` trong Flow Logs.

### Một chi tiết đáng chú ý về chính Ansible

Playbook **không có task nào cài package**. Không phải vì lười — mà vì `dnf install`
cần internet, và máy này không có. Ansible vẫn điều khiển được máy vì nó đi qua SSM,
còn `dnf` thì không có đường ra.

Đó là minh hoạ sống động cho việc **thiết kế mạng quyết định thứ bạn làm được**.
Trong đời thật bạn sẽ giải bằng: nướng sẵn package vào AMI (Image Builder), hoặc dùng
repo mirror nội bộ, hoặc chấp nhận trả tiền NAT.

---

## Cách Ansible vào được máy không có SSH

```yaml
ansible_connection: amazon.aws.aws_ssm
```

Không SSH key. Không bastion. Không public IP. Security group **không mở port nào**.

Cơ chế ngược với trực giác: SSM Agent trên máy **chủ động gọi ra** endpoint, rồi lệnh
được đẩy ngược lại qua kênh đó. Vì là chiều outbound nên không cần mở inbound gì cả.

Plugin cần một bucket S3 làm kênh chuyển file — chính bucket Terraform đã tạo, và traffic
đó cũng đi qua Gateway Endpoint. Tên bucket được đọc bằng `lookup('pipe', 'terraform output')`
chứ không phải `set_fact`, vì **biến kết nối được đánh giá trước cả task đầu tiên**.

---

## Kiến thức thi

### Security Group vs Network ACL — câu hỏi kinh điển

| | Security Group | Network ACL |
|---|---|---|
| Mức | ENI (instance) | Subnet |
| Trạng thái | **Stateful** — cho chiều đi thì chiều về tự động được | **Stateless** — phải viết rule cả hai chiều |
| Rule | Chỉ **Allow** | Có cả **Allow và Deny** |
| Xét | Tất cả rule cùng lúc | Theo **số thứ tự**, khớp đầu tiên là dừng |
| Mặc định | Chặn hết inbound, mở hết outbound | Cho hết cả hai chiều |

Trong `main.tf` có một rule bạn nên thử xoá đi để tự thấy hậu quả:

```hcl
resource "aws_network_acl_rule" "allow_out" {   # ← xoá cái này rồi apply
```

NACL stateless nên bỏ rule outbound đi là máy không gọi được SSM nữa → **bạn mất luôn
đường vào máy**. Bài học đắt giá nhưng miễn phí. (Sửa lại rồi apply là hồi phục.)

### Public subnet khác private subnet ở đâu?

**Chỉ ở route table.** Không có checkbox "public" nào cả.

- Public: có route `0.0.0.0/0 → Internet Gateway`
- Private: không có route đó

Hai subnet giống hệt nhau về mọi mặt còn lại. Đề thi rất thích hỏi kiểu
*"instance trong public subnet không ra được internet, vì sao"* — đáp án thường là
thiếu route, thiếu public IP, hoặc NACL chặn.

### IMDSv2 vì sao quan trọng

IMDSv1 cho lấy credential của role chỉ bằng một `GET` tới `169.254.169.254`.
Nếu ứng dụng dính lỗ hổng SSRF, kẻ tấn công đọc được credential đó.
IMDSv2 bắt buộc `PUT` lấy token trước — SSRF thường không gửi `PUT` được.

---

## Checklist

- [ ] `terraform apply` xong, đã đọc output `chi_phi_moi_gio`
- [ ] Đặt hẹn giờ điện thoại
- [ ] `./verify.sh` — 6/6 đúng
- [ ] `ansible-playbook site.yml` — cả 4 assert đều pass
- [ ] Vào máy bằng `aws ssm start-session`, tự gõ `curl example.com` thấy nó treo
- [ ] Tìm được bản ghi `REJECT` trong Flow Logs
- [ ] Thử xoá rule `allow_out` để thấy NACL stateless nghĩa là gì
- [ ] Giải thích được ba loại endpoint và giá của chúng
- [ ] **`terraform destroy` — và chạy `../../scripts/find-orphans.sh` xác nhận sạch**

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
cd ../.. && ./scripts/find-orphans.sh
```

VPC không mất tiền nên plan gốc bảo giữ lại. Nhưng ở đây **cứ destroy hết**: module VPC
đã nằm trong `_modules/lab-vpc`, tuần 3 sẽ dựng lại trong 40 giây. Giữ lại chỉ tạo rủi ro
quên mất Interface Endpoint đang chạy.
