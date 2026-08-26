# Tuần 5 — Cơ sở dữ liệu

> Đây là tuần có mật độ câu hỏi thi cao nhất trong ba tuần vừa qua. Không phải vì
> database khó, mà vì đề SAA **không hỏi bạn biết gì về DynamoDB** — nó cho một
> tình huống rồi hỏi **chọn database nào**. Vì vậy phần quan trọng nhất của bài này
> không phải mục nào cũng nói về một dịch vụ, mà là **bảng quyết định** ở giữa bài.
> Học phần còn lại chỉ để hiểu vì sao bảng đó đúng.

## Học xong bài này bạn phải trả lời được

1. Ba câu hỏi nào về dữ liệu đủ để chọn đúng database trong 90% câu hỏi SAA?
2. Multi-AZ và Read Replica khác nhau ở điểm nào — và vì sao "database quá tải vì
   quá nhiều truy vấn đọc" **không bao giờ** có đáp án là Multi-AZ?
3. Automated backup và manual snapshot khác nhau ở đâu, và cái nào biến mất khi bạn
   xoá DB instance?
4. Aurora làm gì với 6 bản sao qua 3 AZ mà RDS Multi-AZ không làm được?
5. Chọn partition key sai gây ra hiện tượng gì, và vì sao "tăng capacity" không chữa?
6. LSI và GSI khác nhau ba điểm nào — và điểm nào là **không sửa được sau này**?
7. Vì sao `FilterExpression` trên một Scan **không** làm giảm chi phí đọc?
8. Redis và Memcached: đề dùng từ khoá gì để chỉ đúng một trong hai?

## Bản đồ khái niệm

```
                      Dữ liệu của bạn có hình dạng gì?
                                    │
        ┌───────────────────────────┼────────────────────────────┐
   QUAN HỆ                    KEY-VALUE                    CHUYÊN BIỆT
   schema cố định            schema linh hoạt              hình dạng riêng
   JOIN, transaction         truy vấn theo khoá
        │                           │                            │
   ┌────┴─────┐              ┌──────┴──────┐         ┌───────────┼──────────┐
  RDS      Aurora        DynamoDB     ElastiCache  Redshift   Neptune   DocumentDB
   │          │              │        Redis/Memcached (OLAP)   (graph)  (MongoDB)
   │   storage tách rời      │                         │
   │   6 bản × 3 AZ          │      DAX (µs)           └─ Athena: query thẳng trên S3
   │
   ├─ Multi-AZ ──────► HA, standby KHÔNG phục vụ đọc, synchronous
   ├─ Read Replica ──► scale ĐỌC, phục vụ đọc được, asynchronous
   ├─ RDS Proxy ─────► gom connection pool, giữ kết nối khi failover
   └─ backup: automated (PITR, xoá theo instance)
              manual snapshot (sống mãi cho tới khi bạn xoá)
```

Ba nhánh trên cùng chính là ba câu hỏi bạn phải tự hỏi khi đọc đề. Mọi thứ còn lại
là chi tiết của từng nhánh.

---

## 1. Chọn database — khung ba câu hỏi

Ba câu hỏi, theo đúng thứ tự:

**(1) Dữ liệu có hình dạng cố định và cần JOIN / transaction đa bảng không?**
Có → họ quan hệ (RDS, Aurora). Không → đi tiếp.

**(2) Mọi truy vấn đều biết trước khoá, và cần latency mili giây ở quy mô bất kỳ?**
Có → DynamoDB. Không → đi tiếp.

**(3) Dữ liệu có hình dạng đặc thù không?**
Quan hệ giữa các thực thể quan trọng hơn bản thân thực thể → **Neptune** (graph).
Truy vấn phân tích trên hàng tỉ dòng → **Redshift**. Dữ liệu đã nằm sẵn ở S3, truy
vấn không thường xuyên → **Athena**. JSON document, API tương thích MongoDB →
**DocumentDB**.

