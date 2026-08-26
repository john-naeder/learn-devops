# Đối chiếu — tuần 11

> Đọc file này **sau khi** `./verify.sh` xanh hết. Đọc trước là tự lấy mất bài học.

Lab này khác mười lab trước ở chỗ nó chấm một **quyết định**, không chỉ chấm một
hạ tầng. Đó cũng là điều Domain 2 của đề thi làm với bạn: câu hỏi gần như không
bao giờ là "cái nào chạy được", mà là "cái nào **rẻ nhất mà vẫn đạt** hai con số
nghiệp vụ cho trước".

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Việc trong lab | Khái niệm SAA | Đọc thêm |
|---|---|---|
| Khai `chien_luoc` + hai con số, và chúng phải khớp nhau | **RTO/RPO** và **bốn chiến lược DR** | [sổ tay 13](../../../docs/notebook/13-khoi-phuc-tham-hoa.md) §1, §3 · [`w11`](../../../docs/aws/w11-dr-hybrid.md) §2 |
| Khôi phục kho đơn hàng về **một giây bất kỳ** | **point-in-time recovery**, khôi phục liên tục | [sổ tay 13](../../../docs/notebook/13-khoi-phuc-tham-hoa.md) §5 · [sổ tay 03](../../../docs/notebook/03-database.md) §3 |
| Kế hoạch sao lưu theo lịch, chọn theo tag, có vòng đời | **AWS Backup**: plan / selection / vault / lifecycle | [sổ tay 13](../../../docs/notebook/13-khoi-phuc-tham-hoa.md) §5 · [sổ tay 02](../../../docs/notebook/02-storage.md) §16 |
| Ghi đè không làm mất bản cũ | **versioning**, delete marker | [sổ tay 02](../../../docs/notebook/02-storage.md) §5 |
| Kho tệp chặn public đủ bốn công tắc, ẩn danh bị từ chối | **Block Public Access**, bảo vệ bản sao dự phòng | [sổ tay 02](../../../docs/notebook/02-storage.md) §8 |
| Tín hiệu sức khoẻ thăm dò từ nhiều trạm quan sát | **Route 53 endpoint health check** | [sổ tay 13](../../../docs/notebook/13-khoi-phuc-tham-hoa.md) §7 · [sổ tay 11](../../../docs/notebook/11-san-sang-cao.md) §4 |
| Cảnh báo đọc tín hiệu đó, coi im lặng là dấu hiệu xấu | **CloudWatch alarm**, `treat_missing_data` | [sổ tay 07](../../../docs/notebook/07-quan-tri-giam-sat.md) |
| Runbook nằm trong hạ tầng, có bước đánh số | **runbook / DR plan**, Well-Architected REL | [`w11`](../../../docs/aws/w11-dr-hybrid.md) §2 |
| Khai gì thì phải dựng nấy ở `vung_phu` | **pilot light định nghĩa bằng cái đang có sẵn ở Region phụ** | [sổ tay 13](../../../docs/notebook/13-khoi-phuc-tham-hoa.md) §3 |
| Không gì tính tiền theo giờ | Domain 4 — chi phí trạng thái chờ của một kế hoạch DR | [sổ tay 10](../../../docs/notebook/10-chi-phi.md) |

### Khung RTO/RPO — đây chính là bảng `verify.sh` dùng để chấm bạn

| Chiến lược | RPO chấp nhận | RTO chấp nhận | Region phụ | Ở đó có gì |
|---|---|---|---|---|
| `backup_restore` | 5–1440 phút | 60–2880 phút | không bắt buộc | chỉ dữ liệu nằm im + mã IaC |
| `pilot_light` | 1–60 phút | 10–240 phút | **bắt buộc** | dữ liệu **đang được sao chép**, AMI, ASG ở 0 |
| `warm_standby` | 1–15 phút | 5–60 phút | **bắt buộc, có tính toán** | bản thu nhỏ **đang chạy** |
| `active_active` | 0–5 phút | 0–5 phút | **bắt buộc, có tính toán** | bản đầy đủ **đang phục vụ** |

Hai điều rút ra, và cả hai đều ra thi:

1. **Bốn chiến lược là một thang liên tục, phân biệt bằng "ở Region phụ có gì
   đang chạy".** Không phải bằng công cụ. Cùng một dịch vụ sao lưu có thể phục
   vụ cả bốn — thứ đổi là bạn trả tiền cho bao nhiêu thứ đứng chờ.
