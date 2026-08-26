# Tuần 2 — Máy không có cửa  (tự viết)

`Domain 1 · Security (30%)` `Domain 2 · Resilient (26%)` `Domain 4 · Cost (20%)`

| | |
|---|---|
| **Chi phí khi chạy** | **~$0,041/giờ** — xem phân tích ở "Hàng rào" |
| **Quên 1 tháng** | **~$30** |
| **Thời gian** | ~4 giờ |
| **Điều kiện** | không bắt buộc lab nào trước, nhưng nên xong `w01-iam-foundations` (bạn sẽ phải gắn role cho máy) |

---

## Bối cảnh

Công ty bạn có một job xử lý ảnh chạy hàng đêm: đọc ảnh gốc từ kho lưu trữ, xử lý,
ghi kết quả trở lại. Job chạy trên một máy chủ Linux.

Đội bảo mật vừa ra một quy định sau sự cố ở công ty đối thủ: **không máy chủ nội bộ
nào được có cửa mở ra internet.** Không port 22 từ bên ngoài, không bastion host,
không địa chỉ IP công khai, không khoá SSH nào tồn tại.

Nhưng bạn vẫn phải vận hành được cái máy đó: khi job lỗi lúc 2 giờ sáng, bạn phải
vào xem log được. Và máy vẫn phải cài được gói phần mềm từ repo chính thức của
distro, vì đội dev cập nhật thư viện xử lý ảnh mỗi tháng.

Phòng tài chính thêm một ràng buộc nữa, và đây là ràng buộc thật chứ không phải
bài tập: **cái máy này giá $7,5/tháng. Đường ra internet cho nó không được đắt hơn
chính nó.**

---

## Yêu cầu

1. **Một mạng riêng của bạn**, dải địa chỉ tự chọn, trải **ít nhất 2 vùng sẵn sàng
   (AZ)**, có tầng công khai và tầng riêng tư tách bạch.
2. **Tầng riêng tư đúng nghĩa riêng tư**: không có đường đi mặc định ra internet
   gateway. Tầng công khai thì có.
3. **Một máy chủ Linux đang chạy ở tầng riêng tư**, không có địa chỉ IP công khai.
4. **Bạn chạy được lệnh trên máy đó từ laptop** mà không mở một port inbound nào,
   không dùng khoá SSH, không dựng máy trung gian.
5. **Máy đó tải được danh sách gói phần mềm từ repo chính thức của distro** —
   `dnf check-update` (hoặc `apt-get update`) phải thành công.
6. **Máy đó liệt kê được nội dung một kho object của bạn.** Kho đó không được
   truy cập ẩn danh từ internet.
7. **Máy đó từ chối truy vấn metadata kiểu cũ** — một request tới dịch vụ metadata
   mà không kèm token phải bị trả về `401`.
8. **Mọi lưu lượng bị từ chối trong mạng để lại dấu vết truy được về sau**, và
   dấu vết đó không được giữ vĩnh viễn.
9. **Không có NAT Gateway nào trong mạng.** Đây là một phần của đề bài, không phải
   trở ngại: bài toán "cho máy ở tầng riêng tư ra ngoài mà không trả $33/tháng"
   chính là Domain 4 của đề thi, và nó có ít nhất hai lời giải đúng.

> Yêu cầu 4, 5, 6 nhìn thì giống nhau — đều là "máy riêng tư nói chuyện được với
> bên ngoài". Chúng **không** giống nhau. Ba đích đến đó nằm ở ba chỗ khác nhau
> trên mạng AWS, và giá của ba con đường chênh nhau hàng chục lần. Nhận ra điều đó
> là toàn bộ nội dung của lab này.

---

## Hợp đồng output

| Output | Kiểu | `verify.sh` dùng để |
|---|---|---|
| `vpc_id` | string | tra route table, NAT gateway, flow log, đếm AZ |
| `public_subnet_ids` | string, **phân tách bằng dấu phẩy** | kiểm tra tầng công khai có đường ra IGW |
| `private_subnet_ids` | string, phân tách bằng dấu phẩy | kiểm tra tầng riêng tư **không** có đường ra IGW |
| `instance_id` | string | mọi check về máy chủ; chạy lệnh từ xa |
| `bucket_name` | string | kiểm tra máy đọc được kho; thử truy cập ẩn danh từ internet |
| `flow_log_group` | string | kiểm tra dấu vết lưu lượng và retention |
| `chi_phi` | string | in ra trước khi gõ `yes` |

Danh sách subnet phải là **một chuỗi**, vì `terraform output -raw` không đọc được
list. Dùng `join(",", ...)`.

---

## Hàng rào của lab này

### Trần chi phí

| Thành phần | Giá | 1 tháng |
|---|---|---|
| EC2 `t3.micro` | $0,0104/giờ | $7,59 |
| EBS gp3 8 GB | $0,00089/giờ | $0,64 |
| 3 × Interface Endpoint, 1 AZ | $0,03/giờ | $21,90 |
| Gateway Endpoint | **$0** | **$0** |
| VPC, subnet, route table, IGW, security group, NACL | **$0** | **$0** |
| Flow Logs vào CloudWatch, vài MB | ~$0 | ~$0,05 |
| **Tổng nếu đi đường Interface Endpoint** | **~$0,041/giờ** | **~$30** |

**Lab 4 tiếng ≈ $0,17.** Quên một tháng ≈ **$30** — đắt hơn cả tuần 3.

### Cách làm rẻ nhất