Bảng ánh xạ đầy đủ từ tình huống sang dịch vụ nằm ở mục
[Bảng quyết định](#bảng-quyết-định) cuối bài — đó là phần đáng học thuộc nhất.

---

## 2. RDS

RDS là "MySQL/PostgreSQL nhưng AWS lo phần vận hành". Bạn vẫn nhận được một
endpoint và một cổng, vẫn `psql` vào được. Cái bạn **mất** là quyền `sudo` trên
máy chủ database và quyền vào file `postgresql.conf`.

**Engine hỗ trợ:** MySQL, PostgreSQL, MariaDB, Oracle, SQL Server, Db2 — và Aurora
(MySQL-compatible, PostgreSQL-compatible) nằm dưới cùng cây RDS.

### Multi-AZ so với Read Replica — bẫy kinh điển nhất của cả kỳ thi

| | **Multi-AZ** | **Read Replica** |
|---|---|---|
| Mục đích | **Chịu lỗi (HA)** | **Mở rộng đọc** |
| Standby/replica phục vụ đọc? | **KHÔNG** | **CÓ** |
| Đồng bộ | **Synchronous** | **Asynchronous** (có replication lag) |
| Failover | **Tự động**, RDS đổi bản ghi DNS của endpoint | **Thủ công** — phải `promote` |
| Nằm ở đâu | AZ khác, **cùng region** | Cùng AZ, khác AZ, hoặc **khác region** |
| Số lượng | 1 standby | Tới **15** với RDS MySQL/MariaDB/PostgreSQL |
| Giá | **Gấp đôi** | Cộng thêm mỗi replica |
| Ảnh hưởng tới ghi | Ghi chậm hơn một chút (chờ standby xác nhận) | Không |

Đọc lại dòng thứ hai cho tới khi thuộc: **standby của Multi-AZ không phục vụ đọc.**
Nó tồn tại chỉ để chờ. Vì thế:

- Đề: *"database bị quá tải do quá nhiều truy vấn đọc"* → **Read Replica**.
- Đề: *"phải chịu được mất một AZ, thời gian gián đoạn tối thiểu"* → **Multi-AZ**.
- Đề: *"cần cả hai"* → dùng **cả hai**, chúng không loại trừ nhau.
- Đề: *"chạy báo cáo nặng mà không ảnh hưởng production"* → **Read Replica**.
- Đề: *"DR sang region khác"* → **cross-region Read Replica** (rồi promote khi cần).

**Failover của Multi-AZ** xảy ra khi AZ chính hỏng, instance chính hỏng, đổi instance
type, hoặc patch OS. RDS **đổi bản ghi DNS** của endpoint sang standby — tên endpoint
không đổi nên ứng dụng không sửa config, nhưng ứng dụng **phải kết nối lại**, và client
cache DNS quá lâu thì sẽ treo. Đây là lý do RDS Proxy tồn tại.

Điểm hay bị bỏ qua: RDS yêu cầu **DB subnet group trải ít nhất 2 AZ ngay cả khi chạy
Single-AZ** — để sau này bật Multi-AZ mà không phải dựng lại.

### Backup: automated so với manual snapshot

| | **Automated backup** | **Manual snapshot** |
|---|---|---|
| Ai tạo | RDS, hằng ngày trong backup window | Bạn, khi nào bạn muốn |
| Giữ bao lâu | **1–35 ngày** (đặt `0` là tắt) | **Mãi mãi**, cho tới khi bạn xoá |
| Point-in-time recovery | **Có** — khôi phục về bất kỳ giây nào trong retention (thường trễ ~5 phút so với hiện tại) | Không, chỉ về đúng thời điểm chụp |
| Khi xoá DB instance | **Bị xoá theo** (trừ khi bạn giữ lại có chủ ý) | **Vẫn còn**, vẫn tính tiền |
| Copy sang region khác | Gián tiếp | **Trực tiếp** |

PITR hoạt động nhờ RDS lưu **transaction log** liên tục: khi khôi phục, nó lấy backup
hằng ngày gần nhất rồi replay log tới đúng thời điểm bạn chọn. Khôi phục **luôn tạo ra
một DB instance mới** với endpoint mới — bản gốc không bị đụng tới.

Từ khoá đề: *"khôi phục về trước khi chạy nhầm câu DELETE"* → **PITR từ automated
backup**. *"Giữ bản sao tuân thủ 7 năm"* → **manual snapshot** (hoặc AWS Backup).
Bẫy tiền: quên bỏ chọn "create final snapshot" hoặc quên xoá manual snapshot cũ thì
bạn vẫn trả tiền lưu trữ dù chẳng còn database nào.

### Parameter group và option group

**Parameter group** là nơi thay `postgresql.conf` / `my.cnf` — vì bạn không có `sudo`.
Tham số **dynamic** áp dụng ngay; tham số **static** cần **reboot instance**. Không sửa
được default parameter group của AWS — phải **tạo custom** rồi gán vào instance. Đề hỏi
*"bật `force_ssl`"* hay *"bật slow query log"* → parameter group, nhớ phần reboot.

**Option group** dành cho tính năng thêm của engine (Oracle TDE, SQL Server Native
Backup). Mức nhận biết là đủ.

### RDS Proxy

Vấn đề: mỗi kết nối tới PostgreSQL tốn RAM ở phía server. Lambda scale ra 1.000
concurrent execution thì mở 1.000 kết nối, và RDS sập vì `too many connections`.

RDS Proxy đứng giữa, **gom connection pool** và tái sử dụng kết nối tới database. Ba
lợi ích ra thi: (1) **gom connection** — giải đúng bài toán Lambda + RDS; (2) **giảm
thời gian failover** tới ~66%, vì proxy giữ kết nối của client trong khi database bên
dưới đổi sang standby; (3) **ép xác thực qua IAM và Secrets Manager**, không nhét mật
khẩu vào code. RDS Proxy **chỉ nằm trong VPC**, không có endpoint public.

---

## 3. Aurora

Aurora là engine do AWS viết lại, **tương thích wire protocol** với MySQL và
PostgreSQL. Ứng dụng của bạn không biết mình đang nói chuyện với Aurora.

### Kiến trúc storage tách rời — điểm khác biệt cốt lõi

```
   ┌──────────┐    ┌──────────┐    ┌──────────┐
   │  Writer  │    │ Reader 1 │    │ Reader 2 │   tối đa 15 reader
   └────┬─────┘    └────┬─────┘    └────┬─────┘
        │  chỉ ghi REDO LOG, không ghi cả trang dữ liệu
        └───────────────┼───────────────┘
   ┌────────────────────▼─────────────────────────────┐
   │        CLUSTER VOLUME — dùng chung                │
   │   6 bản sao, trải 3 Availability Zone (2 bản/AZ)  │
   │   ghi cần quorum 4/6 · đọc/sửa cần 3/6            │
   │   tự lớn lên, tối đa 128 TiB (tới 256 TiB tuỳ bản)│
   └──────────────────────────────────────────────────┘
```

Ba hệ quả rút ra từ sơ đồ này, và cả ba đều ra thi:

1. **Thêm replica không nhân bản dữ liệu.** Reader gắn vào **cùng một cluster
   volume** đã có sẵn. Vì thế thêm replica mất vài phút chứ không mất vài giờ như
   RDS, và replication lag thường **dưới 100 ms** thay vì nhiều giây.
2. **Chịu được mất 2 bản sao mà vẫn ghi được, mất 3 bản mà vẫn đọc được.** Quorum
   ghi 4/6 nghĩa là mất trọn một AZ (2 bản) vẫn ghi bình thường. Storage tự
   self-heal ở nền.
3. **Storage tự lớn.** Không có chuyện "hết disk lúc 2 giờ sáng". RDS thì phải bật
   storage autoscaling và vẫn có trần.

**Failover:** Aurora tự promote một reader lên writer, thường **dưới 30 giây**; bạn đặt
được **failover priority** (tier 0–15). Cluster chỉ có writer vẫn an toàn về dữ liệu
(6 bản còn nguyên) nhưng phải chờ Aurora dựng instance mới — nên production luôn có ít
nhất một reader ở AZ khác.

### Endpoint — phải phân biệt

| Endpoint | Trỏ vào đâu | Dùng khi |
|---|---|---|
| **Cluster (writer) endpoint** | Luôn trỏ về **writer hiện tại**, tự đổi khi failover | Mọi thao tác ghi |
| **Reader endpoint** | **Load balance DNS** qua các reader | Mọi thao tác đọc |
| **Custom endpoint** | Một nhóm instance bạn tự chọn | Tách workload: reader to cho báo cáo, reader nhỏ cho app |
| **Instance endpoint** | Đúng một instance | Debug, tuning. **Không dùng trong ứng dụng** |

Bẫy: reader endpoint làm load balancing **ở tầng DNS**, và client cache DNS. Một
ứng dụng giữ connection pool lâu dài có thể dồn hết vào một reader. Cách chữa đúng
là mở lại kết nối định kỳ hoặc dùng RDS Proxy.

### Aurora Serverless v2

Tự co giãn theo **ACU (Aurora Capacity Unit)** — mỗi ACU ≈ 2 GiB RAM cùng CPU và
network tương ứng. Bạn đặt khoảng `min`–`max` theo bước **0,5 ACU**, tối đa **256
ACU**; bản mới cho đặt `min = 0` để **tự pause** khi không có kết nối.

Khác v1: v2 scale **từng bước nhỏ, đang chạy, không ngắt kết nối**, và hỗ trợ replica,
Multi-AZ, Global Database. Chọn khi đề nói **tải thất thường**, **dev/test không dùng
ban đêm**, **không đoán được lúc ra mắt**, **nhiều tenant tải khác nhau**.

### Backtrack

"Tua ngược" cả cluster về một thời điểm trong quá khứ **tại chỗ**, chỉ mất vài phút,
không cần restore ra cluster mới.

Bốn giới hạn phải nhớ: **chỉ Aurora MySQL** (không có cho PostgreSQL), cửa sổ tối đa
**72 giờ**, phải **bật lúc tạo cluster** (bật sau thì phải restore snapshot sang
cluster mới), và nó áp cho **cả cluster** chứ không cho một bảng.

Đề cho tình huống *"vừa chạy nhầm `DELETE` không có `WHERE`, cần khôi phục nhanh
nhất"*: Aurora MySQL có backtrack → **backtrack**. Không có → **PITR**, chậm hơn vì
phải dựng cluster mới.

---

## 4. DynamoDB

Managed NoSQL key-value / document. Không có server, không có instance, không có
version để nâng cấp. Bạn tạo bảng và bắt đầu ghi.

### Partition key và sort key

**Primary key** có hai dạng: **simple** (chỉ **partition key**, mỗi giá trị PK là một
item duy nhất) và **composite** (**PK + sort key**, nhiều item chung PK và sắp xếp theo
SK).

DynamoDB **hash giá trị PK** để quyết định item nằm ở partition vật lý nào. Item
cùng PK nằm cạnh nhau, sắp xếp theo SK — gọi là **item collection**. Đó là lý do
`Query` với một PK và một điều kiện SK là thao tác rẻ nhất mà DynamoDB có.

Ví dụ single-table design từ lab:

```
Khách hàng   PK=KHACH#42   SK=HOSO
Đơn hàng     PK=KHACH#42   SK=DON#2026-08-15#0007
             PK=KHACH#42   SK=DON#2026-08-16#0011
```

Một `Query` với `PK = KHACH#42` lấy được khách **và toàn bộ đơn của họ** trong một
lần gọi. Trong SQL thì đó là một JOIN; ở đây nó chỉ là đọc tuần tự một dải.

### Hot partition — chọn PK sai

Mỗi partition vật lý phục vụ được tối đa **3.000 RCU và 1.000 WCU mỗi giây**. Nếu
90% request đổ vào một giá trị PK, bạn bị **throttle dù bảng còn thừa capacity tổng**.

Đề mô tả *"bảng bị throttle nhưng CloudWatch cho thấy capacity chưa dùng hết"* →
**hot partition**, và cách chữa **không phải** tăng capacity.

Nguyên tắc chọn PK: **cardinality cao** (nhiều giá trị phân biệt) và **truy cập đều**
(không giá trị nào chiếm phần lớn traffic). Tốt: `user_id`, `order_id`, `device_id`.
Tệ: `status` (chỉ vài giá trị), `date` (mọi ghi hôm nay dồn vào một partition). Bị dồn
thật thì dùng **write sharding** — thêm hậu tố ngẫu nhiên `2026-08-17#03` vào PK, rải
ra N shard, khi đọc thì query song song N shard.

**DynamoDB có adaptive capacity** tự tăng throughput cho partition nóng, nhưng nó
chỉ cứu được trong giới hạn tổng của bảng và trần cứng 3.000/1.000 mỗi partition.
Đừng thiết kế dựa vào nó.

Chọn sai PK là sai lầm **không sửa được** — phải tạo bảng mới và migrate.

### LSI so với GSI

| | **GSI** (Global Secondary Index) | **LSI** (Local Secondary Index) |
|---|---|---|
| Partition key | **Khác** khoá chính | **Giống** khoá chính, chỉ đổi sort key |
| Tạo lúc nào | **Bất cứ lúc nào** | **CHỈ khi tạo bảng** — không thêm sau được |
| Xoá được không | Có | Không |
| Capacity | **Riêng** của index | **Dùng chung** với bảng |
| Consistency | **Chỉ eventually consistent** | Hỗ trợ **strongly consistent** |
| Giới hạn | **20** mỗi bảng (mặc định, xin tăng được) | **5** mỗi bảng |
| Giới hạn khác | — | Item collection cùng một PK **tối đa 10 GB** |

Dòng "chỉ khi tạo bảng" là dòng đắt giá nhất: quên LSI lúc `CreateTable` thì bạn
phải tạo bảng mới. Thực tế gần như luôn dùng **GSI**.

Bẫy hay ra thi: đề hỏi *"cần đọc strongly consistent trên một index"* → phải là
**LSI**, vì GSI **không có tuỳ chọn strongly consistent**. Còn đề hỏi *"cần truy vấn
theo một thuộc tính hoàn toàn khác"* → **GSI**, vì LSI bắt buộc cùng partition key.

Chi tiết vận hành: GSI có capacity riêng, nên **GSI bị throttle sẽ làm chậm cả ghi
vào bảng gốc** (DynamoDB không ghi được vào index thì phải chờ). Đây là nguyên nhân
throttle khó chẩn đoán mà đề đôi khi mô tả.

### Capacity mode

| | **On-demand** (`PAY_PER_REQUEST`) | **Provisioned** |
|---|---|---|
| Phải đoán tải | Không | **Có** |
| Giá mỗi request | Đắt hơn đáng kể | Rẻ hơn |
| Xử lý spike | Tự động, tới **gấp đôi peak trước đó** ngay lập tức | Cần auto scaling, phản ứng chậm hơn |
| Auto scaling | Không cần | **Có**, đặt min/max/target utilization |
| Reserved capacity (giảm giá cam kết) | Không | **Có** |
| Free tier của lộ trình này | Tính theo request | **25 WCU + 25 RCU miễn phí** |
| Chọn khi | Tải thất thường, mới ra mắt, dev/test, **không đoán được** | Tải ổn định, dự đoán được, **tối ưu chi phí** |

Đơn vị capacity:

- **1 WCU** = một ghi 1 KB mỗi giây. Item lớn hơn thì làm tròn lên bội của 1 KB.
- **1 RCU** = một đọc **strongly consistent** item ≤ 4 KB mỗi giây.
  **Eventually consistent** chỉ tốn **0,5 RCU**. **Transactional** tốn **2 RCU**.
- Kích thước item được **làm tròn lên** bội của 4 KB (đọc) hoặc 1 KB (ghi).

Đổi qua lại giữa hai mode được, nhưng có giới hạn tần suất.

### Query so với Scan

| | **Query** | **Scan** |
|---|---|---|
| Đọc gì | Chỉ item thuộc **một partition key** | **Toàn bộ bảng** |
| Chi phí | Theo lượng dữ liệu **khớp** | Theo lượng dữ liệu **quét qua** |
| Tốc độ | Ổn định | Chậm dần theo kích thước bảng |
| Kết quả mỗi lần gọi | Tối đa **1 MB**, phải phân trang | Tối đa **1 MB**, phải phân trang |

Điểm mấu chốt mà đề thi hỏi: **`FilterExpression` KHÔNG làm giảm lượng đọc.**
DynamoDB đọc toàn bộ, **tính tiền toàn bộ**, rồi mới lọc trước khi trả về. Bạn trả
tiền cho mọi item bị quét qua, kể cả item bị loại.

Số thật từ lab (2.200 item):

```
Câu hỏi: tất cả đơn hàng của khách #42
  Query theo khoá chính   →  10 kết quả,    0,5 RCU,   12 ms
  Scan + FilterExpression →  10 kết quả,  138,0 RCU,  890 ms   ← đắt hơn 276 lần
```

Scan chỉ đúng khi bạn **thật sự cần cả bảng** (export, phân tích một lần) — và lúc
đó dùng `ParallelScan` để chia segment. Mọi trường hợp còn lại: nếu buộc phải Scan
thì bạn **thiếu một GSI**.

### Streams, TTL, DAX, Global Tables

**DynamoDB Streams** ghi lại mọi thay đổi item theo thứ tự, giữ **24 giờ**. Bốn
`StreamViewType`: `KEYS_ONLY`, `NEW_IMAGE`, `OLD_IMAGE`, `NEW_AND_OLD_IMAGES`.
Nối vào Lambda qua **event source mapping**. Đây là nền của kiến trúc event-driven:
ứng dụng ghi dữ liệu **không cần biết gì** về consumer.

Một chi tiết tinh tế: bản ghi `REMOVE` do **TTL** sinh ra có
`userIdentity.principalId = dynamodb.amazonaws.com`. Đó là cách duy nhất phân biệt
"người dùng xoá" với "TTL tự xoá".

**TTL**: đặt một thuộc tính số chứa Unix epoch; DynamoDB tự xoá item sau thời điểm
đó. **Hoàn toàn miễn phí, không tốn write capacity** — đó là lý do nó là đáp án cho
*"tự động dọn dữ liệu hết hạn với chi phí thấp nhất"*.

Nhưng AWS chỉ cam kết xoá **trong vòng 48 giờ**, **không tức thì**. Hệ quả thiết kế:
nếu ứng dụng **phải không** được thấy item hết hạn, bạn vẫn phải tự lọc theo
`expires_at` khi đọc.

**DAX (DynamoDB Accelerator)**: cache in-memory trước DynamoDB, đưa latency đọc từ
**mili giây xuống micro giây**. Điểm mạnh so với ElastiCache: **API tương thích hoàn
toàn** — đổi endpoint, không sửa code, không tự viết logic invalidation. Nó là
**write-through** và chỉ tăng tốc **đọc**. Đề *"DynamoDB đã nhanh nhưng cần micro giây,
ít sửa code nhất"* → DAX; *"cache truy vấn phức tạp hoặc cache cho RDS"* → ElastiCache.

**Global Tables**: nhân bản multi-region **active-active** — ghi được ở mọi region,
xung đột giải quyết theo **last writer wins**, yêu cầu bảng bật **Streams**. Đề nhắc
*"người dùng toàn cầu, ghi ở mọi region, latency thấp"* → Global Tables.

Ba giới hạn khác: **item tối đa 400 KB** (vượt thì lưu ở S3, giữ đường dẫn trong item),
số bảng và item **không giới hạn thực tế**, và mọi ghi đã được nhân bản qua **3 AZ** —
DynamoDB không có khái niệm "bật Multi-AZ".

---

## 5. ElastiCache và các mẫu caching

| | **Redis / Valkey** | **Memcached** |
|---|---|---|
| Cấu trúc dữ liệu | String, list, set, sorted set, hash, geospatial, stream | **Chỉ string** |
| Multi-threaded | Không (mỗi node một luồng chính) | **Có** — tận dụng node nhiều core |
| Replication | **Có** | Không |
| Multi-AZ + auto failover | **Có** | Không |
| Snapshot / persistence | **Có** | Không |
| Transaction, Pub/Sub, Lua script | **Có** | Không |
| Scale | Thêm shard (cluster mode) và replica | **Thêm node**, đơn giản |
| AWS quản lý như | Stateful, giống RDS (có failover) | Pool node bỏ đi được, giống ASG |

Chọn thế nào — từ khoá trong đề:

- **"HA", "failover", "không mất cache khi node chết", "persistence", "leaderboard",
  "pub/sub", "geospatial"** → **Redis/Valkey**.
- **"đơn giản nhất", "chỉ cache object", "scale ngang bằng cách thêm node",
  "multi-threaded, node nhiều core"** → **Memcached**.

Thực tế Redis/Valkey là lựa chọn mặc định; Memcached chỉ thắng ở tình huống rất hẹp.

### Hai mẫu caching phải phân biệt

**Lazy loading (cache-aside)** — hỏi cache trước; MISS thì đọc database, ghi vào cache
rồi trả về. Ưu: chỉ cache thứ **thật sự được đọc**, cache chết không làm hỏng hệ thống.
Nhược: **miss đầu tiên chậm** (ba lượt đi về) và **dữ liệu có thể cũ** nếu database bị
sửa mà không invalidate.

**Write-through** — ghi vào database và cache cùng lúc. Ưu: cache **luôn tươi**. Nhược:
**ghi chậm hơn**, cache chứa cả dữ liệu **không ai đọc** (lãng phí RAM), và cache mới
dựng thì trống cho tới khi có ghi.

Thực tế kết hợp cả hai cộng thêm **TTL** trên mọi key để giới hạn thời gian dữ liệu cũ
tồn tại. Đề hỏi *"đảm bảo cache không bao giờ cũ"* → write-through; *"chỉ cache thứ
được dùng, tiết kiệm bộ nhớ"* → lazy loading.

Use case ElastiCache hay ra thi nhất: **lưu session của ứng dụng web** để đám EC2
sau ALB trở thành stateless và tắt được sticky session ([tuần 3](w03-ec2-alb-asg.md)).

---

## 6. Bốn dịch vụ chỉ cần nhận diện tình huống

| Dịch vụ | Nó là gì | Đề dùng từ khoá gì |
|---|---|---|
| **Redshift** | Data warehouse OLAP, lưu theo cột, MPP | "**data warehouse**", "BI", "phân tích trên petabyte", "JOIN nhiều bảng cực lớn", "báo cáo phức tạp". **Redshift Spectrum** query thẳng trên S3 |
| **Athena** | Query SQL serverless trực tiếp trên S3 | "**không muốn dựng hạ tầng**", "query **không thường xuyên**", "dữ liệu **đã ở S3**", "trả tiền theo lượng dữ liệu quét". Dùng **Parquet + partition** để giảm chi phí |
| **Neptune** | Graph database (Gremlin, openCypher, SPARQL) | "**mạng xã hội**", "**công cụ gợi ý**", "**phát hiện gian lận**", "đồ thị tri thức", "quan hệ nhiều tầng" |
| **DocumentDB** | Managed, tương thích API MongoDB | "**MongoDB**", "di trú ứng dụng MongoDB hiện có", "JSON document, không muốn viết lại code" |

Ranh giới hay nhầm: **Redshift là OLAP, RDS là OLTP** — giao dịch nhỏ, nhiều, đồng thời
→ OLTP; quét toàn bộ lịch sử để tổng hợp → OLAP. **Athena so với Redshift**: Athena rẻ
và không cần vận hành nhưng chậm với truy vấn lặp lại; Redshift đắt nhưng nhanh và ổn
định cho dashboard chạy liên tục.

---

## Bảng quyết định

| Đề mô tả | Chọn | Vì sao không chọn cái kia |
|---|---|---|
| Ứng dụng cũ dùng MySQL/PostgreSQL, muốn lên cloud, ít sửa code nhất | **RDS** | Aurora: đắt hơn, và "lift-and-shift" không cần |
| Như trên nhưng cần **hiệu năng cao hơn, tự lớn storage, failover nhanh** | **Aurora** | RDS: storage phải tự tăng, failover chậm hơn |
| **Database quá tải vì quá nhiều truy vấn ĐỌC** | **Read Replica** | Multi-AZ: standby **không phục vụ đọc**, không giảm tải một chút nào |
| **Database phải sống sót khi một AZ chết**, tự động | **Multi-AZ** | Read Replica: failover thủ công (phải promote) |
| **Tải ghi** quá cao cho một instance | **Sharding ở tầng ứng dụng**, hoặc **DynamoDB** | Read Replica: chỉ giúp đọc |
| Cần **cả hai**: HA và scale đọc | **Multi-AZ + Read Replica**, dùng chung được | Chọn một cái: thiếu một nửa yêu cầu |
| Lambda mở/đóng hàng nghìn kết nối, RDS hết connection | **RDS Proxy** | Tăng instance class: đắt và không giải đúng vấn đề |
| Traffic **thất thường, không đoán được**, không muốn quản lý instance | **Aurora Serverless v2** hoặc **DynamoDB on-demand** | Provisioned: hoặc thừa hoặc thiếu |
| **Hàng triệu request/giây, latency mili giây ổn định, schema linh hoạt** | **DynamoDB** | RDS: có trần một node |
| DynamoDB đã nhanh nhưng cần **micro giây** | **DAX** | ElastiCache: phải tự viết logic cache |
| Cache session / kết quả truy vấn nặng, **cần replication và persistence** | **ElastiCache Redis/Valkey** | Memcached: không có replication, không persistence |
| Cache đơn giản, nhiều core, **scale ngang bằng cách thêm node** | **ElastiCache Memcached** | Redis: phức tạp hơn mức cần |
| **Báo cáo phân tích trên hàng tỉ dòng**, JOIN nhiều bảng lớn | **Redshift** | RDS: OLTP, không phải OLAP |
| **Query SQL không thường xuyên trên dữ liệu ở S3**, không muốn dựng cluster | **Athena** | Redshift: phải nạp dữ liệu và trả tiền cluster |
| **Quan hệ xã hội, phát hiện gian lận, đồ thị tri thức** | **Neptune** | RDS: JOIN đệ quy nhiều tầng là ác mộng |
| Ứng dụng **MongoDB** hiện có, muốn managed | **DocumentDB** | DynamoDB: phải viết lại toàn bộ tầng dữ liệu |
| Dữ liệu **chuỗi thời gian** từ IoT/metric | **Timestream** | RDS: index theo thời gian không tối ưu bằng |
| Cần đọc **strongly consistent** trên NoSQL | DynamoDB (chọn `ConsistentRead=true`) | GSI: **chỉ eventually consistent**, không có tuỳ chọn |

Từ khoá trong đề đáng khoanh tròn: **"least operational overhead"** → managed hoặc
serverless. **"lowest cost"** → on-demand nếu tải thấp/thất thường, provisioned nếu
tải ổn định. **"minimal code changes"** → giữ nguyên engine (RDS/Aurora tương thích).
**"millisecond"** → DynamoDB. **"microsecond"** → DAX hoặc ElastiCache.

## Số phải thuộc

| Con số | Giá trị |
|---|---|
| RDS automated backup retention | **1–35 ngày** (`0` = tắt) |
| RDS PITR | về bất kỳ giây nào trong retention, thường trễ ~5 phút so với hiện tại |
| RDS Read Replica | tới **15** với MySQL/MariaDB/PostgreSQL |
| RDS Multi-AZ | **1 standby**, synchronous, **không phục vụ đọc**, giá **gấp đôi** |
| Aurora storage | **6 bản sao** qua **3 AZ**, ghi quorum **4/6**, đọc **3/6** |
| Aurora cluster volume | tự lớn, tối đa **128 TiB** (tới 256 TiB ở một số bản) |
| Aurora Replica | tối đa **15**, replication lag thường **< 100 ms** |
| Aurora failover | thường **< 30 giây** |
| Aurora Serverless v2 | **0/0,5 – 256 ACU**, bước **0,5**, mỗi ACU ≈ **2 GiB RAM** |
| Aurora Backtrack | **chỉ Aurora MySQL**, cửa sổ tối đa **72 giờ** |
| DynamoDB item tối đa | **400 KB** |
| DynamoDB partition | **3.000 RCU** và **1.000 WCU** mỗi giây |
| DynamoDB LSI / GSI | **5 LSI** (chỉ tạo lúc `CreateTable`) · **20 GSI** mặc định |
| LSI item collection | tối đa **10 GB** cho một partition key |
| Query/Scan mỗi lần gọi | tối đa **1 MB** |
| RCU / WCU | 1 RCU = đọc strongly consistent **4 KB** (eventual = 0,5; transactional = 2) · 1 WCU = ghi **1 KB** |
| DynamoDB Streams | giữ **24 giờ** |
| DynamoDB TTL | xoá **trong vòng 48 giờ**, miễn phí |

## Bẫy kinh điển

**"Multi-AZ giúp giảm tải đọc."** Sai hoàn toàn. Standby **không nhận một request
nào**. Đề nói "quá tải vì đọc" thì đáp án là **Read Replica**.

**"Read Replica giúp HA."** Chỉ một phần: bạn phải **promote thủ công**, và có
replication lag nên có thể mất dữ liệu. HA tự động là **Multi-AZ**.

**"Xoá DB instance là xoá hết."** Automated backup bị xoá theo, nhưng **manual snapshot
và final snapshot vẫn còn và vẫn tính tiền**.

**"Đổi parameter là có hiệu lực ngay."** Tham số **static** cần **reboot**, và không
sửa được default parameter group — phải tạo custom.

**"Aurora là RDS chạy nhanh hơn."** Không — kiến trúc khác hẳn: storage tách khỏi
compute, 6 bản qua 3 AZ, replica dùng chung volume.

**"Aurora Multi-AZ phải bật riêng."** Storage của Aurora **luôn** trải 3 AZ. Cái
bạn bật là **có reader ở AZ khác** để failover nhanh.

**"Backtrack dùng được cho Aurora PostgreSQL."** Không — **chỉ Aurora MySQL**, và
phải bật lúc tạo cluster.

**"Reader endpoint cân bằng tải hoàn hảo."** Nó cân bằng **ở tầng DNS**. Connection
pool giữ lâu sẽ dồn vào một reader.

**"Tăng capacity sẽ hết throttle."** Không, nếu nguyên nhân là **hot partition**.
Trần **3.000 RCU / 1.000 WCU mỗi partition** là cứng. Phải sửa partition key hoặc
write sharding.

**"`FilterExpression` giảm chi phí Scan."** Không. DynamoDB đọc hết, tính tiền hết,
rồi mới lọc.

**"Thêm LSI sau cũng được."** Không. LSI **chỉ tạo được lúc `CreateTable`** và
không xoá được. GSI thì thêm bớt tự do.

**"GSI đọc được strongly consistent."** Không, GSI **chỉ eventually consistent**.
Cần strong consistency trên index → **LSI**.

**"DynamoDB cần bật Multi-AZ."** Không có khái niệm đó — mọi ghi đã được nhân bản
qua 3 AZ sẵn.

**"DAX thay được ElastiCache."** DAX **chỉ dùng cho DynamoDB**. Cache cho RDS hay
cache kết quả tính toán → ElastiCache.

**"Memcached có replication."** Không: không replication, không persistence, không
failover. Cần những thứ đó → **Redis/Valkey**.

## Nối với lab

[`../../learn-aws/labs/w05-databases/`](../../learn-aws/labs/w05-databases/)

Lab chia đôi theo chi phí: **DynamoDB chơi thoải mái** (~$0, nằm trong always free),
**RDS bật đúng 2 tiếng rồi xoá** (đủ để lấy $20 nhiệm vụ credit).

| Khái niệm trong bài | Quan sát gì khi chạy lab |
|---|---|
| **Query so với Scan** | Playbook nạp 2.200 item rồi in ra số thật: `0,5 RCU / 12 ms` so với `138 RCU / 890 ms`. Đây là phần đáng giá nhất của lab |
| **`FilterExpression` không giảm chi phí** | Nhìn cột RCU của Scan có filter — bằng đúng Scan không filter |
| **Single-table design** | Đơn hàng dùng **chung partition key** với khách (`PK=KHACH#42`), nên "lấy khách và toàn bộ đơn" chỉ tốn **một** Query |
| **Vì sao GSI tồn tại** | Câu hỏi *"tất cả đơn đang giao, của mọi khách"* — khoá chính không trả lời được, không có GSI thì buộc phải Scan |
| **Hot partition** | Tự nghĩ: nếu đổi PK sang `TRANGTHAI` thì cardinality còn bao nhiêu, và điều gì xảy ra |
| **Streams + TTL** | Bảng đặt `NEW_AND_OLD_IMAGES`, nối Lambda. Đọc code Lambda tìm chỗ phân biệt `REMOVE` do người dùng và `REMOVE` do TTL (`principalId = dynamodb.amazonaws.com`) |
| **Multi-AZ vs Read Replica** | Lab **cấm bật Multi-AZ** (nhân đôi giá, mà standby không phục vụ đọc nên **không có gì để quan sát**). Học bằng bảng, viết lại bằng lời của mình |
| **DB subnet group ≥ 2 AZ** | `subnet_ids = module.vpc[0].private_subnet_ids` — RDS bắt buộc trải 2 AZ **kể cả khi Single-AZ** |
| **Mật khẩu trong state file** | `manage_master_user_password = true` để RDS tự sinh và tự xoay, thay vì để mật khẩu **nguyên văn** trong Terraform state |
| **Bẫy snapshot** | `skip_final_snapshot = true` cho lab. Production thì ngược lại. `verify.sh` mục 8 quét snapshot bị bỏ quên |

Aurora và ElastiCache **không lab** tuần này — quá đắt so với ngân sách, và chạy chúng
không dạy thêm điều gì đề thi hỏi.

## Tự kiểm tra

<details>
<summary>1. Ứng dụng chậm vì dashboard phân tích chạy song song với production trên cùng một RDS. Multi-AZ có giúp không?</summary>

Không, một chút nào. Standby của Multi-AZ **không nhận request**, nó chỉ nhận
replication synchronous và chờ. Đáp án là **Read Replica**: trỏ dashboard vào replica
để tách hoàn toàn tải đọc khỏi instance chính. Nếu dashboard thật sự là OLAP — quét
lịch sử, tổng hợp trên hàng tỉ dòng — thì đáp án đúng hơn nữa là **Redshift** hoặc
**Athena**, vì đó không phải việc của một database OLTP.
</details>

<details>
<summary>2. Bạn xoá RDS instance và bỏ chọn "create final snapshot". Tháng sau vẫn thấy hoá đơn RDS. Vì sao?</summary>

Automated backup bị xoá theo instance, nhưng **manual snapshot thì không**. Bất kỳ
snapshot nào bạn từng tự tạo (hoặc final snapshot từ lần xoá trước) đều sống mãi và
tính phí lưu trữ cho tới khi bị xoá tay. Đây là nguồn "hoá đơn ma" phổ biến — dùng
`find-orphans.sh` hoặc `describe-db-snapshots --snapshot-type manual` để quét.
</details>

<details>
<summary>3. Vì sao thêm một Aurora Replica mất vài phút, còn thêm một RDS Read Replica mất hàng giờ?</summary>

RDS Read Replica là một **DB instance mới với storage riêng**: RDS phải chụp snapshot
của instance nguồn, restore ra volume mới, rồi bắt kịp replication. Aurora Replica
**không copy dữ liệu gì cả** — nó gắn vào **cùng một cluster volume** đã tồn tại. Đây
chính là ý nghĩa của "storage tách rời khỏi compute", và nó cũng giải thích vì sao
replication lag của Aurora thường dưới 100 ms trong khi RDS có thể nhiều giây.
</details>

<details>
<summary>4. Bảng DynamoDB provisioned 1.000 WCU. CloudWatch cho thấy chỉ dùng 400 WCU nhưng vẫn bị throttle. Chuyện gì xảy ra?</summary>

**Hot partition.** Mỗi partition vật lý chỉ phục vụ tối đa **1.000 WCU/giây**, và
capacity được chia đều theo partition. Nếu phần lớn ghi dồn vào một giá trị partition
key thì partition đó chạm trần trong khi tổng của bảng còn thừa. Adaptive capacity
giúp được phần nào nhưng không vượt được trần cứng. Cách chữa là sửa thiết kế khoá —
chọn PK cardinality cao hơn, hoặc **write sharding** (thêm hậu tố ngẫu nhiên vào PK
và query song song khi đọc). Tăng capacity **không** chữa được.
</details>

<details>
<summary>5. Đề: "Cần truy vấn bảng theo một thuộc tính khác khoá chính, và kết quả phải strongly consistent." Chọn gì?</summary>

Đây là câu hỏi cài bẫy. Truy vấn "theo thuộc tính khác khoá chính" gợi ý **GSI**,
nhưng GSI **chỉ hỗ trợ eventually consistent** — không có tuỳ chọn nào bật lên được.
Muốn strongly consistent trên index thì phải là **LSI**, mà LSI bắt buộc **cùng
partition key** với bảng và **chỉ tạo được lúc `CreateTable`**. Nên đáp án phụ thuộc
thuộc tính đó: nếu chỉ là sort key khác trong cùng partition → LSI (và phải thiết kế
từ đầu). Nếu là partition key hoàn toàn khác → buộc phải GSI, và yêu cầu strong
consistency phải được xử lý ở tầng khác (đọc lại từ bảng gốc bằng `GetItem`).
</details>

<details>
<summary>6. Lambda scale ra 800 concurrent execution và RDS PostgreSQL sập với "too many connections". Ba cách sửa, cách nào đúng nhất?</summary>

Ba cách: (a) tăng instance class để có `max_connections` lớn hơn — đắt và chỉ đẩy
vấn đề lùi lại; (b) đặt reserved concurrency cho Lambda — hạn chế thông lượng của
chính ứng dụng; (c) **RDS Proxy** — đúng nhất. Proxy gom connection pool và tái sử
dụng kết nối tới database, nên 800 Lambda chỉ tương ứng vài chục kết nối thật. Bonus:
proxy còn giữ kết nối của client trong lúc RDS failover, giảm thời gian gián đoạn
tới ~66%.
</details>

<details>
<summary>7. Đề: "Vừa chạy nhầm UPDATE không có WHERE trên Aurora MySQL, cần khôi phục nhanh nhất." So sánh backtrack và PITR.</summary>

**Backtrack** nếu cluster đã bật nó: tua ngược **tại chỗ**, mất vài phút, không tạo
cluster mới, cửa sổ tối đa **72 giờ**. **PITR** thì luôn khả dụng nhưng phải
**restore ra một cluster mới** — mất hàng chục phút tới hàng giờ tuỳ kích thước, rồi
còn phải chuyển endpoint của ứng dụng. Cái bẫy của backtrack: phải **bật lúc tạo
cluster**; bật sau thì phải restore snapshot sang cluster mới, tức là đã mất luôn lợi
thế tốc độ. Và backtrack **không có cho Aurora PostgreSQL**.
</details>

<details>
<summary>8. Cache dùng lazy loading. Ai đó sửa dữ liệu thẳng trong database. Chuyện gì xảy ra và sửa thế nào?</summary>

Cache vẫn giữ giá trị cũ cho tới khi key hết hạn hoặc bị đẩy ra vì thiếu bộ nhớ —
ứng dụng phục vụ dữ liệu sai mà không có tín hiệu gì. Ba cách xử lý: (a) đặt **TTL**
trên mọi key để giới hạn cửa sổ dữ liệu cũ (rẻ nhất, luôn nên làm); (b) chuyển sang
**write-through** để cache được cập nhật cùng lúc với database; (c) **invalidate
tường minh** trong đường ghi. Bài học kiến trúc: mọi ghi đều phải đi qua một đường
duy nhất — sửa thẳng vào database là chính vấn đề.
</details>

<details>
<summary>9. Đề: "Ứng dụng toàn cầu, người dùng ở châu Âu và châu Á đều phải GHI với latency thấp." Chọn gì?</summary>

**DynamoDB Global Tables** — nhân bản multi-region **active-active**, ghi được ở mọi
region, xung đột giải quyết theo **last writer wins** (yêu cầu bảng bật Streams). Đây
là điểm khác biệt then chốt so với **cross-region Read Replica của RDS** và
**Aurora Global Database**: cả hai cái sau chỉ có **một writer**, region phụ chỉ đọc.
Nếu đề chỉ nói "**đọc** với latency thấp ở nhiều region" thì Aurora Global Database
hoặc cross-region read replica đủ dùng — hãy đọc kỹ đề là đọc hay ghi.
</details>

<details>
<summary>10. Bảng DynamoDB lưu log sự kiện, bật TTL 30 ngày. Kiểm toán viên phàn nàn vẫn thấy bản ghi 31 ngày tuổi. Bạn giải thích thế nào?</summary>

TTL là quá trình nền, AWS chỉ cam kết xoá **trong vòng 48 giờ** sau thời điểm hết
hạn — **không tức thì**. Đó là cái giá của việc nó **miễn phí và không tốn write
capacity**. Nếu yêu cầu nghiệp vụ là "tuyệt đối không được thấy bản ghi hết hạn" thì
TTL không đủ: ứng dụng phải **tự lọc theo `expires_at` khi đọc**, hoặc dùng một quy
trình xoá chủ động (nhưng thao tác đó tốn WCU). TTL là cơ chế **dọn dẹp**, không phải
cơ chế **thực thi chính sách**.
</details>

## Ngoài phạm vi

- **Aurora Global Database write forwarding, Aurora multi-master** — mức Professional.
  [Tài liệu](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-global-database.html)
- **Aurora DSQL, DynamoDB multi-Region strong consistency (MRSC)** — quá mới, chưa
  vào SAA-C03.
- **DynamoDB PartiQL, transaction API, vector index** — biết `TransactWriteItems`
  tồn tại là đủ.
- **Tuning từng engine** (`innodb_buffer_pool_size`, `work_mem`) — không ra thi.
- **Redshift chi tiết**: distribution style, sort key, RA3, Concurrency Scaling,
  Spectrum sâu — chỉ cần nhận diện "OLAP → Redshift".
- **DMS và Schema Conversion Tool** — [tuần 11](w11-dr-hybrid.md).
- **Keyspaces, MemoryDB, Timestream chi tiết** — nhận diện use case là đủ.
- **ElastiCache cluster mode, slot, resharding** — vận hành, không ra thi.

## Nguồn

- [Working with DB instance read replicas](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ReadRepl.html)
- [Configuring and managing a Multi-AZ deployment for Amazon RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.MultiAZ.html)
- [Backing up and restoring your Amazon RDS DB instance](https://docs.aws.amazon.com/AmazonRDS/latest/gettingstartedguide/managing-backup-restore.html)
- [Amazon RDS features — point-in-time recovery](https://aws.amazon.com/rds/features/)
- [Using Amazon RDS Proxy](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy.html)
- [Amazon Aurora DB clusters](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.html)
- [Amazon Aurora storage](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.Overview.StorageReliability.html)
- [Amazon Aurora Under the Hood: Reducing Costs Using Quorum Sets](https://aws.amazon.com/blogs/database/amazon-aurora-under-the-hood-reducing-costs-using-quorum-sets/)
- [ServerlessV2ScalingConfigurationInfo (ACU range)](https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_ServerlessV2ScalingConfigurationInfo.html)
- [Configure backtrack on an Aurora MySQL DB cluster](https://repost.aws/knowledge-center/aurora-mysql-cluster-backtrack)
- [Quotas in Amazon DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/ServiceQuotas.html)
- [Partitions and data distribution in DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.Partitions.html)
- [DynamoDB burst and adaptive capacity](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/burst-adaptive-capacity.html)
- [DynamoDB read and write operations (RCU/WCU)](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/read-write-operations.html)
- [Comparing node-based Valkey, Memcached, and Redis OSS clusters](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/SelectEngine.html)
- [Caching strategies — lazy loading and write-through](https://docs.aws.amazon.com/AmazonElastiCache/latest/dg/Strategies.html)