2. **Cam kết vượt khung là một lỗi thiết kế, không phải lỗi kỹ thuật.** Khai
   `backup_restore` với RTO 30 phút nghĩa là bạn hứa dựng lại toàn bộ hạ tầng và
   khôi phục dữ liệu trong nửa tiếng, chưa từng diễn tập. Trong đời thật, đó là
   kiểu cam kết làm người ta mất việc sau một sự cố.

### RTO không phải một con số, mà là một phép cộng

```
RTO thật = phát hiện + quyết định + dựng hạ tầng + khôi phục dữ liệu
           + hâm nóng + chuyển traffic + xác minh
```

`verify.sh` bắt bạn `RequestInterval × FailureThreshold ≤ 90` giây chính là để
ép bạn nhìn số hạng đầu tiên. **Đồng hồ RTO chạy từ lúc sự cố xảy ra, không
phải từ lúc bạn biết.** Khoảng cách giữa hai mốc đó có tên riêng — **MTTD**
(mean time to detect) — và nó nằm **trọn trong** ngân sách RTO của bạn. Một
kiến trúc DR hoàn hảo với 30 phút phát hiện thủ công vẫn là một kiến trúc DR 30
phút chậm hơn nó tưởng.

Cộng thử cho chính lab này, nếu bạn giải bằng `backup_restore`:

| Số hạng | Trong lab | Rút ngắn bằng |
|---|---|---|
| Phát hiện | 90 giây (tín hiệu sức khoẻ) + vài phút cảnh báo hội tụ | nhịp thăm dò nhanh (tính thêm tiền) |
| Quyết định | 0 nếu tự động, **5–60 phút** nếu chờ người phê duyệt | quy tắc failover viết sẵn trong runbook |
| Dựng hạ tầng | `terraform apply` ở Region còn sống — phút đến hàng giờ | IaC đã kiểm chứng, đã diễn tập |
| Khôi phục dữ liệu | khôi phục ra **một bảng mới**, thời gian theo kích thước bảng | dữ liệu đã ở sẵn đó = trả tiền cho nhân bản |
| Chuyển traffic | TTL bản ghi + thời gian phát hiện | TTL 60 giây, hoặc Global Accelerator |

---

## Ba cách khác để giải bài này

### Cách A — Pilot Light: dữ liệu sáng, tính toán tắt

Kho đơn hàng thành **bảng nhân bản đa Region**; ở Region phụ dựng sẵn VPC,
subnet, security group, launch template, AMI đã copy, và một nhóm tính toán
`desired_capacity = 0`. Khi sự cố: bật số máy từ 0 lên N, đổi DNS.

**Tốt hơn khi:** RTO của bạn tụt xuống dưới một giờ mà bạn vẫn **không trả tiền
cho máy nhàn rỗi** — đây đúng là câu định nghĩa Pilot Light. RPO cũng tốt lên
một bậc: nhân bản đa Region cho độ trễ **~1 giây**, so với **~5 phút** của khôi
phục liên tục. Và nó xoá bỏ số hạng đắt nhất trong phép cộng RTO: khôi phục dữ
liệu về 0, vì dữ liệu đã ở đó rồi.

**Tệ hơn khi:** — và đây là bài này — tiền. Ước tính cho một hệ thống bán vé cỡ
vừa (kho đơn hàng ~50 GB, ~200 GB tệp): nhân bản làm **chi phí ghi tăng khoảng
1,5 lần**, cộng **lưu trữ nhân đôi** (~$0,25/GB-tháng), cộng **$0,02/GB truyền
ra khỏi Region**, cộng lưu trữ AMI/snapshot ở Region phụ. Tổng thêm cỡ
**$30–60/tháng** — vượt trần $5 của kế toán trưởng khoảng mười lần. Ngoài ra
bạn nhận thêm **hai** trách nhiệm mới: **quota ở Region phụ** (account chưa
từng dùng Region đó thường có trần vCPU thấp, và bạn phát hiện ra điều đó đúng
lúc tệ nhất) và **AMI phải được copy lại mỗi lần deploy**, nếu không thì "đèn
mồi" của bạn đang giữ một phiên bản ứng dụng ba tháng tuổi.

