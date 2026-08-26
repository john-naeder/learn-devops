# Tuần 07 — Tách rời hệ thống  (tự viết)

`Domain 2 · Resilient Architectures (26% đề)`

| | |
|---|---|
| **Chi phí khi chạy** | **$0,00/giờ** — SNS, SQS và EventBridge đều nằm trong hạn mức always free |
| **Quên 1 tháng** | **$0,00** — không có tài nguyên nào tính tiền theo giờ trong lab này |
| **Thời gian** | ~3 giờ viết + ~7 phút chạy `verify.sh` |
| **Điều kiện** | không cần lab nào trước. Nên đọc [`docs/aws/w07-decoupling.md`](../../../docs/aws/w07-decoupling.md) trước |

---

## Bối cảnh

Bạn vận hành hệ thống đặt hàng của một sàn thương mại nhỏ. Hôm nay mọi thứ nằm
trong một khối: khi khách bấm "Đặt hàng", cùng một tiến trình vừa ghi sổ kế toán
vừa chấm điểm rủi ro gian lận. Đội chống gian lận muốn đổi thuật toán mỗi tuần,
và mỗi lần họ deploy thì khách hàng không đặt được hàng.

Sếp yêu cầu ba điều, theo đúng thứ tự ưu tiên này:

1. Đội kế toán và đội chống gian lận phải chạy độc lập — một bên chậm hoặc chết
   thì bên kia không được biết.
2. Đội chống gian lận chỉ quan tâm đơn giá trị lớn. Họ **không muốn** thấy đơn
   vặt, vì mỗi đơn họ soi tốn tiền gọi API bên thứ ba.
3. Một đơn hàng "độc" — dữ liệu hỏng làm consumer chết đi chết lại — không được
   phép làm nghẽn cả dây chuyền. Nhưng cũng không được âm thầm biến mất: đội vận
   hành phải mở ra xem được nó là đơn nào.

---

## Yêu cầu

Mỗi yêu cầu ánh xạ 1:1 với một nhóm check trong `verify.sh`.

1. **Một lần phát, nhiều nơi nhận.** Gửi một đơn hàng vào hệ thống đúng **một
   lần**, cả kế toán lẫn chống gian lận đều nhận được **bản sao riêng** của nó.
   Bên này lấy hoặc xoá bản của mình không ảnh hưởng gì tới bên kia.

2. **Lọc ở nguồn, không lọc ở đích.** Đơn có `gia_tri < 1000` **không được**
   xuất hiện ở phía chống gian lận. Việc lọc phải xảy ra **trước khi** thông
   điệp tới nơi họ — nếu consumer của họ phải tự đọc rồi tự bỏ qua thì tiền gọi
   API vẫn mất và yêu cầu này coi như trượt.

3. **Đang xử lý thì không ai giành mất.** Khi một worker đã nhận một đơn nhưng
   chưa báo xong, đơn đó **không được** giao cho worker thứ hai trong ít nhất
   **20 giây**. Nhưng nếu worker chết giữa chừng, đơn phải tự quay lại hàng đợi
   trong vòng **60 giây** — không được kẹt vĩnh viễn.

4. **Đơn độc bị cách ly, không bị mất.** Một đơn mà worker nhận rồi không xử lý
   được, sau **đúng 3 lần** giao phải rời hàng đợi chính và nằm ở một nơi mà đội
   vận hành mở ra đọc được. Sau khi bị cách ly nó **không được** quay lại hàng
   đợi chính.

5. **Nơi cách ly không được cách ly tiếp.** Nơi chứa đơn độc không được có cơ chế
   chuyển tiếp của riêng nó. (Đây là lỗi kinh điển: DLQ trỏ vào DLQ khác, hoặc
   tệ hơn, trỏ ngược về hàng đợi chính tạo vòng lặp vô tận.)

6. **Hỏi hàng đợi rỗng không được trả lời ngay.** Một lần hỏi hàng đợi đang rỗng
   phải chờ ít nhất **10 giây** trước khi trả lời "không có gì". Lý do là tiền:
   trả lời tức thì nghĩa là consumer quay vòng hỏi liên tục, và SQS tính tiền
   theo **số request**, không theo số message.

### Hợp đồng thông điệp

`verify.sh` là consumer giả và producer giả của bạn, nên hai bên phải nói chung
một ngôn ngữ. `verify.sh` sẽ gửi vào hệ thống một đơn hàng có **thân JSON**:

```json
{"ma_don": "<chuỗi duy nhất>", "gia_tri": 10}
```

và kèm theo **một message attribute** tên `gia_tri`, `DataType = Number`, giá
trị bằng đúng số ở trên.

Bạn lọc theo attribute hay lọc theo nội dung thân là quyền của bạn — hợp đồng
này cấp sẵn cả hai đường. Thân JSON phải tới được tay consumer **nguyên vẹn hoặc
bọc trong phong bì** — `verify.sh` chỉ tìm chuỗi `ma_don` bên trong thân nhận
được, nên cả hai kiểu đều đạt.

---

## Hợp đồng output

Thiếu một output = `verify.sh` dừng ngay, không chấm được gì.

