# Gợi ý — tuần 5

> Bài này gần như không có Terraform. Nếu bạn đang bí, gần như chắc chắn bạn
> đang bí ở phần *vẽ khoá ra giấy*, không phải ở phần gõ HCL. Mở tầng 1 trước.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

**Bước 0 — trước khi mở editor, viết ba câu hỏi ra giấy.** Đúng nghĩa đen. Ba
màn hình trong đề bài là ba câu hỏi, và mỗi câu có dạng:

```
Cho <biết trước cái gì>, lấy về <cái gì>, sắp xếp theo <cái gì>.
```

Điền vào ba lần. Cột "biết trước cái gì" là cột quan trọng nhất của cả lab, và
nó là thứ quyết định khoá.

**Bước 1 — hiểu cái ràng buộc "đọc = trả về" thật sự nói gì.** Một kho dữ liệu
kiểu khoá–giá trị có hai cách lấy dữ liệu ra:

- Cách thứ nhất: *nhảy thẳng tới chỗ dữ liệu nằm*, vì bạn biết trước nó nằm ở
  đâu. Đọc bao nhiêu trả về bấy nhiêu.
- Cách thứ hai: *đi từ đầu bảng tới cuối bảng*, xem từng bản ghi, giữ lại cái
  khớp. Trả về 8 bản ghi nhưng đọc 5 triệu.

Điều kiện của đề bài chỉ đơn giản là: **cách thứ hai bị cấm**. Tra hai từ khoá
`Query` và `Scan`, đọc kỹ hai trường `Count` và `ScannedCount` trong response
của cả hai.

**Bước 2 — câu hỏi 1.** "Biết trước": mã khách. "Lấy về": các đơn. "Sắp xếp":
theo thời gian, mới nhất trước. Một kho khoá–giá trị nhảy thẳng được tới một
nhóm bản ghi khi bạn cho nó **một giá trị** làm chỗ để nhảy tới, và trong nhóm
đó dữ liệu **đã nằm sẵn theo thứ tự** của một giá trị thứ hai. Hai giá trị đó
tên là gì? Chúng gọi chung là gì?

**Bước 3 — câu hỏi 1 có lọc thời gian.** Nếu bước 2 bạn làm đúng thì bước này
**không cần thêm gì cả** — nó tự có. Nếu bạn thấy mình phải thêm một thứ mới,
quay lại bước 2: giá trị thứ hai của bạn chưa sắp xếp được theo thời gian.

**Bước 4 — câu hỏi 2.** "Biết trước": trạng thái đơn. Nhưng trạng thái không
phải cái bạn đã chọn ở bước 2. Nghĩa là với cấu trúc hiện tại, câu hỏi này bắt
buộc phải đi từ đầu bảng tới cuối — tức là vi phạm điều kiện cứng.

Cách thoát: dựng **một cách nhìn khác** trên cùng dữ liệu, có khoá riêng của
nó. Tra `secondary index`. Có **hai loại**, và một trong hai loại **không dùng
được** cho bài này — tìm ra loại nào và vì sao (gợi ý: một loại bắt buộc dùng
chung khoá phân hoạch với bảng gốc, mà đúng chỗ đó là chỗ bạn cần đổi).

**Bước 5 — bản ghi tạm.** Có một cơ chế hết hạn sẵn có, miễn phí, chỉ cần bật
và chỉ định một thuộc tính. Nhưng nó có **ba luật ngầm** làm nó hỏng im lặng,
và `verify.sh` bắt cả ba. Tra `TTL` và đọc kỹ phần "TTL attribute requirements"
trong tài liệu AWS — đừng đọc lướt, ba luật đó nằm đúng ở đó.

**Bước 6 — nạp 80 bản ghi.** Đừng gõ tay. Terraform có hàm sinh dãy số và hàm
biến map thành chuỗi JSON. Xem tầng 3 nếu kẹt cú pháp.

Khái niệm cần tra: `partition key`, `sort key`, `composite primary key`,
`Query` vs `Scan`, `Count` vs `ScannedCount`, `FilterExpression`,
`ScanIndexForward`, `LSI` vs `GSI`, `projection`, `TTL`, `hot partition`,
`on-demand` vs `provisioned capacity`, `point-in-time recovery`.

Đọc kèm: `docs/aws/w05-databases.md` mục 4 (toàn bộ), và
`docs/notebook/03-database.md` mục 3.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Chọn kho dữ liệu.** Ba ứng viên, và đề bài đã loại hai:

