# Nền tảng AWS — thứ phải hiểu trước tuần 1

> Bài này không dạy dịch vụ nào cả. Nó dạy cái khung mà mọi dịch vụ nằm trong đó:
> AWS đặt máy ở đâu, ai chịu trách nhiệm phần nào, kiến trúc "tốt" nghĩa là gì theo
> định nghĩa của người ra đề, tiền chảy theo mô hình nào, và vì sao mọi thứ bạn làm
> — console, CLI, Terraform — cuối cùng đều là một lời gọi API giống hệt nhau.
> Đọc xong bài này, tuần 1 và tuần 2 sẽ không còn cảm giác "học vẹt tên dịch vụ".

---

## Học xong bài này bạn phải trả lời được

1. Vì sao AZ chứ không phải Region mới là đơn vị của tính sẵn sàng, và khi nào bạn buộc phải nghĩ tới Region thứ hai?
2. `us-east-1a` trong account của bạn và `us-east-1a` trong account của đồng nghiệp có phải cùng một chỗ không?
3. Ranh giới trách nhiệm bảo mật dịch chuyển thế nào khi bạn đi từ EC2 → RDS → Lambda → S3?
4. Đề thi cho một tình huống, bạn nhận ra nó đang test trụ cột nào trong sáu trụ cột Well-Architected?
5. On-Demand, Reserved Instance, Savings Plan, Spot — khác nhau ở cái gì bạn *cam kết*, không phải ở giá?
6. Organizations giải quyết vấn đề gì mà một account đơn lẻ không giải quyết được?
7. Vì sao "làm bằng console" và "làm bằng Terraform" cho ra kết quả giống nhau, và điều đó có hệ quả gì với bảo mật?
8. Eventual consistency và service quota — hai thứ này làm hỏng script của bạn theo kiểu nào?

---

## Bản đồ khái niệm

```
                        AWS Partition (aws | aws-cn | aws-us-gov)
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        │                            │                            │
   Region us-east-1             Region eu-west-1            Region ap-southeast-1
   (cô lập hoàn toàn)           (cô lập hoàn toàn)          ...
        │
        ├── AZ use1-az1 ──┐
        ├── AZ use1-az2 ──┼── nối nhau bằng metro fiber riêng, độ trễ rất thấp
        ├── AZ use1-az4 ──┘   nhưng NGUỒN ĐIỆN / LÀM MÁT / MẠNG ĐỘC LẬP
        │
        ├── Local Zone us-east-1-bos-1     ← phần mở rộng của Region, đặt gần người dùng
        │
        └── (tách rời hẳn) Edge location / PoP — CloudFront, Route 53, Global Accelerator
                                                 750+ điểm, KHÔNG chạy EC2 của bạn


   Mọi thao tác dưới đây đổ về CÙNG MỘT tập API:

   Console ──┐
   AWS CLI ──┤
   SDK     ──┼──► AWS API endpoint ──► IAM (được phép không?) ──► Control plane ──► tài nguyên
   Terraform ┤                             │
   CloudFormation                          └──► CloudTrail ghi lại TOÀN BỘ
```

Ba lớp cần tách bạch trong đầu ngay từ đầu:

| Lớp | Là gì | Ví dụ hỏng thì sao |
|---|---|---|
| **Control plane** | API để tạo/sửa/xóa tài nguyên | Không launch được instance mới, nhưng instance đang chạy vẫn chạy |
| **Data plane** | Đường đi của traffic thật sự | Instance không phục vụ được request |
| **Management plane** | Billing, Organizations, IAM | Không đăng nhập được, không đổi được quyền |

Kiến trúc chịu lỗi tốt là kiến trúc mà data plane không phụ thuộc control plane khi
sự cố xảy ra. Đây là lý do tuần 11 sẽ nói "pre-provision tài nguyên DR thay vì tạo
lúc thảm họa".

---

## 1. Địa lý của AWS

### Region — đơn vị cô lập lỗi lớn nhất

Một **Region** là một cụm hạ tầng độc lập trong một vùng địa lý. Tính đến hiện tại
AWS có **39 Region** và **123 Availability Zone** (con số này tăng liên tục —
kiểm tra lại trang Global Infrastructure trước khi tin).

Region quan trọng vì bốn lý do, theo đúng thứ tự đề thi hay hỏi:

1. **Cô lập lỗi.** Region này sập không kéo Region kia sập. AWS thiết kế Region để
   không chia sẻ hạ tầng vật lý với nhau.
2. **Chủ quyền dữ liệu.** Dữ liệu bạn đặt ở `eu-west-1` không tự chảy sang Region
   khác. Đề thi gặp từ khóa "GDPR", "dữ liệu phải ở lại quốc gia X" → nghĩ Region.
3. **Độ trễ.** Gần người dùng thì nhanh hơn. Nhưng nếu bài toán chỉ là nội dung
   tĩnh, câu trả lời thường là CloudFront chứ không phải mở Region mới.
4. **Giá.** Mỗi Region một bảng giá. `us-east-1` rẻ nhất, `ap-southeast-1` đắt hơn
   khoảng 10–25%.

Hầu hết dịch vụ là **regional**: bạn tạo một S3 bucket, nó nằm trong đúng một Region.
Một số ít là **global** hoặc có control plane global:

| Dịch vụ | Tính chất | Ý nghĩa |
|---|---|---|
| IAM | Global | User/role/policy dùng chung cho cả account |
| Route 53 | Global | Hosted zone không thuộc Region nào |
| CloudFront | Global (edge) | Distribution phủ toàn cầu |
| S3 | Bucket là regional, **tên bucket là global unique** | Trùng tên với account khác trên thế giới là tạo không được |
| Organizations, Billing | Global, endpoint ở `us-east-1` | Nhiều API billing chỉ gọi được ở `us-east-1` |

