# Tuần 3 — Giết một máy, không ai biết  (tự viết)

`Domain 2 · Resilient (26%)` `Domain 3 · Performance (24%)` `Domain 4 · Cost (20%)`

| | |
|---|---|
| **Chi phí khi chạy** | **~$0,053/giờ** — buổi lab tốn tiền nhất cả bộ |
| **Quên 1 tháng** | **~$39** |
| **Thời gian** | ~4 giờ, làm gọn trong một buổi |
| **Điều kiện** | phải xong `w02-vpc-networking`. Bạn sẽ dựng lại tầng mạng, và kiến thức endpoint từ tuần 2 quyết định máy có cài được phần mềm hay không. |

> **Đặt hẹn giờ điện thoại 4 tiếng ngay bây giờ.** Load balancer tính tiền từ
> giây đầu tiên, không có bậc miễn phí nào. Đây là lab duy nhất mà quên destroy
> một tuần là mất $9.

---

## Bối cảnh

Phòng marketing chạy một chiến dịch. Trang landing sẽ nhận traffic dồn trong ba
ngày rồi tắt. Giám đốc marketing đã có trải nghiệm tệ ở công ty cũ: trang sập giữa
lúc quảng cáo đang chạy, tiền quảng cáo vẫn tiêu, khách vào thì thấy trang trắng.

Yêu cầu của bà ấy chỉ có một câu: **"Tôi muốn một máy chết mà khách không nhận ra."**

Đội bảo mật thêm điều kiện quen thuộc từ tuần trước: máy chạy web không được lộ
ra internet. Chỉ đúng một thứ được phép nhận kết nối từ bên ngoài.

Đội tài chính thêm điều kiện thứ ba: chiến dịch xong là mọi thứ biến mất, và
trong lúc chạy thì không quá bốn máy.

---

## Yêu cầu

1. **Một địa chỉ HTTP công khai** mà bạn đưa cho phòng marketing được. Gọi vào
   phải trả `200`.
2. **Nội dung trả về phải cho biết máy nào đang phục vụ** — thân response chứa
   định danh của máy đó (dạng `i-0abc...`).
3. **Ít nhất hai máy đang phục vụ, trải trên ít nhất hai vùng sẵn sàng.**
4. **Request được chia cho nhiều máy.** Gọi 20 lần liên tiếp phải thấy ít nhất
   hai định danh khác nhau.
5. **Máy phục vụ không lộ ra internet**: không có địa chỉ IP công khai, và không
   security group nào của chúng nhận kết nối từ `0.0.0.0/0`.
6. **Hệ thống biết phân biệt "máy còn sống" với "ứng dụng còn phục vụ được".**
   Một máy mà tiến trình web đã chết phải bị coi là hỏng, dù bản thân máy vẫn boot.
7. **Tự phục hồi.** `verify.sh` sẽ **thật sự terminate một máy đang phục vụ**,
   rồi vừa gọi liên tục vào địa chỉ ở yêu cầu 1 vừa chờ. Trong vòng 12 phút:
   - một máy **mới** (định danh khác) phải xuất hiện và vào trạng thái phục vụ,
   - máy đã chết phải bị gỡ khỏi vòng nhận traffic,
   - và tỉ lệ request lỗi trong suốt quá trình phải dưới 15%.
8. **Trần quy mô:** số máy tối đa không vượt quá 4.

> Yêu cầu 7 là check dạy nhiều nhất trong cả bộ lab. Nó không kiểm tra bạn viết
> đúng resource nào — nó kiểm tra hệ thống của bạn có thật sự tự chữa lành không.
> Nó chạy mất khoảng 5–12 phút. Cứ để nó chạy và **nhìn màn hình**: con số
> "thời gian suy giảm" mà nó in ra là thứ bạn sẽ mang đi trả lời phỏng vấn.

---

## Hợp đồng output

| Output | Kiểu | `verify.sh` dùng để |
|---|---|---|
| `endpoint_url` | string | URL đầy đủ, ví dụ `http://self-w03-...elb.amazonaws.com` — mọi check về hành vi |
| `asg_name` | string | đọc quy mô, kiểu health check, danh sách máy; theo dõi lúc phục hồi |
| `target_group_arn` | string | đếm máy đang khoẻ; xác nhận máy chết bị gỡ ra |
| `vpc_id` | string | kiểm tra máy nằm đúng chỗ |
| `chi_phi` | string | in ra trước khi gõ `yes` |

