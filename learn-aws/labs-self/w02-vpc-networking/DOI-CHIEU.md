# Đối chiếu — tuần 2

> Đọc sau khi `./verify.sh` xanh.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong đề | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1 — dải địa chỉ, 4 subnet, 2 AZ | CIDR, chia subnet, AZ là đơn vị của tính sẵn sàng | [CIDR và chia subnet](../../../docs/aws/w02-vpc-networking.md#1-cidr-và-chia-subnet) · [Cách chia thực dụng](../../../docs/aws/w02-vpc-networking.md#cách-chia-thực-dụng) |
| 2 — tầng riêng tư đúng nghĩa | **route table là thứ duy nhất phân biệt public với private** | [Public subnet vs private subnet](../../../docs/aws/w02-vpc-networking.md#2-public-subnet-vs-private-subnet) · [Route table](../../../docs/aws/w02-vpc-networking.md#route-table) |
| 3 — máy không có IP công khai | ENI, public IPv4 và giá của nó | [ENI và Elastic IP](../../../docs/aws/w02-vpc-networking.md#6-eni-và-elastic-ip) |
| 4 — chạy lệnh không mở port | Session Manager, security group **stateful**, chiều gọi ra | [Security Group vs NACL](../../../docs/aws/w02-vpc-networking.md#5-security-group-vs-network-acl) · [Hai điều quan trọng nhất](../../../docs/aws/w02-vpc-networking.md#hai-điều-quan-trọng-nhất) |
| 5 — tải gói phần mềm | đường ra internet: NAT Gateway / NAT instance / egress-only IGW; và nơi repo distro thật sự nằm | [NAT Gateway vs NAT Instance](../../../docs/aws/w02-vpc-networking.md#4-nat-gateway-vs-nat-instance--và-cái-bẫy-chi-phí) |
| 6 — đọc kho object từ trong VPC | **Gateway Endpoint** (miễn phí) vs Interface Endpoint (tính giờ) | [VPC Endpoint](../../../docs/aws/w02-vpc-networking.md#7-vpc-endpoint--gateway-vs-interface) · [Vì sao Gateway Endpoint miễn phí](../../../docs/aws/w02-vpc-networking.md#vì-sao-gateway-endpoint-miễn-phí) |
| 7 — metadata phải có token | IMDSv2, và vì sao nó chống SSRF | [IMDSv2](../../../docs/aws/w03-ec2-alb-asg.md#vì-sao-imdsv2-bắt-buộc) · [IMDSv2 trong bài IAM](../../../docs/aws/w01-iam-foundations.md#imdsv2--và-vì-sao-nó-bắt-buộc) |
| 8 — dấu vết lưu lượng | VPC Flow Logs, và retention mặc định là **vĩnh viễn** | [VPC Flow Logs](../../../docs/aws/w02-vpc-networking.md#10-vpc-flow-logs) |
| 9 — không NAT Gateway | Domain 4: bài toán chi phí kinh điển nhất của VPC | [Cái bẫy chi phí](../../../docs/aws/w02-vpc-networking.md#cái-bẫy-chi-phí) · [Ba con đường, ba mức giá](../../../docs/aws/w02-vpc-networking.md#ba-con-đường-ba-mức-giá) |

### Ba đích đến, ba con đường, ba mức giá

Đây là bảng đáng chép ra giấy:

| Máy riêng tư muốn tới | Con đường rẻ nhất | Giá | Vì sao |
|---|---|---|---|
| S3, DynamoDB | **Gateway Endpoint** | **$0** | chỉ là một route trong route table, không có hạ tầng nào được dựng riêng cho bạn |
| Dịch vụ AWS khác (SSM, KMS, Secrets Manager, ECR…) | **Interface Endpoint** | $0,01/giờ/AZ + $0,01/GB | AWS dựng một ENI thật trong subnet của bạn, có phần cứng đằng sau |
| Internet công cộng, IPv4 | NAT Gateway | $0,045/giờ + $0,045/GB | AWS chạy một dịch vụ NAT quản lý, HA sẵn |
| Internet công cộng, IPv4, chấp nhận tự vận hành | NAT instance | ~$0,005/giờ | chính là một EC2 của bạn làm router |
| Internet công cộng, **IPv6** | **Egress-only Internet Gateway** | **$0** | IPv6 không cần dịch địa chỉ, nên không cần thiết bị NAT — chỉ cần một cổng chặn chiều vào |

Dòng cuối là chỗ mà rất nhiều người bỏ qua, và cũng là lý do lab này bắt bạn tự
tìm. Egress-only IGW miễn phí **vì nó không phải NAT** — nó chỉ là một internet
gateway có luật "chỉ cho ra, không cho vào". NAT tồn tại vì IPv4 thiếu địa chỉ;
IPv6 thì không thiếu, nên không có gì để dịch.

---

## Ba cách khác để giải bài này

### Cách A — NAT Gateway (cách "chuẩn" mà mọi tutorial dạy)

Một NAT Gateway ở subnet công khai, route `0.0.0.0/0 → nat-xxx` trong route table
của tầng riêng tư. Xong. Máy ra được mọi nơi trên internet, dùng được mọi distro,
gọi được mọi API.

- **Tốt hơn khi:** bạn thật sự cần ra internet công cộng IPv4 tới nhiều đích không
  đoán trước được — cài package từ PyPI/npm, gọi API bên thứ ba, webhook đi ra.
  Đây là lời giải đúng trong production của phần lớn hệ thống.
- **Tệ hơn ở chỗ:** $32,4/tháng tiền giờ **cộng** $0,045/GB dữ liệu đi qua. Một
  job kéo 100 GB ảnh mỗi đêm là thêm $135/tháng chỉ riêng tiền NAT — và đây là
  hoá đơn bất ngờ kinh điển. Và NAT Gateway là **theo AZ**: muốn chịu được lỗi
  một AZ thì phải có hai cái, nhân đôi tiền.
- **Đề thi hỏi thế nào:** khi đề nhấn *"giảm chi phí"*, *"chỉ truy cập S3"*,
  *"traffic không được đi ra internet"* → **không** chọn NAT Gateway, chọn VPC
  Endpoint. Khi đề nhấn *"cần cập nhật OS từ repo bên ngoài"*, *"gọi API bên thứ
  ba"* mà không nhắc chi phí → NAT Gateway. Khi đề nhắc *"chi phí thấp nhất"* và
  *"chấp nhận tự quản lý"* → NAT instance.

### Cách B — Bastion host ở subnet công khai

Một EC2 nhỏ ở tầng công khai, có IP công khai, mở port 22 từ dải IP văn phòng.
Từ đó SSH tiếp vào máy riêng tư.

- **Tốt hơn khi:** bạn cần chuyển tiếp một giao thức mà Session Manager không nói
  được, hoặc đội của bạn đã có quy trình quản lý khoá SSH và audit dựa trên nó.
  Cũng là cách duy nhất khi máy đích không cài được agent.
- **Tệ hơn ở chỗ:** bạn vừa tạo ra đúng thứ đội bảo mật cấm — một cửa mở ra
  internet. Cộng thêm: một EC2 nữa ($7,5/tháng), một IP công khai ($3,6/tháng),
  một bộ khoá SSH phải xoay vòng, và một máy nữa phải vá lỗ hổng. Log phiên làm
  việc thì bạn phải tự dựng.
- **Đề thi hỏi thế nào:** bất cứ lựa chọn nào có "bastion host" hoặc "jump box"
  trong một câu hỏi nhắc tới *"không mở port"*, *"không quản lý khoá SSH"*,
  *"ghi lại toàn bộ phiên"*, *"chi phí vận hành thấp nhất"* → **sai**. Session
  Manager thắng ở cả bốn tiêu chí. Bastion chỉ đúng khi đề nói rõ có ràng buộc
  không cài được agent.

### Cách C — đặt máy ở subnet công khai và siết security group

Bỏ hẳn tầng riêng tư. Máy ở subnet công khai, có IP công khai, security group chỉ
cho phép inbound từ đúng dải IP văn phòng.

- **Tốt hơn khi:** hạ tầng nhỏ, một máy, và bạn muốn ít thành phần nhất có thể.
  Không NAT, không endpoint, không gì cả — máy ra internet trực tiếp qua IGW,
  miễn phí.
- **Tệ hơn ở chỗ:** đây là **phòng thủ một lớp**. Một lần sửa nhầm security group
  là máy phơi ra internet. Với thiết kế tầng riêng tư, kể cả khi security group
  mở toang thì vẫn không có route nào từ internet vào — hai lớp độc lập phải cùng
  hỏng mới thủng. Ngoài ra IP công khai tốn $3,6/tháng và làm máy xuất hiện trong
  mọi bản quét cổng của internet trong vòng vài phút.
- **Đề thi hỏi thế nào:** đề SAA gần như luôn thưởng cho **defence in depth**.
  Khi đề nói *"tuân thủ"*, *"kiểm toán"*, *"không được truy cập từ internet"* →
  private subnet, kể cả khi security group đã đủ chặt về mặt kỹ thuật.

### Bảng quyết định rút ra

| Đề nói | Chọn |
|---|---|
| "private subnet cần truy cập S3, chi phí thấp nhất" | **Gateway Endpoint** |
| "private subnet cần gọi Secrets Manager / KMS, không qua internet" | **Interface Endpoint (PrivateLink)** |
| "cần cài package từ internet, không muốn quản lý gì" | NAT Gateway |
| "cần ra internet, chi phí thấp nhất, chấp nhận tự vận hành" | NAT instance |
| "truy cập instance private, không mở port, có audit" | **Session Manager** |
| "chặn một địa chỉ IP đang tấn công" | **NACL** (SG không có Deny) |
| "cho phép ứng dụng gọi database" | **Security Group tham chiếu SG khác** |

---

## Nếu đề thi hỏi

<details><summary>Câu 1 — Các EC2 ở private subnet cần đọc/ghi một bucket S3. Kiến trúc sư muốn chi phí thấp nhất và traffic không đi qua internet. Chọn gì?</summary>

**A.** NAT Gateway ở public subnet, route mặc định từ private subnet trỏ vào.
**B.** VPC Gateway Endpoint cho S3, thêm route vào route table của private subnet.
**C.** VPC Interface Endpoint (PrivateLink) cho S3.
**D.** Internet Gateway, gán Elastic IP cho từng instance.

**Đáp án: B.**

- **A sai** ở cả hai tiêu chí: $32,4/tháng cộng phí theo GB, và traffic **có** đi
  ra internet công cộng (NAT chỉ dịch địa chỉ, không tạo đường riêng).
- **C chạy được** — Interface Endpoint cho S3 tồn tại thật — nhưng tốn
  $0,01/giờ/AZ cộng $0,01/GB. Nó chỉ đáng khi bạn cần truy cập S3 **từ on-premises
  qua Direct Connect/VPN**, vì Gateway Endpoint không dùng được từ ngoài VPC.
  Đề mà nhắc "từ trung tâm dữ liệu tại chỗ" thì đáp án đổi sang C.
- **D sai** rõ ràng: gán IP công khai biến private subnet thành public, tốn tiền
  IP, và mở instance ra internet.
- **B đúng**: miễn phí, traffic đi trên mạng xương sống của AWS, không rời VPC.

</details>

<details><summary>Câu 2 — Công ty cấm mở SSH và cấm dùng bastion host, nhưng đội vận hành cần shell trên EC2 ở private subnet, có ghi lại toàn bộ phiên làm việc. Chọn gì?</summary>

**A.** Bastion host ở public subnet, giới hạn security group theo IP văn phòng.
**B.** Site-to-Site VPN từ văn phòng vào VPC, rồi SSH qua IP riêng.
**C.** Systems Manager Session Manager, ghi log phiên vào S3/CloudWatch.
**D.** EC2 Instance Connect với khoá SSH tạm thời sống 60 giây.

**Đáp án: C.**

- **A sai** vì đề cấm bastion, chấm hết.
- **B chạy được** nhưng $36/tháng, cần thiết bị đầu cuối phía văn phòng, và vẫn
  là SSH — đề cấm SSH.
- **D thú vị và gần đúng**: khoá chỉ sống 60 giây nên không có khoá dài hạn để rò.
  Nhưng nó **vẫn là SSH trên port 22**, vẫn cần đường mạng tới instance (public IP
  hoặc EC2 Instance Connect Endpoint), và **không ghi lại nội dung phiên**.
  Tiêu chí "ghi lại toàn bộ phiên" loại nó.
- **C đúng**: không port, không khoá, agent gọi ra; ghi log phiên là tính năng có
  sẵn; và mọi lần mở phiên đều nằm trong CloudTrail.

</details>

<details><summary>Câu 3 — Security group của web server cho phép inbound TCP 443 từ 0.0.0.0/0 và KHÔNG có rule outbound nào. Client gửi request HTTPS. Chuyện gì xảy ra?</summary>

**A.** Request tới được nhưng response không về được, kết nối treo.
**B.** Request và response đều bình thường.
**C.** Request bị chặn ngay ở inbound vì không có rule outbound tương ứng.
**D.** Tuỳ vào NACL của subnet.

**Đáp án: B** — với một điều kiện cần nói rõ.

Security group là **stateful**: khi một kết nối được cho phép đi vào, luồng trả lời
tự động được phép đi ra, bất kể rule outbound. Đó chính là lý do trong lab này bạn
chạy được lệnh trên máy mà security group không có rule inbound nào — agent **gọi
ra** trước, nên luồng trả lời được phép **vào**.

- **A và C sai** vì mô tả hành vi của một thiết bị stateless.
- **D là bẫy hay**: NACL thì đúng là stateless và **có** gây ra hiện tượng ở đáp
  án A nếu bạn quên mở dải ephemeral port (1024–65535) ở chiều ngược lại. Nhưng
  đề chỉ hỏi về security group. Nếu đề nhắc NACL thì câu trả lời đổi.

Điều kiện cần nói rõ: security group **mặc định** của AWS có rule outbound
`allow all`. Câu hỏi giả định bạn đã xoá nó — và câu trả lời vẫn là B, vì tính
stateful không phụ thuộc vào rule outbound.

</details>

<details><summary>Câu 4 — Bạn cần chặn một địa chỉ IP đang quét cổng VPC của bạn. Cơ chế nào?</summary>

**A.** Thêm rule Deny vào security group của các instance.
**B.** Thêm rule Deny vào Network ACL của subnet.
**C.** Xoá rule Allow tương ứng trong security group.
**D.** Bật VPC Flow Logs.

**Đáp án: B.**

- **A sai vì một lý do rất cụ thể: security group KHÔNG CÓ Deny.** Nó chỉ có
  Allow; mọi thứ không được Allow là ngầm bị chặn. Đây là câu hỏi mà đề thi ra
  đi ra lại.
- **C sai** vì xoá Allow sẽ chặn **tất cả mọi người**, không chỉ kẻ tấn công.
- **D sai** vì Flow Logs chỉ **quan sát**, không chặn. Nó là công cụ điều tra sau
  sự cố — chính là thứ bạn đã bật ở yêu cầu 8.
- **B đúng**: NACL có cả Allow lẫn Deny, đánh giá theo số thứ tự rule từ nhỏ tới
  lớn, dừng ở rule khớp đầu tiên. Nhớ thêm: NACL **stateless**, nên chặn một
  chiều không tự động chặn chiều kia.

</details>

<details><summary>Câu 5 — Ứng dụng ở private subnet cần cập nhật OS từ repo trên internet. Yêu cầu: chi phí thấp nhất, chấp nhận công sức vận hành. Chọn gì?</summary>

**A.** NAT Gateway ở mỗi AZ.
**B.** Một NAT Gateway dùng chung cho cả hai AZ.
**C.** NAT instance trên t4g.nano, tắt source/destination check.
**D.** Gán Elastic IP cho mỗi instance.

**Đáp án: C.**

- **A** là đáp án đúng cho *"tính sẵn sàng cao nhất"* — mỗi AZ một NAT để lỗi một
  AZ không kéo theo AZ kia. Nhưng $64,8/tháng.
- **B** rẻ hơn A một nửa nhưng tạo phụ thuộc chéo AZ: AZ chứa NAT chết là cả hai
  AZ mất đường ra. Đây là đáp án đúng khi đề nói *"cân bằng chi phí và sẵn sàng"*.
- **D sai**: gán IP công khai cho instance ở private subnet không làm nó ra được
  internet — vẫn cần route tới IGW, và lúc đó nó không còn là private subnet nữa.
  Đây là bẫy kiểm tra xem bạn có hiểu "public subnet là do route table" không.
- **C đúng** với đề bài này: ~$3,8/tháng, và cụm từ *"chấp nhận công sức vận hành"*
  chính là tín hiệu cho phép chọn NAT instance. Chi tiết bắt buộc phải nhớ:
  **tắt source/destination check** — không tắt thì EC2 vứt bỏ mọi gói tin không
  gửi cho chính nó, và NAT instance không hoạt động.

</details>

<details><summary>Câu 6 — VPC của bạn có IPv6. Instance ở private subnet cần gọi API HTTPS bên ngoài qua IPv6, và tuyệt đối không được nhận kết nối từ internet. Chọn gì?</summary>

**A.** Internet Gateway, cộng security group chỉ có rule outbound.
**B.** NAT Gateway (nó hỗ trợ IPv6).
**C.** Egress-only Internet Gateway.
**D.** NAT64 kèm DNS64.

**Đáp án: C.**

- **A sai** vì IGW cho phép **cả hai chiều**. Bạn đang dựa hoàn toàn vào security
  group — một lớp duy nhất. Và với IPv6 thì mỗi instance có địa chỉ định tuyến
  công cộng thật, nên sai sót một rule là phơi hàng ra internet.
- **B sai**: NAT Gateway chỉ làm việc với IPv4. NAT tồn tại để tiết kiệm địa chỉ
  IPv4 — IPv6 không có bài toán đó.
- **D là bẫy tinh vi và cũng là kiến thức thật**: NAT64 + DNS64 dùng khi instance
  **chỉ có IPv6** cần gọi tới một dịch vụ **chỉ có IPv4**. Đề này nói API bên
  ngoài dùng IPv6, nên không cần dịch.
- **C đúng**: đúng một chiều, miễn phí, và là lý do lab này có thể chạy ở
  $0,011/giờ nếu bạn tìm ra nó.

</details>

---

## Chỗ dễ hiểu sai

**"Private subnet nghĩa là không ra được internet."** Không. Private subnet nghĩa
là **không có đường từ internet đi vào**. Chiều ra là chuyện khác và bạn tự chọn
mở hay không. Nhiều người lẫn hai chiều này rồi kết luận sai trong đề thi.

**"Gateway Endpoint miễn phí thì cứ dùng cho mọi thứ."** Nó chỉ tồn tại cho đúng
**hai** dịch vụ: S3 và DynamoDB. Mọi dịch vụ khác là Interface Endpoint và tính
tiền theo giờ. Và Gateway Endpoint **không dùng được từ ngoài VPC** — on-premises
qua Direct Connect không tới được nó, đó là lúc phải trả tiền cho Interface Endpoint.

**"Trong lab tôi ghép cả 3 endpoint SSM vào một AZ để rẻ."** Đúng cho lab, sai
cho production. Interface Endpoint là ENI trong một subnet cụ thể; AZ đó chết là
mất Session Manager với toàn bộ fleet. Production đặt endpoint ở mọi AZ có
workload. Đây là khác biệt "chạy được" với "đúng" của tuần này.

**Flow Logs không phải công cụ debug thời gian thực.** Có độ trễ 1 hoặc 10 phút
tuỳ `max_aggregation_interval`, và nó chỉ ghi **metadata** (ai, tới đâu, port
nào, ACCEPT/REJECT) chứ không ghi nội dung gói tin. Muốn xem nội dung thì cần
Traffic Mirroring — thứ đắt hơn nhiều và nằm ngoài phạm vi SAA.

**Một dòng REJECT trong Flow Logs không cho biết ai đã từ chối.** Security group
và NACL cùng sinh ra REJECT giống hệt nhau trong log. Phân biệt bằng suy luận:
security group stateful nên gói trả lời của một kết nối đã được chấp nhận sẽ
không bao giờ bị REJECT; thấy REJECT ở chiều trả lời thì thủ phạm gần như chắc
chắn là NACL thiếu rule ephemeral port.

**`t3.micro` không có public IP thì không tốn tiền IPv4.** Đúng — từ 01/02/2024
AWS tính $0,005/giờ cho **mỗi địa chỉ IPv4 công khai đang được gán**, kể cả
Elastic IP không dùng. Không gán thì không tính. Đó là một lý do nữa để tầng
riêng tư rẻ hơn bạn tưởng.
