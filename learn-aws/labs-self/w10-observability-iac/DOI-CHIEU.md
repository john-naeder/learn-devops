# Đối chiếu — tuần 10

> Đọc file này **sau khi** `./verify.sh` xanh hết. Đọc trước là tự lấy mất bài học.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong lab | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1. Nhật ký có cấu trúc | **structured logging**, log group / log stream | [`docs/aws/w10-observability-iac.md`](../../../docs/aws/w10-observability-iac.md) §3 |
| 2. Hạn giữ nhật ký | **retention** — bẫy chi phí số một của CloudWatch | [`w10`](../../../docs/aws/w10-observability-iac.md) §3 · [sổ tay chi phí](../../../docs/notebook/10-chi-phi.md) |
| 3. Nhật ký thành con số, và bằng 0 khi khoẻ | **metric filter**, `default_value`, custom metric | [`w10`](../../../docs/aws/w10-observability-iac.md) §3, §1 |
| 4. Cảnh báo kêu và tới được người trực | **CloudWatch alarm** → **SNS** → nhiều loại subscriber | [`w10`](../../../docs/aws/w10-observability-iac.md) §2 · [sổ tay sẵn sàng cao](../../../docs/notebook/11-san-sang-cao.md) |
| 5. Im lặng nhưng không mù | **`treat_missing_data`**, `INSUFFICIENT_DATA` | [`w10`](../../../docs/aws/w10-observability-iac.md) §2 |
| 6. Truy vấn lưu sẵn | **Logs Insights**, query definition | [`w10`](../../../docs/aws/w10-observability-iac.md) §3 |
| 7. State dùng chung, có khoá | **remote state**, state locking, IaC nhiều người | [`w10`](../../../docs/aws/w10-observability-iac.md) §8 |
| 8. Không gì tính tiền theo giờ | Domain 4 — mô hình tính tiền theo lượt dùng | [sổ tay chi phí](../../../docs/notebook/10-chi-phi.md) |
| Quyền đẩy vào hộp thư trực | **confused deputy**, `aws:SourceArn` | [`docs/aws/w09-security-deep.md`](../../../docs/aws/w09-security-deep.md) §8 |

### Ba trạng thái của một cảnh báo, và vì sao trạng thái thứ ba nguy hiểm nhất

| Trạng thái | Nghĩa là | Nhìn trên dashboard |
|---|---|---|
| `OK` | có dữ liệu, và dữ liệu nằm trong ngưỡng | xanh |
| `ALARM` | có dữ liệu, và dữ liệu vượt ngưỡng | đỏ |
| `INSUFFICIENT_DATA` | **không biết** | xám — và mắt người lướt qua nó y như xanh |

Một cảnh báo kẹt ở `INSUFFICIENT_DATA` là một cảnh báo **đã chết mà không ai báo
tang**. Nó không bao giờ kêu, và nó trông vô hại. Đây là dạng sự cố im lặng mà
Bối cảnh của lab mô tả, và `treat_missing_data` là tham số quyết định:

| Giá trị | Khi thiếu dữ liệu thì coi như | Dùng khi |
|---|---|---|
| `missing` (**mặc định**) | không biết → giữ nguyên trạng thái cũ | gần như không bao giờ là thứ bạn muốn |
| `notBreaching` | tốt | số đo *thưa thớt* nhưng hệ thống *chắc chắn còn sống* |
| `breaching` | xấu | khi im lặng chính là triệu chứng (heartbeat, cron job) |
| `ignore` | giữ nguyên trạng thái trước đó | khi bạn muốn cảnh báo "dính" cho tới khi có dữ liệu mới |

