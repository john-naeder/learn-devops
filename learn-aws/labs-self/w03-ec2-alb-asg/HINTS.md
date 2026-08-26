# Gợi ý — tuần 3

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bài này có bốn khối. Làm và verify từng khối; đừng viết hết rồi apply một lần —
mỗi vòng apply/destroy ở tuần này tốn tiền thật và tốn 5 phút chờ.

**Khối 1 — mạng.** Bạn cần đúng thứ tuần 2 đã có: VPC, subnet công khai và riêng
tư trên 2 AZ. Copy tư duy, đừng copy code — viết lại là cách nhớ.
Câu hỏi mới của tuần này: **thứ nhận traffic từ internet nằm ở tầng nào, máy web
nằm ở tầng nào?** Trả lời được câu đó là xong nửa bài.

**Khối 2 — một máy chạy được.** Trước khi nghĩ tới tự phục hồi, hãy làm một máy
duy nhất phục vụ được HTTP và in ra định danh của chính nó. Định danh đó máy tự
lấy ở đâu? (Tuần 2 bạn đã gọi vào đúng chỗ đó rồi — và nhớ là nó cần token.)
Cách kiểm tra nhanh mà không cần load balancer: dùng Systems Manager chạy
`curl localhost` ngay trên máy.

**Khối 3 — hai máy và một cửa vào.** Giờ mới thêm thứ đứng trước. Ba mảnh ghép:
cái nhận request, cái giữ danh sách máy đích, và cái quyết định máy nào còn khoẻ.
Ba mảnh này là ba resource khác nhau và người mới hay gộp nhầm.

**Khối 4 — tự phục hồi.** Thay việc tự tạo máy bằng một thứ quản lý đàn máy. Nó
cần một "khuôn" để biết launch máy như thế nào. Và nó cần biết **hỏi ai** để
đánh giá máy còn tốt không — mặc định nó hỏi sai chỗ, đó chính là yêu cầu 6.

Khái niệm cần tra: `launch template`, `Auto Scaling Group`, `target group`,
`health check` (có **hai** loại health check trong bài này, ở hai chỗ khác nhau —
tìm ra cả hai), `user data`, `instance metadata`, `desired/min/max capacity`,
`cross-zone load balancing`.

Đọc kèm: `docs/aws/w03-ec2-alb-asg.md` mục 11, 12, 13.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Cái nhận traffic.** Ba loại load balancer:

| | Tầng | Đọc được gì | Dùng khi |
|---|---|---|---|
| Application LB | 7 | HTTP header, path, host | định tuyến theo nội dung, health check bằng HTTP |
| Network LB | 4 | chỉ IP và port | cần TCP/UDP, cần IP tĩnh, cần triệu kết nối/giây |
| Gateway LB | 3 | gói tin thô | chèn thiết bị bảo mật bên thứ ba |

Yêu cầu 6 nói "phân biệt máy còn sống với ứng dụng còn phục vụ được". Muốn biết
ứng dụng còn phục vụ được thì phải **hỏi ứng dụng bằng ngôn ngữ của nó**. Câu đó
chọn giúp bạn.

**Cái quản lý đàn máy.** Hai lựa chọn: tự tạo N instance rời rạc, hay dùng
Auto Scaling Group. Câu hỏi giúp chọn: khi một máy chết, ai là người nhận ra và
tạo máy mới? Nếu câu trả lời là "tôi", thì bạn chưa giải được yêu cầu 7.

**Hai loại health check — đây là chỗ mấu chốt của cả lab.**

Có hai thứ khác nhau đang cùng lúc theo dõi máy của bạn:
1. Load balancer kiểm tra từng máy đích để quyết định **có gửi request tới không**.
2. Nhóm quản lý đàn máy kiểm tra để quyết định **có thay máy không**.

Cái thứ hai mặc định chỉ nhìn *trạng thái phần cứng/hypervisor của EC2* — máy
boot được là coi như khoẻ, kể cả khi tiến trình web đã chết từ lâu. Đề bài yêu
cầu nó nhìn vào kết luận của cái thứ nhất. Tra `health_check_type` của ASG và
xem nó nhận những giá trị nào.

Ba tham số quyết định con số "thời gian suy giảm" mà bạn sẽ đo được:
- chu kỳ health check của load balancer (`interval`)
- số lần fail liên tiếp trước khi kết luận hỏng (`unhealthy_threshold`)
- thời gian ân hạn cho máy mới trước khi bị đánh giá (`health_check_grace_period`)

Tham số thứ ba là bẫy: đặt quá ngắn thì máy mới bị giết trước khi kịp cài xong
phần mềm, và bạn có một vòng lặp launch–giết–launch vô tận.