**Đề thi hỏi thế nào:** *"restore within 30 minutes"* + *"do not want to pay for
idle compute"* → Pilot Light, gần như luôn luôn. Nếu đáp án nào có cụm
*"promote the read replica"* thì đó cũng là Pilot Light.

### Cách B — Warm Standby: bản thu nhỏ đang chạy thật

Toàn bộ kiến trúc chạy ở Region phụ nhưng nhỏ hơn: một máy thay vì sáu, một
node cache thay vì ba, cân bằng tải đã sẵn sàng nhận traffic. Khi sự cố: scale
out **rồi mới** đổi DNS.

**Tốt hơn khi:** RTO tính bằng phút, và — điểm mạnh thật sự mà ít người nói —
bạn **biết chắc Region phụ hoạt động**, vì nó đang chạy mỗi ngày. Biến thể hay
ra thi: cho Region phụ nhận **5% traffic thật** bằng trọng số DNS. Đường code
chưa bao giờ chạy là đường code hỏng, và một kế hoạch DR chưa bao giờ chạy cũng
vậy.

**Tệ hơn khi:** cân bằng tải một mình đã ~**$16–22/tháng** đứng yên, cộng máy
chủ nhỏ nhất, cộng CSDL bản sao. Ước tính **25–50% chi phí hệ thống chính**,
tức khoảng **$120–200/tháng** cho hệ thống trong bối cảnh. Và đây là chỗ hàng
rào của lab dạy bạn bằng cách chặn: cân bằng tải, NAT, Elastic IP đều tính tiền
**theo giờ, kể cả khi không ai dùng**. Bẫy vận hành riêng của Warm Standby: đổi
DNS **trước khi** scale xong là tự tay đẩy 100% traffic vào 1/6 công suất và
sập ngay lập tức — sự cố thứ hai, do chính bạn gây ra.

**Đề thi hỏi thế nào:** từ khoá *"a scaled-down version running"* gần như luôn
là Warm Standby. *"minimal downtime"* + *"willing to accept higher cost"* cũng vậy.

### Cách C — Aurora Global Database cho tầng dữ liệu

Đổi kho đơn hàng sang Aurora, bật global database: một cluster writer ở Region
chính, cluster chỉ-đọc ở Region phụ, nhân bản ở **tầng lưu trữ**.

**Tốt hơn khi:** đây là cơ chế DR cross-Region tốt nhất cho dữ liệu quan hệ —
độ trễ nhân bản **dưới 1 giây** ngay cả khi tải nặng, promote **dưới 1 phút**,
và **managed planned switchover** cho **RPO = 0** khi bạn chủ động chuyển Region
theo kế hoạch. Nếu dữ liệu của bạn là quan hệ và ràng buộc là RPO chứ không phải
tiền, đây là đáp án.

**Tệ hơn khi:** — bài này — cluster phụ phải có **ít nhất một instance đang
chạy**. `db.r6g.large` ≈ $0,29/giờ ≈ **$210/tháng**, cộng lưu trữ, cộng I/O
nhân bản. Gấp hơn **40 lần** trần ngân sách. Đó cũng chính là lý do hàng rào của
lab chặn `rds:CreateDBCluster`: Aurora Global Database là đáp án đúng cho một
bối cảnh **khác**, có ngân sách khác. Thêm một giới hạn hay bị quên: global
database chỉ có **một writer**. "Active/active với Aurora" thực chất là "đọc ở
mọi nơi, ghi ở một nơi".

**Đề thi hỏi thế nào:** *"relational"* + *"cross-Region DR"* + *"RPO under one
second"* → Aurora Global Database. Nếu đề thêm *"lowest cost"* và RPO cho phép
tính bằng phút → **cross-Region automated backup replication** (RPO 5–30 phút)
rẻ hơn nhiều và mới là đáp án.

### Ghi chú riêng — bản sao **cùng Region** của bạn cứu được gì

Lab bắt bạn làm mọi thứ trong một Region. Đây là bảng trả lời thẳng câu hỏi
trong "Tiêu chí đạt":

