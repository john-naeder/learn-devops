# Đối chiếu — tuần 12

> Đọc file này **sau khi** `./verify.sh` xanh hết. Đọc trước là tự lấy mất bài học.
>
> Đây là file cuối cùng của mười hai tuần. Nó có hai việc: nối buổi lab hôm nay
> với lý thuyết như mười một file trước, và **nối cả mười hai tuần lại thành một
> bản đồ** để bạn dùng trong 48 giờ cuối.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong lab | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 1. Kho tính tiền theo lượt dùng | **on-demand vs provisioned capacity** — trục chi phí mà IAM không nhìn thấy | [`03-database.md`](../../../docs/notebook/03-database.md) · [`10-chi-phi.md`](../../../docs/notebook/10-chi-phi.md) |
| 1. Hai đường tra khác nhau | **partition key / sort key**, **global secondary index**, single-table design | [`03-database.md`](../../../docs/notebook/03-database.md) · [`12-hieu-nang.md`](../../../docs/notebook/12-hieu-nang.md) |
| 2. Bảng so sánh có cột từ khoá | chính là kỹ năng **dịch từ đề sang dịch vụ** | [`21-tu-khoa-de-thi.md`](../../../docs/notebook/21-tu-khoa-de-thi.md) · [`22-bang-so-sanh.md`](../../../docs/notebook/22-bang-so-sanh.md) |
| 3. Ba lý do loại cho ba phương án sai | **kỹ thuật loại trừ** — thứ quyết định điểm khi còn hai đáp án | [`docs/aws/w12`](../../../docs/aws/w12-exam-review.md) mục "Kỹ thuật loại trừ đáp án" |
| 4. Trọng số bốn miền | chiến thuật ôn tập theo **exam guide** | [`docs/aws/w12`](../../../docs/aws/w12-exam-review.md) mục 1 |
| 5–6. Giám khảo đọc kho, bốc đề | **Lambda + DynamoDB**, event-driven, IAM tối thiểu quyền | [`01-compute.md`](../../../docs/notebook/01-compute.md) · [`06-tich-hop.md`](../../../docs/notebook/06-tich-hop.md) |
| 7. Trần quyền cho danh tính giám khảo | **permissions boundary**, least privilege, ARN của index là tài nguyên riêng | [`05-security.md`](../../../docs/notebook/05-security.md) · [`22-bang-so-sanh.md`](../../../docs/notebook/22-bang-so-sanh.md#scp--iam-policy--permission-boundary) |
| 8. Không gì tính tiền theo giờ | phân biệt **tính theo giờ** với **tính theo lượt dùng** | [`10-chi-phi.md`](../../../docs/notebook/10-chi-phi.md) |
| `ScannedCount` khác `Count` | **Query vs Scan**, và vì sao "ra đúng kết quả" chưa đủ | [`03-database.md`](../../../docs/notebook/03-database.md) · [`12-hieu-nang.md`](../../../docs/notebook/12-hieu-nang.md) |

### Ba con số của một truy vấn, và vì sao đề thi chỉ hỏi con số thứ ba

| | Nghĩa là | Đề thi hỏi |
|---|---|---|
| `Count` | bao nhiêu item **trả về cho bạn** | hầu như không bao giờ |
| `ScannedCount` | bao nhiêu item DynamoDB **đọc lên rồi mới lọc** | gián tiếp, qua chữ *cost* và *performance* |
| Khoảng cách giữa hai số | **tiền bạn trả cho dữ liệu bạn vứt đi** | đây mới là câu hỏi |

`verify.sh` chấm đúng khoảng cách đó, và đó là lý do một lời giải "quét hết rồi
lọc" **ra đúng kết quả nhưng vẫn đỏ**. Trong bài thi, chuyện y hệt: bốn đáp án
thường có hai đáp án cho ra kết quả đúng, và câu hỏi luôn là *"cái nào tốt nhất"*.

---

## Ba cách khác để giải bài này

### Cách A — không dùng hạ tầng gì cả: viết ra file Markdown, hoặc bộ thẻ Anki

Mười bảng và hai mươi câu hoàn toàn nằm vừa trong một file văn bản, hoặc một bộ
thẻ trong công cụ lặp lại ngắt quãng.

**Tốt hơn khi:** — và với **mục đích ôn thi thuần tuý thì đây thật sự tốt hơn.**
Nói thẳng ra: bộ thẻ Anki đánh bại lab này ở đúng thứ quan trọng nhất, vì nó có
**lặp lại ngắt quãng** — thuật toán đưa lại đúng thẻ bạn sắp quên. Nó không tốn
một xu, không cần mạng, và bạn mở được nó trên điện thoại lúc xếp hàng.

**Tệ hơn khi:** file Markdown không ép bạn vào **schema**. Và schema mới là thứ
làm lộ chỗ bạn nhớ mơ hồ: viết "SQS thì bền hơn" vào Markdown thì trôi qua; điền
nó vào một trường bắt buộc tên `tu_khoa_de` cho **từng** lựa chọn thì bạn phải
dừng lại và nghĩ *đề dùng chữ gì để trỏ về SQS chứ không phải Kinesis*.

**Đề thi hỏi thế nào:** không hỏi. Nhưng nó dạy bạn một điều SAA hỏi liên tục:
**cấu trúc dữ liệu là một dạng ràng buộc**, và ràng buộc đặt đúng chỗ thì bắt lỗi
sớm hơn mọi quy trình. Đó là lý do người ta chọn schema chặt cho dữ liệu quan
trọng, dù schema lỏng "linh hoạt hơn".

### Cách B — mỗi loại một kho riêng, thay vì một kho có tiền tố khoá

Một kho cho bảng so sánh, một kho cho câu hỏi. Không cần `phan_loai`, không cần
tiền tố `bang#`/`cauhoi#`.

**Tốt hơn khi:** dễ hiểu hơn nhiều, và ở quy mô này thì **không sai**. Mỗi kho có
sơ đồ khoá riêng, quyền riêng, hạn giữ riêng, và bạn xoá được một loại mà không
đụng loại kia. Với đội nhiều người, ranh giới rõ ràng thường đáng giá hơn một
lần đọc tiết kiệm.

**Tệ hơn khi:** bạn cần lấy **nhiều loại item liên quan nhau trong một lần đọc** —
ví dụ "cho tôi câu hỏi này **cùng với** bảng so sánh của nó". Hai kho nghĩa là
hai lần gọi mạng, và không có giao dịch nào bao được cả hai một cách rẻ. Đó
chính là lý do **single-table design** tồn tại: gom các item hay đi cùng nhau vào
cùng một partition để một lần Query lấy hết.

**Đề thi hỏi thế nào:** SAA-C03 **không** hỏi sâu về single-table design — đó là
đất của kỳ thi Developer và của thực tế. Thứ SAA hỏi là tầng trên nó: *"ứng dụng
cần truy vấn theo một thuộc tính không phải khoá chính, làm sao?"* → **secondary
index**, không phải Scan. Nhận ra được câu đó là đủ điểm.

### Cách C — dùng một cơ sở dữ liệu quan hệ, hoặc để file trên S3 rồi truy vấn bằng SQL

Ngân hàng câu hỏi là dữ liệu có quan hệ rõ ràng (một bảng, nhiều câu hỏi trỏ về
nó). Một cơ sở dữ liệu quan hệ mô tả nó tự nhiên hơn hẳn.

**Tốt hơn khi:** bạn cần **truy vấn linh hoạt, không biết trước** — "câu hỏi nào
thuộc miền D1 **và** liên quan tới bảng có chữ *endpoint* **và** tôi từng trả lời
sai", `JOIN` giữa nhiều thực thể, hay báo cáo tổng hợp. DynamoDB bắt bạn **biết
trước** cách truy vấn ngay từ lúc thiết kế khoá; cơ sở dữ liệu quan hệ thì không.
Nếu bạn định phân tích lịch sử làm bài của mình thì đây là đường đúng.

**Tệ hơn khi:** — bài này — mọi động cơ quan hệ dành cho SAA đều tính tiền **theo
giờ instance**, và điều đó phá thẳng trần $0,00/giờ. Kể cả bản serverless cũng
tính theo đơn vị năng lực theo giây và có sàn tối thiểu. Còn để file trên S3 rồi
truy vấn bằng SQL thì tính $5/TB quét — rẻ tuyệt đối, nhưng nó là công cụ **phân
tích theo lô**, độ trễ vài giây, không hợp cho một giám khảo trả lời từng câu.

**Đề thi hỏi thế nào:** đây là một trục hỏi cố định. Từ khoá `flexible queries`,
`complex joins`, `ad-hoc reporting`, `existing SQL application` → quan hệ. Từ khoá
`single-digit millisecond`, `key-value`, `unpredictable traffic`, `serverless`,
`no capacity planning` → DynamoDB. Từ khoá `query data in S3 directly`,
`no infrastructure to manage`, `pay per query` → Athena.

---

## Nếu đề thi hỏi

<details><summary>Câu 1. Ứng dụng lưu 50 triệu item trong một bảng DynamoDB, khoá chính là <code>orderId</code>. Đội vừa nhận yêu cầu mới: hiển thị mọi đơn hàng của một <code>customerId</code>. Hiện tại họ đang dùng Scan kèm filter và trang này mất 40 giây. Cách sửa nào TỐT NHẤT?</summary>

**A.** Tăng dung lượng đọc đã đặt trước của bảng.
**B.** Tạo một global secondary index với khoá phân vùng là `customerId`, rồi Query trên index đó.
**C.** Bật DAX để cache kết quả Scan.
**D.** Chuyển bảng sang chế độ on-demand.

**Đáp án: B.** Scan đọc **toàn bộ** bảng rồi mới bỏ đi phần không khớp — bạn trả
tiền cho 50 triệu item để lấy về vài chục. Filter chạy **sau** khi đã đọc và đã
tính tiền. GSI cho phép Query đúng theo `customerId`, chỉ đọc những item khớp.

- **A sai** — nhanh hơn chút vì bớt bị throttle, nhưng vẫn đọc 50 triệu item mỗi
  lần và tiền tăng theo. Đây là đáp án "ném tiền vào một thiết kế sai".
- **C sai** — DAX cache kết quả, nên **lần đầu vẫn 40 giây** và mọi khách hàng
  khác nhau đều là cache miss. Cache che triệu chứng, không sửa nguyên nhân.
- **D sai** — on-demand đổi **cách tính tiền**, không đổi **lượng dữ liệu phải
  đọc**. Nó thậm chí làm hoá đơn tệ hơn cho một Scan lặp lại.

Đây chính là check "đường truy vấn RẺ hơn đường quét" mà `verify.sh` vừa chấm
bạn. Từ khoá nhận diện: `query by an attribute that is not the primary key`.

</details>

<details><summary>Câu 2. Một bảng DynamoDB phục vụ ứng dụng có lưu lượng cực khó đoán: im lặng nhiều ngày, rồi bùng lên gấp 40 lần trong vài giờ khi có chiến dịch marketing. Đội không muốn quản lý dung lượng. Lựa chọn nào phù hợp NHẤT?</summary>

**A.** Provisioned capacity đặt theo mức đỉnh.
**B.** Provisioned capacity kèm auto scaling.
**C.** On-demand capacity mode.
**D.** Provisioned capacity đặt theo mức trung bình, chấp nhận throttle lúc đỉnh.

**Đáp án: C.** On-demand tính tiền **theo từng request**, không có gì để đặt
trước, và nó hấp thụ được đỉnh tăng đột ngột mà không cần ai làm gì.

- **A sai** — trả tiền cho mức đỉnh **24/7** trong khi phần lớn thời gian không
  dùng. Đây là dạng lãng phí Domain 4 hỏi nhiều nhất.
- **B sai** — nghe hợp lý và là **bẫy chính của câu này**. Auto scaling của
  DynamoDB phản ứng theo CloudWatch alarm, nên nó mất **vài phút** để bắt kịp;
  một cú tăng gấp 40 lần trong vài giây sẽ bị throttle trong lúc chờ. Nó tốt cho
  lưu lượng biến động **có thể đoán được**, không tốt cho cú sốc.
- **D sai** — throttle là mất giao dịch đúng lúc chiến dịch đang chạy.

Con số nên thuộc để chốt hướng ngược lại: on-demand đắt hơn provisioned khoảng
**7 lần** cho mỗi request, nên nếu tải **ổn định** và bạn dùng được hơn khoảng
**15%** dung lượng đặt trước thì provisioned rẻ hơn. Đề dùng chữ `steady`,
`predictable` → provisioned; `unpredictable`, `spiky`, `new application` → on-demand.

</details>

<details><summary>Câu 3. Một bảng DynamoDB đã chạy trong production hai năm. Đội cần thêm một cách truy vấn mới theo một thuộc tính không phải khoá, và cách truy vấn đó BẮT BUỘC phải đọc nhất quán mạnh (strongly consistent). Điều gì đúng?</summary>

**A.** Tạo một local secondary index trên bảng hiện có.
**B.** Tạo một global secondary index và bật đọc nhất quán mạnh trên nó.
**C.** LSI không thêm được vào bảng đã tồn tại; GSI thêm được nhưng chỉ đọc nhất quán cuối cùng — nên phải tạo bảng mới hoặc đổi yêu cầu.
**D.** Bật DynamoDB Streams rồi đọc từ đó.

**Đáp án: C.** Hai ràng buộc va vào nhau, và đề cố tình dựng ra thế:
**LSI chỉ tạo được lúc tạo bảng** và không xoá được sau đó; **GSI thêm/xoá được
bất cứ lúc nào nhưng luôn đọc nhất quán cuối cùng**.

- **A sai** — LSI không thêm được vào bảng đã tồn tại. Đây là chi tiết bị hỏi
  thẳng.
- **B sai** — GSI **không** hỗ trợ strongly consistent read, bật cũng không được.
  Nó có một bản sao riêng, được cập nhật bất đồng bộ.
- **D sai** — Streams là dòng thay đổi để kích hoạt xử lý, không phải một đường
  truy vấn.

Ba khác biệt phải thuộc: **LSI** dùng chung khoá phân vùng với bảng, tạo cùng lúc
với bảng, đọc mạnh được, giới hạn 10 GB cho mỗi giá trị khoá phân vùng.
**GSI** có khoá phân vùng riêng, thêm bất cứ lúc nào, chỉ đọc nhất quán cuối
cùng, không có giới hạn 10 GB. Bạn vừa dùng GSI trong lab — và `mien` chính là
một khoá phân vùng khác hẳn khoá của kho.

</details>

<details><summary>Câu 4. Một công ty cho đội phát triển tự tạo IAM role để gắn vào Lambda của họ. Yêu cầu: dù đội viết policy thế nào, role họ tạo ra cũng KHÔNG được có quyền vượt quá một tập cho trước. Cơ chế nào phù hợp NHẤT?</summary>

**A.** Service control policy áp lên account.
**B.** Permissions boundary bắt buộc, cưỡng chế bằng một điều kiện trong policy của người tạo role.
**C.** Session policy truyền lúc AssumeRole.
**D.** Một IAM policy chỉ đọc gắn thêm vào từng role.

**Đáp án: B.** Permissions boundary đặt **trần** cho một danh tính: quyền hiệu lực
là **giao** của policy được gắn và boundary. Và mảnh ghép thứ hai của câu này —
mảnh hay bị bỏ sót — là **cưỡng chế**: bạn dùng điều kiện `iam:PermissionsBoundary`
trên quyền `iam:CreateRole` để đội **không tạo nổi** một role thiếu boundary. Đó
đúng là thứ chặn bạn ở `terraform apply` của lab này.

- **A sai** — SCP là công cụ của Organizations, áp cho **cả account** hoặc OU, kể
  cả những danh tính không liên quan. Nó không nhắm được vào "những role đội này
  tự tạo", và nó không phải cơ chế uỷ quyền có kiểm soát.
- **C sai** — session policy chỉ sống trong **một phiên** và do người gọi
  AssumeRole truyền vào. Nó không ràng buộc được role đội tạo ra sau này.
- **D sai** — gắn thêm policy chỉ **cộng thêm** quyền. Không có Deny thì nó không
  đặt trần được gì, và đội vẫn gắn thêm policy khác.

Ba thứ hay bị trộn lẫn: **SCP** = trần cho cả account/OU. **Permissions boundary**
= trần cho một danh tính, dùng khi **uỷ quyền tạo danh tính**. **Session policy**
= trần cho một phiên. Cả ba đều **không cấp quyền**, chỉ giới hạn.

</details>

<details><summary>Câu 5. Một hàm Lambda đọc dữ liệu qua một global secondary index của bảng DynamoDB. Policy của role thực thi cho phép <code>dynamodb:Query</code> trên ARN của bảng. Hàm chạy được với Query thường nhưng báo AccessDenied khi Query trên index. Nguyên nhân?</summary>

**A.** Index cần một role riêng.
**B.** ARN của index là một tài nguyên riêng (`<arn-bảng>/index/<tên>`) và phải được nêu trong policy.
**C.** Lambda cần bật VPC endpoint cho DynamoDB.
**D.** GSI không hỗ trợ truy cập bằng IAM role.

**Đáp án: B.** Trong IAM, `arn:aws:dynamodb:...:table/T` và
`arn:aws:dynamodb:...:table/T/index/I` là **hai tài nguyên khác nhau**. Cấp quyền
trên cái thứ nhất không tự động cấp trên cái thứ hai.

- **A sai** — không có khái niệm role riêng cho index.
- **C sai** — VPC endpoint là chuyện đường mạng, và AccessDenied ở đây là quyết
  định của IAM, không phải lỗi kết nối. Phân biệt được hai loại lỗi này là kỹ
  năng gỡ rối cốt lõi: **AccessDenied = uỷ quyền; timeout = mạng.**
- **D sai** — GSI truy cập bằng IAM bình thường.

Mẹo viết policy đúng ngay lần đầu: nêu cả `table/T` và `table/T/index/*`. Đây
đúng là hai check "giám khảo ĐỌC được kho" và "giám khảo ĐỌC được đường vào thứ
hai" trong `verify.sh`.

</details>

<details><summary>Câu 6. Một bảng DynamoDB chứa dữ liệu giao dịch. Yêu cầu: khôi phục được về BẤT KỲ thời điểm nào trong 35 ngày qua, sau một sự cố ứng dụng ghi đè dữ liệu sai. Chi phí phải thấp nhất có thể. Chọn gì?</summary>

**A.** Bật point-in-time recovery.
**B.** Lập lịch on-demand backup mỗi giờ.
**C.** Bật DynamoDB Streams và tự ghi lại mọi thay đổi vào S3.
**D.** Bật global tables sang một Region thứ hai.

**Đáp án: A.** PITR khôi phục về **bất kỳ giây nào** trong tối đa 35 ngày, bật
bằng một công tắc, và tính $0,20/GB-tháng theo kích thước bảng. Không có gì phải
lập lịch, không có gì phải vận hành.

- **B sai** — backup theo giờ cho RPO **một giờ**, không phải "bất kỳ thời điểm
  nào", và bạn phải nuôi một bộ lập lịch cùng chính sách dọn bản cũ.
- **C sai** — đúng về mặt kỹ thuật nhưng là **tự xây lại PITR**: thêm mã, thêm
  lỗi, thêm tiền. Đề dùng chữ `lowest operational overhead` để loại chính nó.
- **D sai** — global tables là **sao chép**, không phải sao lưu. Một lệnh ghi đè
  sai sẽ được sao chép sang Region kia trong vài giây. Nhầm replication với
  backup là một trong những nhầm lẫn bị hỏi nhiều nhất.

Nhớ cặp đối lập: **replication bảo vệ khỏi mất hạ tầng, backup bảo vệ khỏi mất
dữ liệu do con người.** Chúng không thay thế nhau.

</details>

---

## Chỗ dễ hiểu sai

**"verify.sh xanh nghĩa là tôi ôn xong."**
Không. Nó chứng minh ngân hàng của bạn **đủ hình thù**, không chứng minh nội dung
**đúng**. Máy đếm được 20 câu, đếm được ba lý do loại, đếm được trọng số — máy
không biết bạn có viết sai một lý do nào không. Bạn vừa vừa ra đề vừa đi thi, nên
tầng kiểm chứng cuối cùng là bên ngoài: đối chiếu bảng của bạn với
[`22-bang-so-sanh.md`](../../../docs/notebook/22-bang-so-sanh.md) **sau khi** đã
viết xong, và đối chiếu câu hỏi với một bộ đề thử của bên thứ ba. Chỗ hai bên
lệch nhau là chỗ đáng đọc nhất trong cả buổi.

**"Thiết kế của tôi chạy tốt, nên nó đúng."**
Ở 30 item thì **mọi** thiết kế đều chạy tốt, kể cả Scan. Ba thứ hỏng khi dữ liệu
lớn lên, và cả ba đều là câu hỏi Domain 3:

- **Hot partition.** Cả 10 bảng của bạn nằm chung một giá trị khoá phân vùng
  `BANG`. Ở quy mô lab thì không sao. Ở quy mô thật, một partition có trần thông
  lượng riêng, và mọi lưu lượng dồn vào một giá trị khoá là cách tạo ra nút thắt
  mà thêm dung lượng cũng không gỡ được. Khoá phân vùng tốt là khoá **phân tán
  đều**.
- **Trần 1 MB mỗi lần Query.** Query của bạn trả về hết 10 bảng trong một lần
  gọi. Với 200.000 bảng thì không, và code không xử lý `LastEvaluatedKey` sẽ
  **im lặng trả về thiếu** — không lỗi, không cảnh báo, chỉ thiếu.
- **GSI đọc nhất quán cuối cùng.** Nạp một câu hỏi rồi đếm ngay qua index có thể
  ra số cũ. Trong lab bạn không thấy vì `terraform apply` xong mới chạy verify.
  Trong production, "vừa ghi xong đọc lại không thấy" là một lớp bug rất khó tìm.

**"On-demand luôn rẻ hơn vì chỉ trả cho cái mình dùng."**
Sai, và đây là bẫy Domain 4 kinh điển. On-demand đắt hơn khoảng **7 lần** cho mỗi
request. Nó rẻ hơn khi tải **thưa hoặc khó đoán** — đúng như lab này. Với tải ổn
định dùng trên khoảng 15% dung lượng đặt trước, provisioned rẻ hơn nhiều, và
thêm reserved capacity còn rẻ nữa. **"Chỉ trả cho cái mình dùng" là một cách tính
tiền, không phải một lời hứa rẻ hơn.**

**"Trần quyền nghĩa là giám khảo an toàn."**
Trần quyền chặn nó làm **quá nhiều**. Nó không nói gì về việc bạn đã cấp **đúng
mức tối thiểu** hay chưa. `verify.sh` hỏi thêm hai câu phủ định (không ghi được,
không xoá được) đúng vì lý do đó — và ngay cả hai câu ấy cũng chỉ chạm vào một
góc. Trần quyền là **giới hạn trên**, least privilege là **kỷ luật của bạn**;
tầng nào cũng cần, và không tầng nào thay được tầng kia.

---

## Bản đồ mười hai tuần — dùng trong 48 giờ cuối

Bạn không đọc lại được 13.000 dòng sổ tay trong hai ngày. Đây là thứ tự đáng đọc,
xếp theo trọng số đề, và ba file cuối là ba file nên mở **trong lúc làm đề**:

| Đọc khi | File | Vì sao ưu tiên |
|---|---|---|
| **D1 · 30%** | [`05-security.md`](../../../docs/notebook/05-security.md) | miền nặng nhất, và là miền dễ ăn điểm nhất vì luật của nó xác định |
| **D2 · 26%** | [`11-san-sang-cao.md`](../../../docs/notebook/11-san-sang-cao.md) · [`13-khoi-phuc-tham-hoa.md`](../../../docs/notebook/13-khoi-phuc-tham-hoa.md) | RTO/RPO và Multi-AZ vs replica ra thi liên tục |
| **D3 · 24%** | [`12-hieu-nang.md`](../../../docs/notebook/12-hieu-nang.md) · [`04-networking.md`](../../../docs/notebook/04-networking.md) | phần lớn câu "cải thiện hiệu năng" là câu về cache và về đường mạng |
| **D4 · 20%** | [`10-chi-phi.md`](../../../docs/notebook/10-chi-phi.md) | miền nhỏ nhất nhưng dễ nhất — hầu hết là bảng giá và mô hình mua |
| Nền dịch vụ | [`00-nen-tang.md`](../../../docs/notebook/00-nen-tang.md) · [`01-compute.md`](../../../docs/notebook/01-compute.md) · [`02-storage.md`](../../../docs/notebook/02-storage.md) · [`03-database.md`](../../../docs/notebook/03-database.md) · [`06-tich-hop.md`](../../../docs/notebook/06-tich-hop.md) · [`07-quan-tri-giam-sat.md`](../../../docs/notebook/07-quan-tri-giam-sat.md) | mở đúng mục còn mờ, không đọc cả file |
| **Trong lúc làm đề** | [`21-tu-khoa-de-thi.md`](../../../docs/notebook/21-tu-khoa-de-thi.md) | dịch tiếng đề sang tên dịch vụ, và **bẫy từ khoá** |
| **Còn ba đáp án** | [`20-cay-quyet-dinh.md`](../../../docs/notebook/20-cay-quyet-dinh.md) | 14 cây quyết định, đi từ bài toán tới dịch vụ |
| **Còn hai đáp án** | [`22-bang-so-sanh.md`](../../../docs/notebook/22-bang-so-sanh.md) | cột cuối mỗi bảng là từ khoá phân biệt — đúng thứ bạn vừa tự viết |

Hai việc còn lại, theo đúng thứ tự:

1. **Xuất kho ôn tập ra tệp trước khi `terraform destroy`** (lệnh ở `README.md`
   mục "Dọn dẹp"). Ngày cuối, đọc chữ **của bạn**, không đọc lại sổ tay — thứ bạn
   tự sản xuất ra là thứ trí nhớ giữ chặt nhất.
2. Mở [`docs/aws/w12-exam-review.md`](../../../docs/aws/w12-exam-review.md) mục
   **"Checklist 48 giờ trước khi thi"** và làm theo. Nó nói về giấc ngủ, thứ tự
   làm bài và cách quản lý thời gian — ba thứ ảnh hưởng tới điểm số nhiều hơn bất
   kỳ dịch vụ nào bạn còn chưa thuộc.

Xong rồi. Mười hai tuần, mười hai lần ngồi trước một file trống. Thứ bạn mang đi
không phải mấy nghìn dòng Terraform — chúng đã bị `destroy` hết. Thứ bạn mang đi
là **thói quen hỏi "vì sao không phải ba cái kia"**, và đó cũng đúng là câu hỏi
duy nhất mà cả đề thi lẫn công việc thật sự hỏi bạn.
