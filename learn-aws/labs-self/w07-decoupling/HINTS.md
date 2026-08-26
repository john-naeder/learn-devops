# Gợi ý — tuần 7

Mở từng tầng một. Mở tầng 3 khi chưa thử tầng 1 là tự lấy mất bài học.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Chia bài thành bốn mảnh độc lập, làm xong mảnh nào `terraform apply` mảnh đó.
Đừng viết một lượt rồi apply — bạn sẽ mất 40 phút để tìm ra lỗi nằm ở mảnh nào.

**Mảnh 1 — hai bên nhận độc lập.**
Câu hỏi cần trả lời trước khi gõ: *khi một thông điệp cần tới hai nơi và hai nơi
đó tiêu thụ với tốc độ khác nhau, cái gì đứng giữa?* Nếu bạn định cho hai
consumer cùng đọc một hàng đợi, hãy tự hỏi: khi consumer A lấy một message ra
thì consumer B còn thấy nó không? Trả lời được câu đó là bạn ra kiến trúc.

**Mảnh 2 — lọc.**
Yêu cầu nói rõ "lọc ở nguồn, không lọc ở đích". Tra khái niệm **subscription
filter policy** (nếu bạn chọn pub/sub) hoặc **event pattern** (nếu bạn chọn event
bus). Cả hai đều là thứ bạn khai báo ở *chỗ đăng ký nhận*, không phải ở consumer.

**Mảnh 3 — visibility timeout.**
Đây là một thuộc tính của hàng đợi, một con số giây. Bài yêu cầu 20–60. Đừng
nghĩ phức tạp hơn thế.

**Mảnh 4 — cách ly.**
Tra khái niệm **dead-letter queue** và **redrive policy**. Điểm dễ nhầm: redrive
policy khai ở hàng đợi **nào**? Ở hàng đợi chính hay ở hàng đợi cách ly? Nghĩ
theo hướng "ai là người cần biết phải chuyển đi đâu".

**Một thứ nhiều người quên hoàn toàn:** một hàng đợi mặc định **không cho phép**
một dịch vụ khác đẩy message vào nó. Bạn phải nói với hàng đợi rằng ai được đẩy.
Từ khoá: *resource policy*, và đây chính là kiến thức tuần 1.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

Bạn có ba ứng viên cho vai "điểm phát tán". Chọn bằng cách trả lời ba câu hỏi,
không bằng cách chọn cái quen tay:

| | Nó gửi cho ai | Lọc bằng gì | Chi phí ở lab này |
|---|---|---|---|
| **SNS** | mọi subscriber đã đăng ký, đồng thời | filter policy trên message attribute (hoặc trên thân, nếu bật) | miễn phí |
| **EventBridge** | ai khớp rule | event pattern trên nội dung sự kiện | miễn phí (bus mặc định); $1/triệu sự kiện tự định nghĩa |
| **Kinesis Data Streams** | ai đọc shard, theo thứ tự, đọc lại được | không lọc — consumer tự lọc | **~$11/tháng mỗi shard — hàng rào chặn** |

Ba câu hỏi để tự chọn:

1. Bài này có cần **đọc lại lịch sử** thông điệp (replay) không? Có cần **thứ tự
   tuyệt đối** không? Nếu không cần cả hai thì bạn vừa loại được một ứng viên.
2. Bộ lọc của bạn dựa trên **metadata** (một trường phẳng, kiểu số) hay dựa trên
   **cấu trúc lồng nhau** của sự kiện? Câu trả lời quyết định giữa hai ứng viên
   còn lại.
3. Sáu tháng nữa có bên thứ ba muốn nghe cùng luồng này, họ đăng ký ở đâu và ai
   phải sửa code? Kiến trúc nào làm việc đó rẻ hơn?

Còn một lựa chọn nữa mà nhiều người nghĩ tới: **cho producer gọi thẳng hai hàng
đợi**. Nó chạy được. Trước khi loại nó, hãy nói rõ được nó sai ở đâu — nếu không
nói được, bạn chưa hiểu vì sao pub/sub tồn tại. (`DOI-CHIEU.md` bàn kỹ.)

Về consumer: bài **không** yêu cầu bạn phải có consumer thật. `verify.sh` đóng
vai consumer. Nếu bạn muốn thêm Lambda cho giống thật thì cứ thêm — nhưng nhớ
`permissions_boundary` trên role của nó, và nhớ đặt `retention_in_days` cho log
group.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**Message không bao giờ tới hàng đợi.**
Chín trên mười lần là thiếu resource policy trên hàng đợi. Terraform:
`aws_sqs_queue_policy`. Principal là `service` `sns.amazonaws.com` (hoặc
`events.amazonaws.com`), và **luôn** kèm điều kiện `aws:SourceArn` bằng ARN của
topic/rule — thiếu điều kiện đó là lỗ hổng *confused deputy*, bất kỳ topic nào
trong bất kỳ account nào cũng bơm được vào hàng đợi của bạn.

**Filter policy không có tác dụng.**
Ba nguyên nhân, theo thứ tự hay gặp:
- Filter policy mặc định soi **message attribute**, không soi thân message. Muốn
  soi thân thì phải khai `filter_policy_scope = "MessageBody"`.
- Giá trị số trong filter policy phải viết dạng `{"numeric": [">=", 1000]}`,
  không phải `1000`. So sánh chuỗi `"5000" >= "1000"` không tồn tại trong SNS.
- Filter policy phải là **JSON**, và trong HCL bạn cần `jsonencode`. Đây là cú
  pháp lạ duy nhất trong lab này, nên đây là 2 dòng HCL được trích:

```hcl
filter_policy       = jsonencode({ gia_tri = [{ numeric = [">=", 1000] }] })
filter_policy_scope = "MessageAttributes"
```

**DLQ có message nhưng hàng đợi chính vẫn còn.**
Bạn đang nhìn hai message khác nhau. Mỗi lần `verify.sh` chạy nó gửi mã đơn mới.
Vét sạch cả hai hàng đợi rồi chạy lại.

**`terraform apply` báo `MalformedPolicyDocument` khi tạo role.**
Boundary bắt mọi role mới phải mang `permissions_boundary`. Lấy ARN bằng
`terraform -chdir=../../_boundary output -raw lab_boundary_arn`, hoặc ghép tay:
`arn:aws:iam::<account>:policy/labs-self-boundary`.

**Tài liệu cần tra:**
- `aws_sns_topic_subscription` — chú ý `raw_message_delivery`, `filter_policy`,
  `filter_policy_scope`
- `aws_sqs_queue` — `visibility_timeout_seconds`,
  `receive_wait_time_seconds`, `redrive_policy`
- `aws_sqs_queue_redrive_policy` (tách riêng, tránh vòng phụ thuộc giữa hàng đợi
  chính và DLQ)
- [SQS: Amazon SQS dead-letter queues](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html)
- [SNS: Message filtering](https://docs.aws.amazon.com/sns/latest/dg/sns-message-filtering.html)

</details>
