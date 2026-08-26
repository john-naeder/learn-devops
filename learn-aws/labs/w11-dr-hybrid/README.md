# Tuần 11 — Di trú, hybrid và khôi phục thảm họa

`Domain 2 · Resilient`

| | |
|---|---|
| **Chi phí** | **~$0** — tuần này chủ yếu là thiết kế và sơ đồ |
| **Vì sao không có thư mục `terraform/`** | Xem ngay dưới đây |

---

## Vì sao lab này không có code

Ba công nghệ trọng tâm của tuần — **Direct Connect**, **Transit Gateway**,
**Site-to-Site VPN** — không lab được:

| | Giá | Ghi chú |
|---|---|---|
| Direct Connect | Cần **cổng vật lý** ở datacenter | Không thể lab bằng bất cứ giá nào |
| Site-to-Site VPN | $0,05/giờ ≈ **$36/tháng** | Cần thiết bị đầu kia |
| Transit Gateway | $0,05/giờ/attachment ≈ **$36+/tháng** | Nhân lên theo số attachment |

Và điều quan trọng: **đề thi không hỏi bạn đã bấm nút nào.** Nó hỏi bạn chọn kiến trúc nào
cho RTO/RPO/ngân sách nào. Đó là kiến thức **thiết kế**, học bằng sơ đồ và bảng.

Hai thứ **lab được** và gần như miễn phí (AWS Backup plan, S3 CRR) có snippet copy-paste
ở cuối trang này.

---

## Bốn chiến lược DR — nội dung thi trọng tâm

Đây là bảng phải thuộc nằm lòng:

| Chiến lược | RTO | RPO | Chi phí | Hạ tầng ở region phụ |
|---|---|---|---|---|
| **Backup & Restore** | **Giờ → ngày** | Giờ | **Thấp nhất** | Không có gì, chỉ có backup |
| **Pilot Light** | **Chục phút** | Phút | Thấp | Dữ liệu đã sao chép + hạ tầng lõi **tắt** |
| **Warm Standby** | **Phút** | Giây | Trung bình | Bản sao **thu nhỏ đang chạy** |
| **Multi-Site Active/Active** | **Gần bằng 0** | Gần bằng 0 | **Cao nhất** | Bản sao **đầy đủ**, phục vụ traffic thật |

### Hai định nghĩa không được lẫn

- **RTO** (Recovery *Time* Objective) — **bao lâu** thì hệ thống chạy lại được.
  *Câu hỏi: chúng ta chịu được downtime bao lâu?*
- **RPO** (Recovery *Point* Objective) — **mất bao nhiêu dữ liệu** là chấp nhận được.
  *Câu hỏi: chúng ta chịu mất dữ liệu của bao nhiêu phút gần nhất?*

Mẹo nhớ: **T**ime = **T**hời gian ngừng. **P**oint = **P**hần dữ liệu mất.

### Sơ đồ bốn cấp

```
BACKUP & RESTORE                         RTO: giờ-ngày   RPO: giờ    $
┌──────────────┐                         ┌──────────────┐
│ Region chính │──── AWS Backup ────────▶│ Region phụ   │
│  ĐANG CHẠY   │      S3 CRR             │  (trống)     │
└──────────────┘                         └──────────────┘
Khi sự cố: dựng lại toàn bộ từ IaC + khôi phục dữ liệu từ backup.


PILOT LIGHT                              RTO: chục phút  RPO: phút   $$
┌──────────────┐                         ┌──────────────┐
│ Region chính │──── replication ───────▶│ RDS replica  │  đang chạy
│  ĐANG CHẠY   │                         │ AMI + IaC    │  đã sẵn sàng
└──────────────┘                         │ EC2/ASG: TẮT │
                                         └──────────────┘
Khi sự cố: promote replica, bật ASG lên, đổi DNS.


WARM STANDBY                             RTO: phút       RPO: giây   $$$
┌──────────────┐                         ┌──────────────┐
│ Region chính │──── replication ───────▶│ Bản THU NHỎ  │
│  ĐANG CHẠY   │                         │  ĐANG CHẠY   │
│              │                         │  (1 máy)     │
└──────────────┘                         └──────────────┘
Khi sự cố: scale up rồi đổi DNS. Hệ thống đã sống sẵn, chỉ thiếu công suất.


MULTI-SITE ACTIVE/ACTIVE                 RTO: ~0         RPO: ~0     $$$$
┌──────────────┐                         ┌──────────────┐
│ Region A     │◀─── 2 chiều ───────────▶│ Region B     │
│ PHỤC VỤ THẬT │                         │ PHỤC VỤ THẬT │
└──────┬───────┘                         └───────┬──────┘
       └────── Route 53 latency/weighted ────────┘
Khi sự cố: health check loại region hỏng. Người dùng gần như không nhận ra.
```

