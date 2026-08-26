# Đối chiếu — tuần 5

> Đọc sau khi `./verify.sh` xanh, kể cả bốn check phủ định.

---

## Bạn vừa làm gì, theo ngôn ngữ đề thi

| Yêu cầu trong đề | Khái niệm SAA | Đọc thêm |
|---|---|---|
| 2, 3 — đơn của một khách, có lọc thời gian | **composite primary key**: partition key + sort key | [Partition key và sort key](../../../docs/aws/w05-databases.md#partition-key-và-sort-key) · [sổ tay](../../../docs/notebook/03-database.md#31-partition-key-và-hot-partition) |
| 5 — `Count == ScannedCount` | **Query so với Scan**; `FilterExpression` lọc **sau khi** đã tính tiền | [Query so với Scan](../../../docs/aws/w05-databases.md#query-so-với-scan) |
| 4 — mọi đơn ở một trạng thái | **GSI** (không phải LSI — LSI dùng chung partition key với bảng) | [LSI so với GSI](../../../docs/aws/w05-databases.md#lsi-so-với-gsi) · [sổ tay](../../../docs/notebook/03-database.md#32-lsi-vs-gsi) |
| 6 — hỏi thiếu partition key thì bị TỪ CHỐI | mô hình truy cập của kho khoá–giá trị: **không có query planner** | [Query so với Scan](../../../docs/aws/w05-databases.md#query-so-với-scan) |
| 8 — bản ghi tạm tự biến mất | **TTL**, và ba luật ngầm của nó | [Streams, TTL, DAX](../../../docs/aws/w05-databases.md#streams-ttl-dax-global-tables) · [sổ tay](../../../docs/notebook/03-database.md#37-ttl) |
| 9 — khoá phân hoạch tản đều | **hot partition**, cardinality | [Hot partition](../../../docs/aws/w05-databases.md#hot-partition--chọn-pk-sai) |
| 10 — khôi phục 35 ngày | **PITR** so với snapshot thủ công | [Backup](../../../docs/aws/w05-databases.md#backup-automated-so-với-manual-snapshot) · [PITR](../../../docs/notebook/03-database.md#15-pitr) |
| 11 — chế độ tính tiền | **on-demand so với provisioned**; RCU/WCU | [Capacity mode](../../../docs/aws/w05-databases.md#capacity-mode) · [Tính RCU và WCU](../../../docs/notebook/03-database.md#34-tính-rcu-và-wcu) |
| lab không có RDS | khi nào chọn quan hệ, khi nào chọn khoá–giá trị | [Chọn database](../../../docs/aws/w05-databases.md#1-chọn-database--khung-ba-câu-hỏi) · [Cây quyết định](../../../docs/notebook/20-cay-quyet-dinh.md#4-chọn-database) |

### Hai con số bạn vừa nhìn thấy, và vì sao chúng là cả bài học

Một kho quan hệ có **query planner**: bạn viết `WHERE`, nó tự tìm đường đi rẻ
nhất, và nếu không có chỉ mục nào hợp thì nó vẫn trả lời — chỉ chậm. Bạn có thể
sống nhiều năm mà không biết một câu truy vấn của mình đang quét toàn bảng.

Kho khoá–giá trị **không có query planner**, và đó là thiết kế chứ không phải
thiếu sót. Nó bắt bạn khai trước cách bạn sẽ hỏi. Đổi lại, nó cho bạn một lời
hứa mà kho quan hệ không cho được: **độ trễ không đổi khi dữ liệu lớn lên**.
Một `Query` trên bảng 100 bản ghi và trên bảng 100 tỉ bản ghi tốn như nhau, vì
nó nhảy thẳng tới phân hoạch chứ không đi tìm.

Cái giá của lời hứa đó chính là ràng buộc bạn vừa va vào: câu hỏi nào không nằm
trong khoá thì **không hỏi được**, chứ không phải "hỏi được nhưng chậm".

```
Query  : biết partition key -> nhảy thẳng tới phân hoạch -> đọc đúng thứ cần
         ScannedCount == Count.  Chi phí tỉ lệ với KẾT QUẢ.

Scan   : đi từ đầu bảng tới cuối, cả những phân hoạch không liên quan
         ScannedCount == cả bảng.  Chi phí tỉ lệ với DỮ LIỆU.
         FilterExpression bỏ bớt ở bước CUỐI — sau khi đã đọc, sau khi đã
         tính tiền. Nó tiết kiệm băng thông mạng, không tiết kiệm một xu RCU.
```

Câu cuối là thứ ra thi nhiều nhất trong cả phần DynamoDB, và nó cũng là lý do
bảng-treo-tường ở công ty cũ của trưởng nhóm hạ tầng làm hoá đơn gấp bốn mươi
lần mà vẫn hiển thị đúng.

---

## Ba cách khác để giải bài này

### Cách A — một kho quan hệ (RDS PostgreSQL) với hai chỉ mục B-tree

`CREATE INDEX ON don_hang (ma_khach, ngay_tao DESC)` và
`CREATE INDEX ON don_hang (trang_thai, ngay_tao DESC)`. Xong. Ba câu hỏi trong
đề bài đều là một dòng SQL.

- **Tốt hơn khi:** câu hỏi **chưa biết trước**. Một tuần nữa sếp muốn "doanh
  thu theo tỉnh, theo quý, chỉ tính khách mua trên 3 lần" — với SQL đó là 15
  phút; với kho khoá–giá trị đó là một thiết kế lại. Kho quan hệ cũng cho bạn
  **giao dịch nhiều bảng**, **ràng buộc toàn vẹn**, **JOIN**, và một ngôn ngữ
  mà mọi công cụ BI trên đời đều nói được.
- **Tệ hơn ở chỗ:** tính tiền **theo giờ** dù không ai gọi — $12/tháng cho
  instance nhỏ nhất, và đó là trước khi có Multi-AZ hay replica. Mở rộng theo
  chiều đọc phải thêm read replica (mỗi cái một hoá đơn nữa), mở rộng theo
  chiều ghi thì phải sharding thủ công. Và bạn phải quản lý phiên bản engine,
  cửa sổ bảo trì, connection pool.
- **Đề thi hỏi thế nào:** thấy *"complex queries"*, *"joins"*, *"ACID
  transactions across tables"*, *"existing SQL application"*, *"reporting"* →
  quan hệ. Thấy *"single-digit millisecond latency at any scale"*,
  *"unpredictable traffic"*, *"serverless"*, *"key-value access pattern"*,
  *"no server management"* → DynamoDB. Thấy *"millions of requests per second"*
  → DynamoDB, gần như không có ngoại lệ.

### Cách B — DynamoDB nhưng bỏ chỉ mục phụ, cache toàn bảng cho bảng treo tường

Giữ khoá chính như bạn đã làm. Bỏ GSI đi. Một tiến trình nền `Scan` toàn bảng
mỗi 5 phút, nhét kết quả vào một cache trong bộ nhớ, và bảng treo tường đọc
cache thay vì đọc kho dữ liệu.

- **Tốt hơn khi:** câu hỏi thứ hai **rất tốn kém để đánh chỉ mục** nhưng **rất
  chịu được dữ liệu cũ**. Một GSI làm tăng chi phí **ghi** của *mọi* đơn hàng,
  vĩnh viễn, kể cả những đơn không ai bao giờ nhìn qua bảng treo tường. Nếu tỉ
  lệ ghi/đọc rất lệch về phía ghi thì cách này rẻ hơn thật.
- **Tệ hơn ở chỗ:** dữ liệu trễ tới 5 phút, và bạn vừa thêm một thành phần có
  trạng thái phải vận hành. Nếu cache là ElastiCache thì nó lại là một hoá đơn
  theo giờ — đúng thứ bạn tránh khi chọn DynamoDB. Và `Scan` toàn bảng mỗi 5
  phút vẫn là `Scan` toàn bảng: bạn chỉ giảm **tần suất** chứ không đổi **bản
  chất**.
- **Đề thi hỏi thế nào:** thấy *"eventual consistency is acceptable"*,
  *"dashboard refreshed every N minutes"*, *"reduce cost"* → cache là ứng viên.
  Thấy *"real time"*, *"immediately reflect"* → GSI. Và nhớ **DAX** khi đề nói
  *"cache for DynamoDB"* kèm *"microsecond"* và *"no application code
  changes"* — DAX nói đúng API DynamoDB, ElastiCache thì không.

### Cách C — DynamoDB làm nguồn sự thật, Streams đẩy sang một kho tìm kiếm

Bảng giữ nguyên. Bật **DynamoDB Streams**, một hàm đọc stream và đồng bộ mọi
thay đổi sang OpenSearch (hoặc sang S3 rồi truy vấn bằng Athena).

- **Tốt hơn khi:** số câu hỏi **không đoán trước được** và chúng là truy vấn tự
  do — tìm toàn văn, lọc nhiều chiều, thống kê. Đây là mẫu **CQRS**: một bên tối
  ưu cho ghi và tra cứu theo khoá, một bên tối ưu cho đọc và tìm kiếm. Nó cũng
  là mẫu chuẩn khi bạn cần giữ nguyên một hệ thống đang chạy mà thêm khả năng
  phân tích.
- **Tệ hơn ở chỗ:** hai kho dữ liệu phải đồng bộ, nên bạn nhận thêm cả một lớp
  bài toán mới: trễ, mất bản ghi, xử lý lại từ đầu, và câu hỏi "nếu hai bên lệch
  nhau thì bên nào đúng". Với bài toán chỉ có hai câu hỏi biết trước như đề bài
  này thì đó là độ phức tạp không đổi lấy gì. Và OpenSearch bị hàng rào chặn
  trong bộ lab vì nó ~$25/tháng cho cụm nhỏ nhất.
- **Đề thi hỏi thế nào:** thấy *"full-text search"*, *"ad-hoc analytics on
  DynamoDB data"*, *"log analytics"* → Streams + OpenSearch, hoặc export sang
  S3 + Athena khi đề nhấn *"lowest cost"* và *"infrequent queries"*. Thấy
  *"react to item changes"*, *"trigger a function when an item is modified"* →
  Streams + Lambda, và nhớ rằng Streams giữ 24 giờ.

### Bảng quyết định rút ra

| Đề nói | Chọn |
|---|---|
| "single-digit millisecond, any scale, key-value" | **DynamoDB** |
| "complex joins", "ad-hoc SQL", "reporting" | **RDS / Aurora** |
| "cần một khoá phân hoạch KHÁC bảng gốc" | **GSI** |
| "cần một khoá sắp xếp khác, cùng khoá phân hoạch, và đọc nhất quán mạnh" | **LSI** (và nhớ: **phải tạo cùng lúc với bảng**) |
| "tải không đoán được, có thể bằng 0" | **on-demand** |
| "tải ổn định, biết trước, muốn rẻ nhất" | **provisioned** + auto scaling |
| "dữ liệu tự hết hạn, không cần chính xác từng giây" | **TTL** |
| "microsecond latency", "không sửa code ứng dụng" | **DAX** |
| "chịu lỗi một AZ cho RDS" | **Multi-AZ** (standby **không** phục vụ đọc) |
| "quá tải vì đọc nhiều trên RDS" | **Read Replica** |
| "khôi phục về bất kỳ giây nào trong 35 ngày" | **PITR** |
| "giữ bản sao lâu hơn, chọn thời điểm" | **snapshot thủ công** (nhớ xoá — nó sống lâu hơn bảng) |
| "đọc/ghi ở nhiều region, độ trễ thấp ở mọi nơi" | **DynamoDB Global Tables** (multi-active) |
| "quá nhiều connection làm sập database" | **RDS Proxy** |

---

## Nếu đề thi hỏi

<details><summary>Câu 1 — Ứng dụng gọi `Scan` với `FilterExpression` trên bảng 50 GB để lấy về khoảng 20 bản ghi. Chi phí quá cao. Cách nào giảm chi phí NHIỀU NHẤT?</summary>

**A.** Thêm `Limit` vào lời gọi `Scan`.
**B.** Chuyển sang `Query` với một GSI có khoá phân hoạch là thuộc tính đang lọc.
**C.** Chuyển bảng sang chế độ on-demand.
**D.** Bật DAX để cache kết quả `Scan`.

**Đáp án: B.**

- **A hiểu sai `Limit`**: nó giới hạn số bản ghi **trả về mỗi trang**, không
  giới hạn số bản ghi được **đọc**. Với filter, DynamoDB vẫn đọc rồi mới lọc,
  nên bạn chỉ nhận được ít dữ liệu hơn mỗi lần gọi và phải gọi nhiều lần hơn.
- **C đổi cách tính tiền, không đổi lượng việc**: cùng một `Scan` toàn bảng,
  chỉ là hoá đơn ghi theo request thay vì theo capacity. Có thể còn **đắt hơn**.
- **D sai bản chất**: DAX cache theo **khoá**. Kết quả `Scan` và `Query` cũng
  được cache trong một cache riêng, nhưng nó không giúp gì khi dữ liệu đổi liên
  tục, và nó không sửa cái sai gốc.
- **B đúng**: đây chính là bài bạn vừa làm. Điểm phải nói được trong đầu:
  `FilterExpression` giảm **Count**, không giảm **ScannedCount**, và tiền tính
  theo `ScannedCount`.

</details>

<details><summary>Câu 2 — Bảng đã chạy production 2 năm, khoá chính là `ma_khach` + `ngay_tao`. Giờ cần truy vấn theo `trang_thai`. Không được downtime. Làm gì?</summary>

**A.** Tạo một LSI mới với khoá sắp xếp là `trang_thai`.
**B.** Tạo một GSI với khoá phân hoạch là `trang_thai`.
**C.** Tạo bảng mới với khoá chính khác rồi migrate dữ liệu.
**D.** Dùng `Scan` với `FilterExpression` trên `trang_thai`.

**Đáp án: B.**

- **A sai vì hai lý do độc lập, cả hai đều ra thi**: LSI **phải được tạo cùng
  lúc với bảng** — không thêm được sau; và LSI **bắt buộc dùng chung khoá phân
  hoạch** với bảng, nên nó vẫn đòi bạn biết `ma_khach` trước. Câu hỏi này thì
  không biết.
- **C là câu trả lời đúng cho một câu hỏi khác**: khi bạn cần đổi **khoá chính**
  thì thật sự phải tạo bảng mới. Ở đây không cần.
- **D chạy được và là cái bẫy dễ chọn nhất** — nó "hoạt động" ngay lập tức. Nó
  cũng là nguyên nhân của hoá đơn trong đề bài lab của bạn.
- **B đúng**: GSI thêm được **bất cứ lúc nào** trên bảng đang chạy, có khoá
  phân hoạch riêng, capacity riêng, và quá trình backfill chạy nền không làm
  gián đoạn. Nhớ hai cái giá: GSI chỉ **eventually consistent** (không bao giờ
  đọc nhất quán mạnh được), và mỗi lần ghi vào bảng là một lần ghi vào GSI.

</details>

<details><summary>Câu 3 — Bảng IoT dùng khoá phân hoạch là `ngay` (dạng `2025-08-21`). Ban ngày throttle nặng dù capacity tổng còn dư nhiều. Vì sao?</summary>

**A.** Capacity provisioned quá thấp; tăng RCU/WCU lên.
**B.** Mọi ghi trong một ngày dồn vào một phân hoạch; phân hoạch đó chạm trần riêng của nó.
**C.** Bảng thiếu khoá sắp xếp.
**D.** Cần bật auto scaling.

**Đáp án: B.**

- **A và D chữa triệu chứng**: tăng capacity tổng lên thì DynamoDB chia đều cho
  các phân hoạch, mà vấn đề là **một** phân hoạch nóng còn các phân hoạch khác
  ngủ. Bạn sẽ trả tiền cho capacity không ai dùng và vẫn bị throttle. (Adaptive
  capacity giúp phần nào và bật sẵn, nhưng nó không cứu được một khoá chỉ có
  cardinality bằng số ngày.)
- **C sai**: khoá sắp xếp không đổi cách dữ liệu được chia phân hoạch.
- **B đúng**: mỗi phân hoạch có trần cứng (3.000 RCU / 1.000 WCU). Khoá phân
  hoạch là "ngày" nghĩa là **toàn bộ ghi của hôm nay** đi vào **một** phân hoạch.
  Cách sửa chuẩn của đề thi: **write sharding** — ghép thêm một hậu tố ngẫu
  nhiên (`2025-08-21#7`), hoặc chọn một khoá có cardinality cao ngay từ đầu
  (`ma_thiet_bi`). Đây đúng là lý do yêu cầu 9 của lab tồn tại.

</details>

<details><summary>Câu 4 — RDS đang quá tải vì báo cáo đọc nặng chạy giờ hành chính. Đội đề xuất bật Multi-AZ để "chia tải". Đánh giá?</summary>

**A.** Đúng — standby của Multi-AZ phục vụ đọc.
**B.** Sai — standby không phục vụ traffic; cần Read Replica.
**C.** Đúng nếu đọc từ reader endpoint.
**D.** Sai — cần chuyển sang Aurora mới chia được tải đọc.

**Đáp án: B.**

- **A là hiểu nhầm bị hỏi nhiều nhất trong cả phần database của đề thi.** Trong
  RDS (không phải Aurora), standby của Multi-AZ **không nhận một request nào**.
  Nó chỉ nhận replication đồng bộ và ngồi chờ failover.
- **C nhầm sang Aurora**: reader endpoint là khái niệm của Aurora, RDS thường
  không có.
- **D quá tay**: Read Replica của RDS giải đúng bài này mà không phải đổi engine.
- **B đúng**. Bảng phải thuộc lòng:

  | | Multi-AZ | Read Replica |
  |---|---|---|
  | Giải bài toán | **tính sẵn sàng** | **mở rộng đọc** |
  | Replication | đồng bộ | bất đồng bộ |
  | Phục vụ đọc | **không** | có |
  | Cùng region | có | có hoặc **khác region** |
  | Failover | tự động | thủ công (promote) |
  | Nhân đôi tiền | có | có, mỗi replica |

  Lưu ý một ngoại lệ ra thi gần đây: **Multi-AZ DB Cluster** (ba node) của RDS
  *có* hai reader phục vụ đọc. Đề hỏi "Multi-AZ **instance**" thì đáp án vẫn là
  không.

</details>

<details><summary>Câu 5 — Bảng session bật TTL với `expires_at` = epoch giây. Ứng dụng thỉnh thoảng vẫn đọc được session đã hết hạn. Bug ở đâu?</summary>

**A.** TTL cấu hình sai kiểu dữ liệu.
**B.** Không có bug — TTL xoá trong vòng vài ngày, không đúng giây. Ứng dụng phải tự lọc.
**C.** Cần bật strongly consistent read.
**D.** Cần giảm TTL xuống dưới 24 giờ.

**Đáp án: B.**

- **A là một bug có thật nhưng biểu hiện khác**: sai kiểu (String thay vì
  Number) thì bản ghi **không bao giờ** bị xoá, chứ không phải "thỉnh thoảng
  vẫn đọc được". Đây là chỗ hỏng im lặng mà `verify.sh` của lab bắt.
- **C không liên quan**: nhất quán nói về việc thấy bản ghi vừa ghi, không nói
  về việc bản ghi đã bị xoá chưa.
- **D không đổi gì**: TTL không hứa thời điểm ở bất kỳ giá trị nào.
- **B đúng**: TTL là một tiến trình nền **miễn phí**, và cái giá của "miễn phí"
  chính là "không hứa thời điểm" — AWS nói *thường trong vài ngày*. Mẫu đúng:
  vẫn bật TTL để dọn rác, **và** ứng dụng vẫn so `expires_at` với hiện tại mỗi
  lần đọc. Một chi tiết đẹp nữa: bản ghi bị TTL xoá **có** đi vào DynamoDB
  Streams, và bạn phân biệt được nó với xoá do người dùng bằng
  `userIdentity.principalId = dynamodb.amazonaws.com`.

</details>

<details><summary>Câu 6 — Ứng dụng mới, không ai biết trước lưu lượng, có thể bằng 0 nhiều ngày rồi đột ngột tăng gấp 100 lần. Chọn chế độ capacity nào?</summary>

**A.** Provisioned với auto scaling, min 5, max 40.000.
**B.** On-demand.
**C.** Provisioned với capacity đặt theo đỉnh dự đoán.
**D.** Provisioned + reserved capacity mua 1 năm.

**Đáp án: B.**

- **A gần đúng và là bẫy tốt**: auto scaling của DynamoDB phản ứng theo
  CloudWatch alarm, mất **vài phút** để tăng. Một đỉnh gấp 100 lần trong 30 giây
  sẽ bị throttle suốt thời gian đó. Nó cũng không bao giờ giảm về 0.
- **C trả tiền cho đỉnh 24/7**, kể cả những ngày lưu lượng bằng 0.
- **D là cam kết 1 năm cho một tải mà bạn thừa nhận là không đoán được** — sai
  ở tầng nguyên tắc, không chỉ ở tầng con số.
- **B đúng**: on-demand hấp thụ tăng đột ngột tới gấp đôi đỉnh cũ ngay lập tức,
  và không có gì để trả khi không ai gọi. Cái giá: đắt hơn khoảng **6–7 lần**
  mỗi request so với provisioned dùng hết công suất. Nên câu trả lời đổi khi đề
  nói *"steady, predictable traffic"* và *"lowest cost"* → lúc đó là provisioned,
  và **reserved capacity** nếu đề còn nhấn cam kết dài hạn. Chuyển đổi giữa hai
  chế độ được, nhưng có giới hạn tần suất.

</details>

---

## Chỗ dễ hiểu sai

**"DynamoDB không cần thiết kế schema."** Ngược hẳn. Nó không cần khai *kiểu
dữ liệu của từng cột*, nhưng nó bắt bạn thiết kế **mẫu truy cập** trước khi ghi
dòng dữ liệu đầu tiên — và thiết kế đó khó sửa hơn schema SQL rất nhiều, vì đổi
khoá chính nghĩa là tạo bảng mới và migrate. "Schemaless" nói về **thuộc tính**,
không nói về **khoá**.

**"Thêm GSI cho chắc."** Mỗi GSI nhân số lần ghi lên. Ghi một đơn hàng vào bảng
có 3 GSI là **4** lần ghi được tính tiền, mãi mãi, kể cả với những bản ghi không
ai truy vấn qua GSI bao giờ. Và nếu GSI ở chế độ provisioned mà capacity của nó
cạn, thì **ghi vào bảng gốc cũng bị throttle** — một GSI cấu hình sai có thể làm
chết cả bảng.

**"`ScannedCount` nhỏ nghĩa là truy vấn rẻ."** Gần đúng, nhưng đơn vị tính tiền
là **kích thước** chứ không phải **số bản ghi**: 1 RCU = 4 KB đọc nhất quán cuối
cùng (hoặc 2 KB đọc nhất quán mạnh). Đọc 10 bản ghi mỗi bản 100 KB đắt hơn đọc
1.000 bản ghi mỗi bản 200 byte. Khi đề thi cho kích thước item, họ đang muốn bạn
làm phép chia.

**"Query của tôi luôn trả về hết dữ liệu."** Một lời gọi `Query` trả tối đa
**1 MB**, rồi dừng và trả `LastEvaluatedKey`. Nếu code của bạn không lặp cho tới
khi `LastEvaluatedKey` rỗng, bạn đang im lặng bỏ sót dữ liệu — và bug đó chỉ lộ
ra khi dữ liệu đủ lớn, tức là ở production. (`verify.sh` của lab cố tình dùng
`--no-paginate` để bạn nhìn thấy đúng một trang, giống hệt điều SDK làm mặc định
trong nhiều ngôn ngữ.)

**"Bật TTL là xong việc dọn."** Xem câu 5 ở trên. Và thêm một chuyện: TTL
**không** giảm chi phí lưu trữ ngay — bản ghi vẫn tính tiền cho tới khi thật sự
bị xoá, và việc xoá đó **không tốn WCU** (đây là điểm cộng thật của TTL so với
việc tự chạy job xoá).

**Trong production, cái bạn vừa dựng còn thiếu bốn thứ:** một chiến lược khi
`Query` chạm 1 MB (phân trang thật ở tầng ứng dụng), giám sát
`ThrottledRequests` và `UserErrors` bằng CloudWatch alarm, `deletion_protection`
bật trên bảng, và một quyết định rõ ràng về **đọc nhất quán mạnh hay cuối
cùng** cho từng đường đọc — mặc định là nhất quán cuối cùng, rẻ bằng một nửa, và
nó **là** nguyên nhân của những bug "vừa ghi xong đọc không thấy" mà người mới
luôn đổ cho ứng dụng.