| Output | Kiểu | `verify.sh` dùng để làm gì |
|---|---|---|
| `kenh_don_hang` | string (ARN) | Điểm phát tán. Gửi đơn hàng vào đây. ARN chứa `:sns:` thì gửi bằng `sns publish`; chứa `:events:` thì gửi bằng `events put-events` với `Source=self.w07`, `DetailType=don-hang` |
| `hang_doi_ketoan` | string (URL) | Hàng đợi phía kế toán. Nhận **mọi** đơn |
| `hang_doi_gianlan` | string (URL) | Hàng đợi phía chống gian lận. Chỉ nhận đơn `gia_tri >= 1000` |
| `hang_doi_cach_ly` | string (URL) | Nơi đơn độc nằm lại sau 3 lần thất bại |

Đặt tên resource với prefix `self-w07-`.

> `kenh_don_hang` nhận ARN chứ không nhận tên, vì đó là chỗ duy nhất `verify.sh`
> suy ra được bạn chọn cơ chế phát tán nào. Đây cũng là lý do bài này không nói
> "tạo một SNS topic": có ít nhất hai cách đúng, và `DOI-CHIEU.md` sẽ bàn cách
> nào tốt hơn trong hoàn cảnh nào.

---

## Hàng rào của lab này

**Trần chi phí: $0,00/giờ, $0,00 nếu quên một tháng.** SNS 1 triệu publish/tháng,
SQS 1 triệu request/tháng, EventBridge sự kiện của AWS miễn phí và sự kiện tự
định nghĩa $1/triệu. `verify.sh` gửi khoảng 5 message và gọi khoảng 60 request
SQS mỗi lần chạy. Chạy 100 lần vẫn chưa tới một phần nghìn hạn mức.

**Boundary chặn gì ở lab này:**

| Bị chặn | Vì sao |
|---|---|
| `kinesis:CreateStream` | shard provisioned ~$11/tháng mỗi shard. Nếu bạn định giải bài bằng Kinesis Data Streams thì hàng rào sẽ chặn — đó là cố ý, xem `DOI-CHIEU.md` mục "Ba cách khác" để biết vì sao Kinesis là đáp án **sai** cho bài này |
| `mq:*` | Amazon MQ ~$30/tháng. Cùng lý do |
| Mọi API ngoài `us-east-1` | tài nguyên bỏ quên ở region lạ là cách đốt credit phổ biến nhất |
| `iam:CreateRole` không mang boundary | mọi role bạn tạo (ví dụ role cho Lambda consumer, nếu bạn dùng) phải có `permissions_boundary` trỏ tới `labs-self-boundary` |

**Phân biệt `AccessDenied` của hàng rào với bug của bạn:**

- Thông điệp nhắc tới **`with an explicit deny in a permissions boundary`** →
  hàng rào. Bạn đang cố làm thứ lab này không cần. Đọc lại yêu cầu.
- Thông điệp nhắc tới **`is not authorized to perform`** kèm tên role bạn tự tạo
  → policy bạn viết thiếu. Bug của bạn.
- Chi tiết: [`../_boundary/README.md`](../_boundary/README.md).

---

## Tiêu chí đạt

`./verify.sh` xanh hết là điều kiện **cần**. Điều kiện **đủ** gồm cả những thứ
máy không chấm được:

- [ ] `./verify.sh` xanh hết
- [ ] Giải thích được: vì sao bài này cần **hai** hàng đợi chứ không phải một
      hàng đợi và hai consumer cùng đọc
- [ ] Giải thích được: visibility timeout đặt **quá ngắn** thì hỏng thế nào,
      đặt **quá dài** thì hỏng thế nào — hai kiểu hỏng khác hẳn nhau
- [ ] Giải thích được: `maxReceiveCount = 1` nghĩa là gì, và vì sao gần như luôn
      sai
- [ ] Nói được khi nào bài toán này nên dùng Kinesis thay vì SQS, và vì sao
      **bài toán cụ thể ở trên** thì không
- [ ] Chỉ ra được chỗ trong thiết kế của bạn sẽ vỡ nếu lượng đơn tăng 1000 lần

---

## Quy trình

```bash
source ../../env.sh
../_boundary/guard.sh              # hàng rào còn sống? ngân sách còn không?

cd terraform
terraform init
# viết main.tf + outputs.tf của bạn ở đây
terraform apply

cd ..
./verify.sh                        # ~7 phút, có báo tiến độ
# xanh hết rồi mới đọc:
cat DOI-CHIEU.md

cd terraform && terraform destroy
```

> `verify.sh` **có ghi** vào hệ thống của bạn: nó gửi vài đơn hàng thử và nhận
> chúng ra. Đây là ngoại lệ có chủ ý so với các lab khác — không bơm message vào
> thì không có cách nào chứng minh message đi đâu. Nó dọn sạch những gì nó gửi,
> và chạy lại nhiều lần cho cùng kết quả.

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Kiểm tra đã sạch:

```bash
aws sqs list-queues --queue-name-prefix self-w07 --profile lab-builder
aws sns list-topics --profile lab-builder --query "Topics[?contains(TopicArn,'self-w07')]"
aws events list-rules --profile lab-builder --query "Rules[?starts_with(Name,'self-w07')].Name"
```

Ba lệnh trên phải trả về rỗng. Nếu bạn có tạo Lambda consumer, log group của nó
**không** bị `terraform destroy` xoá khi bạn khai báo log group ngoài Terraform —
kiểm tra thêm:

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/self-w07 --profile lab-builder
```

Lab này không tốn tiền nên giữ lại cũng được. Nhưng SQS giữ message 4 ngày và
`find-orphans.sh` sẽ nhắc bạn mãi — destroy đi cho gọn đầu.