> **Bắc cầu:** Region gần với khái niệm một *cluster Kubernetes riêng biệt* hơn là
> một namespace. Không có "kubectl get pods --all-regions". Mỗi Region là một
> control plane riêng, một endpoint riêng, một hạn ngạch riêng. Đây là lý do quy
> tắc số 1 trong kế hoạch 12 tuần là *một region duy nhất*: tài nguyên bị bỏ quên
> ở Region bạn không mở lại chính là cách đốt credit nhanh nhất.

### Availability Zone — đơn vị của tính sẵn sàng

Mỗi Region có **tối thiểu ba AZ**. Theo tài liệu AWS, các AZ "cách nhau một khoảng
có ý nghĩa, nhiều kilomet, nhưng đều nằm trong phạm vi 100 km (60 dặm) của nhau",
nối với nhau bằng metro fiber chuyên dụng, dư thừa, độ trễ thấp.

Cái quan trọng không phải khoảng cách. Cái quan trọng là **AZ có nguồn điện, làm
mát và mạng độc lập**. Một AZ mất điện thì AZ khác vẫn chạy. Đó là lý do:

> **Multi-AZ = high availability. Multi-Region = disaster recovery.**

Câu đó đáng ghi ra giấy dán màn hình. Đề SAA phân biệt hai chuyện này liên tục.
"Chịu được mất một data center" → trải qua nhiều AZ. "Chịu được mất cả một Region"
→ mới cần Region thứ hai, và lúc đó bạn phải trả giá bằng replication và độ phức tạp.

Hai chi tiết dễ bị bẫy:

**AZ name không phải AZ ID.** AWS ánh xạ AZ vật lý sang tên (`us-east-1a`,
`us-east-1b`…) **ngẫu nhiên theo từng account** ở các Region cũ, để tránh việc ai
cũng dồn vào "zone a". Nên `us-east-1a` của bạn có thể là chỗ khác với
`us-east-1a` của người bên cạnh. Định danh ổn định là **AZ ID** — ví dụ
`use1-az1` — giống nhau ở mọi account. Chuyện này chỉ thành vấn đề khi bạn chia sẻ
subnet giữa các account (AWS RAM) hoặc muốn tránh traffic đi chéo AZ.

**Traffic đi chéo AZ mất tiền.** Không nhiều, nhưng có. Kiến trúc tốt giữ traffic
trong cùng AZ khi có thể, và chỉ trả giá cross-AZ ở chỗ nó mua được tính sẵn sàng.

> **Bắc cầu:** AZ chính là thứ mà `topology.kubernetes.io/zone` trỏ tới, và
> pod anti-affinity theo zone chính là "trải service qua nhiều AZ". Khác biệt: trên
> k8s bạn tự dựng cụm để có nhiều zone; trên AWS thì AZ có sẵn, việc của bạn là
> *dùng* nó — đặt subnet ở nhiều AZ, đặt ASG trải nhiều AZ, bật Multi-AZ cho RDS.

### Local Zone — Region kéo dài ra gần người dùng

Local Zone là **phần mở rộng của một Region**, đặt ở một thành phố lớn, chạy một
tập con dịch vụ (EC2, EBS, VPC…). Bạn opt-in, tạo subnet trong Local Zone, và VPC
của bạn trải luôn ra đó. Control plane vẫn nằm ở **parent Region**.

Dùng khi: workload cần độ trễ một chữ số mili-giây tới người dùng ở một thành phố
cụ thể (game real-time, media production, ML inference tại chỗ) mà Region gần nhất
vẫn quá xa.

Không dùng khi: bài toán chỉ là phân phối nội dung → CloudFront rẻ hơn và đơn giản hơn.

### Edge location — mạng lưới riêng, không phải nơi chạy compute của bạn

AWS có **hơn 750 điểm hiện diện** (PoP: CloudFront edge location + regional edge
cache). Chúng phục vụ:

- **CloudFront** — cache nội dung tĩnh và động ở gần người dùng
- **Route 53** — trả lời truy vấn DNS từ điểm gần nhất
- **AWS Global Accelerator** — đưa traffic TCP/UDP vào mạng backbone AWS sớm nhất có thể
- **S3 Transfer Acceleration** — upload đi qua edge rồi vào bucket qua backbone
- **AWS WAF / Shield** — chặn tấn công ngay tại biên
- **CloudFront Functions / Lambda@Edge** — chạy code rất nhẹ tại biên

Bạn **không** launch EC2 ở edge location. Đây là điểm nhầm lẫn kinh điển.

| Bạn cần | Chọn |
|---|---|
| Nội dung tĩnh, cache được, HTTP/HTTPS | CloudFront |
| Traffic TCP/UDP non-HTTP, cần IP tĩnh, failover nhanh giữa Region | Global Accelerator |
| Compute có state, latency cực thấp tới một thành phố | Local Zone |
| Chịu lỗi khi mất một data center | Multi-AZ trong một Region |
| Chịu lỗi khi mất cả Region | Multi-Region |

---

## 2. Shared Responsibility Model — ranh giới di động

Nguyên văn từ AWS: **AWS chịu trách nhiệm "security *of* the cloud", khách hàng
chịu trách nhiệm "security *in* the cloud".**

AWS lo: cơ sở vật chất, phần cứng, mạng vật lý, tầng ảo hóa, và với dịch vụ managed
thì lo cả OS và platform. Bạn lo: dữ liệu của bạn, ai được truy cập nó, mã hóa,
cấu hình mạng, và mọi thứ bạn tự cài lên.

Câu quan trọng nhất trong tài liệu gốc: **ranh giới này phụ thuộc vào dịch vụ bạn
chọn.** Đây chính là chỗ đề thi ra câu hỏi.

