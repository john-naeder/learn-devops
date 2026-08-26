# Gợi ý — tuần 2

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Chia bài thành bốn khối, làm và verify từng khối một. Đừng viết hết rồi mới apply.

**Khối 1 — bộ xương mạng.** Dải địa chỉ, bốn subnet (2 công khai + 2 riêng tư,
mỗi AZ một cặp), một cổng ra internet cho tầng công khai, hai bảng định tuyến.
Nhớ điều này: **thứ duy nhất phân biệt subnet công khai với subnet riêng tư là
bảng định tuyến của nó.** Không có ô tick "public" nào cả. Sau khối này,
`verify.sh` nhóm "hình dạng mạng" phải xanh.

**Khối 2 — máy chủ.** Một instance nhỏ nhất, đặt vào subnet riêng tư, không xin
IP công khai. Nó sẽ chưa làm được gì — đúng như dự kiến. Sau khối này nhóm
"máy chủ" xanh, nhóm "vào được máy" vẫn đỏ.

**Khối 3 — ba con đường.** Đây là phần khó và là toàn bộ bài học. Ba yêu cầu 4,
5, 6 cần ba đích đến khác nhau:
- *chạy lệnh từ laptop* → đích là các API endpoint của dịch vụ quản lý máy của AWS
- *tải danh sách gói* → đích là repo của distro. **Repo của distro nằm ở đâu?**
  Câu hỏi này quyết định cả lab. Với một số distro, câu trả lời làm bài toán sập
  xuống thành miễn phí. Với distro khác thì không.
- *đọc kho object* → đích là một dịch vụ AWS có loại endpoint riêng, miễn phí

**Khối 4 — bằng chứng.** Ghi lại lưu lượng, đặt thời hạn lưu.

Khái niệm cần tra: `CIDR`, `route table`, `internet gateway`, `VPC endpoint`
(hai loại — chúng khác nhau về cả cơ chế lẫn giá), `Systems Manager Session
Manager`, `instance profile`, `IMDSv2`, `VPC Flow Logs`, `egress-only internet
gateway`.

Đọc kèm: `docs/aws/w02-vpc-networking.md` mục 2, 3, 4, 7.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Vào được máy mà không mở port nào.** Ba lựa chọn:

| | Cần gì | Giá |
|---|---|---|
| Bastion host ở subnet công khai | thêm 1 EC2 + 1 IP công khai + khoá SSH | ~$11/tháng, và vẫn có một cửa mở |
| EC2 Instance Connect Endpoint | không cần agent, chỉ SSH qua | $0 |
| Systems Manager Session Manager | agent trên máy + role + đường ra tới 3 endpoint | $0 phí dịch vụ |

Đề nói "không dùng khoá SSH" — câu đó loại hai trong ba. Cái còn lại cần **hai
thứ**: máy phải có quyền gọi API (nhớ tuần 1: quyền cho máy thì đi qua cái gì?),
và máy phải **gọi ra được** tới ba endpoint dịch vụ. Chú ý chiều: agent gọi ra,
AWS không gọi vào. Đó là lý do security group không cần rule inbound nào.

**Tải danh sách gói phần mềm.** Câu hỏi quyết định: repo mặc định của distro bạn
chọn nằm ở đâu?
- Amazon Linux 2023: repo nằm trong một dịch vụ lưu trữ object của AWS, **trong
  cùng region**.
- Ubuntu/Debian: repo nằm ở `archive.ubuntu.com`, một máy chủ trên internet công cộng.

Nếu bạn đã có một con đường miễn phí tới dịch vụ lưu trữ object đó, thì với distro
thứ nhất bài này miễn phí. Với distro thứ hai bạn cần một đường ra internet thật.
**Đây là lựa chọn kiến trúc, không phải chi tiết vặt** — và nó là dạng câu hỏi
Domain 4 rất hay gặp.

**Đường ra internet thật, mà không phải NAT Gateway.** Ba lựa chọn:
- NAT instance tự dựng: một EC2 nhỏ làm router. Rẻ hơn NAT Gateway (~$3,8/tháng)
  nhưng bạn phải tự vá, tự lo HA, tự tắt source/dest check. Đề thi hỏi về nó
  chủ yếu để so sánh.
- Interface Endpoint cho từng dịch vụ AWS: không phải "internet", chỉ tới đúng
  dịch vụ đó. $0,01/giờ/AZ mỗi cái.
- Một cổng ra **chỉ cho chiều đi**, dành riêng cho một họ giao thức. Miễn phí
  hoàn toàn. Câu hỏi tự kiểm: AWS có bao nhiêu họ giao thức địa chỉ, và bạn đang
  chỉ dùng một trong số đó?

**Đọc kho object từ trong VPC.** Có đúng hai dịch vụ AWS hỗ trợ loại endpoint
miễn phí. Kho object là một trong hai. Tra `Gateway Endpoint` và so với
`Interface Endpoint` — chúng gắn vào hai chỗ hoàn toàn khác nhau trong VPC (một
cái gắn vào *bảng định tuyến*, một cái tạo *card mạng* trong subnet). Hiểu chỗ
gắn là hiểu vì sao một cái miễn phí.

