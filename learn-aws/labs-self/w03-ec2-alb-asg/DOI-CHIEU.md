# Đối chiếu — tuần 3

> Đọc sau khi `./verify.sh` xanh, kể cả bài kiểm tra phục hồi.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong đề | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1, 4 — một địa chỉ, nhiều máy phía sau | Application Load Balancer, listener, target group | [Ba loại ELB](../../../docs/aws/w03-ec2-alb-asg.md#11-ba-loại-elastic-load-balancer) · [Target group](../../../docs/aws/w03-ec2-alb-asg.md#12-target-group-health-check-sticky-session-cross-zone) |
| 2 — máy tự biết định danh của mình | Instance Metadata Service, IMDSv2 | [User data và IMDS](../../../docs/aws/w03-ec2-alb-asg.md#4-user-data-và-instance-metadata-service) |
| 3 — hai máy, hai AZ | AZ là **đơn vị của tính sẵn sàng**; cross-zone load balancing | [Vì sao ASG + ALB + multi-AZ là câu trả lời mặc định](../../../docs/aws/w03-ec2-alb-asg.md#14-vì-sao-asg--alb--multi-az-là-câu-trả-lời-mặc-định) |
| 5 — máy không lộ ra internet | security group tham chiếu security group, defence in depth | [Security Group vs NACL](../../../docs/aws/w02-vpc-networking.md#5-security-group-vs-network-acl) |
| 6 — phân biệt máy sống với ứng dụng sống | **`health_check_type = ELB`** — bẫy kinh điển | [Health check type](../../../docs/aws/w03-ec2-alb-asg.md#health-check-type--bẫy-kinh-điển) |
| 7 — tự phục hồi | Auto Scaling Group, launch template, grace period | [Auto Scaling Group](../../../docs/aws/w03-ec2-alb-asg.md#13-auto-scaling-group) · [Cooldown và warm-up](../../../docs/aws/w03-ec2-alb-asg.md#cooldown-và-warm-up--hai-thứ-hay-bị-lẫn) |
| 8 — trần quy mô | Domain 4: giới hạn nổ chi phí | [Mô hình mua](../../../docs/aws/w03-ec2-alb-asg.md#3-mô-hình-mua--nơi-domain-4-sống) |
| Con số "thời gian suy giảm" | MTTR, và vì sao self-healing ≠ zero-downtime | dưới đây |

### Phân tích con số bạn vừa đo được

Cửa sổ suy giảm ≈ **(chu kỳ health check × ngưỡng hỏng) + thời gian máy mới sẵn sàng**,
và hai vế đó chồng lấn nhau chứ không cộng thẳng:

```
t=0      terminate — máy biến mất ngay, kết nối đang mở bị đứt
t=0..X   load balancer VẪN gửi request tới máy đã chết  ← nguồn lỗi duy nhất
         X = interval × unhealthy_threshold  (mặc định 30 × 2 = 60 giây)
t=X      target bị đánh dấu unhealthy, ngừng nhận traffic → LỖI DỪNG
         từ đây hệ thống chạy với 1 máy: chậm hơn, nhưng đúng
t=X..Y   ASG nhận ra thiếu máy, launch máy mới, chờ grace period, chờ health check pass
t=Y      trở lại 2 máy khoẻ
```

**Bài học quan trọng nhất của cả lab nằm ở đây:** self-healing bảo vệ bạn khỏi
*downtime kéo dài*, không bảo vệ khỏi *lỗi trong vài chục giây đầu*. Muốn về 0%
lỗi bạn cần thêm hai thứ mà một cú `terminate-instances` cố tình bỏ qua:

- **Connection draining / deregistration delay** — load balancer ngừng gửi request
  mới nhưng để các request đang chạy hoàn tất. Chỉ có tác dụng khi máy được **gỡ ra
  một cách có trật tự** (scale-in, deploy, instance refresh), không có tác dụng khi
  máy chết đột ngột.
- **ASG lifecycle hook** — chặn quá trình terminate lại để chạy việc dọn dẹp trước.
  Cũng chỉ áp dụng cho terminate **do ASG khởi xướng**.

Máy bị rút điện thì không cơ chế nào ở phía máy kịp chạy. Thứ duy nhất giảm được
cửa sổ lỗi lúc đó là **health check nhạy hơn** — và đó là một đánh đổi thật:
health check quá nhạy sẽ đá nhầm những máy chỉ đang chậm tạm thời, gây ra một
vòng thay máy vô ích ngay giữa lúc tải cao.

---

## Ba cách khác để giải bài này

### Cách A — không load balancer: Route 53 với health check, trỏ thẳng vào IP máy

Hai máy, mỗi máy một IP công khai. Một bản ghi DNS kiểu failover hoặc weighted,
kèm health check của Route 53. Máy chết thì Route 53 rút bản ghi ra.

- **Tốt hơn khi:** bạn cần cân bằng tải **giữa nhiều region**, hoặc giữa AWS và
  một trung tâm dữ liệu tại chỗ — load balancer không làm được việc đó vì nó nằm
  trong một region. Route 53 cũng rẻ hơn nhiều ($0,50/zone + $0,50/health check
  so với $16,4/tháng cho ALB).
- **Tệ hơn ở chỗ:** DNS có **TTL**. Client đã cache bản ghi sẽ tiếp tục gọi vào
  máy chết cho tới khi cache hết hạn — và rất nhiều thư viện HTTP, JVM, trình
  duyệt bỏ qua TTL theo cách riêng của chúng. Cửa sổ lỗi tính bằng phút chứ không
  phải giây. Ngoài ra máy phải có IP công khai, tức là vi phạm yêu cầu 5.
- **Đề thi hỏi thế nào:** thấy *"failover giữa các region"*, *"disaster recovery"*,
  *"kết hợp on-premises"* → Route 53. Thấy *"phân phối tải trong một region"*,
  *"chuyển hướng nhanh khi instance hỏng"* → load balancer. Đề mà nhắc **TTL** hay
  **client caching** thì gần như chắc chắn đang loại bỏ đáp án DNS.

### Cách B — chạy container trên ECS Fargate thay vì EC2

Cùng một ALB, nhưng phía sau là ECS service với desired count = 2 trên Fargate.
ECS tự thay task chết, y hệt ASG thay instance.

- **Tốt hơn khi:** ứng dụng đã đóng gói container. Task mới lên trong ~30 giây
  thay vì 2–4 phút cho một EC2 boot xong và chạy user data — tức là cửa sổ suy
  giảm ngắn hơn nhiều. Không có OS để vá, không có AMI để dựng lại, không có
  launch template để bảo trì.
- **Tệ hơn ở chỗ:** Fargate đắt hơn EC2 cho tải chạy liên tục (bạn trả cho vCPU
  và GB theo giây, không có Spot rẻ như EC2 Spot, không có Reserved Instance).
  Không kiểm soát được kernel, không gắn được instance store, không dùng được
  GPU tuỳ ý. Và với người chưa quen container thì đây là một hệ khái niệm mới
  hoàn toàn.
- **Đề thi hỏi thế nào:** thấy *"ít vận hành nhất"*, *"không muốn quản lý máy chủ"*,
  *"đã có Docker image"* → Fargate. Thấy *"cần truy cập cấp OS"*, *"licence tính
  theo core"*, *"tải chạy 24/7 và cần chi phí thấp nhất"* → EC2 (kèm Savings Plan).

### Cách C — một máy duy nhất, dựa vào EC2 Auto Recovery

Một instance. Bật CloudWatch alarm `StatusCheckFailed_System` với action
`ec2:recover`. Máy hỏng phần cứng thì AWS tự khởi động nó lại trên phần cứng khác,
giữ nguyên instance ID, IP riêng, và EBS volume.

- **Tốt hơn khi:** ứng dụng **có trạng thái** và không chạy nhiều bản song song
  được — một database tự quản lý, một license server, một job scheduler kiểu
  singleton. Auto Recovery giữ nguyên danh tính của máy, thứ mà ASG không làm được
  (ASG luôn tạo máy MỚI, mất hết dữ liệu trên ổ đĩa tạm).
- **Tệ hơn ở chỗ:** downtime tính bằng **phút**, không phải giây, vì máy phải boot
  lại. Không chịu được lỗi cấp AZ — máy phục hồi trong cùng AZ. Và Auto Recovery
  chỉ phản ứng với lỗi *phần cứng của AWS* (`StatusCheckFailed_System`), **không**
  phản ứng với ứng dụng chết — đúng cái bẫy của yêu cầu 6, ở một tầng khác.
- **Đề thi hỏi thế nào:** thấy *"instance có trạng thái"*, *"phải giữ nguyên
  instance ID / private IP"*, *"phục hồi sau lỗi phần cứng"* → Auto Recovery.
  Thấy *"tính sẵn sàng cao"*, *"chịu được lỗi AZ"* → ASG multi-AZ. Hai thứ này
  giải hai bài toán khác nhau và đề thi rất thích đặt cạnh nhau.

### Bảng quyết định rút ra

| Đề nói | Chọn |
|---|---|
| "định tuyến theo path hoặc hostname" | **ALB** |
| "cần IP tĩnh", "TCP/UDP", "hàng triệu kết nối/giây", "độ trễ cực thấp" | **NLB** |
| "failover giữa region", "kết hợp on-premises" | **Route 53** |
| "instance hỏng phải được thay tự động" | **ASG** với `health_check_type = ELB` |
| "instance có trạng thái, giữ nguyên danh tính" | **EC2 Auto Recovery** |
| "chịu được lỗi một AZ" | ASG trải ≥ 2 AZ, desired đủ để **một AZ gánh hết tải** |
| "giảm chi phí cho tải ổn định 24/7" | Savings Plan / Reserved Instance |
| "tải batch chịu được gián đoạn" | **Spot**, kèm mixed instances policy trong ASG |

---

## Nếu đề thi hỏi

<details><summary>Câu 1 — Ứng dụng web chạy trên ASG sau ALB. Một instance có tiến trình web bị treo nhưng OS vẫn chạy bình thường. ASG không thay nó. Vì sao?</summary>

**A.** Desired capacity đang bằng min capacity.
**B.** `health_check_type` của ASG đang là `EC2`, chỉ kiểm tra status check của instance.
**C.** Cooldown period quá dài.
**D.** ALB chưa bật cross-zone load balancing.

**Đáp án: B.**

- **A sai**: quan hệ desired/min không liên quan tới việc phát hiện máy hỏng. ASG
  vẫn thay máy hỏng để **giữ** desired.
- **C là bẫy hợp lý**: cooldown làm chậm các hoạt động **scaling**, nhưng việc thay
  một instance unhealthy không bị cooldown chặn.
- **D sai**: cross-zone ảnh hưởng tới phân bố traffic, không ảnh hưởng tới phát hiện lỗi.
- **B đúng**: `EC2` health check chỉ nhìn `StatusCheckFailed_Instance` và
  `StatusCheckFailed_System` — tức là phần cứng và khả năng boot. Tiến trình chết
  mà OS còn sống thì cả hai đều PASS. Đổi sang `ELB` thì ASG dùng kết luận của
  target group, và target group hỏi bằng HTTP nên thấy ngay. Đây là câu hỏi ra
  đi ra lại, và bạn vừa tự dựng lại đúng tình huống đó.

</details>

<details><summary>Câu 2 — Ứng dụng cần địa chỉ IP tĩnh để khách hàng đưa vào allowlist firewall, xử lý hàng triệu kết nối TCP mỗi giây, độ trễ phải cực thấp. Chọn gì?</summary>

**A.** Application Load Balancer với Elastic IP.
**B.** Network Load Balancer.
**C.** Classic Load Balancer.
**D.** ALB đứng sau CloudFront.

**Đáp án: B.**

- **A sai vì một sự thật kỹ thuật cụ thể: ALB không gán được Elastic IP.** Địa
  chỉ IP của ALB thay đổi khi AWS scale nó. Đây là lý do số một để chọn NLB, và
  đề thi biết điều đó.
- **C sai**: Classic LB là di sản, AWS khuyến nghị không dùng cho hệ thống mới.
- **D sai**: CloudFront là CDN cho nội dung HTTP, không cho TCP thô, và nó có
  hàng nghìn IP edge chứ không phải IP tĩnh.
- **B đúng**: NLB gán được một Elastic IP cho mỗi AZ, hoạt động ở tầng 4, độ trễ
  tính bằng chục micro-giây, và chịu được hàng triệu kết nối/giây.

</details>

<details><summary>Câu 3 — ASG trải 2 AZ với min=2, desired=2, max=4. Một AZ mất hoàn toàn. Chuyện gì xảy ra, và thiết kế này có đủ không?</summary>

**A.** Mất 1 máy, ASG launch máy thay thế ở AZ còn lại, hệ thống chạy tiếp với 2 máy.
**B.** Mất 1 máy, hệ thống chạy với 1 máy vĩnh viễn cho tới khi AZ hồi phục.
**C.** ASG tự tăng desired lên 4 để bù.
**D.** ALB ngừng phục vụ vì không đủ 2 AZ khoẻ.

**Đáp án: A — nhưng "đủ hay không" là câu hỏi thật.**

- **B sai**: ASG luôn cố giữ desired capacity. Không launch được ở AZ chết thì nó
  launch ở AZ còn sống.
- **C sai**: ASG **không tự đổi desired** vì lý do AZ hỏng. Chỉ scaling policy mới
  đổi desired, và nó phản ứng với metric (CPU, số request), không phản ứng với AZ.
- **D sai**: ALB tiếp tục phục vụ từ AZ còn khoẻ.
- **A đúng về cơ chế.** Nhưng bài học kiến trúc là chỗ khác: nếu 2 máy là vừa đủ
  cho tải bình thường, thì trong vài phút giữa lúc AZ chết và lúc máy thay thế
  sẵn sàng, bạn chỉ có **1 máy gánh 100% tải** — và nó sẽ sập theo. Quy tắc
  **N+1 theo AZ**: desired phải sao cho khi mất một AZ, số máy còn lại vẫn đủ
  gánh đỉnh tải. Với 2 AZ, nghĩa là mỗi AZ phải chạy được ở 50% công suất lúc
  bình thường. Đây chính là câu hỏi tự vấn số 2 mà `verify.sh` in ra.

</details>

<details><summary>Câu 4 — Cần triển khai phiên bản mới lên fleet EC2 sau ALB, không được downtime, và phải quay lui nhanh nếu có lỗi. Cơ chế nào tốt nhất?</summary>

**A.** Sửa launch template rồi terminate lần lượt từng instance bằng tay.
**B.** ASG instance refresh với minimum healthy percentage 90%.
**C.** Tạo ASG mới với launch template mới, gắn vào cùng target group, rồi giảm ASG cũ về 0.
**D.** Cập nhật user data rồi reboot từng instance.

**Đáp án: B** trong hầu hết tình huống, **C** khi đề nhấn mạnh quay lui tức thì.

- **A** chạy được nhưng thủ công, dễ sai, không có cơ chế dừng khi phát hiện lỗi.
- **D sai hoàn toàn** vì một chi tiết quan trọng: **user data chỉ chạy ở lần boot
  đầu tiên** của một instance. Reboot không chạy lại nó. Đây là bẫy kỹ thuật mà
  bạn có thể đã gặp trong lab.
- **B đúng cho câu hỏi như đã nêu**: instance refresh thay máy theo lô, giữ tỉ lệ
  khoẻ tối thiểu, và có checkpoint để dừng giữa chừng.
- **C — blue/green — đúng hơn khi đề nói "quay lui trong vài giây"**, vì fleet cũ
  vẫn còn nguyên và bạn chỉ việc đảo trọng số ở target group. Đánh đổi: bạn trả
  tiền cho gấp đôi số máy trong lúc chuyển đổi.

</details>

<details><summary>Câu 5 — Trang web có tải cao ổn định giờ hành chính, gần như bằng 0 ban đêm, cộng một đợt đỉnh dự đoán trước vào 9h sáng thứ Hai. Cấu hình scaling nào?</summary>

**A.** Chỉ target tracking theo CPU 50%.
**B.** Chỉ scheduled scaling theo giờ hành chính.
**C.** Target tracking theo CPU, cộng scheduled action tăng min capacity trước 9h sáng thứ Hai.
**D.** Step scaling với nhiều bậc CPU.

**Đáp án: C.**

- **A sai** ở đợt đỉnh biết trước: target tracking là **phản ứng** — nó chỉ scale
  sau khi CPU đã tăng, và một EC2 mất 2–4 phút mới phục vụ được. Trong 4 phút đó
  khách gặp lỗi.
- **B sai** ở chiều ngược lại: lịch cố định không xử lý được tải bất thường ngoài
  dự đoán.
- **D**: step scaling mạnh hơn target tracking khi bạn cần phản ứng khác nhau theo
  mức độ vượt ngưỡng, nhưng vẫn là phản ứng, vẫn không giải quyết đỉnh biết trước.
- **C đúng**: dùng cả hai. Scheduled action **nâng min capacity** trước giờ đỉnh
  (chứ không phải đặt desired), rồi target tracking lo phần còn lại. Chi tiết
  "nâng min chứ không đặt desired" là thứ đề thi hay kiểm.

</details>

<details><summary>Câu 6 — Sau khi terminate một instance, ALB vẫn trả 502/504 trong khoảng một phút. Cách nào giảm cửa sổ đó nhiều nhất?</summary>

**A.** Tăng desired capacity từ 2 lên 3.
**B.** Giảm health check interval và unhealthy threshold của target group.
**C.** Tăng deregistration delay của target group.
**D.** Bật sticky session.

**Đáp án: B.**

- **A giảm được *tác động*** (mỗi máy còn lại gánh ít hơn) nhưng **không giảm cửa
  sổ lỗi** — ALB vẫn gửi request tới máy chết cho tới khi health check kết luận.
- **C sai chiều**: deregistration delay là thời gian ALB **chờ** trước khi cắt hẳn
  một target đang được gỡ ra có trật tự. Tăng nó lên chỉ kéo dài mọi thứ, và với
  một máy chết đột ngột thì nó không giúp gì cả.
- **D sai**: sticky session làm tình hình **tệ hơn** — client đã dính vào máy chết
  sẽ tiếp tục bị gửi tới đó.
- **B đúng**: cửa sổ ≈ interval × unhealthy_threshold. Từ 30×2=60 giây xuống
  10×2=20 giây là giảm ba lần. Đánh đổi phải nói ra được: health check dày hơn
  nghĩa là nhiều request kiểm tra hơn tới ứng dụng, và ngưỡng thấp hơn nghĩa là
  dễ đá nhầm máy chỉ đang chậm tạm thời.

</details>

---

## Chỗ dễ hiểu sai

**"ASG là để scale."** Đó là công dụng phụ. Trong đề thi SAA, ASG xuất hiện trong
câu hỏi về **tính sẵn sàng** nhiều hơn hẳn câu hỏi về hiệu năng. Một ASG với
min=desired=max=2 không scale gì cả nhưng vẫn là kiến trúc đúng, vì nó bảo đảm
**luôn có đúng 2 máy khoẻ**.

**"Self-healing nghĩa là không downtime."** Lab vừa cho bạn con số thật để bác bỏ
điều đó. Self-healing rút ngắn MTTR từ "tới khi có người trực nhận ra" xuống
"vài chục giây tự động". Đó là cải thiện khổng lồ, nhưng không phải 0.

**"Health check pass nghĩa là ứng dụng đúng."** Health check của bạn gọi `/` và
xem mã 200. Nếu ứng dụng mất kết nối database mà vẫn trả 200 cho trang chủ, health
check vẫn xanh và load balancer vẫn gửi khách vào một hệ thống hỏng. Production
dùng một endpoint riêng (`/healthz`) thật sự kiểm tra các phụ thuộc — nhưng cẩn
thận với chiều ngược lại: health check kiểm tra database sẽ làm **toàn bộ fleet
bị đánh dấu hỏng cùng lúc** khi database chớp một nhịp, biến một sự cố nhỏ thành
sự cố toàn phần. Đây là một trong những đánh đổi thật sự khó của nghề.

**"Máy ở private subnet thì an toàn rồi."** Lab này có hai lớp: không có route từ
internet vào, **và** security group chỉ nhận từ security group của load balancer.
Đừng bỏ lớp thứ hai vì tin vào lớp thứ nhất. Một VPC peering hay một VPN được
thêm vào sáu tháng sau sẽ phá vỡ giả định "private nghĩa là không ai tới được".

**Trong production, cái bạn vừa dựng còn thiếu ba thứ:** TLS ở listener (443 với
chứng chỉ ACM, và chuyển hướng 80 → 443), access log của load balancer để điều tra
sự cố, và một scaling policy thật để hệ thống co giãn theo tải. Lab bỏ cả ba vì
chúng thêm chi phí hoặc thêm một tên miền phải sở hữu — nhưng thiếu chúng thì
đây chưa phải kiến trúc production.
