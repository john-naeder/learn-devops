# Gợi ý — tuần 10

Mở từng tầng một. Lab này có một bước mà gần như ai cũng kẹt (biến nhật ký thành
số đo mà vẫn phát ra 0 khi không có lỗi) — nó nằm ở tầng 3.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bài này có **sáu mảnh** gần như độc lập. Làm xong mảnh nào apply mảnh đó và tự
kiểm bằng tay trước khi chạy `verify.sh` — chạy verify để debug là cách tốn 10
phút mỗi vòng.

**Mảnh 1 — dịch vụ và nhật ký.** Viết hàm sao cho mỗi lệnh gọi in ra đúng một
dòng JSON. Chú ý: runtime của bạn có thể tự bọc thêm dòng `START`/`END`/`REPORT`
— đó là bình thường, `verify.sh` chỉ tìm dòng có mã yêu cầu của nó. Điều bạn
phải tự kiểm: gọi tay một lần rồi mở nhóm nhật ký ra xem dòng đó có đúng là JSON
**một dòng** không. JSON xuống dòng nhiều dòng sẽ làm hỏng cả mảnh 2 lẫn mảnh 5.

**Mảnh 2 — hạn giữ nhật ký.** Đây là mảnh dễ nhất và cũng hay bị bỏ sót nhất, vì
nếu bạn để dịch vụ tự tạo nhóm nhật ký thì mặc định là **giữ vĩnh viễn** và
Terraform không quản lý nó. Câu hỏi: làm sao để nhóm nhật ký nằm trong tay
Terraform *trước khi* dịch vụ kịp tự tạo nó? (Tra: quy ước đặt tên nhóm nhật ký
của Lambda, và `depends_on`.)

**Mảnh 3 — từ nhật ký ra con số.** Khái niệm cần tra: **metric filter**. Đọc kỹ
phần nói về **mẫu lọc cho log dạng JSON** — cú pháp khác hẳn mẫu lọc cho log
dạng văn bản thường. Và đọc kỹ thuộc tính điều khiển "phát ra gì khi dòng log
KHÔNG khớp mẫu" — đó là chìa khoá của yêu cầu 3.

**Mảnh 4 — cảnh báo.** Ba con số của yêu cầu 4 ánh xạ thẳng vào ba tham số của
một cảnh báo: độ dài chu kỳ, số chu kỳ phải xét, và ngưỡng. Có một tham số thứ
tư không nằm trong đề bài nhưng quyết định yêu cầu 5 — nó trả lời câu hỏi *"khi
không có dữ liệu nào trong chu kỳ này thì coi như tốt hay xấu?"*.

**Mảnh 5 — truy vấn lưu sẵn.** Hai phần: viết được câu truy vấn (thử trong
console trước cho nhanh), và **lưu** nó lại thành một đối tượng có tên. Phần thứ
hai mới là thứ `verify.sh` chấm.

**Mảnh 6 — state dùng chung.** Đây là mảnh có bài toán mồi: nơi chứa state phải
tồn tại trước khi bạn khai báo dùng nó. README mục "Quy trình" mô tả hai pha.
Đừng cố làm một pha.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Cho việc "biến sự kiện trong ứng dụng thành số đo" (yêu cầu 3)** — ba đường,
xếp theo chi phí vận hành:

| | Cách làm | Chi phí | Điểm yếu |
|---|---|---|---|
| **Metric filter trên log** | khai báo một lần, không sửa code | $0 (số đo tính vào hạn mức 10) | trễ 1–2 phút; phụ thuộc định dạng log |
| **`PutMetricData` từ trong code** | code tự gọi API sau mỗi sự kiện | $0,01/1000 lệnh gọi + tiền số đo | thêm một lệnh gọi mạng trên đường xử lý; hỏng thì mất số liệu |
| **Embedded Metric Format (EMF)** | code in ra log theo một cấu trúc JSON đặc biệt, CloudWatch tự trích | $0 (ngoài tiền log) | phải theo đúng schema; ít người biết đọc |

Ba câu hỏi để tự chọn:
1. Bạn có sửa được code của dịch vụ không? Nếu **không** (ứng dụng của bên thứ
   ba, log đã có sẵn) thì hai đường sau bị loại ngay.
2. Bạn cần số đo **ngay lập tức** hay chậm 1–2 phút cũng được? Cảnh báo có chu
   kỳ 60 giây thì độ trễ đó có làm hỏng gì không?