Bẫy phải nhớ: bạn vừa chọn `notBreaching` để cảnh báo im lặng lúc khoẻ. Nhưng
nếu dịch vụ **chết hẳn**, không còn dòng log nào, thì số đo cũng thiếu dữ liệu —
và `notBreaching` sẽ nói "vẫn tốt". Cảnh báo "có lỗi" không bao giờ thay được
cảnh báo "không còn lưu lượng". Trong production bạn cần cả hai, và ghép chúng
bằng **composite alarm** để không bị đánh thức hai lần cho cùng một sự cố.

---

## Ba cách khác để giải bài này

### Cách A — dùng số đo có sẵn của dịch vụ thay vì tự sinh từ log

Lambda đã tự phát ra `Invocations`, `Errors`, `Duration`, `Throttles` trong
namespace `AWS/Lambda`. Đặt cảnh báo thẳng lên `Errors`, khỏi metric filter.

**Tốt hơn khi:** bạn muốn **không tốn công và không tốn tiền** — số đo dựng sẵn
của dịch vụ AWS **miễn phí**, không tính vào hạn mức 10 custom metric; nó có
ngay lập tức, không phụ thuộc định dạng log; và nó bắt được cả những lỗi mà code
**không kịp ghi log**: hết bộ nhớ, timeout, lỗi khởi tạo, bị throttle.

**Tệ hơn khi:** — và đây là bài này — nó chỉ biết **lỗi runtime**, không biết
**lỗi nghiệp vụ**. Một hàm trả về HTTP 200 kèm thân `{"trang_thai":"tu_choi_the"}`
là thành công hoàn hảo dưới mắt `AWS/Lambda Errors`. Mọi thứ ứng dụng *biết là
sai* mà vẫn kết thúc êm đẹp đều vô hình ở tầng này.

**Đề thi hỏi thế nào:** từ khoá `application-specific error`, `custom business
metric`, `without modifying application code` (mà log đã có sẵn) → metric filter.
Từ khoá `function errors`, `throttling`, `minimal effort` → số đo dựng sẵn.
Và câu trả lời đúng trong đời thật là **cả hai**: số đo dựng sẵn bắt lỗi hạ tầng,
metric filter bắt lỗi nghiệp vụ. Chúng không thay thế nhau — đây chính là câu
hỏi tự vấn thứ hai mà `verify.sh` in ra khi xanh.

### Cách B — code tự đẩy số đo lên, bằng `PutMetricData` hoặc EMF

Ứng dụng gọi thẳng API để ghi số đo, hoặc in log theo Embedded Metric Format và
để CloudWatch tự trích.

**Tốt hơn khi:** bạn cần số đo **có nhiều chiều** (mã khách hàng, loại giao dịch,
mã vùng) mà mẫu lọc log không tách nổi; cần **độ chính xác cao hơn** hoặc thống
kê phân vị; cần số đo xuất hiện **ngay** thay vì chờ 1–2 phút. EMF là lựa chọn
tốt nhất trong nhóm này vì nó **không thêm lệnh gọi mạng** — chỉ in ra log rồi
CloudWatch trích, tức là bạn có số đo với chi phí của một dòng log.

**Tệ hơn khi:** — `PutMetricData` thêm một lệnh gọi mạng **trên đường xử lý**:
chậm hơn, có thể lỗi, và khi CloudWatch bị throttle thì bạn mất số liệu đúng lúc
cần nhất. Nó cũng tính tiền theo lệnh gọi ($0,01/1000). Và cả hai đường đều buộc
bạn **sửa code** — nếu ứng dụng là của bên thứ ba thì hết cửa.

**Cái bẫy tiền phải nhớ ở cả nhóm này:** mỗi **tổ hợp dimension khác nhau** là
một số đo riêng, $0,30/tháng. Đưa `ma_yeu_cau` vào dimension nghe rất tiện lúc
debug — và nó sinh ra một số đo mới cho **mỗi request**. Vài triệu request là
vài triệu số đo. Đây là cách hoá đơn CloudWatch nổ, và đề thi có hỏi dưới dạng
"chi phí giám sát tăng bất thường, nguyên nhân nào có khả năng nhất".