Có một con đường ra internet của AWS **hoàn toàn miễn phí**, không tính giờ, không
tính GB. Nó chỉ hoạt động với một họ giao thức nhất định, và vì thế nhiều người
không nghĩ tới. Đi đường đó thì lab còn **~$0,011/giờ (~$8,3/tháng)** — tức là chỉ
còn tiền máy, đúng như phòng tài chính yêu cầu.

Gợi ý để tự tìm: bảng giá VPC có đúng ba dòng ghi "$0.00". Bạn đã dùng một dòng
(gateway endpoint). Còn hai dòng nữa.

Nếu bạn chọn đường Interface Endpoint: **đặt endpoint ở đúng MỘT subnet**, không
phải cả hai AZ. Giá tính theo endpoint × AZ. Hai AZ là nhân đôi $21,90 thành
$43,80/tháng mà không đổi gì cho bài học.

### Boundary chặn gì, vì sao

| Boundary chặn | Vì sao |
|---|---|
| `ec2:CreateNatGateway` | $33/tháng, gấp 4 lần cái máy nó phục vụ. Đây là kẻ giết credit số 1 và cũng là **một phần của đề bài** |
| `ec2:AllocateAddress` (Elastic IP) | $3,6/tháng mỗi IP, tính cả khi không gắn vào đâu. Lab này không cần IP công khai nào |
| `ec2:RunInstances` với instance type ngoài danh sách `t2/t3.micro`, `t3/t4g.small` | một `m5.large` chạy quên một tháng là $70 |
| mọi API ngoài `us-east-1` | tài nguyên bỏ quên ở region lạ là cách đốt credit phổ biến nhất |
| `ec2:CreateVpnGateway`, Transit Gateway, Direct Connect | $36+/tháng, và SAA chỉ hỏi lý thuyết về chúng |

**Gặp `AccessDenied` — boundary hay bug?**

- `...explicit deny in a permissions boundary` khi bạn `apply` một NAT Gateway →
  **đúng như thiết kế**. Đọc lại yêu cầu 9. Đừng tìm cách lách; hãy tìm con đường khác.
- `AccessDenied` khi máy chủ chạy `aws s3 ls` → **bug của bạn**: đó là quyền của
  role gắn vào máy, boundary không đụng tới.
- `UnauthorizedOperation` lúc `RunInstances` → xem lại instance type.
- Máy chạy nhưng `verify.sh` báo không chạy lệnh từ xa được → không phải boundary.
  Đó là đường mạng: SSM Agent trên máy **chủ động gọi ra**, nên nếu nó không gọi
  ra được thì bạn chưa mở đường cho nó.

**Không bao giờ tắt boundary để làm bài.**

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh toàn bộ, gồm cả bốn check phủ định
- [ ] `terraform destroy` sạch trong một lần
- [ ] Nói được **ba con đường** khác nhau mà ba yêu cầu 4, 5, 6 đi qua, và giá
      của từng con đường
- [ ] Trả lời được: nếu ngày mai bạn phải cho máy này gọi một API HTTPS của bên
      thứ ba (không phải AWS), con đường bạn đang dùng còn đủ không? Nếu không
      thì phải thêm gì, và giá bao nhiêu?
- [ ] Giải thích được vì sao security group của máy **không cần một rule inbound
      nào** mà bạn vẫn chạy được lệnh trên đó. Câu trả lời liên quan tới chữ
      *stateful*
- [ ] Chỉ ra được trong Flow Logs một dòng `REJECT` và đọc được nó nói gì
- [ ] Trả lời được: `t3.micro` ở tầng riêng tư, không public IP — vậy nó có tốn
      $3,6/tháng tiền IPv4 không? Vì sao?

---

## Quy trình

```bash
source ../../env.sh
../guard.sh

cd terraform
terraform init
terraform apply                 # đọc chi_phi trước khi gõ yes

# Máy cần ~90 giây sau boot mới đăng ký được với Systems Manager.
# verify.sh sẽ chờ, nhưng nếu bạn nóng ruột thì:
aws ssm describe-instance-information --profile lab-builder \
  --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output table

cd .. && ./verify.sh
$PAGER DOI-CHIEU.md             # chỉ mở khi đã xanh hết

cd terraform && terraform destroy
```

`verify.sh` có chạy lệnh **trên máy chủ** của bạn qua Systems Manager (đọc trạng
thái, cập nhật cache gói phần mềm). Nó không đụng vào hạ tầng AWS.

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Ba thứ hay sót lại và cách kiểm tra:

```bash
# 1. Interface Endpoint — tính tiền theo giờ, dễ quên nhất
aws ec2 describe-vpc-endpoints --profile lab-builder \
  --query 'VpcEndpoints[?VpcEndpointType==`Interface`].[VpcEndpointId,ServiceName]' --output table

# 2. ENI treo lại sau khi endpoint hoặc instance bị xoá dở
aws ec2 describe-network-interfaces --profile lab-builder \
  --filters Name=status,Values=available --query 'NetworkInterfaces[].NetworkInterfaceId' --output text

# 3. Log group của Flow Logs — không tốn tiền theo giờ nhưng ăn vào 5 GB miễn phí
aws logs describe-log-groups --profile lab-builder \
  --query 'logGroups[?starts_with(logGroupName, `/aws/vpc`) || starts_with(logGroupName, `self-w02`)].[logGroupName,retentionInDays]' --output table
```

Cả ba lệnh phải không in ra gì của bạn. Nếu `terraform destroy` treo ở bước xoá
VPC, thủ phạm gần như luôn là một ENI mà Terraform không quản lý.