| Loại sự cố | Bản sao cùng Region | Bản sao khác Region |
|---|---|---|
| Xoá nhầm một tệp / một bản ghi | **có cứu** (nếu bật lịch sử phiên bản hoặc PITR) | có cứu |
| Ghi đè nhầm | **có cứu** | có cứu |
| Mã độc mã hoá dữ liệu | **có cứu** nếu bản sao bất biến (WORM/Object Lock) | có cứu |
| Hỏng một AZ | **có cứu** — kho object và bảng managed vốn đã trải nhiều AZ | có cứu |
| **Hỏng cả một Region** | **bó tay** | có cứu |
| **Tài khoản AWS bị chiếm** | **bó tay** nếu bản sao cùng tài khoản | **bó tay** nếu cùng tài khoản |

Hai dòng cuối là hai bài học riêng biệt và hay bị gộp làm một:

- **Region** là ranh giới của *sự cố hạ tầng*. Muốn vượt qua nó thì phải trả
  tiền truyền dữ liệu ra khỏi Region ($0,02/GB) và tiền lưu trữ nhân đôi.
- **Tài khoản** là ranh giới của *sự cố con người*. Một credential bị lộ xoá
  được cả bản chính lẫn bản sao nếu chúng nằm chung tài khoản, dù cách nhau nửa
  vòng trái đất. Đáp án cho vế này là **vault ở tài khoản riêng** cộng khoá WORM
  chế độ compliance — không phải thêm một Region nữa.

Và câu hỏi cuối trong "Tiêu chí đạt": **xoá ở kho nguồn có xoá ở kho đích
không?** Tuỳ một công tắc tên `delete_marker_replication`. Mặc định **tắt**, và
với mục đích DR thì tắt thường là đúng: bạn muốn bản sao **sống sót qua thao tác
xoá**, kể cả thao tác xoá do chính bạn gây ra. Bật nó lên nghĩa là bạn đang dùng
nhân bản để **đồng bộ**, không phải để **bảo vệ** — hai mục đích khác nhau, và
lẫn chúng là một trong những cách mất dữ liệu êm ái nhất.

---

## Nếu đề thi hỏi

<details><summary>Câu 1. Một hệ thống bán vé chạy trên DynamoDB và S3. Nghiệp vụ yêu cầu RTO 4 giờ, RPO 15 phút, và tài chính từ chối trả tiền cho bất kỳ tài nguyên nhàn rỗi nào. Giải pháp nào ĐẠT yêu cầu với chi phí thấp nhất?</summary>

**A.** Multi-Site Active/Active: DynamoDB Global Tables và một tầng ứng dụng đầy đủ ở Region thứ hai, chia traffic bằng latency-based routing.
**B.** Bật point-in-time recovery cho bảng, dùng AWS Backup theo lịch có copy sang Region thứ hai, giữ hạ tầng dưới dạng IaC và dựng lại khi cần.
**C.** Warm Standby: một instance ứng dụng và một ALB chạy thường trực ở Region thứ hai.
**D.** Chụp snapshot EBS mỗi giờ, copy sang Region thứ hai, giữ sẵn các EC2 ở trạng thái stopped.

**Đáp án: B.** RTO 4 giờ là **rất lỏng** — đủ để chạy IaC và khôi phục dữ liệu.
RPO 15 phút được PITR đáp ứng thoải mái (mốc khôi phục trễ ~5 phút). Không có
tài nguyên nào đứng chờ, nên ràng buộc tiền được tôn trọng.

- **A sai** — đạt yêu cầu **quá xa** và tốn khoảng gấp đôi hệ thống chính. Đề
  hỏi "chi phí thấp nhất **vẫn đạt**", không hỏi "tốt nhất".
- **C sai** — cùng lý do, cộng thêm ALB tính tiền theo giờ, vi phạm thẳng ràng
  buộc "không trả tiền cho tài nguyên nhàn rỗi".
- **D sai** — hai lỗi: dữ liệu nằm trong DynamoDB và S3, snapshot EBS không
  chạm tới chúng; và một EC2 stopped ở Region khác không phải cơ chế DR (bạn
  vẫn trả tiền EBS, và AMI mới là thứ nên copy).

</details>

<details><summary>Câu 2. Một ứng dụng dùng Route 53 failover routing với TTL 60 giây, health check nhịp 30 giây và ngưỡng 3 lần. Nghiệp vụ vừa siết RTO xuống 60 giây. Cần thay đổi gì?</summary>

**A.** Giảm TTL xuống 10 giây.
**B.** Đổi health check sang nhịp nhanh 10 giây.
**C.** Đặt AWS Global Accelerator trước hai Region và bỏ phụ thuộc vào DNS failover.
**D.** Tăng failure threshold lên 10 để tránh failover nhầm.