### Cách C — đẩy log ra khỏi CloudWatch, phân tích ở nơi khác

Subscription filter trên log group → Firehose → S3, rồi truy vấn bằng Athena;
hoặc đẩy sang OpenSearch, Splunk, Datadog.

**Tốt hơn khi:** bạn cần **giữ log nhiều tháng hoặc nhiều năm** — S3 rẻ hơn
CloudWatch Logs hàng chục lần cho lưu trữ dài hạn, và có lifecycle xuống Glacier;
cần **gộp log của nhiều account, nhiều region** vào một chỗ; cần **tương quan
log với dữ liệu khác** bằng SQL; hoặc đội đã có sẵn một nền tảng quan sát và
không muốn nuôi hai nơi.

**Tệ hơn khi:** — bài này — bạn thêm một đường ống phải vận hành, thêm độ trễ,
và **mất khả năng cảnh báo gần thời gian thực** trừ khi dựng thêm. Với vài KB log
và một cảnh báo, đây là kiến trúc lớn hơn vấn đề vài bậc.

**Đề thi hỏi thế nào:** từ khoá `retain logs for 7 years`, `lowest storage cost`,
`query with SQL`, `centralize across accounts` → đẩy sang S3/Firehose. Từ khoá
`alert within minutes`, `operational monitoring` → giữ trong CloudWatch.
Lưu ý hàng rào của bộ lab chặn `kinesis:CreateStream` (shard provisioned
~$11/tháng mỗi shard) nhưng **không** chặn Firehose — Firehose tính theo lượng
dữ liệu, không có phí đứng yên. Sự khác nhau đó chính là câu hỏi Domain 4.

### Ghi chú riêng: khoá state — hai cách, và cách bạn vừa dùng đã có người kế nhiệm

| | Bảng khoá riêng (bạn vừa làm) | Khoá bằng file trong chính kho state |
|---|---|---|
| Cần thêm tài nguyên | có, một bảng | không |
| Terraform tối thiểu | mọi phiên bản | **1.10 trở lên** (`use_lockfile = true`) |
| Chi phí | ~$0 ở quy mô lab, nhưng là một thứ nữa phải nuôi | $0 |
| Quan sát từ ngoài | có — `verify.sh` chấm được | khó, khoá chỉ tồn tại trong lúc chạy |
| Trạng thái | vẫn dùng được, đang trên đường nghỉ hưu | hướng khuyến nghị cho thiết kế mới |

Lab chấm cách cũ vì nó **nhìn thấy được qua AWS API** — và luật của bộ lab này
là `verify.sh` không đọc file `.tf` của bạn. Trong dự án thật hôm nay, nếu
Terraform của bạn ≥ 1.10 thì `use_lockfile` là lựa chọn gọn hơn.

Điều **không** đổi giữa hai cách, và đó mới là phần đề thi hỏi: state chứa
**toàn bộ** thuộc tính của mọi tài nguyên, kể cả những giá trị nhạy cảm mà bạn
tưởng là bí mật. Vì vậy kho state phải mã hoá, chặn public, và bật versioning —
versioning ở đây không phải để đẹp, mà là **cách duy nhất** cứu bạn khi một lần
`apply` hỏng làm state sai lệch.

---

## Nếu đề thi hỏi

<details><summary>Câu 1. Một cảnh báo được đặt trên số đo đếm lỗi sinh từ log. Ứng dụng ngừng hoạt động hoàn toàn: không có request nào, không có dòng log nào. Cảnh báo đang cấu hình `treat_missing_data = notBreaching`. Chuyện gì xảy ra?</summary>

**A.** Cảnh báo chuyển sang `ALARM` vì không có dữ liệu.
**B.** Cảnh báo giữ nguyên `OK` — sự cố hoàn toàn im lặng.
**C.** Cảnh báo chuyển sang `INSUFFICIENT_DATA` và gửi thông báo.
**D.** Cảnh báo tự động chuyển sang đo số đo khác.

