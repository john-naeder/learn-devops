# Đối chiếu — tuần 7

> Đọc file này **sau khi** `./verify.sh` xanh hết. Đọc trước là tự lấy mất bài học.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong lab | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1. Một lần phát, nhiều nơi nhận | **Fanout pattern**, pub/sub, `SNS → nhiều SQS` | [`docs/aws/w07-decoupling.md`](../../../docs/aws/w07-decoupling.md) §3, §8 · [sổ tay tích hợp](../../../docs/notebook/06-tich-hop.md) |
| 2. Lọc ở nguồn | **Subscription filter policy** / **event pattern** | [`w07`](../../../docs/aws/w07-decoupling.md) §3, §4 |
| 3. Đang xử lý thì không ai giành mất | **Visibility timeout**, at-least-once delivery | [`w07`](../../../docs/aws/w07-decoupling.md) §2 |
| 4. Đơn độc bị cách ly | **Dead-letter queue**, `maxReceiveCount`, redrive policy | [`w07`](../../../docs/aws/w07-decoupling.md) §2 |
| 5. Nơi cách ly không cách ly tiếp | chống **poison-pill loop** | [`w07`](../../../docs/aws/w07-decoupling.md) §2 |
| 6. Hỏi rỗng không trả lời ngay | **Long polling** — Domain 4, giảm chi phí request | [sổ tay chi phí](../../../docs/notebook/10-chi-phi.md) |
| Resource policy trên hàng đợi | **Confused deputy**, `aws:SourceArn` | [`docs/aws/w09-security-deep.md`](../../../docs/aws/w09-security-deep.md) §8 |

Bốn mẫu kiến trúc mà đề thi gọi tên và bạn vừa dựng hai trong số đó:
**fanout** (một nguồn, nhiều đích độc lập) và **queue-based load levelling**
(hàng đợi hấp thụ đỉnh tải để consumer chạy đều).

---

## Ba cách khác để giải bài này

Đây là mục quan trọng nhất của file. Đề SAA gần như không bao giờ hỏi
*"cách nào chạy được"* — cả bốn đáp án thường đều chạy được. Nó hỏi
*"cách nào TỐT NHẤT"*, và "tốt nhất" luôn được định nghĩa bởi ràng buộc trong đề.

### Cách A — producer gọi thẳng hai hàng đợi, bỏ hẳn điểm phát tán

Ứng dụng đặt hàng gọi `SendMessage` hai lần, một lần cho mỗi hàng đợi.

**Tốt hơn khi:** bạn chỉ có đúng hai đích và chắc chắn sẽ không bao giờ có đích
thứ ba; độ trễ là tối thượng và bạn muốn bỏ một chặng mạng; bạn cần biết ngay
lập tức message nào vào được hàng đợi nào.

**Tệ hơn khi:** — và đây là trường hợp trong đề bài — mỗi khi thêm một bên nghe,
bạn phải **sửa và deploy lại producer**. Đó chính là coupling mà bài này muốn
xoá. Tệ hơn nữa: hai lần `SendMessage` không có tính nguyên tử, gửi xong cái thứ
nhất mà chết thì hệ thống ở trạng thái nửa vời. Và logic lọc "chỉ đơn lớn mới
gửi sang gian lận" chui vào code producer, tức là quy tắc nghiệp vụ của đội
chống gian lận nằm trong repo của đội đặt hàng.

**Đề thi hỏi thế nào:** *"Công ty muốn thêm hệ thống tiêu thụ mới mà không thay
đổi ứng dụng hiện có"* → từ khoá `without modifying the existing application`
loại thẳng cách A. Đáp án luôn là một lớp pub/sub ở giữa.

### Cách B — EventBridge custom bus thay cho SNS

Một event bus, hai rule, mỗi rule một target là một hàng đợi. Rule của đội chống
gian lận có event pattern `{"detail": {"gia_tri": [{"numeric": [">=", 1000]}]}}`.