3. Sự kiện của bạn có kèm **nhiều chiều** (mã khách hàng, mã vùng, mã yêu cầu)
   không? Nếu có, hãy đếm thử số tổ hợp rồi nhân với $0,30 trước khi chọn.

**Cho việc "cảnh báo tới được người trực" (yêu cầu 4)** — cảnh báo của CloudWatch
chỉ biết đẩy vào vài loại đích. Loại nào **phát tán được cho nhiều người nhận
cùng lúc**, mỗi người một kiểu (một người nhận mail, một hệ thống nhận thông
điệp máy đọc được)? Bạn đã dựng đúng mẫu đó ở tuần 7 rồi.

Lưu ý một chi tiết dễ mất 20 phút: hộp thư của bạn **mặc định không cho** dịch
vụ khác đẩy vào. Cần một resource policy, và **kèm điều kiện nguồn** — nếu không
thì bất kỳ ai cũng nhét được thông điệp giả vào hộp thư trực của bạn. Đây là lỗ
hổng confused deputy, đúng thứ bạn gặp ở tuần 7 và tuần 9.

**Cho việc "state dùng chung" (yêu cầu 7)** — bốn điều kiện của đề bài (lịch sử
phiên bản, mã hoá, không lộ ra ngoài, khoá chống ghi đồng thời) chia thành hai
nhóm. Ba điều đầu là thuộc tính của **nơi lưu**. Điều cuối cần một **thứ khác**,
vì kho object không có cơ chế khoá nguyên tử theo kiểu Terraform cần — nó cần
một chỗ ghi được có điều kiện.

> Terraform từ phiên bản 1.10 có thêm cách khoá bằng chính file trong kho object
> (`use_lockfile`), và đó là hướng AWS/HashiCorp khuyến nghị cho thiết kế mới.
> Lab này vẫn chấm cách cũ vì nó **quan sát được từ bên ngoài qua AWS API** —
> `verify.sh` không được phép đọc file `.tf` của bạn. `DOI-CHIEU.md` bàn kỹ hai
> cách và khi nào chọn cái nào.

**Cho việc lưu truy vấn (yêu cầu 6)** — có hai thứ tên gần giống nhau trong
CloudWatch Logs: một cái *lưu câu truy vấn để dùng lại*, một cái *đẩy log sang
nơi khác theo thời gian thực*. Bạn cần cái thứ nhất. Tra cả hai để không nhầm.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**`terraform apply` báo `AccessDenied` ở `aws_iam_role`.**
Thiếu `permissions_boundary`. Lấy ARN:
`terraform -chdir=../../_boundary output -raw lab_boundary_arn`.
Nếu đã có mà vẫn hỏng **và** thông điệp nhắc tới permissions boundary: kiểm tra
tên role có prefix `self-w10-` chưa. Sai prefix cho ra thông điệp y hệt.

**Hàm chạy nhưng không thấy nhật ký đâu.**
Role thực thi thiếu `logs:CreateLogStream` và `logs:PutLogEvents`. Nếu bạn tự
tạo nhóm nhật ký bằng Terraform thì hàm **không** cần `logs:CreateLogGroup` —
và không cấp quyền đó lại là cách tốt để bảo đảm hàm không tự tạo nhóm ở chỗ
khác.

**Nhóm nhật ký bị Lambda tạo trước, Terraform báo `ResourceAlreadyExistsException`.**
Xoá nhóm đó bằng tay rồi apply lại. Để tránh lặp lại: khai nhóm nhật ký trong
Terraform với đúng tên `/aws/lambda/<tên hàm>` và cho hàm `depends_on` nó.

**Số đo không có điểm dữ liệu nào dù đã gọi hàm nhiều lần.**
Ba nguyên nhân, theo thứ tự hay gặp:
- Mẫu lọc không khớp. Log JSON cần mẫu dạng `{ $.truong = "giá trị" }` —
  chú ý dấu `$.` và dấu ngoặc nhọn bao ngoài. Mẫu kiểu văn bản thường
  (`"ERROR"`) vẫn khớp được nhưng nó bắt cả dòng nào tình cờ chứa chữ đó.
- Dòng log không phải JSON hợp lệ (in nhiều dòng, có prefix timestamp của
  runtime dán vào trước dấu `{`).
- Bạn đang nhìn nhầm cửa sổ thời gian. Số đo trễ 1–2 phút.
  Kiểm tra nhanh bằng chính công cụ AWS cho việc này:
  `aws logs test-metric-filter --filter-pattern '...' --log-event-messages '<một dòng log thật>'`