**Đáp án: B.** Và đây là loại sự cố tệ nhất: hệ thống chết, dashboard xanh.

- **A sai** — `notBreaching` nghĩa là *coi thiếu dữ liệu như trong ngưỡng*.
- **C sai** — `INSUFFICIENT_DATA` chỉ xảy ra khi `treat_missing_data = missing`.
  Và mặc định thì CloudWatch **không** gửi thông báo cho chuyển đổi sang trạng
  thái đó trừ khi bạn khai `insufficient_data_actions`.
- **D sai** — không có cơ chế nào như vậy.

Cách sửa đúng: thêm một cảnh báo trên số đo **lưu lượng** (ví dụ `Invocations`)
với điều kiện "nhỏ hơn ngưỡng" và `treat_missing_data = breaching`. Đây là mẫu
**dead man's switch**, và nó là một trong những thứ hay bị hỏi nhất trong Domain 2.

</details>

<details><summary>Câu 2. Hoá đơn CloudWatch của một đội tăng từ $12 lên $900/tháng sau khi họ thêm giám sát cho một API mới. Lượng request không đổi đáng kể. Nguyên nhân nào có khả năng nhất?</summary>

**A.** Họ bật Logs Insights.
**B.** Họ đưa một giá trị có độ phân tán cao (như mã request hoặc mã người dùng) vào làm dimension của custom metric.
**C.** Họ tăng hạn giữ log từ 7 lên 30 ngày.
**D.** Họ thêm một dashboard.

**Đáp án: B.** Mỗi **tổ hợp dimension** là một số đo riêng, $0,30/tháng. Vài
nghìn người dùng là vài nghìn số đo. Đây là cách hoá đơn CloudWatch nổ, và nó
xảy ra thường xuyên trong đời thật.

- **A sai** — Logs Insights tính $0,005/GB **quét**. Phải quét 180 TB mới ra
  $900.
- **C sai** — lưu trữ log là $0,03/GB-tháng. Nhân thêm hơn bốn lần thời gian giữ
  vẫn là con số nhỏ trừ khi họ nạp vào hàng TB.
- **D sai** — 3 dashboard đầu miễn phí, sau đó $3/dashboard/tháng.

Quy tắc thực dụng: **dimension là để nhóm, không phải để định danh.** Cần định
danh từng request thì đó là việc của **log** và **trace**, không phải của metric.

</details>

<details><summary>Câu 3. Đội vận hành cần biết chính xác "ai đã xoá bảng dữ liệu lúc 3 giờ sáng". Họ đang có CloudWatch alarm, dashboard và log của ứng dụng. Cần thêm gì?</summary>

**A.** Bật CloudWatch Logs Insights trên log group của ứng dụng.
**B.** Bật CloudTrail và tra sự kiện `DeleteTable` cùng `userIdentity`.
**C.** Bật X-Ray tracing.
**D.** Bật AWS Config.

**Đáp án: B.** CloudTrail ghi lại **ai gọi API nào, lúc nào, từ đâu**. Đó đúng là
câu hỏi được hỏi. Trail quản trị (management events) mặc định lưu 90 ngày trong
Event history, và cần một trail để lưu lâu hơn.

- **A sai** — log ứng dụng chỉ chứa những gì ứng dụng tự ghi. Một người vào
  console xoá bảng không để lại dòng nào trong đó.
- **C sai** — X-Ray theo dõi **một request đi qua các dịch vụ**, để tìm chỗ chậm
  và chỗ lỗi. Nó không phải sổ cái kiểm toán.
- **D sai** — Config trả lời "**cấu hình** đã thay đổi thế nào theo thời gian" và
  "tài nguyên có tuân thủ quy tắc không". Nó cho biết bảng đã biến mất, nhưng
  không nói ai làm — muốn biết ai thì vẫn phải sang CloudTrail.