**Đáp án: C.** Tính thử: `60 (TTL) + 30 × 3 = 150` giây, đã vượt RTO. Và ngay cả
khi TTL bằng 0, **TTL chỉ là gợi ý** — nhiều resolver và rất nhiều thư viện HTTP
trong ứng dụng cache DNS lâu hơn, có thư viện cache vĩnh viễn. Global Accelerator
dùng **anycast IP cố định**: địa chỉ không đổi nên client không phải tra lại DNS,
và việc chuyển hướng xảy ra trong mạng của AWS, tính bằng **giây**.

- **A sai** — giảm được một số hạng nhưng vẫn còn 90 giây phát hiện, và vẫn phụ
  thuộc vào resolver có tôn trọng TTL không.
- **B sai** — xuống còn `60 + 30 = 90` giây, vẫn vượt, lại tính thêm tiền.
- **D sai** — đi ngược hướng: ngưỡng cao hơn nghĩa là phát hiện **chậm hơn**.

Con số phải thuộc: failover mặc định hoàn toàn = `300 + 30 × 3` = **390 giây**.

</details>

<details><summary>Câu 3. Một lập trình viên xoá nhầm hàng nghìn object trong bucket sản xuất. Bucket đang bật Cross-Region Replication sang một Region khác. Đội vận hành mở bucket đích và thấy các object đó vẫn còn. Kết luận nào ĐÚNG, và cần làm gì để chuyện này không lặp lại?</summary>

**A.** Replication đã cứu họ; đây chính là mục đích của nó.
**B.** Các object còn nguyên vì delete marker không được sao chép theo mặc định. Đó là may mắn dựa vào một tuỳ chọn cấu hình, không phải một cơ chế bảo vệ. Cần versioning ở bucket nguồn cộng MFA Delete hoặc Object Lock.
**C.** Cần bật replication hai chiều để đồng bộ trạng thái.
**D.** Cần chuyển sang Same-Region Replication cho nhanh hơn.

**Đáp án: B.** Xoá một object trong bucket có versioning chỉ **thêm một delete
marker**; bản cũ vẫn nằm đó. Delete marker **không** được replicate trừ khi bạn
bật riêng. Nếu ai đó bật công tắc đó — hoặc xoá đích danh một version — thì bản
sao biến mất cùng lúc.

- **A sai** — nhớ câu phải nói được thành lời: **replication chống mất hạ tầng,
  backup chống mất dữ liệu.** Replication sao chép cả sai lầm của bạn; thứ cứu
  bạn ở đây là **độ trễ theo thời gian**, mà replication cố tình không có.
- **C sai** — làm vấn đề tệ hơn: giờ thao tác xoá lan theo cả hai chiều.
- **D sai** — đổi khoảng cách địa lý, không đổi bản chất cơ chế.

</details>

<details><summary>Câu 4. Một ứng dụng chạy trên EC2 trong private subnet, không có địa chỉ public. Kiến trúc sư cần Route 53 tự chuyển traffic sang Region dự phòng khi ứng dụng này hỏng. Cách nào KHẢ THI?</summary>

**A.** Endpoint health check trỏ tới private IP của instance.
**B.** Calculated health check cộng gộp các health check con.
**C.** CloudWatch alarm health check: đặt alarm trên một số đo của ứng dụng, rồi tạo health check theo dõi trạng thái alarm đó.
**D.** Bật `Evaluate Target Health` trên alias record trỏ tới instance.

**Đáp án: C.** Trạm quan sát của Route 53 nằm **trên internet công cộng** — chúng
không định tuyến được tới địa chỉ private. Loại health check đọc trạng thái một
CloudWatch alarm là **cách duy nhất** theo dõi tài nguyên không gọi được từ
ngoài, và cũng là cách theo dõi những điều kiện mà một request HTTP không diễn
tả nổi (độ dài hàng đợi, độ trễ nhân bản, số lỗi nghiệp vụ).

- **A sai** — không tới được, health check sẽ luôn báo hỏng.
- **B sai** — cộng gộp các kết quả không tồn tại vẫn ra không tồn tại.
- **D sai** — alias + evaluate target health dùng cho ALB/CloudFront/S3, không
  trỏ thẳng vào EC2 được, và vẫn cần thứ gì đó ở giữa quan sát được từ ngoài.