**Máy web không lộ ra internet nhưng load balancer phải gọi tới được.** Security
group của máy web nên cho phép nguồn là **security group của load balancer**, chứ
không phải một dải IP. Câu hỏi tự kiểm: load balancer có bao nhiêu địa chỉ IP, và
chúng có cố định không?

**Máy cài phần mềm bằng cách nào.** Máy ở tầng riêng tư, không NAT — đúng bài
toán tuần 2. Hai lối ra: chọn distro có repo nằm trong kho object của AWS, hoặc
đừng cài gì cả (nhiều AMI đã có sẵn thứ đủ để phục vụ HTTP một trang chữ).
Lối thứ hai làm máy mới sẵn sàng nhanh hơn nhiều — và "thời gian máy mới sẵn sàng"
chính là một trong ba tham số ở trên.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**Lỗi 1 — target luôn `unhealthy`, dù `curl localhost` trên máy trả 200.**
Theo thứ tự kiểm tra:
1. Security group của máy web có cho phép nguồn từ security group của load
   balancer trên đúng port không? Nhớ rằng port health check có thể khác port
   phục vụ (`traffic-port` là mặc định).
2. Đường dẫn health check (`/`) có thật sự trả 200 không, hay trả 301/403?
   Load balancer coi 3xx là hỏng trừ khi bạn khai `matcher` khác.
3. Load balancer có nằm ở subnet cùng AZ với máy không? ALB cần **ít nhất hai
   subnet ở hai AZ khác nhau**, và nếu không bật cross-zone thì nó chỉ gửi tới
   máy trong AZ của chính nó.

**Lỗi 2 — ASG launch máy rồi giết, launch rồi giết, không dừng.**
`health_check_grace_period` quá ngắn so với thời gian user data chạy xong. Đo
thời gian thật: `cloud-init analyze blame` trên máy, hoặc đơn giản là tăng ân hạn
lên 300 giây rồi giảm dần.

**Lỗi 3 — `terraform apply` thành công nhưng ASG có 0 máy và không báo gì.**
Đây là lỗi im lặng khó chịu nhất của tuần này. ASG không làm `apply` thất bại;
nó ghi lý do vào lịch sử hoạt động của chính nó:

```bash
aws autoscaling describe-scaling-activities --auto-scaling-group-name <ten> \
  --profile lab-builder --query 'Activities[].[StatusCode,StatusMessage]' --output table
```

Lý do hay gặp: instance type không có ở AZ đó, AMI sai kiến trúc (`arm64` vs
`x86_64`), subnet hết địa chỉ, hoặc launch template tham chiếu một security group
ở VPC khác.

**Lỗi 4 — `curl` vào địa chỉ công khai trả 503.**
503 từ load balancer nghĩa là **không có target nào khoẻ**. Đây không phải lỗi
mạng của bạn — quay lại lỗi 1.

**Lỗi 5 — 20 lần gọi đều ra cùng một máy.**
Ba khả năng: chỉ có một máy khoẻ; bạn bật sticky session; hoặc bạn đang dùng
NLB (NLB băm theo flow nên cùng một client hay rơi vào cùng một đích).

**Lỗi 6 — user data không chạy.**
User data chỉ chạy **lần boot đầu tiên** của một instance. Sửa launch template
rồi reboot máy cũ thì không có gì đổi — phải để ASG launch máy mới. Kiểm tra kết
quả ở `/var/log/cloud-init-output.log`.

**Lỗi 7 — `terraform destroy` treo ở target group.**
Target group không xoá được khi còn máy đăng ký. Đặt desired capacity về 0, đợi,
rồi destroy. Xem lệnh ở mục Dọn dẹp của README.

**Cú pháp lạ duy nhất bạn có thể cần** — nhúng script user data mà không phải
escape từng dòng, và bọc base64 như AWS đòi hỏi:

```hcl
user_data = base64encode(file("${path.module}/khoi-dong.sh"))
```

**Resource Terraform cần tra:** `aws_launch_template` (chú ý `metadata_options`
và `network_interfaces`), `aws_autoscaling_group` (chú ý `health_check_type`,
`health_check_grace_period`, `target_group_arns`, `vpc_zone_identifier`),
`aws_lb`, `aws_lb_target_group` (chú ý khối `health_check`), `aws_lb_listener`,
`aws_security_group_rule` với `source_security_group_id`.

**Docs:**
- Health check của target group: <https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html>
- ASG health check: <https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-health-checks.html>
- Vì sao instance bị thay: <https://docs.aws.amazon.com/autoscaling/ec2/userguide/ts-as-instancelaunchfailure.html>

</details>