Phân biệt bốn công cụ này là một trục hỏi cố định: **CloudWatch** = số đo và log
vận hành. **CloudTrail** = ai gọi API. **Config** = cấu hình thay đổi và tuân
thủ. **X-Ray** = đường đi của một request.

</details>

<details><summary>Câu 4. Một cảnh báo trên `CPUUtilization` của EC2 luôn ở `OK` trong khi ứng dụng bị hết bộ nhớ và chết liên tục. Vì sao?</summary>

**A.** Chu kỳ đánh giá quá dài.
**B.** CloudWatch không có số đo bộ nhớ cho EC2 nếu không cài agent.
**C.** Cần đặt `treat_missing_data = breaching`.
**D.** Cảnh báo phải dùng thống kê `Maximum` thay vì `Average`.

**Đáp án: B.** Đây là bẫy kinh điển nhất của cả bài. CloudWatch nhìn EC2 **từ
phía hypervisor**, nên nó thấy CPU, mạng, đĩa ở mức thiết bị — nhưng **không**
thấy bộ nhớ đã dùng, dung lượng đĩa còn trống ở mức filesystem, hay tiến trình
nào đang chạy. Ba thứ đó nằm *bên trong* hệ điều hành, và muốn có thì phải cài
**CloudWatch Agent**.

- **A, C, D sai** — cả ba đều nói về cách cấu hình một cảnh báo trên một số đo
  đã tồn tại. Vấn đề ở đây là số đo **không tồn tại**.

Ba thứ phải thuộc: **memory, disk space (mức filesystem), và tiến trình** không
có sẵn cho EC2. Với Lambda và RDS thì bộ nhớ có sẵn — vì AWS quản lý cả tầng
trong đó.

</details>

<details><summary>Câu 5. Hai kỹ sư chạy `terraform apply` cách nhau 3 giây trên cùng một hạ tầng, dùng chung một nơi lưu state nhưng KHÔNG có cơ chế khoá. Hậu quả xấu nhất là gì?</summary>

**A.** Người thứ hai nhận lỗi và phải chạy lại.
**B.** State bị ghi đè, một số tài nguyên biến thành "mồ côi": tồn tại thật trên AWS nhưng không còn trong state, nên Terraform không quản lý và cũng không xoá được.
**C.** Terraform tự động gộp hai thay đổi.
**D.** Không có gì xảy ra, S3 tự xử lý xung đột.

**Đáp án: B.** Đây là lý do state locking tồn tại. Hai tiến trình đọc cùng một
state cũ, mỗi bên tạo tài nguyên của mình, rồi bên ghi sau **ghi đè** state của
bên ghi trước. Tài nguyên của bên ghi trước vẫn chạy, vẫn tính tiền, và không
`terraform destroy` nào tìm thấy chúng.

- **A sai** — đó là kết quả khi **có** khoá. Đề nói không có.
- **C sai** — Terraform không có cơ chế merge state.
- **D sai** — S3 đảm bảo *ghi cuối cùng thắng*, chính là cơ chế gây ra vấn đề này.

Và đây là lý do **versioning** trên kho state không phải trang trí: nó là đường
lùi duy nhất khi chuyện này xảy ra.

</details>

<details><summary>Câu 6. Đội trực phàn nàn bị đánh thức 40 lần mỗi đêm bởi các cảnh báo lẻ, trong khi phần lớn là cùng một sự cố gốc. Cách cải thiện nào phù hợp NHẤT?</summary>

**A.** Tăng ngưỡng của mọi cảnh báo lên gấp đôi.
**B.** Gộp các cảnh báo liên quan bằng composite alarm, chỉ báo động khi tổ hợp điều kiện cùng đúng.
**C.** Tắt bớt cảnh báo.
**D.** Chuyển tất cả cảnh báo sang gửi email thay vì SMS.