| Trách nhiệm | EC2 (IaaS) | RDS (managed) | Lambda (serverless) | S3 (abstracted) |
|---|---|---|---|---|
| Phần cứng, DC, mạng vật lý | AWS | AWS | AWS | AWS |
| Hypervisor / tầng ảo hóa | AWS | AWS | AWS | AWS |
| **Guest OS + patch OS** | **Bạn** | AWS | AWS | AWS |
| **Patch database engine** | Bạn | AWS (bạn chọn maintenance window) | — | — |
| **Runtime / thư viện ngôn ngữ** | Bạn | — | AWS (bạn chọn version, và phải nâng khi EOL) | — |
| **Mã ứng dụng + thư viện của bạn** | Bạn | — | **Bạn** | — |
| **Cấu hình mạng** (SG, subnet) | Bạn | Bạn | Bạn (nếu đặt trong VPC) | Bạn (bucket policy, endpoint) |
| **IAM / phân quyền truy cập** | **Bạn** | **Bạn** | **Bạn** | **Bạn** |
| **Mã hóa dữ liệu và quản lý key** | Bạn | Bạn (bật, chọn KMS key) | Bạn | Bạn |
| **Phân loại dữ liệu** | Bạn | Bạn | Bạn | Bạn |
| Tính sẵn sàng của hạ tầng | AWS (AZ) | AWS (Multi-AZ nếu bạn bật) | AWS | AWS |
| **Kiến trúc chịu lỗi của ứng dụng** | Bạn | Bạn | Bạn | Bạn |

Đọc bảng theo chiều ngang, bạn thấy quy luật: **càng đi về phía serverless, phần
"Bạn" càng co lại — nhưng bốn dòng in đậm không bao giờ chuyển sang AWS.**
IAM, mã hóa, phân loại dữ liệu, và kiến trúc ứng dụng luôn là của bạn.

> **Bắc cầu:** giống hệt việc bạn dùng managed control plane thay vì tự dựng etcd.
> Bạn hết phải lo etcd backup, nhưng RBAC và NetworkPolicy vẫn là việc của bạn.
> AWS chỉ đẩy được biên giới xuống, không xóa được nó.

**Cách nhận diện trong đề thi:** câu hỏi nào có dạng "ai chịu trách nhiệm cho X"
thì hỏi ngược lại — *X có nằm trong tầm tay tôi qua API không?* Nếu có, đó là việc
của bạn. Bạn gọi được API để đặt bucket policy → bucket policy sai là lỗi của bạn.
Bạn không gọi được API nào để patch hypervisor → đó là việc của AWS.

---

## 3. Well-Architected Framework — sáu trụ cột

Đây không phải lý thuyết suông. Đề SAA-C03 được viết theo khung này, và mỗi câu hỏi
đều đang ngầm test một trụ cột. Nhận ra trụ cột là nhận ra đáp án.

| Trụ cột | Câu hỏi trung tâm | Từ khóa trong đề |
|---|---|---|
| **Operational excellence** | Vận hành và cải tiến hệ thống thế nào? | "ít thao tác vận hành nhất", "tự động hóa", "giảm gánh nặng quản trị" |
| **Security** | Bảo vệ dữ liệu, hệ thống, tài sản thế nào? | "least privilege", "mã hóa", "audit", "không lộ ra internet" |
| **Reliability** | Phục hồi khi hạ tầng hoặc dịch vụ hỏng thế nào? | "high availability", "chịu lỗi AZ", "RTO/RPO", "tự phục hồi" |
| **Performance efficiency** | Dùng tài nguyên tính toán hiệu quả thế nào? | "độ trễ thấp nhất", "throughput", "mở rộng khi tải tăng" |
| **Cost optimization** | Tránh chi phí không cần thiết thế nào? | "chi phí thấp nhất", "hiệu quả nhất về chi phí" |
| **Sustainability** | Giảm tác động môi trường thế nào? | ít gặp trong SAA-C03, nhưng biết là có |

Bốn domain của đề ánh xạ khá thẳng: Security 30%, Resilient (Reliability) 26%,
High-Performing (Performance efficiency) 24%, Cost-Optimized 20%. Operational
excellence không phải một domain riêng nhưng len vào mọi câu có chữ
"operational overhead".

### Kỹ thuật đọc đề dựa trên trụ cột

Phần lớn câu SAA có **hai đáp án đúng về mặt kỹ thuật**. Cái quyết định là ràng
buộc trong đề — và ràng buộc đó luôn là tên một trụ cột trá hình:

- *"…với chi phí thấp nhất"* → Cost. Loại mọi đáp án có NAT Gateway, Interface
  Endpoint, cluster luôn bật, khi có phương án rẻ hơn.
- *"…với ít thao tác vận hành nhất"* → Operational excellence. Managed thắng
  self-managed. Serverless thắng EC2. Aurora thắng MySQL trên EC2.
- *"…có tính sẵn sàng cao nhất"* → Reliability. Multi-AZ thắng Single-AZ.
- *"…độ trễ thấp nhất cho người dùng toàn cầu"* → Performance. CloudFront /
  Global Accelerator / read replica ở Region gần.
- *"…mà không đi qua internet công cộng"* → Security. VPC Endpoint / PrivateLink.

Khi hai đáp án đều đúng, đọc lại đề tìm tính từ so sánh nhất. Nó luôn ở đó.

---

## 4. Mô hình giá — chỉ khái niệm

Chi tiết ở tuần 12. Ở đây bạn chỉ cần cái trục phân biệt: **bạn cam kết cái gì?**

| Mô hình | Bạn cam kết | Giảm giá | Rủi ro | Dùng khi |
|---|---|---|---|---|
| **On-Demand** | Không gì cả | 0% | Không | Tải không đoán được, môi trường dev, đang thử nghiệm |
| **Savings Plans** | Một mức **$/giờ** trong 1 hoặc 3 năm | Compute SP tới 66%, EC2 Instance SP tới 72% | Không dùng hết vẫn trả | Tải ổn định nhưng có thể đổi instance type / service |
| **Reserved Instance** | Một **cấu hình instance cụ thể** (family, Region, OS, tenancy) 1 hoặc 3 năm | Standard RI tới 72%, Convertible tới 66% | Mua sai thì kẹt | Tải ổn định, cấu hình không đổi; Zonal RI còn **giữ chỗ capacity** |
| **Spot** | Không gì, nhưng chấp nhận bị lấy lại | tới 90% | Bị thu hồi với **thông báo trước 2 phút** | Batch, CI, xử lý dữ liệu, worker stateless chịu được gián đoạn |
| **Dedicated Host** | Cả một máy chủ vật lý | — (đắt) | — | Yêu cầu license theo socket/core, hoặc compliance bắt buộc |