</details>

<details><summary>Câu 5. Một tổ chức tài chính cần bảo đảm bản sao lưu không thể bị xoá — kể cả bởi một tài khoản quản trị bị chiếm quyền, kể cả bởi root, kể cả qua AWS Support. Giải pháp nào ĐÁP ỨNG?</summary>

**A.** AWS Backup Vault Lock ở **governance mode** cộng SCP chặn `backup:DeleteRecoveryPoint`.
**B.** AWS Backup Vault Lock ở **compliance mode**, vault đặt trong một tài khoản riêng, đã qua thời gian cooling-off tối thiểu 72 giờ.
**C.** Bật versioning và MFA Delete trên bucket chứa backup.
**D.** IAM policy từ chối mọi hành động xoá, gắn cho tất cả người dùng.

**Đáp án: B.** **Compliance mode** sau cooling-off (tối thiểu **72 giờ / 3
ngày**) trở thành **bất biến vĩnh viễn** — không ai gỡ được, kể cả root, kể cả
AWS Support. Đặt vault ở **tài khoản riêng** là lớp thứ hai: ranh giới tài khoản
mới là ranh giới của sự cố con người.

- **A sai** — governance mode cố ý cho phép người có quyền đặc biệt gỡ lock. Nó
  chống lỡ tay, không chống kẻ tấn công. SCP thì management account sửa được.
- **C sai** — đúng hướng nhưng yếu hơn hẳn: MFA Delete cần credential root và
  không áp dụng cho recovery point của AWS Backup.
- **D sai** — policy nào cũng sửa được bởi người có quyền sửa policy. Đó chính
  là kẻ tấn công trong đề bài.

</details>

<details><summary>Câu 6. Một đội cam kết RTO 15 phút cho kho dữ liệu DynamoDB, lập luận rằng "PITR khôi phục về bất kỳ giây nào nên gần như tức thì". Sai lầm trong lập luận này là gì?</summary>

**A.** PITR chỉ giữ 7 ngày nên không dùng cho DR.
**B.** PITR khôi phục ra một **bảng mới** với tên mới; thời gian khôi phục phụ thuộc kích thước bảng, và ứng dụng phải được trỏ sang tên mới. Cả hai việc đó nằm trong RTO.
**C.** PITR không hoạt động nếu bảng dùng chế độ on-demand.
**D.** PITR chỉ khôi phục được trong cùng một AZ.

**Đáp án: B.** Hai chi tiết cơ chế phải thuộc: PITR giữ **35 ngày** (không phải
7), và **restore luôn tạo tài nguyên mới** — DynamoDB tạo bảng mới,
`RestoreDBInstanceToPointInTime` của RDS tạo instance mới với **endpoint mới**.
Nghĩa là runbook của bạn phải có một bước "trỏ ứng dụng sang tên/endpoint mới",
và thời gian của bước đó là một số hạng thật trong phép cộng RTO.

- **A sai** — 35 ngày, cố định, không chỉnh được.
- **C, D sai** — PITR hoạt động với cả hai chế độ capacity, và không phải khái
  niệm gắn với AZ.

Đây cũng là lý do "có backup" và "khôi phục được" là hai việc khác nhau, và là
câu hỏi tự vấn thứ hai mà `verify.sh` in ra khi bạn xanh hết.

</details>

---

## Chỗ dễ hiểu sai

**"`verify.sh` xanh nghĩa là tôi khôi phục được."**
Nó chứng minh bạn **có** bản sao lưu, **có** tín hiệu phát hiện, và **có** một
runbook viết ra thành chữ. Nó không chứng minh được bạn **khôi phục được**, và
khoảng cách giữa hai điều đó là nơi phần lớn kế hoạch DR chết. Hoạt động lấp
khoảng cách đó có tên riêng: **DR drill / game day**, và AWS Backup có
**restore testing plan** làm đúng việc này theo lịch — tự khôi phục thử, đo thời
gian thật, chạy kiểm chứng, rồi xoá tài nguyên test. Con số RTO chưa từng được
đo bằng một lần khôi phục thật chỉ là một ước lượng.