### Cách đề thi hỏi

Đề cho một tình huống kèm **ràng buộc**, rồi hỏi chọn chiến lược nào.
Từ khoá quyết định:

| Từ khoá trong đề | Chiến lược |
|---|---|
| "chi phí thấp nhất", "chấp nhận downtime vài giờ" | **Backup & Restore** |
| "khôi phục trong vòng 30 phút", "ngân sách hạn chế" | **Pilot Light** |
| "downtime tối thiểu", "sẵn sàng trả thêm" | **Warm Standby** |
| "không được downtime", "phục vụ toàn cầu" | **Multi-Site Active/Active** |

---

## Bảy chiến lược di trú (7R)

| Chiến lược | Nghĩa | Ví dụ |
|---|---|---|
| **Rehost** | "Lift and shift" — bê nguyên lên | VM on-prem → EC2 bằng AWS MGN |
| **Replatform** | "Lift, tinker and shift" — chỉnh nhẹ | MySQL tự quản → RDS |
| **Repurchase** | Mua sản phẩm khác thay thế | CRM tự viết → Salesforce |
| **Refactor** | Viết lại kiến trúc | Monolith → serverless |
| **Retire** | Bỏ luôn, không di trú | Ứng dụng không ai dùng nữa |
| **Retain** | Giữ nguyên on-prem | Ràng buộc pháp lý, phần cứng đặc thù |
| **Relocate** | Chuyển nguyên hypervisor | VMware Cloud on AWS |

Đề thi hay hỏi *"cách nhanh nhất để di trú"* → **Rehost**.
*"Tận dụng dịch vụ managed mà ít sửa code nhất"* → **Replatform**.

### Công cụ di trú

| Công cụ | Dùng cho |
|---|---|
| **Application Discovery Service** | Khảo sát on-prem trước khi di trú |
| **Migration Hub** | Bảng điều khiển theo dõi tiến độ |
| **AWS MGN** (Application Migration Service) | **Rehost** server — thay thế SMS |
| **DMS** (Database Migration Service) | Di trú database, **có thể chạy liên tục** |
| **SCT** (Schema Conversion Tool) | Đổi engine (Oracle → PostgreSQL) — đi kèm DMS |
| **DataSync** | Đồng bộ file on-prem ↔ S3/EFS/FSx, có lịch |
| **Transfer Family** | SFTP/FTPS/FTP tới S3 |

**Cặp hay nhầm:** DMS di trú **dữ liệu**; SCT chuyển đổi **schema và mã stored procedure**.
Cùng engine thì chỉ cần DMS. Khác engine thì cần cả hai.

### Chuyển dữ liệu lớn: chọn theo dung lượng và thời gian

| Dung lượng | Cách | Lưu ý |
|---|---|---|
| < vài TB | **DataSync** qua internet/DX | Đơn giản nhất |
| Chục TB → PB | **Snowball Edge** | Thiết bị vật lý gửi qua bưu điện |
| Nhiều PB | **Snowmobile** | Xe container 45 foot |