Ba điều đủ để trả lời phần lớn câu hỏi giá ở mức SAA:

1. **Savings Plans linh hoạt hơn RI, RI cụ thể hơn Savings Plans.** Compute Savings
   Plans áp dụng tự động cho cả EC2, Fargate và Lambda, xuyên qua family, size, OS,
   tenancy, thậm chí Region. RI khóa vào cấu hình.
2. **Chỉ Zonal Reserved Instance mới giữ chỗ capacity.** Savings Plans *không*
   giữ chỗ. Đề hỏi "đảm bảo luôn có capacity ở một AZ cụ thể" → Zonal RI hoặc
   On-Demand Capacity Reservation, không phải Savings Plans.
3. **Spot có thông báo 2 phút.** Kiến trúc dùng Spot phải bắt được tín hiệu đó
   (instance metadata hoặc EventBridge) và drain gọn gàng.

> **Cảnh báo cho tài khoản của bạn:** Free plan **không dùng được** Savings Plans
> và Reserved Instances. Phần này bạn học bằng lý thuyết, không lab được — và đó
> là quyết định đúng, vì đề thi hỏi *khi nào chọn cái nào*, không hỏi cách bấm nút mua.

---

## 5. Account và Organizations

Một **AWS account** không phải "user". Nó là **ranh giới cô lập mạnh nhất** trên AWS:

- Ranh giới **billing** — mỗi account một hóa đơn.
- Ranh giới **bảo mật** — mặc định, không có gì đi xuyên qua giữa hai account.
  Muốn xuyên qua phải cấu hình rõ ràng (cross-account role, resource policy).
- Ranh giới **service quota** — quota tính theo account theo Region.

> **Bắc cầu:** account gần với "một cluster k8s riêng" hơn là "một namespace".
> Namespace chia logic trong cùng một control plane; account thì mọi thứ tách rời
> thật sự, kể cả quota và hóa đơn. Đây là lý do mô hình multi-account phổ biến hơn
> nhiều so với "một account khổng lồ chia bằng tag".

**AWS Organizations** gom nhiều account thành một tổ chức:

```
Root
 ├── Management account          ← tạo organization, trả tiền cho tất cả
 │                                 SCP KHÔNG áp dụng cho account này
 ├── OU "Security"
 │    ├── account log-archive
 │    └── account audit
 ├── OU "Production"
 │    ├── account prod-app
 │    └── account prod-data
 └── OU "Sandbox"
      └── account dev-nhan-vien
```

Bốn thứ Organizations mang lại, ở mức SAA cần biết:

1. **Consolidated billing** — một hóa đơn duy nhất, **miễn phí**. Usage của mọi
   account được gộp lại để tính bậc giá theo volume, và để chia sẻ lợi ích của
   Reserved Instance / Savings Plans giữa các account.
2. **Service Control Policy (SCP)** — hàng rào quyền tối đa cho các member account.
   Chi tiết ở [Tuần 1](w01-iam-foundations.md); ba điều cần nhớ ngay: SCP
   **không cấp quyền**, chỉ giới hạn; SCP **không áp dụng cho management account**;
   quyền hiệu lực là **giao** của SCP và policy trong account.
3. **Organizational Unit (OU)** — cây thư mục để gắn SCP theo nhóm. Policy gắn ở
   root hoặc OU chảy xuống mọi thứ bên dưới.
4. **Tạo account bằng API** — nền tảng cho AWS Control Tower và mô hình
   landing zone.

Mẫu thiết kế bạn sẽ gặp trong đề: **tách production và development thành hai
account khác nhau** thay vì hai VPC trong cùng account. Lý do: một sai lầm IAM ở
dev không thể chạm tới prod, vì ranh giới account là ranh giới cứng.

---

## 6. API, CLI, SDK, CloudFormation — cùng một control plane

Đây là mảnh ghép làm mọi thứ khác sáng ra.

**AWS chỉ có một cách để làm bất cứ việc gì: gọi HTTPS API có ký (SigV4) tới
endpoint của dịch vụ.** Tất cả những thứ sau chỉ là vỏ bọc:

| Mặt | Thực chất | Dùng khi |
|---|---|---|
| **Management Console** | Ứng dụng web gọi API thay bạn | Học, khám phá, đọc dashboard |
| **AWS CLI v2** | Chương trình dòng lệnh gọi API | Script, kiểm tra nhanh, `verify.sh` trong lab |
| **SDK** (boto3, aws-sdk-go…) | Thư viện gọi API trong code | Ứng dụng |
| **CloudFormation** | Nhận template, tự gọi API theo đúng thứ tự phụ thuộc | IaC native, StackSet, drift detection |
| **CDK / SAM** | Sinh ra template CloudFormation | IaC bằng ngôn ngữ lập trình |
| **Terraform** | Gọi thẳng API, tự giữ state riêng | IaC đa cloud (thứ bạn đã biết) |

Bốn hệ quả bạn phải rút ra:

1. **IAM không quan tâm bạn dùng mặt nào.** Cùng một permission chi phối cả console
   lẫn Terraform. Không có "quyền riêng cho console". Nếu policy chặn
   `ec2:RunInstances` thì bấm nút trong console cũng hỏng.
2. **CloudTrail ghi lại mọi thứ ở cùng một chỗ.** Bấm chuột trong console cũng sinh
   ra một event `RunInstances` y hệt như `terraform apply`. Đây là lý do kế hoạch
   Ngày 0 bảo bạn bật CloudTrail rồi vào đọc log: để tận mắt thấy console chỉ là
   một API client.