`endpoint_url` phải có cả `http://`. Không có scheme thì `curl` không gọi được và
mọi check hành vi sẽ đỏ vì lý do không liên quan gì tới kiến trúc của bạn.

---

## Hàng rào của lab này

### Trần chi phí — đọc kỹ, đây là buổi đắt nhất

| Thành phần | Giá | 1 tháng |
|---|---|---|
| Application Load Balancer | $0,0225/giờ + phí LCU | $16,43 |
| 2 địa chỉ IPv4 công khai của load balancer | $0,01/giờ | $7,30 |
| 2 × EC2 `t3.micro` | $0,0208/giờ | $15,18 |
| 2 × EBS gp3 8 GB | $0,0018/giờ | $1,28 |
| Target group, ASG, launch template, health check | **$0** | **$0** |
| **Tổng** | **~$0,053/giờ** | **~$39** |

**Lab 4 tiếng ≈ $0,21.** Quên một tháng ≈ **$39** — hơn một phần tư ngân sách
cả khoá.

### Cách làm rẻ nhất

- Đổi sang `t4g.micro` (Graviton, $0,0084/giờ thay vì $0,0104): tiết kiệm
  $0,004/giờ. Nhớ đổi luôn AMI sang bản `arm64` — quên là instance không boot
  và bạn sẽ mất 20 phút không hiểu vì sao ASG cứ thay máy liên tục.
- **Đừng dùng Network Load Balancer** cho bài này. NLB có giá giờ tương tự nhưng
  không đọc được HTTP, nên yêu cầu 6 (phân biệt "máy sống" với "ứng dụng sống")
  sẽ khó hơn nhiều.
- Đừng bật access log của load balancer vào S3. Không tốn mấy nhưng tạo thêm
  một bucket có version để bạn quên.
- **Làm hết trong một buổi.** Đây là cách tiết kiệm lớn nhất, và nó không phải
  mẹo kỹ thuật nào cả.

### Boundary chặn gì, vì sao

| Boundary chặn | Vì sao |
|---|---|
| `autoscaling:CreateAutoScalingGroup` với `MaxSize > 4` | một ASG max 20 vô tình scale lên là $150/tháng. Boundary **không** chặn được instance type mà ASG launch (ASG launch qua service-linked role), nên thứ chặn được là **số lượng** |
| `ec2:RunInstances` với type ngoài danh sách rẻ | chặn được lúc bạn tự launch máy để thử |
| `ec2:CreateNatGateway`, `ec2:AllocateAddress` | như tuần 2 |
| `elasticloadbalancing:CreateLoadBalancer` **không** bị chặn theo loại | IAM **không có condition key** cho loại load balancer. Muốn chặn Gateway Load Balancer thì phải Deny cả action — mà bài này cần ALB. Hàng rào ở đây là `variable` validation trong Terraform của bạn, không phải IAM |
| mọi API ngoài `us-east-1` | như mọi tuần |

**Cảnh báo về một lỗ hổng thật của boundary:** Auto Scaling Group launch máy bằng
**service-linked role của chính dịch vụ Auto Scaling**, không bằng danh tính
`lab-builder` của bạn. Nghĩa là permission boundary **không nhìn thấy** những
lần launch đó và **không chặn được instance type**. Nếu bạn viết `m5.24xlarge`
vào launch template, boundary im lặng và AWS launch thật. Hàng rào duy nhất còn
lại lúc đó là `MaxSize` và ngân sách $5.

Đây không phải khiếm khuyết của lab — đây là bài học Domain 1: **permission
boundary chỉ ràng buộc principal mà nó gắn vào, không ràng buộc dịch vụ hành
động thay bạn.** Đề thi hỏi đúng ý này dưới dạng câu về `iam:PassRole`.

**Gặp `AccessDenied` — boundary hay bug?**

- `ValidationError ... MaxSize` lúc tạo ASG → boundary, đúng thiết kế. Giảm xuống ≤ 4.
- ASG tạo xong nhưng `Instances` rỗng mãi → **không phải boundary**. Xem
  "Activity history" của ASG trong console, hoặc:
  ```bash
  aws autoscaling describe-scaling-activities --auto-scaling-group-name <ten> \
    --profile lab-builder --max-items 5 --query 'Activities[].[StatusCode,StatusMessage]' --output table
  ```
  Đây là nơi ASG kể lý do thật, và gần như không ai biết để mở nó ra.