**Tốt hơn khi:** bạn cần lọc theo **cấu trúc lồng nhau** của sự kiện, không chỉ
theo metadata phẳng; bạn cần **schema registry** và khám phá sự kiện; bạn cần
**archive và replay** sự kiện cũ; bạn cần nhận sự kiện từ **SaaS bên thứ ba**
(Datadog, Zendesk, Shopify) hoặc từ chính các dịch vụ AWS; bạn muốn một target
là Step Functions, Lambda, API Gateway... chứ không chỉ hàng đợi.

**Tệ hơn khi:** cần thông lượng rất cao với độ trễ thấp nhất — SNS nhanh hơn và
rẻ hơn EventBridge cho fanout thuần; cần fanout tới **hàng nghìn** subscriber
(SNS chịu 12,5 triệu subscription mỗi topic); cần gửi SMS, email, mobile push —
EventBridge không làm được, SNS làm được.

**Đề thi hỏi thế nào:** từ khoá `route based on the content of the event`,
`third-party SaaS`, `schedule`, `replay` → EventBridge. Từ khoá
`fanout to multiple queues`, `notify subscribers`, `SMS/email` → SNS.
Bài này nằm ở ranh giới, và cả hai đều đạt `verify.sh` — đó là cố ý.

### Cách C — Kinesis Data Streams

Một stream, hai consumer application đọc độc lập, mỗi cái giữ checkpoint riêng.

**Tốt hơn khi:** cần **thứ tự** trong từng partition key (mọi đơn của cùng một
khách phải xử lý theo đúng thứ tự); cần **replay** — đọc lại toàn bộ 24 giờ
(tới 365 ngày) dữ liệu khi thuật toán chống gian lận đổi; cần xử lý theo **lô
lớn** với phân tích thời gian thực; nhiều consumer cần đọc **cùng một bản ghi**
nhiều lần.

**Tệ hơn khi:** — và đây là bài này — bạn phải **tự quản lý shard**, tự
checkpoint, tự xử lý resharding. Không có DLQ sẵn: message độc phải tự phát hiện
và tự chuyển đi, nếu không nó **chặn cả shard** vì Kinesis đọc theo thứ tự. Và
shard provisioned tính tiền **theo giờ dù không có dữ liệu** — hàng rào của bộ
lab này chặn `kinesis:CreateStream` chính vì lý do đó.

**Đề thi hỏi thế nào:** từ khoá `ordering`, `replay`, `real-time analytics`,
`multiple consumers reading the same record` → Kinesis. Từ khoá
`decouple`, `retry`, `poison message`, `at-least-once` → SQS.
Bẫy kinh điển: đề mô tả một hệ thống xử lý đơn hàng bình thường rồi nhét từ
"streaming" vào để dụ bạn chọn Kinesis. Đọc kỹ xem có yêu cầu **thứ tự** hay
**replay** không — không có thì không phải Kinesis.

---

## Nếu đề thi hỏi

<details><summary>Câu 1. Một ứng dụng đẩy thông báo đơn hàng vào một SNS topic có hai SQS subscriber. Đội vận hành phát hiện một số message xuất hiện trong hàng đợi kế toán nhưng không bao giờ được xử lý xong, và consumer log báo cùng một message hàng trăm lần. Cách khắc phục nào TỐT NHẤT?</summary>

**A.** Tăng visibility timeout của hàng đợi lên 12 giờ.
**B.** Cấu hình redrive policy trỏ tới một dead-letter queue với `maxReceiveCount` hợp lý.
**C.** Chuyển hàng đợi sang FIFO để mỗi message chỉ được giao đúng một lần.
**D.** Bật long polling trên hàng đợi.

**Đáp án: B.**

- **A sai** — visibility timeout dài hơn chỉ làm message bị kẹt lâu hơn giữa hai
  lần thử. Nó không hề giới hạn *số lần* thử. Message độc vẫn quay lại vô hạn,
  chỉ là chậm hơn.
- **C sai** — FIFO cho **exactly-once processing** trong cửa sổ khử trùng lặp 5
  phút, nhưng đó là chống *trùng lặp khi gửi*. Message vẫn được giao lại khi
  consumer không xoá nó. FIFO không giải quyết poison message, và còn làm chậm
  đi (300 msg/s không batch).
- **D sai** — long polling là chuyện chi phí request và độ trễ khi hàng đợi rỗng.
  Không liên quan gì tới message bị xử lý lặp.