**Runbook của bạn đang nằm trong Region mà kịch bản giả định là đã chết.**
Đây là câu hỏi tự vấn thứ nhất của `verify.sh`, và nó có hai lời giải với hai
loại giá: sao chép runbook sang Region hoặc tài khoản khác (**tốn tiền**, rất
ít — vài KB), hoặc giữ một bản ngoài AWS: wiki của đội, kho mã nguồn, một bản
in trong tủ trực (**tốn kỷ luật** — bản ngoài luôn có nguy cơ cũ hơn bản thật).
Đội trưởng thành làm cả hai và đặt việc cập nhật runbook vào định nghĩa "xong"
của mỗi thay đổi kiến trúc.

**"Một Region là đủ vì dữ liệu đã có ba bản sao."**
Kho object và bảng managed đã trải nhiều AZ — đó là **độ bền**, không phải DR.
Đọc kỹ đề: **Availability Zone** hay **Region**? Đề mô tả mất một AZ mà bạn chọn
kiến trúc multi-Region là lỗi bị phạt rất nặng, vì nó đắt gấp nhiều lần mức cần.
Và chiều ngược lại cũng đúng: đề nói *"survive a Region-wide outage"* thì
Multi-AZ **không đủ**, dù nghe rất giống.

**`treat_missing_data` không có một đáp án đúng cố định.**
Ở tuần 10, `notBreaching` là đúng cho một số đo đếm lỗi. Ở tuần 11,
`verify.sh` đòi `breaching` cho một số đo sức khoẻ. **Cùng một tham số, hai đáp
án ngược nhau**, vì câu hỏi thật là *"khi số đo im lặng thì im lặng đó nghĩa là
gì?"*. Với tín hiệu sức khoẻ, im lặng nghĩa là thứ đang thăm dò cũng đã chết.

**Chi phí trạng thái chờ là thứ giết các kế hoạch DR, không phải chi phí lúc sự cố.**
Bốn con số của lab này đáng nhớ vì chúng nhỏ tới mức dễ bị bỏ qua khi thiết kế:
tín hiệu sức khoẻ **$0,50/tháng** cộng khoảng **$1,00/tháng mỗi tuỳ chọn** (nhịp
nhanh, so khớp chuỗi, HTTPS); khôi phục liên tục **$0,20/GB-tháng** theo kích
thước bảng; lưu trữ bản sao lưu tính tiền **cho tới khi vòng đời xoá nó** —
thiếu `delete_after` là một khoản tăng đều mãi mãi; cảnh báo CloudWatch **10 cái
đầu miễn phí**, sau đó $0,10/cái/tháng. Nhân chúng với hàng trăm tài nguyên
trong một tài khoản thật và bạn hiểu vì sao "DR đắt quá" là lý do phổ biến nhất
khiến một kế hoạch DR không bao giờ được duyệt.

**Một hệ thống thật hiếm khi chỉ có một chiến lược.**
Lab và đề thi buộc bạn chọn một nhãn cho toàn hệ thống, nhưng kiến trúc thật
thường trộn: tầng dữ liệu ở mức Warm Standby vì nhân bản rẻ, tầng tính toán ở
mức Pilot Light vì máy chủ đắt, tầng tệp tĩnh ở mức Backup & Restore. Biết điều
này không giúp bạn chọn nhanh hơn trong phòng thi — nhưng nó giúp bạn **loại**
đáp án, vì đáp án sai hay mô tả một mức bảo vệ đồng nhất cho những thứ có giá
trị rất khác nhau.

**Phần "hybrid" của tuần 11 bạn chưa chạm vào, và đó là chủ ý.**
Direct Connect, Site-to-Site VPN, Transit Gateway, DX Gateway đều bị hàng rào
chặn vì cả bốn tính tiền theo giờ và cái đầu tiên còn cần cáp vật lý. Nhưng phần
đề thi hỏi về chúng là phần **thiết kế**, không phải phần gõ: VPN dựng trong vài
phút và có mã hoá sẵn, DX mất vài tuần đến vài tháng nhưng cho **độ trễ ổn
định** — mẫu đúng gần như luôn là **DX làm đường chính, VPN làm đường dự phòng**,
chuyển đổi tự động bằng BGP. Học bằng sơ đồ ở
[sổ tay 13](../../../docs/notebook/13-khoi-phuc-tham-hoa.md) §11 và
[`docs/aws/w11-dr-hybrid.md`](../../../docs/aws/w11-dr-hybrid.md) §8.