3. **Cái gì làm được bằng console thì làm được bằng IaC** — và ngược lại, gần như
   luôn đúng. Console đôi khi âm thầm tạo thêm tài nguyên phụ (role, SG mặc định)
   mà bạn không thấy; IaC thì buộc bạn viết ra hết. Đó là ưu điểm chứ không phải nhược.
4. **Idempotency là của bạn, không phải của API.** Gọi `RunInstances` hai lần thì
   ra hai instance. Terraform và CloudFormation thêm lớp state/stack để biến chuyện
   đó thành khai báo. AWS API bản thân nó là mệnh lệnh.

> **Bắc cầu:** `kubectl apply` cũng chỉ là HTTP client tới kube-apiserver, và
> RBAC không quan tâm request đến từ `kubectl` hay từ controller. Cùng một mô hình.
> Khác biệt lớn nhất: k8s có reconciliation loop dựng sẵn trong control plane;
> AWS thì không — bạn phải mang loop đó tới (Terraform, CloudFormation drift
> detection, AWS Config).

**Về CloudFormation trong phạm vi SAA:** bạn cần biết nó tồn tại, biết stack /
change set / drift detection / StackSet là gì, và biết khi nào đề gợi ý dùng nó
("triển khai lặp lại được ở nhiều account và Region" → StackSet). Bạn *không* cần
thuộc cú pháp. Tuần 10 sẽ chạm vào.

---

## 7. Eventual consistency

AWS là hệ phân tán. Vài API trả về "thành công" trước khi thay đổi hiện diện ở mọi
nơi. Ba trường hợp bạn phải nhớ:

| Dịch vụ | Mô hình | Hệ quả thực tế |
|---|---|---|
| **IAM** | **Eventual consistency** | Tạo role rồi assume ngay có thể lỗi `AccessDenied`. Tạo user rồi gọi API ngay có thể chưa thấy. |
| **S3 dữ liệu object** | **Strong read-after-write** (từ 12/2020) | PUT xong GET ngay là ra dữ liệu mới. LIST cũng strong. Mọi tài liệu cũ nói S3 eventual consistency đều đã lỗi thời. |
| **S3 cấu hình bucket** | Eventual consistency | Xóa bucket rồi list ngay vẫn có thể thấy nó. Bật versioning rồi đọc lại có thể chưa thấy. |
| **EC2 / VPC** | Eventual consistency | Tạo subnet rồi `describe` ngay có thể chưa thấy. Terraform xử lý bằng retry sẵn. |
| **DynamoDB** | Mặc định eventually consistent read, **có thể chọn** strongly consistent | Đọc mặc định rẻ hơn nhưng có thể thấy dữ liệu cũ. Tuần 5. |

Lời khuyên nguyên văn từ tài liệu IAM: **đừng đặt thay đổi IAM vào đường tới hạn,
sẵn sàng cao của ứng dụng.** Đưa nó vào một routine khởi tạo riêng, chạy ít, và
kiểm tra xem thay đổi đã lan tới nơi chưa trước khi phụ thuộc vào nó.

Trên thực tế bạn sẽ gặp chuyện này ngay ở lab tuần 1: `terraform apply` tạo role
xong, script kiểm chứng chạy ngay và đôi khi phải retry. Đó không phải bug.

---

## 8. Service quota

Mọi tài nguyên trên AWS đều có **quota** (tên cũ: limit). Quota mặc định thường
tính **theo account, theo Region**.

Ba tính chất phải nhớ:

1. **Có quota adjustable và non-adjustable.** VPC per Region mặc định 5, tăng được.
   Số IP dự trữ trong mỗi subnet là 5, không tăng được.
2. **Quota tính theo Region.** 5 Elastic IP ở `us-east-1` không giúp gì cho
   `eu-west-1`.
3. **Service Quotas** là một dịch vụ riêng: xem quota hiện tại, xin tăng, và
   **đặt CloudWatch alarm khi sắp chạm quota**.

```bash
aws service-quotas get-service-quota \
  --service-code ec2 --quota-code L-0263D0A3 --region us-east-1
```

Vì sao chuyện này ra thi: rất nhiều câu hỏi kiến trúc có đáp án bẫy là "hệ thống
không mở rộng được" — và lý do thật là chạm quota, không phải thiếu tiền hay thiếu
máy. Ví dụ điển hình bạn sẽ gặp ở tuần 2: **mỗi subnet mất 5 địa chỉ IP cho AWS**,
nên một `/28` chỉ còn 11 IP dùng được, và ASG sẽ không scale nổi.

> **Bắc cầu:** giống ResourceQuota và LimitRange trong namespace k8s, nhưng bạn
> không tự sửa được — phải mở ticket hoặc dùng Service Quotas console.

---

## Bảng quyết định

| Tình huống | Chọn | Vì sao không chọn cái kia |
|---|---|---|
| Chịu được hỏng một data center | Multi-AZ trong một Region | Multi-Region đắt và phức tạp hơn nhiều cho cùng mục tiêu |
| Chịu được hỏng cả Region | Multi-Region (tuần 11) | Multi-AZ không cứu được khi cả Region sự cố |
| Người dùng toàn cầu, nội dung tĩnh | CloudFront | Mở Region mới tốn kém và không giải quyết được nội dung tĩnh tốt hơn cache |
| Người dùng toàn cầu, TCP/UDP không phải HTTP | Global Accelerator | CloudFront chỉ tối ưu cho HTTP/HTTPS |
| Cần độ trễ cực thấp tới một thành phố, có state | Local Zone | Edge location không chạy compute của bạn |
| Dữ liệu buộc phải ở lại một quốc gia | Chọn đúng Region | Edge/CDN không đảm bảo được yêu cầu pháp lý về nơi lưu trữ |
| Tách môi trường prod và dev triệt để | Hai AWS account + Organizations | Hai VPC cùng account vẫn chung ranh giới IAM và quota |
| Một hóa đơn cho nhiều account, chia sẻ RI | Organizations consolidated billing | Không có cách nào khác, và nó miễn phí |
| Giới hạn quyền tối đa của cả một OU | SCP | Permission boundary chỉ áp cho từng entity, không áp cả account |
| Tải ổn định, nhưng có thể đổi instance type | Compute Savings Plans | RI khóa cứng cấu hình |
| Tải ổn định, cần **giữ chỗ capacity** ở một AZ | Zonal Reserved Instance | Savings Plans không giữ chỗ capacity |
| Batch job chịu được gián đoạn | Spot | On-Demand đắt gấp nhiều lần cho cùng công việc |
| Hạ tầng phải dựng lại được ở account khác | IaC (Terraform / CloudFormation) | Console không tái lập được, và account này có ngày hết hạn |