</details>

<details><summary>Câu 2. Một hệ thống dùng SNS fanout ra ba SQS queue. Một trong ba đội chỉ cần 5% lượng message, nhưng consumer của họ vẫn phải nhận và bỏ đi 95% còn lại, làm phát sinh chi phí gọi API bên thứ ba. Giải pháp nào ít thay đổi kiến trúc nhất mà giải quyết được?</summary>

**A.** Tạo một SNS topic thứ hai chỉ dành cho 5% message đó.
**B.** Thêm một Lambda giữa topic và hàng đợi để lọc.
**C.** Đặt subscription filter policy trên subscription của đội đó.
**D.** Chuyển sang EventBridge và viết rule lọc.

**Đáp án: C.**

- **A sai** — producer phải biết khi nào gửi vào topic nào, tức là quy tắc nghiệp
  vụ của đội tiêu thụ chui ngược vào producer. Đúng cái coupling ta đang xoá.
- **B sai** — chạy được nhưng thêm một dịch vụ, thêm tiền, thêm chỗ hỏng, thêm
  độ trễ. SNS đã có tính năng này sẵn và miễn phí. Đề hỏi "ít thay đổi kiến trúc
  nhất".
- **D sai** — cũng đúng về mặt kỹ thuật, nhưng phải viết lại toàn bộ tầng phát
  tán và mọi subscription. Đây là đáp án "tốt nhưng quá tay" mà đề SAA rất thích
  đặt vào để thử xem bạn có phân biệt được "giải pháp đúng" với "giải pháp cân
  xứng với vấn đề" không.

</details>

<details><summary>Câu 3. Consumer xử lý mỗi message mất trung bình 4 phút, cao nhất 9 phút. Visibility timeout đang là 30 giây. Triệu chứng nào sẽ xuất hiện?</summary>

**A.** Message bị mất sau 30 giây.
**B.** Cùng một message được xử lý bởi nhiều consumer song song, gây tác dụng phụ trùng lặp.
**C.** Hàng đợi từ chối nhận thêm message mới.
**D.** Consumer nhận được lỗi `ReceiptHandleIsInvalid` ngay khi bắt đầu xử lý.

**Đáp án: B.**

- **A sai** — SQS không mất message vì visibility timeout. Message chỉ rời hàng
  đợi khi bị xoá, khi hết message retention period (mặc định 4 ngày), hoặc khi
  bị chuyển sang DLQ.
- **C sai** — không có cơ chế nào như vậy. Hàng đợi standard gần như không giới
  hạn số message đang chờ.
- **D sai** — `ReceiptHandleIsInvalid` xảy ra khi *xoá* bằng một receipt handle
  đã hết hạn, tức là **sau** khi xử lý xong, chứ không phải khi bắt đầu. Đây là
  triệu chứng thứ cấp, không phải triệu chứng chính.

Đáp án đúng cho tình huống này: đặt visibility timeout ≥ thời gian xử lý dài nhất
(thường lấy 6 lần thời gian trung bình), hoặc dùng `ChangeMessageVisibility` để
gia hạn theo nhịp trong lúc đang xử lý — đó là heartbeat pattern.

</details>

<details><summary>Câu 4. Kiến trúc SNS → SQS đang chạy. Bảo mật yêu cầu: chỉ topic của chúng ta được đẩy vào hàng đợi của chúng ta. Hiện tại queue policy cho phép Principal service `sns.amazonaws.com`. Rủi ro là gì và sửa thế nào?</summary>

**A.** Không có rủi ro, `sns.amazonaws.com` đã là danh tính cụ thể.
**B.** Bất kỳ SNS topic nào ở bất kỳ account nào cũng đẩy được vào hàng đợi. Thêm điều kiện `aws:SourceArn`.
**C.** Đổi Principal sang account ID của mình.
**D.** Bật mã hoá SSE-KMS cho hàng đợi.

**Đáp án: B.** Đây là lỗ hổng **confused deputy**: bạn tin một *dịch vụ*, và dịch
vụ đó phục vụ cả thế giới.