**Ghi lại lưu lượng.** Có ba đích đến: CloudWatch Logs, S3, Kinesis Data Firehose.
Với lab thì cái nào cũng được, nhưng `verify.sh` yêu cầu một `flow_log_group`,
nên chọn cái có "log group". Đừng quên đặt thời hạn lưu — mặc định là **vĩnh viễn**.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**Lỗi 1 — máy chạy nhưng không bao giờ xuất hiện trong `describe-instance-information`.**
Ba nguyên nhân, theo thứ tự hay gặp:
1. Máy chưa có instance profile, hoặc role thiếu policy quản lý
   `AmazonSSMManagedInstanceCore`. Kiểm tra bằng
   `aws ec2 describe-instances --query 'Reservations[].Instances[].IamInstanceProfile'`.
2. Agent không gọi ra được. Cần **cả ba** endpoint: `ssm`, `ssmmessages`,
   `ec2messages`. Thiếu `ssmmessages` thì máy hiện Online nhưng Session Manager
   treo — triệu chứng gây bối rối nhất của lab này.
3. Interface Endpoint chưa bật DNS riêng, nên tên miền dịch vụ vẫn phân giải ra
   IP công cộng. Tra `private_dns_enabled`, và kiểm tra VPC đã bật
   `enable_dns_hostnames` lẫn `enable_dns_support` chưa. Mặc định của Terraform
   khác mặc định của console.

**Lỗi 2 — Gateway Endpoint tạo xong mà máy vẫn không đọc được kho object.**
Gateway Endpoint hoạt động bằng cách chèn một route vào **bảng định tuyến**. Bạn
phải nói cho nó biết chèn vào bảng nào. Nếu bạn chỉ tạo endpoint mà không gắn
`route_table_ids` thì nó không làm gì cả và cũng không báo lỗi.

**Lỗi 3 — `dnf` treo rồi timeout.**
Nếu bạn đi đường gateway endpoint: kiểm tra bạn dùng đúng Amazon Linux 2023 chứ
không phải Ubuntu. Nếu bạn dùng Ubuntu thì `archive.ubuntu.com` không nằm trong
kho object của AWS và không có đường nào tới đó.
Nếu bạn đi đường IPv6: kiểm tra máy đã thật sự **nhận** địa chỉ IPv6 chưa
(`ip -6 addr`), và subnet đã bật gán IPv6 tự động chưa. Cấp IPv6 cho VPC không
tự động cấp cho subnet, và cấp cho subnet không tự động gán cho instance.

**Lỗi 4 — check IMDS trả về 200 thay vì 401.**
Máy đang cho phép cả kiểu truy vấn cũ. Tra `metadata_options` và giá trị
`http_tokens`. Mặc định của AWS vẫn là `optional` vì lý do tương thích ngược.

**Lỗi 5 — `terraform destroy` treo ở bước xoá subnet hoặc VPC.**
Có ENI mà Terraform không biết. Interface Endpoint tạo ENI; xoá endpoint thì ENI
đi theo, nhưng nếu bạn xoá tay giữa chừng thì ENI ở lại. Xem lệnh dò trong mục
Dọn dẹp của README.

**Lỗi 6 — Flow Log tạo xong mà log group rỗng.**
Hai khả năng: role của flow log thiếu quyền ghi vào CloudWatch Logs (flow log
cần một role riêng, trust `vpc-flow-logs.amazonaws.com`), hoặc bạn đang chờ chưa
đủ — flow log gom theo cửa sổ 10 phút hoặc 1 phút tuỳ `max_aggregation_interval`.

**Resource Terraform cần tra:** `aws_vpc`, `aws_subnet`, `aws_internet_gateway`,
`aws_egress_only_internet_gateway`, `aws_route_table`, `aws_route`,
`aws_route_table_association`, `aws_vpc_endpoint` (chú ý `vpc_endpoint_type`),
`aws_security_group`, `aws_instance` (chú ý `metadata_options`),
`aws_iam_instance_profile`, `aws_flow_log`, `aws_cloudwatch_log_group`,
`data.aws_ami`, `data.aws_availability_zones`.

Cú pháp lạ duy nhất bạn có thể cần — lấy AMI Amazon Linux 2023 mới nhất mà không
hard-code ID (AMI ID khác nhau theo region và đổi mỗi lần AWS phát hành bản mới):

```hcl
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
```

**Docs:**
- VPC endpoint: <https://docs.aws.amazon.com/vpc/latest/privatelink/concepts.html>
- Session Manager cần endpoint nào: <https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html>
- Egress-only internet gateway: <https://docs.aws.amazon.com/vpc/latest/userguide/egress-only-internet-gateway.html>
- IMDSv2: <https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html>

</details>