---

## Số phải thuộc

| Con số | Giá trị | Ghi chú |
|---|---|---|
| Số AZ tối thiểu mỗi Region | **3** | Theo tài liệu AWS hiện hành |
| Khoảng cách giữa các AZ | trong phạm vi **100 km** | "nhiều kilomet" nhưng cùng metro |
| Số trụ cột Well-Architected | **6** | Operational excellence, Security, Reliability, Performance efficiency, Cost optimization, Sustainability |
| Trọng số Security trong SAA-C03 | **30%** | Miền nặng nhất |
| Giảm giá Spot | tới **90%** so với On-Demand | |
| Thông báo trước khi Spot bị thu hồi | **2 phút** | Qua instance metadata và EventBridge |
| Giảm giá Savings Plans | Compute tới **66%**, EC2 Instance tới **72%** | |
| Giảm giá Reserved Instance | Standard tới **72%**, Convertible tới **66%** | |
| Kỳ hạn cam kết | **1 hoặc 3 năm** | Cho cả SP và RI |
| Giá public IPv4 | **$0,005 / IP / giờ** | Tính cả khi đang gắn vào instance; áp dụng từ 01/02/2024 *(kiểm tra lại trang pricing)* |
| Region / AZ hiện có | **39 Region / 123 AZ** | *(kiểm tra lại trang Global Infrastructure — con số này tăng liên tục)* |
| Điểm hiện diện edge | **750+** | CloudFront PoP + regional edge cache *(kiểm tra lại)* |

---

## Bẫy kinh điển

**"Region có tính sẵn sàng cao nên chỉ cần deploy vào một Region là đủ."**
Sai theo cả hai chiều. Deploy vào một Region *nhưng chỉ một AZ* thì không có tính
sẵn sàng gì cả. Ngược lại, deploy Multi-AZ trong một Region đã đủ cho phần lớn
yêu cầu HA — không cần Multi-Region trừ khi đề nói rõ về thảm họa cấp Region.

**"Edge location là nơi chạy code gần người dùng."**
Chỉ đúng với CloudFront Functions và Lambda@Edge, và cả hai đều bị giới hạn nghiêm
ngặt về thời gian chạy và tài nguyên. Bạn không launch EC2 hay chạy container ở
edge. Muốn compute thật sự gần người dùng thì đó là Local Zone hoặc Region mới.

**"`us-east-1a` là một chỗ cố định."**
Không. Tên AZ được ánh xạ ngẫu nhiên theo account ở các Region cũ. Định danh ổn
định là AZ ID (`use1-az1`). Chuyện này quan trọng khi share subnet giữa các account.

**"AWS lo bảo mật, tôi chỉ cần dùng."**
AWS lo *of the cloud*. Bucket S3 để public là lỗi của bạn. Security group mở
`0.0.0.0/0` port 22 là lỗi của bạn. Không patch OS trên EC2 là lỗi của bạn.
Gần như mọi vụ rò rỉ dữ liệu trên AWS đều nằm ở phía "in the cloud".

**"Lambda thì AWS lo hết bảo mật."**
Không. Mã của bạn, thư viện của bạn, IAM role của function, và biến môi trường
chứa secret — tất cả vẫn là của bạn. Serverless thu hẹp bề mặt, không xóa nó.

**"Savings Plans giữ chỗ capacity cho tôi."**
Không. Savings Plans chỉ là cam kết chi tiêu để đổi lấy giá rẻ. Muốn giữ chỗ thì
dùng Zonal Reserved Instance hoặc On-Demand Capacity Reservation.

**"S3 là eventual consistency."**
Đã lỗi thời từ tháng 12/2020. S3 hiện cho **strong read-after-write consistency**
cho cả GET, PUT, DELETE và LIST. Chỉ *cấu hình bucket* mới còn eventual consistency.
Nhiều bộ đề luyện cũ vẫn còn câu hỏi sai chỗ này — đừng học theo.

**"Console và Terraform là hai đường khác nhau nên quyền cũng khác nhau."**
Cùng một API, cùng một IAM, cùng một CloudTrail. Không có ngoại lệ.

**"Chạm giới hạn thì AWS tự tăng cho tôi."**
Không. Quota là quota. Bạn phải chủ động xin tăng, và một số quota không tăng được.

---

## Nối với phần còn lại của lộ trình

Bài này không có lab riêng — nó là nền cho mọi lab khác. Cụ thể:

| Khái niệm ở đây | Xuất hiện lại ở đâu |
|---|---|
| Shared responsibility, IAM là của bạn | [Tuần 1](w01-iam-foundations.md) — toàn bộ bài, và `labs/w01-iam-foundations/` |
| AZ là đơn vị sẵn sàng | [Tuần 2](w02-vpc-networking.md) — subnet trải 2 AZ trong `labs/w02-vpc-networking/` |
| Region duy nhất, quota theo Region | Mọi lab; quy tắc số 1 trong `aws-saa-plan.md` |
| Control plane thống nhất, CloudTrail | Ngày 0 (bật CloudTrail), tuần 10 (observability + IaC) |
| Eventual consistency của IAM | Tuần 1 — `verify.sh` đôi khi phải retry sau `terraform apply` |
| 5 IP dự trữ mỗi subnet (service quota) | Tuần 2 — khi chia CIDR |
| Mô hình giá, Spot / RI / Savings Plans | Tuần 3 (EC2), tuần 12 (ôn tập chi phí) |
| Multi-AZ vs Multi-Region | Tuần 5 (RDS Multi-AZ), tuần 11 (4 chiến lược DR) |
| Sáu trụ cột Well-Architected | Tuần 12 — đọc lại whitepaper trước khi thi |
| Organizations và SCP | Tuần 9 — bảo mật chuyên sâu |

