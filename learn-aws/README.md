# learn-aws — Lộ trình SAA-C03 trong 12 tuần

Kế hoạch học AWS từ số 0 tới chứng chỉ Solutions Architect Associate, kèm 12 lab thực hành
có Terraform và Ansible chạy được.

Thiết kế quanh một ràng buộc cụ thể: account mở sau 15/07/2025 nên dùng **Free Tier mới** —
không còn "750 giờ EC2 miễn phí 12 tháng", chỉ có một túi credit và một đồng hồ đếm ngược.
Mục tiêu chi tiêu cho toàn bộ 12 tuần: **dưới $15**. Nếu làm đúng quy trình dọn dẹp thì
thực tế **dưới $2**.

---

## Bắt đầu từ đâu

```bash
# 1. Cài công cụ (không cần sudo, mọi thứ vào ~/.local)
./scripts/setup-tools.sh

# 2. Cấu hình AWS
aws configure --profile learn        # region: us-east-1, output: json

# 3. Mỗi phiên làm việc
source env.sh
```

Rồi đọc theo thứ tự:

1. **[`aws-saa-plan.md`](aws-saa-plan.md)** — kế hoạch đầy đủ. Đọc phần
   *Free tier*, *Bảng bẫy tiền*, và *Ngày 0* **trước khi tạo tài nguyên đầu tiên**.
2. **[`labs/README.md`](labs/README.md)** — cách dùng lab, quy trình một buổi, guardrail chi phí.
3. **[`labs/w01-iam-foundations/`](labs/w01-iam-foundations/)** — lab đầu tiên, miễn phí hoàn toàn.

> `aws-saa-plan.html` là bản gốc, có thanh tiến độ lưu trong trình duyệt.
> `aws-saa-plan.md` là cùng nội dung, để đọc trong terminal và grep.

---

## Trong repo có gì

```
learn-aws/
├── aws-saa-plan.md          kế hoạch 12 tuần (bản markdown)
├── aws-saa-plan.html        bản gốc, có checklist lưu trong trình duyệt
├── env.sh                   source mỗi phiên: PATH + locale + AWS_PROFILE
│
├── scripts/
│   ├── setup-tools.sh       cài Terraform, Ansible, AWS CLI, session-manager-plugin
│   ├── cost-check.sh        chi tiêu N ngày, tách theo service
│   ├── find-orphans.sh      quét tài nguyên bỏ quên (--all: mọi region)
│   ├── set-log-retention.sh ép retention cho mọi CloudWatch log group
│   └── check-labs.sh        validate toàn repo, không cần credential AWS
│
└── labs/
    ├── README.md            hướng dẫn chung + bảng chi phí từng lab
    ├── _modules/lab-vpc/    module VPC dùng lại cho tuần 2, 3, 5
    ├── w01-iam-foundations/         ┐
    ├── w02-vpc-networking/          │
    ├── w03-ec2-alb-asg/             │
    ├── w04-s3-cloudfront/           │  10 lab có Terraform + Ansible
    ├── w05-databases/               │  + README + verify.sh
    ├── w06-serverless-api/          │
    ├── w07-decoupling/              │
    ├── w08-dns-cdn-edge/            │
    ├── w09-security-deep/           │
    ├── w10-observability-iac/       ┘
    ├── w11-dr-hybrid/       tài liệu: 4 chiến lược DR, 7R, hybrid
    └── w12-exam-review/     10 bảng so sánh + đáp án + chiến thuật phòng thi
```

---

## Cách repo này khác một bộ tutorial

**Chi phí là nội dung học, không phải chú thích.** Mỗi lab in ra chi phí theo giờ, chi phí
cho một buổi 3 tiếng, và chi phí nếu bạn quên tắt một tháng — **trước khi** bạn gõ `yes`.
Mọi tài nguyên đắt tiền (NAT Gateway, RDS, Route 53, GuardDuty) mặc định **tắt** và phải
bật tay sau khi đọc dòng comment ghi giá.

Đây không phải sự tiết kiệm vặt. NAT Gateway đắt gấp bốn lần cái EC2 nó phục vụ — và đó
chính là **Domain 4 của đề thi**. Bạn nhớ nó mãi vì đã tự tay tránh nó.

**Mỗi lab có `verify.sh`.** Kiểm chứng khách quan chứ không phải cảm giác "hình như chạy rồi".
Nó cũng kết thúc bằng vài câu hỏi buộc bạn giải thích *vì sao* mọi thứ hoạt động.

**Sự cố là bài học, không phải tai nạn.** Tuần 3 có `chaos.yml` phá health check để bạn
xem ASG tự chữa lành. Tuần 7 có công tắc ép Lambda lỗi để xem message rơi vào DLQ.
Tuần 10 gây lỗi thật để **điện thoại bạn rung** vì một alarm bạn tự đặt.

**Comment trong code giải thích tại sao, không phải cái gì.** Chỗ nào ra thi đều được đánh
dấu. Chỗ nào là lỗi kinh điển đều được nêu tên.

---

## Terraform và Ansible chia việc thế nào

| | Terraform | Ansible |
|---|---|---|
| Trả lời | **Hạ tầng nào tồn tại?** | **Nó đang hoạt động ra sao?** |
| Chạy | Một lần, hiếm khi đổi | Nhiều lần mỗi ngày |

Ansible đóng hai vai tuỳ tuần: **config management trên EC2** (tuần 2, 3 — qua SSM,
**không dùng SSH**) và **vận hành/kiểm chứng** (các tuần còn lại — chạy test, đo đạc,
gây sự cố có kiểm soát).

Các tuần serverless không có OS nào để cấu hình. Thay vì bịa playbook giả cho đủ bộ,
Ansible ở đó làm đúng việc một kỹ sư vận hành làm sau mỗi lần deploy.

Chi tiết trong [`labs/README.md`](labs/README.md).

---

## Kiểm tra repo còn lành không

```bash
./scripts/check-labs.sh
```

Chạy `terraform validate` + `fmt` trên 11 thư mục, `ansible-playbook --syntax-check` trên
11 playbook, `bash -n` trên mọi script, và xác minh **mọi FQCN Ansible có thật sự tồn tại**
trong collection đã cài. **Không cần credential AWS, không tạo tài nguyên nào.**

Trạng thái hiện tại: toàn bộ đạt, với Terraform 1.9.8 · Ansible core 2.21.3 ·
amazon.aws 11.4.0 · community.aws 11.1.0 · AWS CLI 2.36.23.

---

## Ba mốc phải đặt vào lịch

| Ngày | Việc |
|---|---|
| **10/11/2026** | Còn 3 tháng free plan. Kiểm tra credit, quyết định có lên Paid plan không |
| **10/01/2027** | Còn 1 tháng. Đảm bảo mọi thứ cần giữ đã nằm dưới dạng mã trên GitHub |
| **10/02/2027** | Free plan hết hạn. **Account tự đóng nếu không nâng cấp** — AWS giữ dữ liệu thêm 90 ngày |

Đây chính là lý do tồn tại của thư mục `labs/`: account có ngày hết hạn, repo thì không.
Account chết thì `terraform apply` ở account mới là xong.

---

## Cảnh báo

Giá tham khảo tại `us-east-1` tại thời điểm viết và **có thể thay đổi** — luôn đối chiếu
trang pricing chính thức trước khi tạo tài nguyên.

Code trong repo đã qua `terraform validate` và `ansible-playbook --syntax-check`, nhưng
**chưa từng chạy `terraform apply` lên một account AWS thật**. Lần `apply` đầu tiên của
mỗi lab, hãy đọc kỹ plan trước khi xác nhận.