**Đáp án: B.** **Composite alarm** kết hợp trạng thái của nhiều cảnh báo con bằng
biểu thức logic (`ALARM(a) AND ALARM(b)`), và chỉ nó mới gửi thông báo. Các cảnh
báo con vẫn tồn tại để chẩn đoán, nhưng không đánh thức ai.

- **A sai** — cảnh báo sẽ kêu ít hơn, nhưng cũng bỏ sót sự cố thật. Đó là đổi
  một loại lỗi lấy một loại lỗi tệ hơn.
- **C sai** — cùng vấn đề, và tệ hơn vì mất hẳn khả năng phát hiện.
- **D sai** — chỉ đổi kênh, không đổi số lượng. Người trực vẫn nhận 40 thông báo.

"Alarm fatigue" là một khái niệm được hỏi thẳng: một cảnh báo mà người ta học
cách phớt lờ thì tệ hơn không có cảnh báo, vì nó tạo cảm giác an toàn giả.

</details>

---

## Chỗ dễ hiểu sai

**"verify.sh xanh nghĩa là hệ thống của tôi quan sát được."**
Nó nghĩa là bạn đo được **một** thứ và báo động được **một** kiểu. Bốn khoảng
trống, và cả bốn đều là chuyện production:

- **Bạn chỉ có metric và log, chưa có trace.** Khi một request đi qua năm dịch
  vụ và chậm, metric nói "chậm", log nói "cái này chậm", nhưng chỉ **trace** nói
  "chậm ở chặng nào". Ba trụ cột của observability là metric, log, trace — bạn
  vừa dựng hai. Cái thứ ba là X-Ray.

- **Trung bình là con số dối trá.** Cảnh báo của bạn đếm số lỗi, nên nó không
  dính bẫy này — nhưng cảnh báo về **độ trễ** thì có. Trung bình 200 ms có thể
  che giấu việc 1% người dùng chờ 9 giây. Số phải nhìn là **p99**, và CloudWatch
  hỗ trợ phân vị sẵn. Trong đời thật, "trung bình đẹp mà khách hàng vẫn kêu" là
  triệu chứng gần như luôn chỉ về đuôi phân bố.

- **Cảnh báo chưa từng kêu là cảnh báo chưa được kiểm chứng.** Bạn vừa được
  `verify.sh` ép thử một lần. Trong production, một cảnh báo được viết ba năm
  trước và chưa kêu bao giờ thì **không ai biết** nó còn hoạt động không: số đo
  có thể đã đổi tên, subscription có thể đã bị huỷ, đích thông báo có thể đã
  chết. Đội trưởng thành thì diễn tập định kỳ — cố tình gây lỗi trong môi trường
  kiểm thử và xem có ai được đánh thức không. Đó đúng là việc `verify.sh` vừa làm.

- **Bí mật trong state.** State của bạn giờ nằm trong S3, mã hoá, chặn public.
  Tốt. Nhưng bất kỳ ai có quyền đọc bucket đó đều đọc được **mọi** giá trị trong
  hạ tầng của bạn ở dạng thô. Quyền đọc kho state phải được coi ngang với quyền
  admin lên hạ tầng — đây là điều rất nhiều đội bỏ sót, và nó nối thẳng với bài
  tuần 9.

**Một chỗ nữa: `evaluation_periods` không phải `datapoints_to_alarm`.**
`evaluation_periods = 5` với `datapoints_to_alarm = 3` nghĩa là "**3 trong 5**
chu kỳ gần nhất vượt ngưỡng thì kêu" — đây là mẫu **M trong N**, dùng để chịu
được nhiễu thoáng qua mà vẫn phát hiện sự cố kéo dài. Đặt hai số bằng nhau (như
lab này) nghĩa là "phải liên tiếp". Đề thi hỏi sự khác nhau đó dưới dạng "cảnh
báo kêu quá nhạy / quá chậm, sửa tham số nào".