| | Trả lời được ba câu hỏi không | Vấn đề |
|---|---|---|
| Kho quan hệ (RDS) | Có, dễ, chỉ cần vài chỉ mục B-tree | tính tiền **theo giờ** dù không ai gọi. Đề bài đòi nằm trong hạn mức miễn phí, và một instance nhỏ nhất cũng là $12/tháng |
| Kho tài liệu / cluster (Aurora, DocumentDB) | Có | boundary chặn **hoàn toàn** mọi `CreateDBCluster`, và không có instance nhỏ rẻ |
| Kho khoá–giá trị theo request | Có, **nếu** khoá thiết kế đúng | không tự do như SQL: câu hỏi nào không nằm trong khoá thì phải đọc cả bảng |

Câu hỏi giúp bạn tự chốt: **cái gì tính tiền khi không ai dùng?** Đó là câu
hỏi Domain 4 đứng sau gần như mọi lựa chọn serverless trong đề thi.

**Chọn hình dạng khoá — đây mới là bài.** Có ba cách bố trí, và chỉ một cách
qua được yêu cầu 5:

| Cách | Câu hỏi 1 | Câu hỏi 2 | Vấn đề |
|---|---|---|---|
| Khoá chính chỉ có **một** phần: mã đơn | phải đọc cả bảng | phải đọc cả bảng | không có nhóm nào để nhảy tới |
| Khoá chính hai phần: **trạng thái** + thời gian | phải đọc cả bảng | nhanh | chỉ có 4–5 trạng thái, nên toàn bộ dữ liệu dồn vào 4–5 nhóm. Tra `hot partition` để biết vì sao đây là thảm hoạ ở quy mô thật |
| Khoá chính hai phần: **mã khách** + thời gian, thêm một cách nhìn phụ theo trạng thái | nhanh | nhanh | không có — đây là hình dạng đúng |

Nhưng đừng tin bảng này. Hãy tự dựng nó bằng cách hỏi, cho từng cách: *"nếu
tôi biết trước X, tôi nhảy thẳng tới đâu được?"*

**Hai loại chỉ mục phụ — phân biệt bằng đúng một câu.** Một loại cho phép đổi
**cả hai** phần của khoá; loại kia chỉ cho đổi phần thứ hai và **bắt buộc** giữ
nguyên phần thứ nhất. Câu hỏi 2 của bạn cần đổi phần thứ nhất (từ mã khách sang
trạng thái). Vậy loại nào? Ba khác biệt nữa đáng nhớ vì đề thi hỏi: loại nào
tạo được **sau khi** bảng đã tồn tại, loại nào có capacity **riêng**, và loại
nào hỗ trợ đọc **nhất quán mạnh**.

**Chọn cái gì để chiếu (project) vào chỉ mục phụ.** Ba mức: chỉ khoá, một danh
sách bạn chọn, hoặc tất cả. Đánh đổi thật, và nó ra thi: chiếu ít thì tốn ít
lưu trữ và ít capacity ghi, nhưng mỗi lần cần một thuộc tính ngoài danh sách,
kho dữ liệu phải **quay lại bảng gốc lấy tiếp** — và lần quay lại đó tốn thêm
một lượt đọc mà bạn không nhìn thấy trong `ScannedCount` của chỉ mục. Bảng
treo tường của đội vận hành cần hiện những gì? Chiếu đúng chừng đó.

**Đừng dùng `FilterExpression` để giải bài.** Nó lọc **sau khi** dữ liệu đã
được đọc và đã được tính tiền. Nó làm `Count` nhỏ đi mà **không** làm
`ScannedCount` nhỏ đi — và verify.sh so đúng hai con số đó. Đây không phải mẹo
chấm điểm; đó là một trong ba hiểu nhầm bị hỏi nhiều nhất trong phần DynamoDB
của đề thi.

**Yêu cầu 10 (khôi phục 35 ngày).** Hai cơ chế khác nhau, đừng nhầm: một cơ chế
là *ảnh chụp tại một thời điểm do bạn ra lệnh*, sống độc lập và bạn phải nhớ
xoá; cơ chế kia là *khôi phục về bất kỳ giây nào trong 35 ngày*, bật một lần
rồi quên. Đề bài nói "bất kỳ thời điểm nào" và "không cần ai nhớ" — nó đang mô
tả cơ chế nào?

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**Lỗi 1 — `ValidationException: Query condition missed key schema element`.**
Câu truy vấn của bạn thiếu điều kiện trên khoá phân hoạch. Đây là hành vi đúng
của dịch vụ (và là yêu cầu 6 của đề bài) — không có cách nào "sửa cấu hình" để
nó chạy. Nếu bạn *cần* hỏi kiểu đó thật, thì bạn cần một chỉ mục phụ có khoá
phân hoạch khác.