- Máy launch rồi chết rồi launch lại thành vòng lặp → health check đang fail.
  Không phải boundary; đó là yêu cầu 6 của bạn đang hoạt động đúng nhưng ứng dụng
  chưa lên. Xem log user data:
  ```bash
  aws ssm send-command --instance-ids <id> --document-name AWS-RunShellScript \
    --parameters 'commands=["tail -50 /var/log/cloud-init-output.log"]' --profile lab-builder
  ```

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh toàn bộ, gồm cả bài kiểm tra phục hồi
- [ ] `terraform destroy` sạch trong một lần, và `find-orphans.sh` không thấy gì
- [ ] Ghi lại con số **thời gian suy giảm** mà `verify.sh` in ra, và giải thích
      nó bằng ba tham số cấu hình của bạn (chu kỳ health check, ngưỡng hỏng,
      thời gian máy mới sẵn sàng phục vụ)
- [ ] Trả lời được: nếu bạn đổi kiểu health check của nhóm máy về loại mặc định,
      bài kiểm tra phục hồi còn xanh không? Thử đi, rồi đổi lại
- [ ] Giải thích được vì sao security group của máy web tham chiếu **security
      group của load balancer** thay vì một dải địa chỉ IP — và điều gì xảy ra
      nếu bạn dùng dải IP
- [ ] Trả lời được: hệ thống này chịu được **một máy** chết. Nó có chịu được
      **một AZ** chết không? Chứng minh bằng cấu hình, đừng đoán
- [ ] Trả lời được: tỉ lệ lỗi trong bài kiểm tra không phải 0%. Muốn về 0% thì
      phải thêm cơ chế gì, và cơ chế đó có cứu được trường hợp máy bị rút điện
      đột ngột không?

---

## Quy trình

```bash
source ../../env.sh
../guard.sh

cd terraform
terraform init
terraform apply                 # đọc chi_phi trước khi gõ yes

# Chờ máy vào trạng thái khoẻ trước khi verify — thường 2–4 phút.
watch -n 10 "aws elbv2 describe-target-health --profile lab-builder \
  --target-group-arn \$(terraform output -raw target_group_arn) \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table"

cd .. && ./verify.sh            # 6–14 phút, có giết máy thật

$PAGER DOI-CHIEU.md

cd terraform && terraform destroy
```

**Bỏ qua phần giết máy** khi đang debug những phần khác:

```bash
SKIP_CHAOS=1 ./verify.sh
```

Nhưng lab chỉ tính là xong khi đã chạy đầy đủ ít nhất một lần.

---

## Dọn dẹp

Thứ tự xoá luôn ngược thứ tự tạo. `terraform destroy` tự lo thứ tự, nhưng nếu
bạn từng sửa tay trong console thì phải kiểm tra lại:

```bash
cd terraform && terraform destroy

# Kiểm tra từng loại, theo đúng thứ tự tiền đắt trước:
aws elbv2 describe-load-balancers --profile lab-builder \
  --query 'LoadBalancers[].[LoadBalancerName,State.Code]' --output table
aws autoscaling describe-auto-scaling-groups --profile lab-builder \
  --query 'AutoScalingGroups[].[AutoScalingGroupName,DesiredCapacity]' --output table
aws ec2 describe-instances --profile lab-builder \
  --filters Name=instance-state-name,Values=running,pending \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType]' --output table
aws ec2 describe-volumes --profile lab-builder --filters Name=status,Values=available \
  --query 'Volumes[].[VolumeId,Size]' --output table
../../scripts/find-orphans.sh
```

Bốn lệnh đầu phải không in ra gì của bạn.

**Bẫy riêng của tuần này:** nếu `destroy` chạy khi ASG vẫn còn máy, Terraform có
thể xoá target group trước khi máy rời khỏi nó và treo ở đó. Cách chắc ăn: đặt
desired capacity về 0, đợi máy biến mất, rồi mới destroy.

```bash
aws autoscaling set-desired-capacity --profile lab-builder \
  --auto-scaling-group-name "$(terraform output -raw asg_name)" --desired-capacity 0
```

**Sáng hôm sau mở Cost Explorer kiểm tra lại.** Đây là tuần duy nhất nghi thức
đó thật sự cần thiết.