Quy tắc thực dụng: tính thời gian truyền qua mạng. Nếu **lâu hơn một tuần** thì
Snowball rẻ và nhanh hơn.

---

## Kết nối hybrid

| | Direct Connect | Site-to-Site VPN |
|---|---|---|
| Đường truyền | **Cáp riêng**, không qua internet | **Qua internet**, mã hoá IPsec |
| Băng thông | 1/10/100 Gbps ổn định | Tối đa ~1,25 Gbps mỗi tunnel |
| Độ trễ | **Thấp, ổn định** | Thay đổi theo internet |
| Thời gian thiết lập | **Hàng tuần đến hàng tháng** | **Vài phút** |
| Chi phí | Cao, cam kết dài hạn | Thấp |
| Mã hoá | **Không mặc định** (phải thêm VPN/MACsec) | Có sẵn |

**Mẫu kiến trúc kinh điển ra thi:** Direct Connect làm đường chính, **Site-to-Site VPN
làm dự phòng**. DX cho hiệu năng, VPN cho tính sẵn sàng khi cáp đứt.

Đề hỏi *"cần băng thông ổn định và độ trễ thấp, chấp nhận chờ vài tuần"* → **DX**.
*"Cần kết nối ngay hôm nay"* → **VPN**.

### Transit Gateway vs VPC Peering

| | VPC Peering | Transit Gateway |
|---|---|---|
| Mô hình | Điểm-điểm | **Trung tâm hình sao** |
| Transitive | **KHÔNG** — A↔B, B↔C không cho A↔C | **CÓ** |
| Số kết nối cho N VPC | N(N−1)/2 — bùng nổ | N attachment |
| Giá | **Miễn phí** (chỉ trả data transfer) | $0,05/giờ/attachment |

**Ngưỡng quyết định:** vài VPC thì peering (miễn phí). Chục VPC trở lên thì peering trở
thành mớ bòng bong (10 VPC = 45 kết nối) → Transit Gateway.

### Storage Gateway — ba kiểu

| Kiểu | Giao thức | Dùng cho |
|---|---|---|
| **File Gateway** | NFS/SMB | File on-prem lưu vào S3 |
| **Volume Gateway** | iSCSI | Block storage, backup vào S3 dạng snapshot |
| **Tape Gateway** | iSCSI VTL | **Thay thế thư viện băng từ** vật lý |

Đề hỏi *"thay hệ thống backup băng từ mà không đổi phần mềm backup"* → **Tape Gateway**.

### Outposts, Local Zones, Wavelength

| | Là gì | Dùng khi |
|---|---|---|
| **Outposts** | Tủ rack AWS **đặt tại datacenter của bạn** | Dữ liệu bắt buộc ở tại chỗ, độ trễ cực thấp |
| **Local Zones** | Mở rộng region tới thành phố lớn | Độ trễ một chữ số ms cho thành phố cụ thể |
| **Wavelength** | Nhúng trong mạng 5G của nhà mạng | Ứng dụng di động cần độ trễ cực thấp |

---

## Hai thứ LAB ĐƯỢC — snippet copy-paste

Cả hai gần như miễn phí. Thêm vào bất kỳ lab nào đã có, hoặc tạo thư mục riêng.

### 1. AWS Backup plan cho EBS snapshot theo lịch

```hcl
resource "aws_backup_vault" "lab" {
  name = "w11-vault"
}

resource "aws_backup_plan" "hang_ngay" {
  name = "w11-backup-hang-ngay"

  rule {
    rule_name         = "hang-ngay-giu-7-ngay"
    target_vault_name = aws_backup_vault.lab.name
    schedule          = "cron(0 17 * * ? *)" # 00:00 giờ VN

    lifecycle {
      delete_after = 7 # giữ 7 ngày rồi tự xoá — đừng để backup phình mãi
    }
  }
}

data "aws_iam_policy_document" "backup_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "w11-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_trust.json
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Chọn tài nguyên bằng TAG thay vì liệt kê ARN: tài nguyên mới có tag đúng
# sẽ tự động được backup mà không phải sửa code. Đây là cách làm đúng.
resource "aws_backup_selection" "theo_tag" {
  name         = "moi-thu-co-tag-learn"
  iam_role_arn = aws_iam_role.backup.arn
  plan_id      = aws_backup_plan.hang_ngay.id

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Project"
    value = "learn"
  }
}
```