**Số đo có dữ liệu khi lỗi, nhưng KHÔNG có dữ liệu khi bình thường.**
Đây chính là check "số đo lỗi có dữ liệu ngay cả khi không có lỗi nào". Bạn thiếu
thuộc tính điều khiển "phát ra gì khi dòng log không khớp mẫu". Tra `default_value`
trong `metric_transformation`. Vì sao điều này quan trọng: không có nó, khi hệ
thống ngừng nhận lưu lượng hoàn toàn (chết hẳn), số đo trở thành *thiếu dữ liệu*
chứ không phải *0* — và tuỳ cách bạn cấu hình, cảnh báo có thể **im lặng đúng lúc
hệ thống chết**.

**Cảnh báo mãi ở `INSUFFICIENT_DATA`.**
Tra `treat_missing_data`. Bốn giá trị: `missing` (mặc định — giữ nguyên trạng
thái INSUFFICIENT_DATA), `notBreaching` (coi như tốt), `breaching` (coi như xấu),
`ignore` (giữ nguyên trạng thái *trước đó*). Với bài này bạn muốn cảnh báo ở `OK`
khi im lặng — nhưng hãy nghĩ thêm một nhịp: nếu hệ thống chết hẳn thì `notBreaching`
nói "vẫn tốt". Đó là lý do trong production, cảnh báo "số lỗi" luôn phải đi kèm
một cảnh báo "không còn lưu lượng nào".

**Cảnh báo kêu nhưng hộp thư trống.**
Kênh thông báo đã đẩy đi, nhưng hộp thư không nhận. Chín trên mười lần là thiếu
resource policy trên hộp thư (giống hệt tuần 7). Kiểm tra nhanh:
`aws sns publish --topic-arn <kênh> --message thu` rồi đọc hộp thư — nếu thông
điệp thủ công cũng không tới thì vấn đề nằm ở đăng ký/quyền, không nằm ở cảnh báo.

**`verify.sh` báo "chưa xác nhận subscription".**
Đăng ký bằng email cần một cú bấm chuột trong hộp thư của bạn. Terraform tạo
subscription ở trạng thái `PendingConfirmation` và **không thể** tự xác nhận —
đây là một trong số rất ít chỗ IaC buộc phải dừng chờ con người, và đề thi có
hỏi. Đăng ký bằng một đích máy-với-máy thì được xác nhận tự động.

**Truy vấn chạy nhưng `ms` ở dòng đầu không đủ lớn.**
Truy vấn của bạn thiếu `sort` hoặc sort nhầm chiều, hoặc cột không tên đúng `ms`.
Logs Insights tự tách trường của log JSON, nên `ms` dùng được thẳng. Nếu bạn
dùng `stats` thì cột kết quả mang tên hàm tổng hợp chứ không phải `ms` — đặt tên
lại bằng `as`. Cửa sổ thời gian verify dùng là 30 phút gần nhất.

**`terraform init -migrate-state` báo `NoSuchBucket` hoặc `AccessDenied`.**
Kho state phải được `apply` xong ở pha 1 **trước** khi bạn thêm khối backend.
Nếu bạn thêm backend ngay từ đầu thì Terraform cố đọc state ở một chỗ chưa tồn tại.

**Cú pháp lạ đáng trích** — mẫu lọc JSON và giá trị mặc định là chỗ duy nhất
trong lab có cú pháp không đoán được:

```hcl
pattern = "{ $.muc = \"ERROR\" }"
metric_transformation { default_value = "0" }
```

**Tài liệu cần tra:**
- `aws_cloudwatch_log_group` (`retention_in_days`),
  `aws_cloudwatch_log_metric_filter`, `aws_cloudwatch_metric_alarm`
  (`period`, `evaluation_periods`, `datapoints_to_alarm`, `treat_missing_data`),
  `aws_cloudwatch_query_definition`
- `aws_sns_topic_subscription`, `aws_sqs_queue_policy`
- `aws_s3_bucket_versioning`, `aws_s3_bucket_server_side_encryption_configuration`,
  `aws_s3_bucket_public_access_block`, `aws_dynamodb_table`
- [Filter and pattern syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [Using CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html) — đọc kỹ mục "Configuring how CloudWatch alarms treat missing data"
- [CloudWatch Logs Insights query syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)

</details>