**Lỗi 2 — `Query key condition not supported`.** Bạn đang dùng `>=`,
`begins_with` hoặc `between` trên **khoá phân hoạch**. Khoá phân hoạch chỉ nhận
`=`, không có ngoại lệ. Toán tử khoảng chỉ dùng được trên khoá sắp xếp.

**Lỗi 3 — `verify.sh` báo ScannedCount lớn hơn Count.** Nếu verify tự dựng câu
truy vấn mà vẫn đọc thừa, chỉ có hai khả năng: bảng của bạn không có khoá sắp
xếp (nên "nhóm" của bạn to hơn cần thiết), hoặc bạn nạp thêm những bản ghi
**khác loại** vào cùng một khoá phân hoạch (ví dụ bản ghi tạm của khách dùng
chung khoá với đơn hàng của khách). Cách thứ hai chính là `single-table design`
— nó hợp lệ và mạnh, nhưng lúc đó khoá sắp xếp của bạn phải có **tiền tố phân
loại** để tách hai loại ra (`DON#2025-...` so với `TAM#...`), và câu truy vấn
phải dùng `begins_with`. Trong phạm vi lab này, cách đơn giản nhất là để bản
ghi tạm mang khoá phân hoạch riêng.

**Lỗi 4 — TTL bật rồi mà không có gì hết hạn.** Ba luật ngầm, và verify.sh bắt
cả ba:
1. Giá trị phải là **kiểu Number**, không phải String. Một chuỗi
   `"1735689600"` trông y hệt nhưng TTL bỏ qua nó, vĩnh viễn, không báo lỗi.
2. Đơn vị là **giây** kể từ epoch, không phải mili-giây. Nhân nhầm 1000 thì
   bản ghi hết hạn vào năm 57000.
3. Tên thuộc tính phải khớp **chính xác** cái bạn khai khi bật TTL.

Và một luật thứ tư không phải lỗi mà là kỳ vọng sai: TTL xoá **trong vòng vài
ngày**, không phải đúng giây. Trong khoảng chênh đó bản ghi **vẫn trả về** khi
truy vấn. Ứng dụng thật phải tự lọc theo mốc thời gian, chứ không tin vào TTL.
Đây là một câu hỏi thi.

**Lỗi 5 — chỉ mục phụ báo `ResourceNotFoundException` ngay sau apply.** Chỉ mục
cần vài chục giây tới vài phút để `ACTIVE`. Xem lệnh `watch` ở mục Quy trình
của README.

**Lỗi 6 — apply chậm khủng khiếp khi nạp dữ liệu.** Nếu bạn tạo mỗi bản ghi là
một resource riêng thì Terraform gọi 80 lần API tuần tự theo mặc định `-parallelism=10`.
Chấp nhận được (khoảng 20–40 giây). Nếu bạn thấy hàng phút, kiểm tra xem có
đang ở chế độ provisioned với capacity quá thấp không — ghi bị throttle và
Terraform tự thử lại.

**Cú pháp lạ bạn có thể cần** — sinh 80 bản ghi mà không gõ tay 80 lần, và biến
một map Terraform thành chuỗi JSON mà API đòi hỏi:

```hcl
for_each = { for i in range(80) : tostring(i) => i }
item     = jsonencode({ ma_khach = { S = "KHACH#${each.value % 12}" } })
```

**Resource và data source Terraform cần tra:** `aws_dynamodb_table` (chú ý các
khối `attribute`, `global_secondary_index`, `ttl`, `point_in_time_recovery`, và
tham số `billing_mode`), `aws_dynamodb_table_item`. Hàm: `range`, `formatdate`,
`timeadd`, `jsonencode`, `tostring`.

**Lệnh CLI để tự soi trước khi chạy verify.sh:**

```bash
T=$(terraform -chdir=terraform output -raw table_name)
aws dynamodb describe-table --table-name "$T" --profile lab-builder \
  --query 'Table.[KeySchema,AttributeDefinitions,GlobalSecondaryIndexes[].{Ten:IndexName,Khoa:KeySchema,Chieu:Projection}]'
```

**Docs:**
- Best practice thiết kế khoá phân hoạch: <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html>
- Query so với Scan: <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Scan.html>
- Yêu cầu với thuộc tính TTL: <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/time-to-live-ttl-before-you-start.html>
- LSI so với GSI: <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/SecondaryIndexes.html>

</details>