Việc cần làm ngay sau bài này, trước khi vào tuần 1:

```bash
# Xác nhận bạn đang gọi API bằng danh tính nào — KHÔNG được là root
aws sts get-caller-identity --profile learn

# Xem AWS đang cho bạn bao nhiêu Elastic IP ở us-east-1 (mặc định 5)
aws service-quotas get-service-quota \
  --service-code ec2 --quota-code L-0263D0A3 --region us-east-1

# Xem Region hiện có bao nhiêu AZ, và AZ ID tương ứng
aws ec2 describe-availability-zones --region us-east-1 \
  --query "AvailabilityZones[].[ZoneName,ZoneId,State]" --output table
```

Lệnh thứ ba đáng chạy thật: bạn sẽ thấy tận mắt `us-east-1a` ↔ `use1-azN` ánh xạ
ra sao trong account của mình.

---

## Tự kiểm tra

<details>
<summary>1. Ứng dụng phải chịu được sự cố mất điện toàn bộ một data center. Multi-AZ hay Multi-Region?</summary>

**Multi-AZ.** Mỗi AZ có nguồn điện, làm mát và mạng độc lập, nên mất một AZ không
kéo theo AZ khác. Multi-Region giải quyết bài toán lớn hơn (mất cả Region) với chi
phí và độ phức tạp cao hơn nhiều — chỉ dùng khi đề nói rõ về thảm họa cấp Region
hoặc yêu cầu RTO/RPO mà một Region không đáp ứng nổi.
</details>

<details>
<summary>2. Vì sao AWS ánh xạ tên AZ ngẫu nhiên theo account, và khi nào điều đó gây rắc rối?</summary>

Để tránh mọi khách hàng cùng dồn tài nguyên vào "zone a", gây mất cân bằng tải
giữa các AZ vật lý. Nó gây rắc rối khi bạn chia sẻ tài nguyên zonal giữa các account
(qua AWS RAM) hoặc muốn đảm bảo hai account đặt workload cùng một AZ vật lý để
tránh phí và độ trễ cross-AZ. Giải pháp: dùng **AZ ID** (`use1-az1`) thay vì tên.
</details>

<details>
<summary>3. Bạn chạy PostgreSQL trên EC2 và bị lộ dữ liệu vì chưa patch một CVE của engine. Ai chịu trách nhiệm? Nếu chạy trên RDS thì sao?</summary>

Trên EC2: **bạn**. EC2 là IaaS, guest OS và mọi phần mềm bạn cài lên đều thuộc
"security in the cloud".

Trên RDS: **AWS** vá engine, nhưng bạn vẫn phải *cho phép* nó xảy ra — chọn
maintenance window, và với một số bản vá lớn thì phải chủ động nâng version.
Nếu bạn cố tình hoãn nâng cấp qua nhiều chu kỳ thì rủi ro lại quay về phía bạn.
Bài học: managed dịch chuyển ranh giới, không xóa nó.
</details>

<details>
<summary>4. Đề hỏi: "giải pháp nào cho phép instance trong private subnet truy cập S3 với ít thao tác vận hành nhất VÀ chi phí thấp nhất?" Hai trụ cột nào đang bị test cùng lúc, và điều đó dẫn tới đáp án nào?</summary>

