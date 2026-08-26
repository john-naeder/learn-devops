# Mạng

> **Tra nhanh:** gói tin đi từ đâu tới đâu, ai chặn nó ở chặng nào, và cấu hình
> nào làm hoá đơn phình ra.

`Domain 1 · Kiến trúc bảo mật (30% đề)` · `Domain 2 · Chịu lỗi (26%)` · `Domain 3 · Hiệu năng (24%)`

Bài tuần tương ứng: [Tuần 2 — VPC](../aws/w02-vpc-networking.md) và
[Tuần 8 — DNS, CDN, tầng biên](../aws/w08-dns-cdn-edge.md). Đây là file dài nhất
sổ tay vì networking là mảng nặng nhất của đề.

## Bản đồ

| Mục | Đọc khi bạn cần |
|---|---|
| [CIDR và 5 IP bị lấy](#11-cidr-và-năm-địa-chỉ-aws-lấy-đi) | tính số IP dùng được, chia subnet |
| [Public vs private subnet](#12-public-hay-private-là-do-route-table) | "instance có public IP mà vẫn không ra internet" |
| [NAT Gateway vs NAT instance](#13-igw-nat-gateway-và-nat-instance) | đề hỏi chi phí egress, băng thông, HA |
| [Route table, longest prefix](#14-route-table-và-longest-prefix-match) | có nhiều đường tới cùng đích |
| [DHCP option set, DNS trong VPC](#15-dhcp-option-set-và-dns-trong-vpc) | resolver tuỳ biến, private hosted zone không phân giải |
| [Security Group vs NACL](#2-security-group-vs-nacl) | kết nối chết một chiều, ephemeral port |
| [VPC Endpoint](#3-vpc-endpoint) | bài toán kinh điển "giảm chi phí NAT Gateway" |
| [Peering và Transit Gateway](#4-peering-và-transit-gateway) | nối nhiều VPC, nối on-premises |
| [Flow Logs](#5-vpc-flow-logs) | điều tra "vì sao gói tin bị chặn" |
| [ALB vs NLB vs GWLB](#6-elastic-load-balancing) | chọn load balancer, giữ IP nguồn, cross-zone |
| [Route 53](#7-route-53) | alias vs CNAME, 8 routing policy, health check |
| [CloudFront](#8-cloudfront) | cache key, OAC, signed URL, edge function |
| [Global Accelerator](#9-global-accelerator-vs-cloudfront) | "static IP" + "toàn cầu" + "không phải HTTP" |
| [Bảng số phải nhớ](#bảng-số-phải-nhớ) | ôn 10 phút trước khi thi |
| [Nguồn nói khác](#nguồn-nói-khác) | con số trong `aws-saa-c03/` đã sai |

---

## 1. VPC

### 1.1 CIDR và năm địa chỉ AWS lấy đi

VPC CIDR nằm trong khoảng **/16 tới /28**. CIDR chính **không sửa được** sau khi
tạo; bạn chỉ thêm được **secondary CIDR** (tối đa 5, xin tăng tới 50).

Mỗi subnet AWS giữ **5 địa chỉ**, không xin lại được:

| Địa chỉ | Dùng làm gì |
|---|---|
| `x.x.x.0` | network address |
| `x.x.x.1` | **VPC router** — default gateway của mọi ENI trong subnet |
| `x.x.x.2` | **Amazon DNS resolver** (VPC CIDR base **+2**, không phải subnet base +2) |
| `x.x.x.3` | dự phòng cho tính năng tương lai |
| `x.x.x.255` | broadcast address (VPC không hỗ trợ broadcast nhưng vẫn giữ) |

Số IP dùng được = **2^(32 − prefix) − 5**. `/24` → 251. `/28` → **11**, không phải
16. `/28` là subnet nhỏ nhất được phép, và 11 IP cạn rất nhanh khi ALB, NAT Gateway
và interface endpoint đều ăn ENI.

Hệ quả thực dụng: đừng chia subnet nhỏ để "tiết kiệm IP". Địa chỉ private không
mất tiền. Chia `/20` cho mỗi subnet (4.091 IP) là mặc định hợp lý — thứ khiến bạn
đau về sau là **hết IP** chứ không bao giờ là **thừa IP**.

### 1.2 Public hay private là do route table

Không có thuộc tính "public" trên subnet. Định nghĩa duy nhất:

> Subnet là **public** khi route table gắn với nó có một route trỏ `0.0.0.0/0` sang
> **Internet Gateway**. Không có route đó thì nó private, dù bạn đặt tên là gì.

`MapPublicIpOnLaunch` chỉ quyết định instance có được cấp public IPv4 hay không —
nó **không** tạo đường ra. Đó là lý do triệu chứng "instance có public IP mà vẫn
không ping ra ngoài được" luôn có ba nghi phạm: thiếu route tới IGW, security group
chặn outbound, hoặc NACL chặn **chiều về**.

IGW làm hai việc mà người ta hay quên là **NAT một-một**: gói ra thì đổi private IP
nguồn thành public IP; gói vào thì đổi ngược lại. Instance **không bao giờ nhìn
thấy** public IP của chính nó trên interface — `ip addr` chỉ hiện private IP. Đây
là lý do phải hỏi metadata service để biết public IP.

**Một VPC gắn được đúng một IGW**, và IGW tự scale ngang, không có băng thông giới hạn.

### 1.3 IGW, NAT Gateway và NAT instance

NAT Gateway cho phép instance trong private subnet **khởi tạo** kết nối ra ngoài
mà không nhận được kết nối vào. Nó phải nằm trong **public subnet** (vì chính nó
cần đường ra IGW) và cần một Elastic IP.

| | NAT Gateway | NAT instance |
|---|---|---|
| Ai vận hành | AWS | bạn |
| Băng thông | **5 Gbps tự scale tới 100 Gbps** | theo instance type |
| Packet/giây | **1 triệu tự scale tới 10 triệu** | theo instance type |
| HA | dự phòng **trong một AZ** | tự dựng (ASG + script đổi route) |
| Security Group | **không gắn được** | gắn được |
| Port forwarding, bastion | không | được |
| Giá (ap-southeast-1) | ~$0,045/giờ **+ $0,045/GB xử lý** | giá EC2 |

Hai con số hay bị dạy sai, viết hẳn ra vì đây là bẫy:

- **Băng thông là 5 → 100 Gbps.** Con số "10 → 45 Gbps" đến từ một blog AWS năm
  2018 và vẫn được chép lại khắp nơi. Xem [Nguồn nói khác](#nguồn-nói-khác).
- **55.000 kết nối đồng thời là *mỗi IPv4* tới *mỗi đích duy nhất*.** "Đích duy
  nhất" = bộ ba (IP đích, cổng đích, giao thức). Đổi một trong ba là một đích khác
  với hạn mức 55.000 riêng. Gắn tới **8 IPv4** (1 chính + 7 phụ) thì thành
  **440.000** kết nối tới cùng một đích. Nó **không** phải trần cứng của gateway.

Lỗi `ErrorPortAllocation` nghĩa là bạn chạm trần đó — cách sửa là **gắn thêm IP**
cho NAT Gateway, không phải dựng thêm NAT Gateway.

NAT instance có một chi tiết cấu hình mà đề vẫn hỏi: phải **tắt source/destination
check** trên ENI, vì mặc định EC2 vứt bỏ gói tin mà nó không phải nguồn hoặc đích.

Về HA: NAT Gateway dự phòng **trong một AZ**. Một NAT Gateway cho cả VPC thì chạy
được nhưng AZ chứa nó chết là mọi AZ khác mất internet, **và** mọi byte từ AZ khác
đi qua nó đều tính phí cross-AZ. Chuẩn production là **một NAT Gateway mỗi AZ** với
route table riêng cho từng AZ.

### 1.4 Route table và longest prefix match

Route table là danh sách `đích → target`. Mỗi subnet gắn với **đúng một** route
table; không gắn tường minh thì dùng **main route table** của VPC.

Route `VPC-CIDR → local` luôn tồn tại, không xoá được, và **luôn thắng** với lưu
lượng trong VPC.

Khi nhiều route khớp, AWS chọn theo **longest prefix match** — prefix dài hơn (cụ
thể hơn) thắng:

```
10.0.0.0/16   local          ← luôn thắng cho traffic nội bộ
10.0.5.0/24   vpce-xxx       ← thắng 0.0.0.0/0 vì /24 cụ thể hơn
172.31.0.0/16 pcx-xxx
0.0.0.0/0     nat-xxx        ← chỉ nhận phần còn lại
```

Khi prefix **bằng nhau**, thứ tự ưu tiên: route tĩnh bạn tự thêm > route lan truyền
(propagated). Trong nhóm propagated: Direct Connect BGP > VPN tĩnh > VPN BGP.

Đây là cơ chế đằng sau mọi bài "chèn firewall vào đường đi": bạn không chặn được
route `local`, nhưng bạn thêm được route cụ thể hơn trỏ sang **Gateway Load Balancer
endpoint** hoặc appliance.

### 1.5 DHCP option set và DNS trong VPC

VPC có hai công tắc DNS, và đề phân biệt chúng:

- **`enableDnsSupport`** — bật resolver ở địa chỉ `VPC-CIDR-base + 2` (và
  `169.254.169.253`). Tắt cái này thì không instance nào phân giải được tên gì.
- **`enableDnsHostnames`** — cấp cho instance có public IP một hostname public dạng
  `ec2-x-x-x-x.compute.amazonaws.com`.

**Private hosted zone của Route 53 chỉ hoạt động khi cả hai đều bật.** Đây là câu
hỏi thi thật, và cũng là nguyên nhân số một của "private hosted zone không phân
giải được".

**DHCP option set** đẩy cấu hình xuống instance qua DHCP: `domain-name-servers`,
`domain-name`, `ntp-servers`, `netbios-*`. Dùng khi cần trỏ về DNS server
on-premises (ví dụ Active Directory). Không **sửa** được một option set đang tồn
tại — phải tạo cái mới và gắn lại vào VPC; instance nhận cấu hình mới khi DHCP lease
gia hạn, nên hiệu lực không tức thì.

Trần cần nhớ: **1.024 gói DNS mỗi giây mỗi ENI**, không tăng được. Ứng dụng phân
giải tên trong vòng lặp sẽ chạm trần này và nhận lỗi ngắt quãng rất khó chẩn đoán —
sửa bằng cache DNS phía client.

---

## 2. Security Group vs NACL

Đừng học bảng thuộc lòng. Học **cơ chế**, rồi bảng tự suy ra.

**Security Group là stateful** vì nó có một **bảng theo dõi kết nối** (connection
tracking) trong hạ tầng Nitro. Khi một gói được cho phép đi ra, hạ tầng ghi lại
"luồng này hợp lệ"; gói trả về được nhận diện thuộc luồng đó và **được cho qua bất
kể rule inbound**. Vì thế SG chỉ cần rule một chiều.

**NACL là stateless** vì nó chỉ là bộ lọc gói tin trên ranh giới subnet, không giữ
trạng thái gì. Mỗi gói được xét độc lập. Gói đi ra khớp rule outbound; gói trả về
là một gói khác, phải khớp rule **inbound** riêng.

Hệ quả trực tiếp — bẫy **ephemeral port**:

```
Instance (10.0.1.5:47234)  →  API bên ngoài (203.0.113.9:443)
Gói đi:  src 10.0.1.5:47234  dst 203.0.113.9:443   ← khớp NACL outbound "allow 443"
Gói về:  src 203.0.113.9:443 dst 10.0.1.5:47234    ← cần NACL inbound "allow 1024-65535"
```

Chỉ mở 443 ở NACL inbound là kết nối chết một chiều: TCP handshake không hoàn tất,
triệu chứng là timeout chứ không phải "connection refused" — rất khó đọc. Dải cần
mở: **1024–65535** (Linux thực tế dùng 32768–60999, Windows 49152–65535, ELB và NAT
Gateway dùng 1024–65535 — mở cả dải cho an toàn).

| | Security Group | NACL |
|---|---|---|
| Gắn vào | **ENI** | **subnet** |
| Trạng thái | stateful | stateless |
| Loại rule | **chỉ ALLOW** | ALLOW **và DENY** |
| Đánh giá | **mọi rule**, hợp nhất | **theo số thứ tự**, dừng ở rule khớp đầu tiên |
| Số hiệu rule | không có | **1–32766**, nhỏ hơn = ưu tiên cao hơn |
| Mặc định | deny inbound, allow outbound | **allow tất cả** hai chiều |
| Nguồn của rule | CIDR **hoặc security group khác** | chỉ CIDR |
| Hạn mức | 60 rule mỗi chiều, 5 SG mỗi ENI (tăng tới 16) | 20 rule mỗi chiều (tăng tới 40) |

Hai điểm chỉ SG làm được và đề hay dùng: **tham chiếu security group khác** làm
nguồn (`nguồn = sg-web` thay vì một dải CIDR — instance thêm bớt tự do, rule không
đổi), và **tự tham chiếu** để cho phép các thành viên cùng nhóm nói chuyện với nhau.

Điểm chỉ NACL làm được: **DENY**. Đề nói *"chặn một dải IP đang tấn công"* →
**NACL**, vì SG không có DENY. Nhưng NACL chỉ chặn ở tầng 3/4; chặn theo nội dung
HTTP thì đó là **AWS WAF**.

Thứ tự gói tin đi qua khi vào một instance: **NACL của subnet → Security Group của
ENI**. Đi ra thì ngược lại. Gói bị NACL chặn thì SG không bao giờ thấy nó.

---

## 3. VPC Endpoint

Mặc định, instance trong private subnet gọi `s3.ap-southeast-1.amazonaws.com` phải
đi qua NAT Gateway ra internet công cộng rồi vòng lại AWS. Endpoint cắt đường vòng
đó.

| | **Gateway Endpoint** | **Interface Endpoint (PrivateLink)** |
|---|---|---|
| Cơ chế | **chèn route** vào route table, đích là một **prefix list** | tạo **ENI có private IP** trong subnet |
| Dịch vụ | **chỉ S3 và DynamoDB** | hầu hết dịch vụ AWS, và dịch vụ của bên thứ ba |
| Giá | **MIỄN PHÍ** | **~$0,01/giờ mỗi AZ + ~$0,01/GB** |
| Từ on-premises (VPN/DX) | **KHÔNG** | **có** |
| Qua peering / Transit Gateway | **không** | **có** |
| Chính sách truy cập | endpoint policy | endpoint policy + **security group** |
| DNS | không đổi tên miền, đổi đường đi | **private DNS** ghi đè tên dịch vụ về IP riêng |

**Bài toán kinh điển của đề:** *"Instance trong private subnet tải file từ S3, hoá
đơn NAT Gateway rất cao. Giải pháp rẻ nhất?"* → **S3 Gateway Endpoint**. Không bao
giờ là "thêm NAT Gateway", không bao giờ là "chuyển instance ra public subnet".

Vì sao Gateway Endpoint miễn phí được: nó không tạo hạ tầng nào, chỉ là một mục
trong route table trỏ tới prefix list của dịch vụ. Không có ENI để tính giờ, không
có gói tin nào bị "xử lý" bởi thiết bị của AWS. Interface Endpoint thì tạo ENI thật,
nên tính tiền như một thiết bị.

Ba bẫy đi kèm:

1. **Gateway Endpoint không dùng được từ on-premises.** Route table của VPC không
   áp lên gói tin đến từ VPN/Direct Connect theo cách đó. Đề nói "văn phòng truy cập
   S3 riêng tư qua Direct Connect" → phải là **Interface Endpoint cho S3**, và nó
   **có phí**.
2. **Không đi ké qua peering.** VPC B peering với VPC A **không** dùng được Gateway
   Endpoint của A. Mỗi VPC phải có endpoint riêng.
3. **Endpoint policy khác bucket policy.** Endpoint policy giới hạn *đi qua đường
   này thì được làm gì*; bucket policy với điều kiện `aws:SourceVpce` giới hạn
   *bucket này chỉ nhận request từ endpoint nào*. Đề hỏi "chỉ cho phép truy cập
   bucket từ trong VPC" → **bucket policy có `aws:SourceVpce`**.

**AWS PrivateLink** là chính cơ chế Interface Endpoint, mở cho dịch vụ tự viết:
bên cung cấp đặt một **NLB** (hoặc GWLB) trước dịch vụ và tạo *endpoint service*;
bên tiêu thụ tạo interface endpoint trỏ tới đó. Không cần peering, **không cần CIDR
không chồng nhau**, và lưu lượng một chiều (consumer khởi tạo). Đề nói "cung cấp
dịch vụ SaaS cho hàng trăm VPC khách hàng, không muốn peering" → **PrivateLink**.

---

## 4. Peering và Transit Gateway

**VPC Peering** là một đường ống một-một giữa hai VPC (khác account, khác Region
đều được). Ba giới hạn định nghĩa nó:

- **CIDR không được chồng nhau.** Không có NAT trong peering. Đây là lý do quy
  hoạch IP phải làm trước khi dựng VPC đầu tiên.
- **Không transitive.** A↔B và B↔C không cho A↔C. Cơ chế: route table của A không
  có đường tới C, và AWS cố tình không cho bạn thêm.
- **Không edge-to-edge routing.** VPC B **không đi ké** IGW, NAT Gateway, Gateway
  Endpoint hay VPN của VPC A. Mọi lối ra biên phải tự có.

Và bước hay quên nhất: sau khi peering ở trạng thái `active`, phải **thêm route ở
cả hai route table**. Peering không tự thêm route.

Số peering mỗi VPC: **50** đang hoạt động (tăng tới 125). Đó là lý do mô hình
full-mesh sập đổ nhanh — n VPC cần n(n−1)/2 kết nối; 10 VPC là 45 peering và 45 lần
sửa route table.

**Transit Gateway** là router khu vực theo mô hình hub-and-spoke. Mỗi VPC, VPN,
Direct Connect gateway gắn vào TGW bằng một *attachment*, và TGW **định tuyến
transitive** giữa chúng.

| | Peering | Transit Gateway |
|---|---|---|
| Mô hình | lưới một-một | hub-and-spoke |
| Transitive | không | **có** |
| Quy mô | 50 mỗi VPC | **5.000 attachment** mỗi TGW |
| Băng thông | như trong VPC | **tới 100 Gbps mỗi VPC attachment mỗi AZ**, 7,5 triệu pps |
| Phân đoạn mạng | bằng route table của từng VPC | **nhiều route table trên TGW** |
| Giá | chỉ phí truyền dữ liệu | **~$0,05/giờ mỗi attachment + ~$0,02/GB xử lý** |
| Nối on-premises | không | **có** (VPN, Direct Connect) |

Đánh đổi thật: peering **rẻ hơn** (không phí xử lý dữ liệu) và **độ trễ thấp hơn
một chặng**. TGW đắt hơn nhưng vận hành được ở quy mô. Ngưỡng thực dụng thường
quanh **5 VPC** — dưới đó peering; trên đó TGW.

Nhiều **TGW route table** là thứ khiến TGW mạnh hơn hẳn peering: bạn gắn mỗi
attachment vào một route table khác nhau để tạo phân đoạn — ví dụ VPC production
và VPC dev cùng tới được VPC dịch vụ chung, nhưng không tới được nhau. Peering
không mô phỏng được điều này mà không thêm firewall.

TGW **peering giữa các Region** được, nhưng peering đó cũng **không transitive**:
gói tin không đi từ TGW A qua TGW B rồi sang TGW C.

---

## 5. VPC Flow Logs

Ghi **metadata** của luồng IP — không phải payload, không phải tcpdump. Bật được ở
ba mức: **VPC**, **subnet**, hoặc **ENI**; đích là CloudWatch Logs, S3, hoặc
Data Firehose.

Trường quan trọng nhất là hai trường cuối:

```
2 123456789012 eni-0abc 10.0.1.5 203.0.113.9 47234 443 6 12 1842 1690000000 1690000060 ACCEPT OK
                                                        ↑protocol                      ↑action ↑status
```

`action` là `ACCEPT` hoặc `REJECT`. Quy tắc chẩn đoán rút ra từ [mục 2](#2-security-group-vs-nacl):

- Thấy **`REJECT` cả chiều đi lẫn chiều về** → nhiều khả năng là **NACL** (stateless,
  chặn cả hai hướng độc lập).
- Thấy **`ACCEPT` chiều đi nhưng không có bản ghi chiều về** → gói không bao giờ
  quay lại: sai route, hoặc bên kia chặn.
- Thấy **`REJECT` chỉ ở chiều vào** → **Security Group** thiếu rule inbound.

Những thứ Flow Logs **không** bắt được, và đề dùng đúng danh sách này:

- DNS tới Amazon DNS resolver (dùng **Route 53 Resolver query log**)
- Instance metadata `169.254.169.254` và Amazon Time Sync `169.254.169.123`
- DHCP
- Lưu lượng tới địa chỉ dành riêng của VPC router
- **Nội dung gói tin** — cần payload thì dùng **Traffic Mirroring**

Hai giới hạn vận hành: **không sửa được cấu hình sau khi tạo** (kể cả định dạng bản
ghi — phải xoá và tạo lại), và aggregation interval là 1 hoặc 10 phút nhưng trên
instance Nitro **luôn ≤ 1 phút**.

---

## 6. Elastic Load Balancing

### 6.1 Chọn tầng nào

| | **ALB** | **NLB** | **GWLB** |
|---|---|---|---|
| Tầng | **7** — HTTP/HTTPS/gRPC | **4** — TCP/UDP/TLS | **3** — mọi gói IP |
| Độ trễ thêm vào | ~**400 micro giây** | ~**100 micro giây** | tối thiểu |
| IP tĩnh | không | **có**, một IP mỗi AZ, gắn được EIP | qua endpoint |
| Định tuyến theo path/host/header | **có** | không | không |
| Target | instance, IP, **Lambda**, ALB khác | instance, IP, **ALB** | instance, IP (appliance) |
| Giao thức đặc thù | WebSocket, HTTP/2, gRPC | UDP, TLS passthrough | **GENEVE cổng 6081** |
| Security Group | có | **có** (nếu bật lúc tạo) | không |
| Cross-zone | **bật sẵn** ở mức LB | **tắt sẵn** | tắt sẵn |

Con số độ trễ là **micro giây**, không phải milli giây — nguồn `aws-saa-c03/` viết
"~100 ms vs ~400 ms", sai 1.000 lần. Xem [Nguồn nói khác](#nguồn-nói-khác).

GWLB tồn tại để chèn **thiết bị bảo mật của bên thứ ba** (firewall, IDS/IPS) vào
đường đi mà không đổi địa chỉ gói tin. Nó bọc gói gốc trong **GENEVE cổng 6081**,
gửi tới appliance, nhận lại, rồi thả tiếp. Bạn định tuyến tới nó bằng một **GWLB
endpoint** đặt trong route table — chính là ứng dụng của
[longest prefix match](#14-route-table-và-longest-prefix-match).

### 6.2 Target type

`instance` đăng ký theo instance ID và gửi tới **private IP chính**. `ip` đăng ký
địa chỉ trực tiếp — bắt buộc cho Fargate `awsvpc`, và là cách duy nhất trỏ tới
**máy on-premises** qua VPN/Direct Connect. `lambda` chỉ có ở ALB. `alb` chỉ có ở
NLB, dùng khi cần một **IP tĩnh đứng trước** một ALB (whitelist của đối tác).

Chi tiết quyết định kiến trúc: NLB đứng trước ALB thì client thấy IP tĩnh, còn ALB
vẫn lo định tuyến tầng 7. Chiều ngược lại (ALB trước NLB) không tồn tại.

### 6.3 Giữ IP nguồn — chỗ nhiều sắc thái nhất

ALB **luôn kết thúc kết nối TCP** và mở kết nối mới tới target. Target thấy IP của
ALB. IP thật của client nằm trong header **`X-Forwarded-For`** — nghĩa là ứng dụng
phải đọc header, và **NACL/security group của target không lọc được theo IP client**.

NLB thì phức tạp hơn bảng "NLB giữ IP nguồn: có" mà tài liệu ôn hay chép:

| Loại target group | Mặc định giữ IP client |
|---|---|
| `instance` | **bật** |
| `ip` với UDP / TCP_UDP / QUIC | **bật**, và không tắt được |
| `ip` với **TCP / TLS** | **TẮT** — target thấy IP của NLB |

Kèm ba ràng buộc: chỉ đổi được cho target group TCP/TLS qua thuộc tính
`preserve_client_ip.enabled`; thay đổi chỉ áp cho **kết nối TCP mới**; và
**không hoạt động khi target được với tới qua Transit Gateway**. Còn một cái bẫy
vòng lặp: khi giữ IP client, một target **không tự gọi được vào NLB của chính nó**
(gói có src = dst = IP của nó, hệ điều hành vứt đi).

### 6.4 TLS termination

Chứng chỉ lấy từ **ACM**, gắn vào listener. Với ALB, **SNI** cho phép tới 25 chứng
chỉ trên một listener — nhiều tên miền, một load balancer.

Ba mô hình, đề dùng để phân biệt:

- **Kết thúc TLS tại ALB**, gửi HTTP về target — đơn giản nhất, ALB đọc và định
  tuyến theo header/path được.
- **Kết thúc TLS tại ALB rồi mã hoá lại** tới target (HTTPS) — cần cho compliance
  "mã hoá đầu cuối", target dùng chứng chỉ tự ký cũng được vì ALB không kiểm.
- **NLB TCP passthrough** — NLB không giải mã, target tự kết thúc TLS. Duy nhất
  cách này giữ được TLS đầu-cuối thật sự (client xác thực chứng chỉ của target),
  nhưng đổi lại **không có định tuyến tầng 7** và **không dùng được WAF**.

**AWS WAF gắn được vào ALB và CloudFront, không gắn được vào NLB** — vì WAF làm
việc ở tầng 7 còn NLB không giải mã. Đây là một câu loại đáp án rất hay gặp.

### 6.5 Sticky session

Chỉ ALB (và CLB) có. Hai kiểu:

- **Duration-based** — ALB tự phát cookie `AWSALB`, thời hạn 1 giây tới 7 ngày.
- **Application-based** — ALB bọc cookie do ứng dụng bạn chỉ định (`AWSALBAPP`),
  hết hạn theo ứng dụng.

Cơ chế: cookie mã hoá target ID, ALB giải mã và gửi thẳng tới target đó.

Hệ quả và bẫy: sticky session **làm tải lệch** (target nhận nhiều phiên dài sẽ nóng),
và **mất trạng thái khi target chết**. Nó là **giải pháp tạm**, không phải kiến trúc.
Đáp án đúng cho đề dạng *"ứng dụng lưu session trong bộ nhớ, muốn scale ngang"* là
**đưa session ra ngoài** — ElastiCache hoặc DynamoDB — chứ không phải bật sticky.

NLB có "sticky" theo cách khác: mặc định nó dùng **flow hash** (5-tuple), nên cùng
một kết nối TCP luôn tới cùng target. Đó không phải session affinity theo người dùng.

### 6.6 Cross-zone load balancing

Chỗ này ra thi vì mặc định **khác nhau giữa các loại**:

| | Mặc định | Tắt/bật được ở đâu | Phí cross-AZ |
|---|---|---|---|
| **ALB** | **bật** ở mức load balancer | không tắt được ở mức LB, **tắt được ở mức target group** | **không tính** |
| **NLB** | **tắt** | mức LB và mức target group | **có tính** khi bật |
| **GWLB** | **tắt** | mức LB | có tính khi bật |

Cơ chế: mỗi AZ có một node của load balancer, và DNS trả về IP của các node. Cross-zone
**bật** = node ở AZ-a phân phối tới target ở mọi AZ. Cross-zone **tắt** = node ở AZ-a
chỉ gửi tới target trong AZ-a.

Hệ quả phải hiểu: khi cross-zone **tắt**, lưu lượng chia đều **theo AZ** chứ không
theo target. AZ-a có 2 target và AZ-b có 8 target thì mỗi target ở AZ-a nhận gấp
**4 lần**. Đó là lý do khi tắt cross-zone thì số target mỗi AZ phải cân.

Vì sao AWS chọn mặc định trái ngược: ALB tính tiền theo LCU nên AWS không tính phí
cross-AZ riêng; NLB tính theo lưu lượng nên bật cross-zone là bạn trả phí truyền
liên AZ. Đề nói *"NLB, tải phân bố không đều giữa các AZ"* → **bật cross-zone**, và
phải nói rõ đánh đổi chi phí.

### 6.7 Health check và deregistration

Health check: giao thức HTTP/HTTPS/TCP, **interval 5–300 giây**, timeout 2–120 giây,
ngưỡng healthy/unhealthy 2–10 lần. Với ALB, mã trả về "khoẻ" mặc định là `200`, đổi
được thành dải (`200-299`).

Bẫy kinh điển: health check trỏ vào `/` mà `/` lại truy vấn database. Database chậm
→ health check timeout → ALB rút **toàn bộ** target ra → toàn bộ dịch vụ sập, dù
phần lớn endpoint không cần database. Endpoint health check phải **nông**.

**Deregistration delay** (connection draining) mặc định **300 giây**: khi target bị
gỡ, ALB ngừng gửi request mới nhưng chờ request đang chạy hoàn tất. Đặt quá cao thì
deploy chậm; đặt 0 thì cắt giữa chừng request của người dùng.

**Idle timeout** của ALB mặc định **60 giây**. Ứng dụng có kết nối giữ lâu (WebSocket,
long polling, tải file lớn) phải tăng lên, và **keep-alive timeout của target phải
lớn hơn idle timeout của ALB**, nếu không bạn gặp lỗi 502 ngẫu nhiên vì target đóng
kết nối trước.

---

## 7. Route 53

### 7.1 Alias và CNAME — vì sao zone apex bắt buộc alias

RFC của DNS cấm bản ghi CNAME cùng tồn tại với bản ghi khác trên cùng một tên. Zone
apex (`example.com`) bắt buộc có **SOA** và **NS**, nên **không thể** có CNAME ở đó.

**Alias** là bản ghi riêng của Route 53, không phải chuẩn DNS. Route 53 tự phân
giải đích thành địa chỉ IP và trả về **bản ghi A/AAAA** — client không biết có alias.
Vì thế nó dùng được ở zone apex.

| | Alias | CNAME |
|---|---|---|
| Ở zone apex | **được** | **không** |
| Trỏ tới | tài nguyên AWS (ALB, NLB, CloudFront, S3 website, API Gateway, Global Accelerator, VPC endpoint) hoặc **bản ghi khác trong cùng hosted zone** | bất kỳ tên miền nào |
| Phí truy vấn | **miễn phí** | tính tiền |
| TTL | không đặt được — theo TTL của đích | bạn đặt |
| Đổi IP khi tài nguyên đổi | tự động | tự động |

Điều alias **không** làm được, và đề gài: **không trỏ thẳng vào EC2 instance**. Trỏ
tới instance thì dùng bản ghi **A** với Elastic IP, hoặc đặt ALB/NLB ở giữa.

### 7.2 Tám routing policy

Nguồn `aws-saa-c03/` liệt kê 7. Từ 2022 có **8** — thiếu **IP-based routing**.

| Policy | Cơ chế chọn | Dùng khi |
|---|---|---|
| **Simple** | một bản ghi; nhiều giá trị thì client tự chọn ngẫu nhiên | một tài nguyên, **không gắn health check được** |
| **Weighted** | quay số theo trọng số (0–255) | A/B test, chuyển dần lưu lượng, canary; trọng số **0** = tắt |
| **Latency-based** | độ trễ đo được giữa **Region** và mạng của resolver | ứng dụng đa Region, tối ưu tốc độ |
| **Failover** | primary khoẻ thì trả primary, không thì secondary | active-passive DR; **bắt buộc health check** |
| **Geolocation** | theo quốc gia/châu lục/tiểu bang của resolver | tuân thủ pháp lý, nội dung bản địa; **phải có bản ghi `Default`** |
| **Geoproximity** | khoảng cách địa lý + **bias −99…+99** | dịch chuyển ranh giới vùng phục vụ; **cần Traffic Flow** |
| **Multivalue answer** | trả tới **8** bản ghi khoẻ, ngẫu nhiên | phân tải thô có health check, **không thay được ELB** |
| **IP-based** | theo **CIDR của client** mà bạn nạp lên | ép người dùng của một ISP về một endpoint, giảm phí transit |

Ba chỗ dễ nhầm nhất:

- **Latency-based đo tới Region, không tới edge location.** Nó không biết ứng dụng
  của bạn nhanh hay chậm, chỉ biết độ trễ mạng. Và nó dựa vào IP của **resolver**,
  không phải của người dùng, trừ khi resolver hỗ trợ EDNS Client Subnet.
- **Geolocation ≠ Geoproximity.** Geolocation là "người dùng ở nước nào" (rời rạc,
  theo ranh giới hành chính); Geoproximity là "gần điểm nào hơn" (liên tục, theo
  khoảng cách, chỉnh được bằng bias).
- **Multivalue answer không phải load balancer.** Nó không biết tải, không cân bằng,
  chỉ loại bản ghi hỏng khỏi câu trả lời. Đề đưa nó làm đáp án cho "phân tải HTTP"
  là bẫy — đáp án đúng là ALB.

### 7.3 Health check

Ba loại: **endpoint** (gọi thẳng IP hoặc tên miền), **calculated** (kết hợp nhiều
health check bằng AND/OR/NOT), **CloudWatch alarm** (theo trạng thái một alarm).

Cơ chế: 15+ trạm kiểm tra rải toàn cầu gọi endpoint. Endpoint bị coi là hỏng khi
**dưới 18%** số trạm báo khoẻ. Interval **30 giây** (chuẩn) hoặc **10 giây** (fast,
tính tiền cao hơn); ngưỡng lỗi 1–10, mặc định 3.

Suy ra thời gian phát hiện: 30 giây × 3 lần ≈ **90 giây**, cộng TTL của bản ghi mới
ra RTO thật của DNS failover. Đây là lý do failover bằng DNS **luôn chậm hơn**
failover bằng load balancer hay Global Accelerator, và là lý do TTL của bản ghi
failover nên đặt **60 giây**.

Bẫy quan trọng: health check của Route 53 **chỉ gọi được endpoint công cộng**. Tài
nguyên trong private subnet thì phải dùng loại **CloudWatch alarm** — CloudWatch đo
được bên trong VPC, Route 53 đọc trạng thái alarm.

### 7.4 Private hosted zone

Hosted zone chỉ phân giải **từ bên trong** các VPC bạn gắn vào nó. Điều kiện bắt
buộc: `enableDnsSupport` **và** `enableDnsHostnames` (xem [1.5](#15-dhcp-option-set-và-dns-trong-vpc)).

Cùng một tên có thể tồn tại ở cả public và private hosted zone — gọi là **split-horizon
DNS**. Từ trong VPC, private hosted zone **thắng**; từ ngoài, public. Mẫu này dùng
để cho `api.example.com` trỏ về ALB nội bộ khi gọi từ trong, và về ALB công cộng
khi gọi từ ngoài.

**Route 53 Resolver endpoint** nối DNS hai chiều với on-premises: *inbound endpoint*
cho on-prem truy vấn tên trong AWS; *outbound endpoint* + *forwarding rule* cho VPC
truy vấn tên của on-prem. Đây là đáp án cho "kiến trúc lai, hai bên phải phân giải
tên của nhau" — không phải DHCP option set (cách đó thay hẳn resolver và làm mất
khả năng phân giải tên nội bộ AWS).

---

## 8. CloudFront

### 8.1 Kiến trúc hai tầng cache

Mạng biên gồm **hơn 400 edge location** và **13 regional edge cache (REC)**, tổng
**hơn 410 điểm hiện diện**. REC nằm giữa edge và origin: edge miss thì hỏi REC
trước khi hỏi origin. REC lớn hơn nên giữ object lâu hơn, và gộp request từ nhiều
edge lại — origin nhận ít lượt hơn hẳn.

Hai ngoại lệ đề hay hỏi: request **PUT/POST/DELETE** đi thẳng tới origin, không qua
REC; và **proxy method** không được cache.

### 8.2 OAC thay OAI

Bài toán: S3 bucket phải chặn truy cập trực tiếp, chỉ nhận request từ CloudFront.

**OAI** (cũ) là một identity đặc biệt được ghi vào bucket policy. **OAC** (từ 2022)
ký request bằng **SigV4** với credential ngắn hạn, xoay vòng thường xuyên.

Dùng OAC vì OAI **không hỗ trợ**: bucket mã hoá bằng **SSE-KMS**, các method động
(`PUT`/`POST`/`DELETE`) tới S3, và **Region ra mắt sau tháng 1/2023**. AWS khuyến
nghị OAC cho mọi thiết lập mới; OAI chỉ còn để tương thích ngược.

Chi tiết hay bị bỏ sót: **S3 static website endpoint** không dùng được OAC/OAI —
nó là endpoint HTTP công cộng. Cần OAC thì phải dùng **REST endpoint** của bucket,
và bù lại mất tính năng index document của website hosting (thay bằng CloudFront
Functions hoặc `DefaultRootObject`).

Origin tuỳ chỉnh (ALB, EC2) không có OAC. Khoá bằng cách khác: CloudFront gửi một
**custom header bí mật**, ALB chỉ chấp nhận request có header đó (listener rule);
kèm security group chỉ cho phép prefix list `com.amazonaws.global.cloudfront.origin-facing`.

### 8.3 Cache key và policy

**Cache key** là vân tay của request. Hai request cùng cache key = CloudFront coi
là cùng một thứ và trả cùng một bản.

Mặc định cache key chỉ gồm **domain của distribution + đường dẫn**. Query string,
header, cookie **không** nằm trong đó trừ khi bạn đưa vào. Ba loại policy tách bạch
hai câu hỏi khác nhau:

| Policy | Trả lời câu hỏi |
|---|---|
| **Cache policy** | cái gì vào **cache key**, và TTL bao nhiêu |
| **Origin request policy** | cái gì được **chuyển tiếp tới origin** (không nhất thiết vào cache key) |
| **Response headers policy** | header nào CloudFront **thêm vào response** (CORS, HSTS, security headers) |

Sự tách này là điểm tinh tế đáng học nhất: bạn muốn chuyển `User-Agent` tới origin
để ghi log, nhưng **không** muốn nó vào cache key (vì có hàng nghìn giá trị → hit
ratio về 0). Cache policy bỏ nó ra, origin request policy đưa nó vào.

Quy tắc chung: **càng nhiều thứ trong cache key, hit ratio càng thấp**. Mỗi giá trị
khác nhau tạo một bản cache riêng ở **mỗi** edge location.

TTL có ba con số: **Minimum**, **Maximum**, **Default**. Origin gửi `Cache-Control:
max-age` thì CloudFront tôn trọng nhưng kẹp vào khoảng [Min, Max]; origin không gửi
gì thì dùng Default.

**Invalidation** xoá cache trước hạn: **1.000 path mỗi tháng miễn phí**, sau đó
~$0,005 mỗi path. Cách rẻ hơn và tốt hơn là **versioned object** — đổi tên file
(`app.a1b2c3.js`) thay vì xoá cache. URL mới thì không có cache cũ để xoá, và bạn
rollback được bằng cách trỏ lại tên cũ.

### 8.4 Cache behavior

Behavior khớp theo **path pattern** và quyết định: origin nào, policy nào, method
nào được phép, có bắt buộc HTTPS không, có gắn edge function không.

Thứ tự đánh giá là **từ trên xuống, dừng ở cái khớp đầu tiên**; behavior mặc định
(`*`) luôn ở cuối. Đặt sai thứ tự là bug im lặng: `/*` đặt trước `/api/*` thì
`/api/*` không bao giờ được dùng.

Mẫu chuẩn cho một ứng dụng web:

```
/api/*     → origin ALB    · cache policy CachingDisabled · cho phép mọi method
/static/*  → origin S3     · TTL 1 năm                    · versioned object
*          → origin S3     · TTL ngắn                     · index.html
```

Một distribution nhận **nhiều origin** và có **origin group** để tự chuyển sang
origin dự phòng khi origin chính trả 4xx/5xx — đó là DR ở tầng CDN, RTO tính bằng
giây, nhanh hơn hẳn Route 53 failover.

### 8.5 Signed URL và signed cookie

Cùng cơ chế: một policy JSON (hết hạn khi nào, IP nào được phép) được ký bằng
**private key**, CloudFront xác minh bằng **public key** trong một **key group**.

| | Signed URL | Signed cookie |
|---|---|---|
| Phạm vi | **một file** | **nhiều file** khớp một pattern |
| Dùng khi | tải một file, link chia sẻ có hạn | thư viện phim, khu vực trả phí, streaming HLS nhiều segment |
| URL | dài, có tham số chữ ký | **giữ nguyên URL gốc** |
| Client | mọi client | phải hỗ trợ cookie |

Ghi chú cần nhớ: cách cũ (*trusted signer*, dùng CloudFront key pair của tài khoản
root) đã lỗi thời; cách hiện hành là **trusted key group**, tạo và xoay khoá được
mà không cần credential root.

So với **S3 presigned URL**: presigned URL trỏ thẳng vào S3, dùng credential IAM
của người ký, không đi qua CDN. CloudFront signed URL đi qua CDN nên có cache, có
WAF, có geo restriction. Đề nói "phân phối nội dung trả phí toàn cầu" → **CloudFront
signed URL/cookie**; "cho một người tải một file từ bucket riêng tư" → **S3 presigned URL**.

### 8.6 CloudFront Functions và Lambda@Edge

| | **CloudFront Functions** | **Lambda@Edge** |
|---|---|---|
| Chạy ở đâu | **edge location (PoP)** | **regional edge cache**, không ở edge |
| Ngôn ngữ | JavaScript (ES 5.1+) | Node.js, Python |
| Thời gian tối đa | **< 1 milli giây** | **5 giây** (viewer) / **30 giây** (origin) |
| Bộ nhớ | 2 MB | 128 MB (viewer) / tới 10 GB (origin) |
| Trigger | viewer request/response | cả **4**: viewer + origin, request + response |
| Gọi mạng, đọc file | **không** | **có** |
| Truy cập body của request | không | có (origin trigger) |
| Giá | rẻ hơn khoảng **6 lần** | theo Lambda |
| Lưu trữ dữ liệu | **CloudFront KeyValueStore** | dịch vụ ngoài |

Điểm cơ chế quyết định lựa chọn: **Lambda@Edge luôn chạy ở REC, không ở PoP**. Vì
thế viewer-request trigger bằng Lambda@Edge tốn thêm một chặng mạng so với
CloudFront Functions. Nếu việc cần làm chỉ là viết lại URL, chuẩn hoá header, kiểm
tra một token đơn giản, hay redirect — dùng **CloudFront Functions**.

Dùng Lambda@Edge khi cần **gọi dịch vụ khác** (DynamoDB, S3, API xác thực), xử lý
**body**, hoặc chạy logic nặng — ví dụ server-side rendering, chọn ảnh theo thiết bị,
tích hợp bot detection.

Mẹo tối ưu: gắn Lambda@Edge vào **origin-request** thay vì viewer-request thì nó chỉ
chạy khi **cache miss**. Với hit ratio 95%, chi phí và độ trễ giảm 20 lần.

### 8.7 Origin Shield

Thêm **một tầng cache nữa** ở một Region bạn chọn, đứng giữa REC và origin. Mọi
REC đều hỏi Origin Shield trước khi hỏi origin.

Dùng khi: origin ở xa và tải nặng, nội dung được yêu cầu từ nhiều châu lục cùng lúc,
hoặc origin đắt tiền mỗi request (ví dụ transcoding). Đổi lại có **phí riêng cho
mỗi request tới Origin Shield**, và với nội dung ít được dùng lại thì nó chỉ thêm
một chặng.

Chọn Region đặt Origin Shield **gần origin nhất**, không phải gần người dùng.

**Geo restriction** ở CloudFront chặn theo quốc gia bằng danh sách cho phép hoặc
danh sách chặn, thực thi ở edge, miễn phí. Cần chặn theo tiêu chí phức tạp hơn
(quốc gia + đường dẫn + rate limit) thì dùng **WAF geo match rule**.

**Price class** giới hạn tập edge location được dùng (100 = rẻ nhất, chỉ Bắc Mỹ và
châu Âu; 200 thêm châu Á; All = tất cả). Giảm giá, đổi lại người dùng ở vùng bị loại
phải đi tới edge xa hơn.

---

## 9. Global Accelerator vs CloudFront

Cả hai đưa người dùng vào **mạng backbone của AWS** ngay tại edge gần nhất, nhưng
làm hai việc khác nhau.

| | **CloudFront** | **Global Accelerator** |
|---|---|---|
| Bản chất | **CDN có cache** | **định tuyến anycast tầng 4** |
| Tầng | 7 (HTTP/HTTPS/WebSocket) | 4 (**TCP, UDP**) |
| Cache | **có** | **không** |
| Địa chỉ | tên miền, IP thay đổi | **2 IP anycast tĩnh** |
| Endpoint | S3, ALB, NLB, EC2, HTTP bất kỳ | ALB, NLB, EC2, **Elastic IP** |
| Chuyển vùng khi lỗi | origin group, vài giây | **~30 giây, không phụ thuộc DNS** |
| Điều khiển lưu lượng | behavior theo path | **traffic dial** theo Region, **weight** theo endpoint |
| TLS | kết thúc tại edge | **đi thẳng**, không giải mã |

Điểm mạnh riêng của Global Accelerator là **IP không đổi**. Failover xảy ra ở tầng
định tuyến chứ không ở DNS, nên client **không phải chờ TTL hết hạn** — đó là lý do
RTO của nó tính bằng giây trong khi DNS failover tính bằng phút. Và IP tĩnh là thứ
duy nhất thoả mãn yêu cầu "đối tác chỉ whitelist địa chỉ IP".

Chọn:

- Nội dung tĩnh, API HTTP, video → **CloudFront**.
- Game, VoIP, MQTT/IoT, giao thức tự chế trên TCP/UDP → **Global Accelerator**.
- Cần IP tĩnh toàn cầu, hoặc chuyển vùng nhanh giữa các Region → **Global Accelerator**.
- Cần cả hai (web có cache **và** IP tĩnh) → CloudFront cho `/static/*`, Global
  Accelerator cho phần còn lại; chúng không loại trừ nhau.

---

## Bảng số phải nhớ

| Con số | Giá trị |
|---|---|
| VPC / subnet CIDR | **/16 tới /28**; 5 CIDR mỗi VPC (tăng tới 50) |
| **IP dự trữ mỗi subnet** | **5** — dùng được = **2^(32−prefix) − 5**; `/28` → **11** |
| Amazon DNS resolver | **VPC CIDR base + 2**, và `169.254.169.253` |
| DNS query mỗi ENI | **1.024 gói/giây** — không tăng được |
| IGW mỗi VPC | **1** |
| **NAT Gateway băng thông** | **5 Gbps → 100 Gbps**; **1 → 10 triệu pps** |
| **NAT Gateway kết nối đồng thời** | **55.000 mỗi IPv4 tới mỗi đích duy nhất**; 8 IP → **440.000** |
| Giá NAT Gateway / Interface Endpoint / Gateway Endpoint | ~$0,045/giờ + $0,045/GB · ~$0,01/giờ mỗi AZ + $0,01/GB · **$0** |
| SG: rule mỗi chiều / SG mỗi ENI | **60** (tăng được) / **5** (tăng tới 16) |
| NACL: rule mỗi chiều / số hiệu | **20** (tăng tới 40) / **1–32766** |
| **Ephemeral port cần mở ở NACL** | **1024–65535** |
| Peering đang hoạt động mỗi VPC | **50** (tăng tới 125) |
| Transit Gateway | **5.000 attachment**; **100 Gbps** mỗi VPC attachment mỗi AZ; 7,5 triệu pps |
| Giá Transit Gateway | ~$0,05/giờ mỗi attachment + ~$0,02/GB |
| Site-to-Site VPN | **1,25 Gbps mỗi tunnel**, **2 tunnel** mỗi kết nối |
| **Độ trễ ELB thêm vào** | ALB ~**400 micro giây** · NLB ~**100 micro giây** |
| **Cross-zone mặc định** | ALB **bật** (miễn phí) · NLB và GWLB **tắt** (bật thì tính phí cross-AZ) |
| ALB idle timeout / deregistration delay | **60 giây** / **300 giây** (1–3600) |
| Health check của target group | interval **5–300 giây**, ngưỡng **2–10** |
| Chứng chỉ SNI mỗi ALB listener | **25** |
| GWLB | **GENEVE cổng 6081** |
| Route 53 health check | **30 giây** (hoặc 10 giây fast), ngưỡng mặc định **3** → phát hiện ~**90 giây** |
| Route 53 routing policy | **8** (có IP-based) |
| Multivalue answer | tới **8** bản ghi khoẻ |
| Geoproximity bias | **−99 tới +99** |
| CloudFront | **400+ edge location**, **13 REC**, **410+ PoP** |
| CloudFront invalidation | **1.000 path/tháng miễn phí**, sau đó ~$0,005/path |
| CloudFront Functions vs Lambda@Edge | **< 1 ms / 2 MB** · **5 giây** viewer, **30 giây** origin |
| Global Accelerator | **2 IP anycast tĩnh**, chuyển vùng ~**30 giây** |

## Bẫy đề thi

**"Subnet có checkbox public."** Không có. Public là **route `0.0.0.0/0` → IGW**;
đặt tên "public" mà thiếu route đó thì vẫn là private.

**"Instance có public IP là ra được internet."** Còn cần route tới IGW, SG cho phép
outbound, và NACL cho phép **cả hai chiều**. Và instance **không nhìn thấy** public
IP của mình trên interface vì IGW làm NAT một-một.

**"NAT Gateway trần 10 Gbps / 45 Gbps."** Sai — **5 Gbps tự scale tới 100 Gbps**.
Con số cũ đến từ một blog năm 2018 vẫn được chép khắp nơi.

**"NAT Gateway chỉ chịu được 55.000 kết nối."** Sai — đó là hạn mức **mỗi IPv4 tới
mỗi đích duy nhất** (IP đích + cổng đích + giao thức). Gắn 8 IP → **440.000** tới
cùng một đích. Gặp `ErrorPortAllocation` thì **thêm IP**, đừng thêm gateway.

**"NAT Gateway đặt trong private subnet."** Nó phải ở **public subnet** vì chính nó
cần đường ra IGW.

**"Security Group chặn được một IP."** SG **chỉ có ALLOW**. Muốn DENY → **NACL**.
Muốn chặn theo nội dung HTTP → **WAF**.

**"NACL cho phép cổng 443 là kết nối chạy."** NACL **stateless** — gói trả về đến từ
cổng nguồn 443 tới **ephemeral port** của client, cần rule inbound cho **1024–65535**.
Thiếu là timeout, không phải "connection refused".

**"Gateway Endpoint dùng được từ on-premises."** Không. Nó chỉ hoạt động từ **trong
VPC**, và không đi qua peering hay Transit Gateway. Từ on-prem → **Interface
Endpoint**, và nó **có phí**.

**"Dùng NAT Gateway để instance private gọi S3 rẻ nhất."** Sai — **S3 Gateway
Endpoint miễn phí**, cắt hẳn cả phí giờ lẫn phí xử lý dữ liệu.

**"A peering B, B peering C, vậy A tới được C."** **Không transitive**. Và VPC B
cũng **không đi ké** IGW, NAT Gateway, Gateway Endpoint hay VPN của VPC A.

**"Tạo peering xong là hai bên nói chuyện được."** Phải thêm route ở **cả hai** route
table. Đây là lỗi phổ biến nhất với peering.

**"Flow Logs bắt được mọi thứ."** Không có: DNS tới resolver của AWS, metadata
`169.254.169.254`, Time Sync, DHCP, và **nội dung gói tin**. Cần payload →
**Traffic Mirroring**; cần DNS → **Resolver query log**.

**"NLB giữ IP nguồn, chấm hết."** Đúng với target `instance`, nhưng target `ip` với
**TCP/TLS thì mặc định TẮT** — target thấy IP của NLB. Và không hoạt động khi target
được với tới qua **Transit Gateway**.

**"ALB cho IP tĩnh để whitelist."** ALB không có IP tĩnh. Cần IP tĩnh → **NLB**
(gắn EIP), hoặc **NLB với target group kiểu `alb`** đặt trước ALB, hoặc **Global
Accelerator**.

**"Gắn WAF vào NLB."** Không được — WAF làm việc ở tầng 7 còn NLB không giải mã.
WAF gắn vào **ALB, CloudFront, API Gateway, AppSync, Cognito**.

**"Cross-zone mặc định giống nhau."** **ALB bật sẵn và miễn phí; NLB/GWLB tắt sẵn và
bật thì tính phí cross-AZ.** Khi tắt, lưu lượng chia đều **theo AZ** chứ không theo
target — AZ ít target thì mỗi target gánh nhiều hơn.

**"Bật sticky session để ứng dụng scale ngang."** Sticky là giải pháp tạm: làm tải
lệch và mất trạng thái khi target chết. Đúng là **đưa session ra ngoài** —
ElastiCache hoặc DynamoDB.

**"CNAME cho zone apex."** Chuẩn DNS cấm. Dùng **alias** — nó trả về bản ghi A, miễn
phí truy vấn, và trỏ được tới ALB/CloudFront/S3. Nhưng **không trỏ thẳng vào EC2**.

**"Multivalue answer thay được ELB."** Không — nó không biết tải, chỉ loại bản ghi
hỏng khỏi câu trả lời DNS.

**"Route 53 health check kiểm tra được tài nguyên trong private subnet."** Không —
chỉ endpoint công cộng. Private → health check kiểu **CloudWatch alarm**.

**"Đưa nhiều header vào cache policy cho chắc."** Mỗi giá trị khác nhau tạo một bản
cache riêng ở mỗi edge → hit ratio sụp. Cần header ở origin nhưng không cần trong
cache key → đưa vào **origin request policy**.

**"Dùng OAI cho bucket mã hoá SSE-KMS."** OAI **không hỗ trợ SSE-KMS**, không hỗ trợ
method động, không hỗ trợ Region ra mắt sau 1/2023. Dùng **OAC**.

**"Lambda@Edge chạy ở edge location."** Nó chạy ở **regional edge cache**. Việc nhẹ
và cần độ trễ thấp nhất → **CloudFront Functions** (< 1 ms, chạy ngay tại PoP).

**"Global Accelerator có cache."** Không. Nó tăng tốc **đường đi**, không lưu nội
dung. Cần cache → **CloudFront**.

## Cây quyết định

**Cho instance private ra internet:** cần gọi S3/DynamoDB → **Gateway Endpoint**
(miễn phí). Cần gọi dịch vụ AWS khác → **Interface Endpoint**. Cần gọi internet
công cộng → **NAT Gateway mỗi AZ**. Chỉ nhận kết nối vào, không cần ra →
**không cần gì cả**.

**Nối mạng:** hai VPC → **peering**. Trên 5 VPC, hoặc cần nối on-premises, hoặc cần
phân đoạn → **Transit Gateway**. Cung cấp dịch vụ một chiều cho VPC của người khác
→ **PrivateLink**. Nối on-prem nhanh và rẻ → **Site-to-Site VPN**; băng thông lớn
và độ trễ ổn định → **Direct Connect**; cần cả hai → DX với VPN dự phòng.

**Chọn load balancer:** HTTP/HTTPS có định tuyến theo path/host, target là Lambda
hoặc container → **ALB**. TCP/UDP, cần IP tĩnh, cần độ trễ thấp nhất, cần triệu
kết nối mỗi giây → **NLB**. Chèn firewall/IDS của bên thứ ba → **GWLB**. Cần IP tĩnh
*và* định tuyến tầng 7 → **NLB đứng trước ALB**.

**Chọn routing policy:** một tài nguyên → Simple. Chuyển dần lưu lượng → Weighted.
Nhanh nhất cho người dùng → Latency-based. Active-passive → Failover + health check.
Ràng buộc pháp lý theo quốc gia → Geolocation. Dịch chuyển ranh giới vùng phục vụ →
Geoproximity. Nhiều IP có health check → Multivalue. Theo dải IP của ISP → IP-based.

**Tăng tốc toàn cầu:** nội dung cache được, HTTP → **CloudFront**. Không cache được,
TCP/UDP, hoặc cần IP tĩnh → **Global Accelerator**. Chỉ cần đưa người dùng tới Region
gần nhất bằng DNS → **latency-based routing** (rẻ nhất, nhưng chậm khi failover).

**Bảo mật tầng mạng:** cho phép theo nguồn → **Security Group** (tham chiếu SG khác
làm nguồn). Chặn một dải IP → **NACL**. Chặn theo nội dung HTTP, SQL injection, rate
limit → **WAF**. Chống DDoS tầng 3/4 → **Shield** (Standard mặc định, Advanced trả
phí). Điều tra ai nói chuyện với ai → **Flow Logs**.

## Nối với thực hành

Lab có lời giải:

- [`learn-aws/labs/w02-vpc-networking/`](../../learn-aws/labs/w02-vpc-networking/) —
  **~$0,04/giờ, để quên một tháng ≈ $30**, đặt hẹn giờ ngay khi `apply` xong. Lab
  này dựng instance ở private subnet và vào bằng SSM **qua ba interface endpoint**
  thay vì NAT Gateway — đó chính là mục [3](#3-vpc-endpoint) hiện ra thành hoá đơn.
  So sánh bảng giá trong README của lab với bảng ở mục 3: cùng một quyết định kiến
  trúc, một bên là lý thuyết, một bên là tiền thật.
- [`learn-aws/labs/w08-dns-cdn-edge/`](../../learn-aws/labs/w08-dns-cdn-edge/) —
  CloudFront trong hạn mức miễn phí. Chạm vào [cache key](#83-cache-key-và-policy):
  playbook gọi cùng một URL với query string khác nhau và cho bạn xem header
  `X-Cache: Hit from cloudfront` đổi thành `Miss` — hiểu hit ratio bằng cách nhìn
  chứ không bằng cách đọc.

Đáng tự làm thêm khi lab w02 đang chạy, mỗi cái chứng minh một mục:

```bash
# Longest prefix match (1.4): xem route nào thực sự được chọn cho một đích.
aws ec2 describe-route-tables --profile learn \
  --query 'RouteTables[].Routes[].[DestinationCidrBlock,GatewayId,NatGatewayId,VpcPeeringConnectionId]' \
  --output table

# Ephemeral port (mục 2): thêm NACL inbound chỉ cho 443, rồi curl ra ngoài.
# Kết nối treo tới timeout chứ không refused — triệu chứng phải nhận ra được.

# Flow Logs (mục 5): lọc đúng những gói bị chặn.
aws logs filter-log-events --profile learn --log-group-name /aws/vpc/flowlogs \
  --filter-pattern '[version,account,eni,src,dst,srcport,dstport,proto,pkt,bytes,start,end,action=REJECT,status]'
```

Lab tự viết (đề bài, không có lời giải — xem
[quy ước](../../learn-aws/labs-self/CONVENTIONS.md)):

- `learn-aws/labs-self/w02-*/` — dựng VPC từ file rỗng. Đề bài nói "instance ở
  private subnet phải `apt update` được" và **không** nói tạo resource nào; chọn
  NAT Gateway hay endpoint là quyết định của bạn, và `verify.sh` chấm cả chi phí.
- `learn-aws/labs-self/w08-*/` — dựng CloudFront trước S3 riêng tư. Phần khó là
  [OAC](#82-oac-thay-oai) và behavior đúng thứ tự, không phải cú pháp Terraform.

Cơ sở dữ liệu nằm trong private subnet nên mục [2](#2-security-group-vs-nacl) và
[3](#3-vpc-endpoint) là tiền đề của [`03-database.md`](03-database.md); ngược lại
RDS Proxy và ElastiCache đều là ENI trong subnet của bạn, chịu đúng những luật ở đây.

## Nguồn nói khác

Đã kiểm chứng lại bằng docs chính thức (mốc **2026-08**).

| Nguồn | Nói | Thực tế |
|---|---|---|
| `03-database-services.md` không có, nhưng `04-networking-services.md` §2 và `Q-service-comparisons.md` §4.1 | NLB độ trễ "~100 ms", ALB "~400 ms" | Đơn vị là **micro giây**, không phải milli giây — sai **1.000 lần**. `Q` §4.1 ghi đúng "< 100 microseconds" ở một dòng rồi lại ghi "~50-100ms" cho ALB ở dòng khác; hai chỗ mâu thuẫn nhau trong cùng một bảng |
| Blog AWS 2018 (còn được chép ở nhiều tài liệu ôn) | NAT Gateway "10 Gbps tự scale tới 45 Gbps" | **5 Gbps tự scale tới 100 Gbps**, và **1 → 10 triệu pps** ([NAT gateway basics](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-basics.html)). Bản thân `04-networking-services.md` §1 ghi đúng 5–100 Gbps — nhưng tài liệu ôn khác thì không |
| Blog AWS 2018, và mọi tài liệu chép lại | NAT Gateway "hỗ trợ 55.000 kết nối đồng thời tới mỗi đích" như trần của **gateway** | **55.000 mỗi địa chỉ IPv4** tới mỗi đích duy nhất; gắn tới **8 IPv4** (1 chính + 7 phụ) → **440.000** ([whitepaper](https://docs.aws.amazon.com/whitepapers/latest/building-scalable-secure-multi-vpc-network-infrastructure/using-nat-gateway-for-centralized-egress.html)) |
| `Q-service-comparisons.md` §4.3 | Transit Gateway "50 Gbps per AZ" | **Tới 100 Gbps mỗi VPC attachment mỗi AZ**, 7,5 triệu pps ([TGW quotas](https://docs.aws.amazon.com/vpc/latest/tgw/transit-gateway-quotas.html)) |
| `04-networking-services.md` §3 | "Route 53 routing policies (7 types)" | **8** — thiếu **IP-based routing**, có từ 2022 ([docs](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-policy-ipbased.html)) |
| `04-networking-services.md` §4, `Q` §4.2 | CloudFront "400+ edge locations" / "600+" | **Hơn 400 edge location**, **13 regional edge cache**, tổng **hơn 410 PoP** ([whitepaper](https://docs.aws.amazon.com/whitepapers/latest/aws-fault-isolation-boundaries/points-of-presence.html)). Con số "600+" của `Q` không khớp nguồn nào |
| `Q-service-comparisons.md` §4.1 | ALB cross-zone "always enabled", NLB "disabled by default" | Đúng ở mức load balancer, nhưng **thiếu**: ALB **tắt được ở mức target group**, và NLB bật/tắt được ở **cả hai** mức, với target group ghi đè load balancer ([docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/edit-target-group-attributes.html)) |
| `04-networking-services.md` §2, `Q` §4.1 | NLB "Preserve source IP: Yes" (không điều kiện) | Phụ thuộc target type: `instance` **bật**; `ip` với UDP/TCP_UDP/QUIC **bật, không tắt được**; `ip` với **TCP/TLS mặc định TẮT**. Và không hoạt động qua **Transit Gateway** ([docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/edit-target-group-attributes.html)) |
| `Q-service-comparisons.md` §4.1 | NLB không có mục Security Group | NLB **hỗ trợ security group** từ 2023, nhưng phải bật **lúc tạo** — không thêm được sau |
| `04-networking-services.md` §4 | "OAI (Origin Access Identity) / OAC (newer, recommended)" — coi như tương đương | OAI **không hỗ trợ** SSE-KMS, method động (`PUT`/`POST`/`DELETE`), và Region ra mắt sau **1/2023** ([docs](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)). Với thiết lập mới, OAI là **đáp án sai** |
| `04-networking-services.md` §4 | Lambda@Edge chạy ở "Regional Edge Caches (slower, more powerful)" | Đúng nhưng chưa đủ: **mọi** trigger của Lambda@Edge chạy ở REC, kể cả viewer-request. Đó là lý do CloudFront Functions (chạy ở PoP) nhanh hơn hẳn cho việc nhẹ |
| `04-networking-services.md` §1 | Direct Connect "50 Mbps – 100 Gbps" | Dedicated connection hiện có **1/10/100/400 Gbps**; hosted connection từ 50 Mbps |

Nguồn cũng **thiếu hẳn**, dù đều nằm trong đề SAA-C03 hiện hành: cache policy /
origin request policy / response headers policy (nó chỉ nói "cache keys"), Origin
Shield, origin group và origin failover, trusted key group (nó vẫn ngụ ý cách cũ),
Route 53 Resolver endpoint cho kiến trúc lai, split-horizon DNS, GWLB endpoint trong
route table, ALB idle timeout, và điều kiện `enableDnsHostnames` cho private hosted zone.

## Ngoài phạm vi

- **Cloud WAN** — quản lý mạng toàn cầu tập trung, mức Professional: <https://docs.aws.amazon.com/network-manager/>
- **VPC Lattice** — service mesh của AWS, `docs/CONVENTIONS.md` loại tường minh: <https://docs.aws.amazon.com/vpc-lattice/>
- **Transit Gateway Connect (GRE/BGP)** — loại tường minh trong quy ước: <https://docs.aws.amazon.com/vpc/latest/tgw/tgw-connect.html>
- **Network Firewall** — firewall có trạng thái ở tầng VPC; biết tên là đủ: <https://docs.aws.amazon.com/network-firewall/>
- **Traffic Mirroring** — sao chép gói tin để phân tích sâu: <https://docs.aws.amazon.com/vpc/latest/mirroring/>
- **IPv6 trong VPC, NAT64/DNS64, egress-only IGW** — đề chạm rất nhẹ: <https://docs.aws.amazon.com/vpc/latest/userguide/vpc-migrate-ipv6.html>
- **API Gateway** — thuộc `06-tich-hop.md`, không phải file này: <https://docs.aws.amazon.com/apigateway/>
- **CloudFront field-level encryption, KeyValueStore, real-time log** — hiếm khi ra thi: <https://docs.aws.amazon.com/AmazonCloudFront/>

## Tự kiểm tra

**1.** Instance ở private subnet gọi một API HTTPS bên ngoài. NACL của subnet có
inbound `allow 443` và outbound `allow 443`; security group cho phép outbound tất
cả. Kết nối treo tới timeout. Giải thích bằng cơ chế và nêu cách sửa.

<details><summary>Đáp án</summary>

NACL **stateless**: nó xét từng gói độc lập, không có bảng theo dõi kết nối. Gói đi
ra có `dst port 443` nên khớp outbound. Gói trả về có `src port 443` và
`dst port = ephemeral port của client` (ví dụ 47234) — nó **không** khớp rule inbound
`allow 443`, nên bị chặn. TCP handshake không hoàn tất → treo tới timeout, chứ không
phải "connection refused".

Sửa: thêm rule NACL inbound `allow TCP 1024–65535`. Security Group không cần sửa vì
nó **stateful** — hạ tầng Nitro đã ghi luồng đi ra và cho gói về qua bất kể rule inbound.
</details>

**2.** Kiến trúc: 200 instance ở private subnet, mỗi ngày tải 8 TB ảnh từ S3 và gọi
Secrets Manager mỗi 5 phút. Hoá đơn NAT Gateway rất cao. Nêu hai thay đổi và ước
lượng mỗi cái tiết kiệm được gì.

<details><summary>Đáp án</summary>

**S3 Gateway Endpoint** — miễn phí hoàn toàn. 8 TB/ngày qua NAT Gateway là
8.000 GB × $0,045 ≈ **$360/ngày** chỉ riêng phí xử lý dữ liệu, chưa kể phí giờ.
Endpoint đưa con số đó về **$0**, và chỉ cần thêm một mục vào route table.

**Interface Endpoint cho Secrets Manager** — ~$0,01/giờ mỗi AZ, ba AZ là ~$22/tháng
cộng $0,01/GB. Lưu lượng Secrets Manager nhỏ nên tiết kiệm ở đây không đáng kể, nhưng
nó là lý do **bảo mật**: request không rời khỏi mạng AWS, và bạn gắn được endpoint
policy giới hạn secret nào được đọc.

Đáp án sai hấp dẫn là "thêm NAT Gateway" — không giảm phí xử lý dữ liệu chút nào, chỉ
thêm phí giờ.
</details>

**3.** NLB có 2 target ở AZ-a và 8 target ở AZ-b, cross-zone tắt. Traffic tới đều
giữa hai AZ. Mỗi target ở AZ-a nhận gấp mấy lần AZ-b? Nêu hai cách sửa và đánh đổi.

<details><summary>Đáp án</summary>

Cross-zone tắt nghĩa là node của NLB ở mỗi AZ chỉ gửi tới target **trong AZ đó**.
Mỗi AZ nhận 50% lưu lượng: AZ-a chia cho 2 target = 25% mỗi target; AZ-b chia cho 8
= 6,25% mỗi target. Gấp **4 lần**.

Cách 1 — **cân số target mỗi AZ**. Miễn phí, giữ lưu lượng trong AZ nên không phát
sinh phí cross-AZ và độ trễ thấp hơn. Nên là lựa chọn mặc định.

Cách 2 — **bật cross-zone**. Phân phối đều ngay, nhưng với NLB thì mọi byte đi sang
AZ khác đều **tính phí truyền liên AZ**, và thêm một chặng độ trễ. Với ALB thì cách
này miễn phí và đã bật sẵn — đó chính là chỗ mặc định của hai loại khác nhau.
</details>

**4.** Vì sao `example.com` không thể là CNAME, còn alias thì được? Và alias có
trỏ thẳng vào một EC2 instance được không?

<details><summary>Đáp án</summary>

Chuẩn DNS cấm CNAME cùng tồn tại với bản ghi khác trên cùng một tên. Zone apex bắt
buộc có **SOA** và **NS**, nên CNAME ở đó là vi phạm — resolver sẽ hành xử không
xác định.

**Alias** không phải bản ghi DNS chuẩn; nó chỉ tồn tại bên trong Route 53. Khi có
truy vấn, Route 53 tự phân giải đích rồi trả về **bản ghi A/AAAA** thật. Client không
bao giờ thấy alias, nên không có xung đột với SOA/NS. Kèm hai lợi ích: truy vấn
**miễn phí** và IP tự cập nhật khi tài nguyên đổi.

**Không trỏ thẳng vào EC2 instance được.** Alias chỉ nhận ALB/NLB, CloudFront,
S3 website endpoint, API Gateway, Global Accelerator, VPC endpoint, hoặc một bản ghi
khác trong cùng hosted zone. Muốn trỏ tới instance thì dùng bản ghi **A** với Elastic IP.
</details>

**5.** Trang web dùng CloudFront, hit ratio chỉ 12%. Log cho thấy CloudFront chuyển
tiếp mọi header và mọi cookie tới origin. Giải thích nguyên nhân và cách sửa mà vẫn
giữ được dữ liệu origin cần.

<details><summary>Đáp án</summary>

Header và cookie được chuyển tiếp mà **cũng nằm trong cache key** thì mỗi tổ hợp giá
trị tạo một bản cache riêng, ở **mỗi** edge location. `User-Agent` có hàng nghìn giá
trị, cookie phiên thì gần như duy nhất mỗi người dùng — số bản cache bùng nổ và hầu
như không bản nào được dùng lại. Hit ratio 12% là hệ quả tất yếu.

Sửa bằng cách tách hai câu hỏi: **cache policy** chỉ giữ những thứ thật sự làm thay
đổi nội dung (ví dụ `Accept-Encoding` và một query string `?v=`); **origin request
policy** vẫn chuyển tiếp `User-Agent`, `Referer` và cookie phân tích tới origin. Origin
vẫn nhận đủ dữ liệu, còn cache key thì gọn lại và hit ratio tăng.

Với tài sản tĩnh, thêm **versioned object** (`app.a1b2c3.js`) và TTL dài — vừa bỏ
được invalidation vừa cho phép cache một năm.
</details>

**6.** Đối tác chỉ whitelist địa chỉ IP, ứng dụng của bạn là HTTP có định tuyến theo
path, chạy ở hai Region để chịu lỗi. Nêu kiến trúc và giải thích vì sao ALB đơn thuần
hay Route 53 failover không đủ.

<details><summary>Đáp án</summary>

**ALB không có IP tĩnh** — AWS thay đổi IP của nó khi scale, nên whitelist theo IP
sẽ đứt bất kỳ lúc nào.

**Route 53 failover** trả về tên miền và dựa vào DNS. Đối tác whitelist IP thì họ
cũng phải theo được IP mới, mà DNS failover còn mất ~90 giây phát hiện cộng TTL — RTO
tính bằng phút.

Kiến trúc đúng: **Global Accelerator** đứng trước hai ALB ở hai Region. Nó cho **2 IP
anycast tĩnh** để đối tác whitelist một lần; ALB vẫn lo định tuyến theo path; và
chuyển vùng xảy ra ở **tầng định tuyến chứ không qua DNS**, nên client không phải chờ
TTL — RTO khoảng **30 giây**. Traffic dial còn cho phép rút lưu lượng khỏi một Region
một cách có kiểm soát khi triển khai.

Lựa chọn thay thế rẻ hơn nhưng yếu hơn: **NLB với Elastic IP + target group kiểu
`alb`** ở mỗi Region — được IP tĩnh nhưng vẫn phải dùng DNS để chuyển vùng.
</details>