> **Chi phí:** snapshot tính theo dung lượng thay đổi (~$0,05/GB/tháng).
> Với volume 8 GB của lab thì vài xu. **Nhớ `delete_after`** — không có nó thì backup
> tích luỹ vĩnh viễn.

### 2. S3 Cross-Region Replication — Backup & Restore thu nhỏ

Đã có sẵn và đầy đủ comment trong [tuần 4](../w04-s3-cloudfront/terraform/main.tf):

```bash
cd ../w04-s3-cloudfront/terraform
terraform apply -var enable_crr=true
# kiểm chứng file được nhân bản sang us-west-2
terraform apply -var enable_crr=false    # TẮT NGAY
```

Ba điều kiện bắt buộc của CRR (hay ra thi):
1. **Cả hai** bucket bật versioning
2. Cần IAM role cho S3 assume
3. **Chỉ object tạo SAU khi bật rule** mới được nhân bản — object cũ cần S3 Batch Replication

### 3. Route 53 failover — cơ chế chuyển vùng

Đã có sẵn trong [tuần 8](../w08-dns-cdn-edge/terraform/main.tf) (`enable_route53=true`).
Đây chính là cơ chế "đổi DNS" trong sơ đồ Pilot Light và Warm Standby ở trên.

---

## Bài tập bắt buộc của tuần

1. **Vẽ bốn sơ đồ DR** cho *chính ứng dụng capstone tuần 6* (S3 + CloudFront + API Gateway
   + Lambda + DynamoDB). Với mỗi cấp, ghi rõ:
   - Cần thêm những tài nguyên gì ở region phụ
   - RTO và RPO ước tính
   - **Chi phí hàng tháng ước tính**
   - Các bước cần làm khi sự cố xảy ra

   > Gợi ý thú vị: với kiến trúc serverless này, **Multi-Site Active/Active rẻ hơn nhiều**
   > so với kiến trúc EC2. DynamoDB Global Tables + Lambda ở hai region gần như không tốn
   > thêm gì khi không có traffic. Đó là một lập luận rất mạnh khi đi phỏng vấn.

2. **Đọc trọn vẹn** whitepaper *Disaster Recovery of Workloads on AWS: Recovery in the Cloud*.
   Không lướt. Đây là nguồn trực tiếp của các câu hỏi DR trong đề.

3. Lưu toàn bộ sơ đồ vào `labs/w11-dr-hybrid/so-do/`. Đây là nền cho dự án DR site
   hybrid mà bạn muốn làm sau khi thi xong.

---

## Checklist

- [ ] Thuộc bảng 4 chiến lược DR kèm RTO/RPO/chi phí
- [ ] Phân biệt được RTO và RPO không cần suy nghĩ
- [ ] Vẽ xong 4 sơ đồ DR cho ứng dụng capstone, có ước tính chi phí
- [ ] Thuộc 7R và nhận diện được qua tình huống
- [ ] Phân biệt DMS với SCT
- [ ] Biết ngưỡng chọn Snowball thay vì truyền qua mạng
- [ ] Thuộc bảng Direct Connect vs Site-to-Site VPN
- [ ] Hiểu vì sao VPC Peering **không** transitive và khi nào cần Transit Gateway
- [ ] Nhận diện được ba kiểu Storage Gateway
- [ ] Đã đọc hết whitepaper DR
- [ ] Nếu có bật CRR ở tuần 4: **đã tắt và xoá bucket region phụ**
- [ ] `../../scripts/find-orphans.sh --all` — sạch ở **mọi** region