- **A sai** — `sns.amazonaws.com` là tên của **dịch vụ**, không phải của topic
  bạn. Nó bao gồm mọi topic của mọi khách hàng AWS.
- **C sai** — đúng hướng nhưng chưa đủ hẹp: mọi topic trong account bạn vẫn đẩy
  được. Và nó phá luôn cách SNS gọi tới (SNS gọi bằng principal dịch vụ, không
  bằng account bạn).
- **D sai** — mã hoá bảo vệ dữ liệu lúc nghỉ, không trả lời câu hỏi "ai được ghi".
  Nhầm trục hoàn toàn — một bẫy rất hay gặp.

</details>

<details><summary>Câu 5. Đội cần xử lý sự kiện đơn hàng theo đúng thứ tự cho từng khách hàng, và cần đọc lại 7 ngày dữ liệu khi mô hình chấm điểm rủi ro thay đổi. Chọn gì?</summary>

**A.** SQS FIFO với `MessageGroupId` là mã khách hàng.
**B.** SNS với filter policy.
**C.** Kinesis Data Streams với partition key là mã khách hàng và retention 7 ngày.
**D.** SQS Standard với DLQ.

**Đáp án: C.** Hai từ khoá cùng xuất hiện: **thứ tự theo nhóm** và **đọc lại**.

- **A sai vì một nửa** — FIFO cho thứ tự theo `MessageGroupId` rất tốt, nhưng
  message bị **xoá sau khi xử lý**. Không đọc lại được. Retention tối đa 14 ngày
  chỉ áp dụng cho message *chưa* được xử lý.
- **B sai** — SNS không lưu trữ gì cả. Không subscriber thì message biến mất.
- **D sai** — Standard không đảm bảo thứ tự, và cũng không replay được.

Bẫy: nhiều người thấy "thứ tự" là chọn FIFO ngay. Phải đọc hết đề — chữ
**replay** là thứ loại FIFO.

</details>

---

## Chỗ dễ hiểu sai

**"verify.sh xanh nghĩa là hệ thống của tôi đúng."**
Không. Nó nghĩa là hệ thống của bạn đúng *với 4 message và 1 consumer*. Trong
production, ba thứ dưới đây sẽ vỡ và lab không chạm tới:

- **Idempotency.** Bạn vừa tận mắt thấy một message được giao lại sau khi worker
  chết. SQS Standard là **at-least-once**, không phải exactly-once. Consumer của
  bạn *phải* xử lý được việc nhận trùng — bằng khoá idempotency, bằng
  conditional write vào DynamoDB, bằng gì cũng được, nhưng phải có. Lab này
  không kiểm tra điều đó vì `verify.sh` không có consumer thật.

- **Visibility timeout tĩnh là một lời nói dối.** Bạn đặt 30 giây vì hôm nay xử
  lý mất 5 giây. Sáu tháng nữa có người thêm một lệnh gọi API bên ngoài vào vòng
  lặp và nó thành 45 giây. Không ai sửa visibility timeout, và hệ thống bắt đầu
  xử lý trùng — âm thầm. Cách làm đúng trong production là **heartbeat**: gọi
  `ChangeMessageVisibility` định kỳ trong lúc đang xử lý.

- **DLQ không có ai đọc thì bằng không có DLQ.** Bạn vừa chứng minh message độc
  rơi xuống nơi cách ly. Trong production phải có **alarm trên
  `ApproximateNumberOfMessagesVisible` của DLQ** — nếu không, message nằm đó 4
  ngày rồi bị xoá theo retention và không ai biết. Đó chính là bài tuần 10.

**Một chỗ nữa: `maxReceiveCount = 3` không phải con số thiêng.**
Nó là sự đánh đổi. Quá thấp thì một lỗi mạng thoáng qua cũng đẩy message hợp lệ
vào DLQ. Quá cao thì message độc chiếm chỗ và tốn tiền xử lý. Quy tắc thực dụng:
đặt đủ cao để vượt qua các lỗi *tạm thời* (thường 3–5), rồi dựa vào DLQ để bắt
lỗi *vĩnh viễn*. Nếu lỗi tạm thời của bạn kéo dài hơn thế, vấn đề nằm ở chỗ khác.