Operational excellence ("ít thao tác vận hành") và Cost optimization ("chi phí thấp
nhất"). Cả hai đều loại NAT Gateway (đắt, và vẫn phải quản lý routing ra internet)
và loại luôn NAT instance (tự quản lý = nhiều thao tác vận hành nhất). Đáp án là
**S3 Gateway Endpoint** — miễn phí và chỉ là một route trong route table. Chi tiết
ở [Tuần 2](w02-vpc-networking.md).
</details>

<details>
<summary>5. Công ty cần chắc chắn có đủ capacity cho một workload quan trọng ở đúng một AZ, đồng thời muốn giảm giá. Mua gì?</summary>

**Zonal Reserved Instance.** Đây là mô hình duy nhất trong nhóm vừa giảm giá vừa
*giữ chỗ capacity* ở một AZ cụ thể. Savings Plans giảm giá nhưng không giữ chỗ.
Regional RI giảm giá và linh hoạt hơn về AZ nhưng cũng không giữ chỗ. Nếu chỉ cần
giữ chỗ mà không cần cam kết dài hạn thì dùng On-Demand Capacity Reservation.
</details>

<details>
<summary>6. Script CI của bạn tạo IAM role rồi lập tức assume nó, và thỉnh thoảng lỗi AccessDenied. Chuyện gì xảy ra và sửa thế nào?</summary>

IAM là **eventually consistent**. Role đã được tạo nhưng chưa lan tới endpoint STS
mà bạn gọi. Sửa bằng retry có backoff, hoặc tách việc tạo IAM ra khỏi đường chạy
chính — tạo trước ở bước setup, dùng sau ở bước chạy. Tài liệu AWS nói thẳng: đừng
đặt thay đổi IAM vào critical path.
</details>

<details>
<summary>7. Vì sao tách prod và dev thành hai AWS account tốt hơn hai VPC trong cùng một account?</summary>

Vì account là ranh giới cứng của cả ba thứ: IAM, billing, và service quota. Hai VPC
cùng account vẫn chia sẻ chung một tập IAM policy — một role thừa quyền có thể chạm
tới cả hai. Chúng cũng chia chung quota, nên dev có thể ăn hết quota của prod. Và
hóa đơn không tách được sạch sẽ. Tách account thì mọi đường đi giữa hai bên đều
phải được khai báo tường minh.
</details>

<details>
<summary>8. Đồng nghiệp nói: "tôi làm bằng console nên không cần lo IAM policy, policy chỉ áp cho CLI." Sai ở đâu?</summary>

Console chỉ là một API client. Nó gọi cùng endpoint, cùng cơ chế ký, và bị cùng
một tập IAM policy chi phối. Nếu policy chặn `ec2:RunInstances`, nút "Launch
instance" trong console cũng thất bại. Và CloudTrail ghi lại event giống hệt như
khi gọi từ CLI. Không tồn tại "quyền riêng cho console".
</details>

<details>
<summary>9. Bạn tính chia một subnet /28 cho Auto Scaling Group tối đa 12 instance. Vấn đề?</summary>

`/28` có 16 địa chỉ, AWS giữ lại **5** (network address, VPC router, DNS, dự phòng,
broadcast), còn **11** dùng được. ASG scale tới 12 sẽ thất bại vì hết IP — và thông
báo lỗi thường không nói rõ nguyên nhân. Đây là service quota loại **không tăng được**.
Chi tiết cách chia CIDR ở [Tuần 2](w02-vpc-networking.md).
</details>

<details>
<summary>10. Bộ đề luyện cũ hỏi: "ứng dụng ghi object vào S3 rồi đọc lại ngay, kiến trúc nào đảm bảo đọc được dữ liệu mới nhất?" Vấn đề của câu hỏi này là gì?</summary>

Câu hỏi đã lỗi thời. Từ tháng 12/2020, S3 cho **strong read-after-write consistency**
mặc định cho mọi ứng dụng, mọi Region, không tính thêm tiền — bao gồm cả LIST. Không
cần kiến trúc gì thêm. Chỉ *cấu hình bucket* (bật versioning, xóa bucket…) mới còn
eventual consistency. Nếu gặp câu này trong bộ đề, đó là dấu hiệu bộ đề chưa được cập nhật.
</details>

---

## Ngoài phạm vi

- **AWS Control Tower / Landing Zone Accelerator** — tự động dựng multi-account theo best practice. Mức Professional. [Tài liệu](https://docs.aws.amazon.com/controltower/latest/userguide/what-is-control-tower.html)
- **Wavelength Zone** — hạ tầng đặt trong mạng 5G của nhà mạng. Biết tên là đủ. [Tài liệu](https://docs.aws.amazon.com/wavelength/latest/developerguide/what-is-wavelength.html)
- **AWS Outposts** — rack AWS đặt trong DC của bạn. Nhận diện use case ở tuần 11, không đi sâu. [Tài liệu](https://docs.aws.amazon.com/outposts/latest/userguide/what-is-outposts.html)
- **Resource Control Policy (RCP)** — họ hàng của SCP nhưng áp cho resource. Mới và chưa nằm trong SAA-C03. [Tài liệu](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_rcps.html)
- **Chi tiết SigV4** — cách ký request. Không ra thi SAA. [Tài liệu](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_sigv.html)
- **AWS Partition khác `aws`** (`aws-cn`, `aws-us-gov`) — chỉ cần biết ARN có chứa partition. [Tài liệu](https://docs.aws.amazon.com/whitepapers/latest/aws-fault-isolation-boundaries/partitions.html)
- **Sustainability pillar chi tiết** — có trong Well-Architected nhưng gần như không ra trong SAA-C03. [Whitepaper](https://docs.aws.amazon.com/wellarchitected/latest/sustainability-pillar/sustainability-pillar.html)

---

## Nguồn

- [AWS Global Infrastructure](https://aws.amazon.com/about-aws/global-infrastructure/) — số Region, AZ, edge location
- [Regions and Availability Zones](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/) — tối thiểu 3 AZ, khoảng cách 100 km
- [AZ IDs](https://docs.aws.amazon.com/global-infrastructure/latest/regions/az-ids.html) — ánh xạ tên AZ theo account
- [Availability Zone IDs for your AWS resources](https://docs.aws.amazon.com/ram/latest/userguide/working-with-az-ids.html)
- [AWS Local Zones concepts](https://docs.aws.amazon.com/local-zones/latest/ug/concepts-local-zones.html)
- [AWS Local Zones FAQs](https://aws.amazon.com/about-aws/global-infrastructure/localzones/faqs/)
- [Shared responsibility — Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/shared-responsibility.html)
- [The pillars of the Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/migration-lens/well-architected-framework-pillars.html)
- [Compute Savings Plans and Reserved Instances](https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-ris.html) — bảng % giảm giá
- [Should I use Savings Plans or Reserved Instances](https://repost.aws/knowledge-center/ec2-savings-plan-reserved-instances)
- [Tutorial: Test Spot Instance interruptions using AWS FIS](https://docs.aws.amazon.com/fis/latest/userguide/fis-tutorial-spot-interruptions.html) — giảm giá tới 90%
- [Taking Advantage of Amazon EC2 Spot Instance Interruption Notices](https://aws.amazon.com/blogs/compute/taking-advantage-of-amazon-ec2-spot-instance-interruption-notices/) — thông báo 2 phút
- [New – AWS Public IPv4 Address Charge](https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/)
- [Service control policies (SCPs)](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- [Consolidated billing process](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/useconsolidatedbilling-procedure.html)
- [Troubleshoot IAM — Changes are not always immediately visible](https://docs.aws.amazon.com/IAM/latest/UserGuide/troubleshoot.html)
- [Amazon S3 data consistency model](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html)
- [Amazon S3 Update – Strong Read-After-Write Consistency](https://aws.amazon.com/blogs/aws/amazon-s3-update-strong-read-after-write-consistency/)
- [Subnet CIDR blocks — 5 địa chỉ dự trữ](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html)
- [Amazon VPC quotas](https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html)
- [Request a Quota Increase with Service Quotas](https://docs.aws.amazon.com/hands-on/latest/request-service-quota-increase/request-service-quota-increase.html)
