# Tuần 6 — Serverless: Lambda, API Gateway và bạn bè

> Tuần này trả lời một câu hỏi kiến trúc duy nhất: **khi nào bạn không nên sở hữu
> một cái server nào cả** — và cái giá phải trả cho lựa chọn đó. Bạn đã biết cách
> chạy container trên máy mình và trên Kubernetes. Ở đây bạn giao luôn cả vòng đời
> tiến trình cho AWS, đổi lấy hai thứ: scale về 0 và không phải patch OS. Đổi lại
> bạn mất quyền kiểm soát cold start, thời gian chạy tối đa, và mô hình giá lật
> ngược hoàn toàn khi tải trở nên đều đặn.

## Học xong bài này bạn phải trả lời được

1. Cold start đến từ đâu, và ba cách giảm nó khác nhau ở chỗ nào (provisioned
   concurrency, SnapStart, viết code cho đúng)?
2. Reserved concurrency và provisioned concurrency — cái nào giới hạn, cái nào
   làm ấm? Vì sao đặt reserved = 0 lại là nút tắt khẩn cấp?
3. Ba kiểu gọi Lambda (đồng bộ, bất đồng bộ, poll-based) khác nhau thế nào về
   **retry và DLQ**? Vì sao Lambda đọc SQS thì DLQ nằm trên queue chứ không nằm
   trên function?
4. Khi nào Lambda cần đặt trong VPC, và vì sao đặt vào VPC lại kéo theo NAT
   Gateway hoặc VPC endpoint?
5. REST API, HTTP API hay WebSocket API — chọn cái nào theo tình huống nào? Ba
   loại authorizer khác nhau ra sao?
6. Khi nào dùng ALB làm trigger cho Lambda thay vì API Gateway?
7. Khi nào một chuỗi Lambda gọi nhau là sai, và Step Functions giải quyết điều gì?
8. Đặt Lambda, Fargate, ECS-on-EC2 và EC2 lên cùng một phổ — trục nào phân biệt
   chúng, và tải kiểu nào thì serverless hết rẻ?

## Bản đồ khái niệm

```
                        ┌─────────────── TẦNG VÀO ────────────────┐
   client ──HTTPS──►    │  API Gateway (REST / HTTP / WebSocket)  │
                        │  hoặc  ALB      hoặc  Lambda Function URL│
                        └───────┬─────────────────────────────────┘
                                │ ĐỒNG BỘ — caller chịu trách nhiệm retry
                                ▼
   S3 event ──┐        ┌────────────────────┐        ┌──────────────────┐
   SNS      ──┼─BẤT ĐB►│      LAMBDA        │◄─POLL──┤ SQS / Kinesis /  │
   EventBridge┘        │  execution env     │        │ DynamoDB Streams │
                       │  = microVM Firecra.│        └──────────────────┘
                       │  INIT → INVOKE →   │         (event source mapping:
                       │  FREEZE → INVOKE   │          Lambda service tự poll)
                       └──────┬──────┬──────┘
        execution role (IAM)  │      │  resource policy (ai được gọi tôi)
                              ▼      ▼
                    DynamoDB / S3 / bất kỳ API AWS nào
                    (KHÔNG cần VPC — chúng là API công khai)

   Cần orchestration?  →  Step Functions gói các Lambda lại thành state machine
   Cần đăng nhập?      →  Cognito user pool (xác thực) + identity pool (cấp credential AWS)
```

Bốn thứ trên bản đồ là bốn thứ bạn phải quyết định trong mọi kiến trúc serverless:
**ai gọi (tầng vào), gọi theo kiểu nào (đồng bộ/bất đồng bộ/poll), chạy bằng quyền
gì (execution role), và ai điều phối (code hay state machine)**.

---

## 1. Serverless nghĩa là gì — và không nghĩa là gì

Bạn đã quen mô hình: viết Dockerfile, build image, đẩy lên registry, khai báo
Deployment, Kubernetes lo scheduling. Serverless bỏ đi ba lớp: image, node, và
scheduler. Bạn giao **một hàm** cùng runtime, AWS lo phần còn lại.

Bốn tính chất, theo đúng thứ tự quan trọng với đề thi:

| Tính chất | Nghĩa thực tế | Hệ quả kiến trúc |
|---|---|---|
| Không quản lý server | Không patch OS, không chọn AMI, không SSH | Bớt việc Domain 1 (bảo mật OS) |
| Scale tự động, kể cả **về 0** | 0 request = 0 execution environment | Không tốn tiền khi rảnh |
| Trả tiền theo lần dùng | GB-giây + số request, không phải giờ máy | Đây là chỗ đánh đổi lật ngược |
| Sẵn sàng cao mặc định | Chạy trải nhiều AZ, bạn không cấu hình gì | Không cần ASG, không cần health check |

**Serverless không nghĩa là:** *không có server* (có — microVM Firecracker do AWS
quản lý); *luôn rẻ hơn* (xem mục 13, có điểm giao rất rõ); *không có vận hành*
(bạn đổi "patch kernel" lấy "hiểu cold start, concurrency, idempotency, giới hạn
15 phút"); *chỉ có Lambda* (S3, DynamoDB, SQS, SNS, Fargate, Aurora Serverless v2
đều serverless theo nghĩa không có instance nào bạn sở hữu).

Đề SAA gần như luôn diễn đạt serverless bằng cụm **"least operational overhead"**.
Thấy cụm đó, ưu tiên managed/serverless trước khi đọc đáp án còn lại.

---

## 2. Execution model — cái quyết định mọi thứ còn lại

Một **execution environment** là một microVM. Vòng đời của nó có ba pha:

```
INIT      tải code → khởi động runtime → chạy code ngoài handler
          (chỉ chạy MỘT lần cho mỗi environment)
   │
   ▼
INVOKE    chạy handler(event, context)
   │
   ▼
FREEZE    tiến trình bị đóng băng, KHÔNG bị xoá
   │      → biến toàn cục còn nguyên, /tmp còn nguyên, kết nối TCP còn nguyên
   │      → thread nền cũng bị đóng băng (đây là chỗ bug hay xảy ra)
   ▼
INVOKE    lần gọi tiếp theo dùng lại environment này  ← "warm start"
   ...
SHUTDOWN  AWS thu hồi sau một khoảng nhàn rỗi (không có SLA công bố)
```

Ba hệ quả bạn phải nhớ:

1. **Khởi tạo nặng đặt ngoài handler.** Client SDK, kết nối DB, đọc cấu hình —
   đặt ở phạm vi module. Chúng chạy một lần mỗi cold start, không phải mỗi request.
   Đây chính là quyết định số 1 trong lab tuần này.
2. **Đừng giữ state trong biến toàn cục để làm logic.** Environment có thể biến
   mất bất cứ lúc nào, và hai request liên tiếp có thể rơi vào hai environment
   khác nhau. Cache thì được; đếm số thì không.
3. **Một environment xử lý đúng một request tại một thời điểm.** Không có
   thread pool phục vụ nhiều request song song như một web server thường. Muốn
   xử lý 100 request cùng lúc thì phải có 100 environment — đó chính là
   *concurrency*.

**Memory là núm điều chỉnh duy nhất.** Không có nút chỉnh CPU. Lambda cấp CPU tỉ
lệ thuận với memory; tại **1.769 MB** hàm có tương đương **1 vCPU**. Hệ quả phản
trực giác: với hàm nặng CPU, tăng memory có thể làm **giảm** tổng chi phí, vì thời
gian chạy giảm nhanh hơn đơn giá tăng.

---

## 3. Cold start — nguyên nhân và ba cách giảm khác nhau

Cold start = thời gian pha INIT. Nó gồm:

| Thành phần | Ai chịu trách nhiệm | Giảm bằng cách nào |
|---|---|---|
| Tải và giải nén deployment package | AWS + kích thước package của bạn | Package nhỏ, bỏ dependency thừa |
| Khởi động runtime | Runtime bạn chọn | Python/Node nhanh; Java/.NET chậm nhất |
| Chạy code khởi tạo (ngoài handler) | Bạn | Lazy init thứ không dùng ngay |
| Gắn ENI vào VPC | AWS | **Đã hết là vấn đề** — xem mục 8 |

Ba công cụ, và chúng **không thay thế nhau**:

**Provisioned concurrency.** Bạn trả tiền để AWS giữ sẵn N environment đã INIT
xong. Request rơi vào N environment đó không có cold start. Vượt N thì tràn sang
on-demand và vẫn cold start bình thường. Tính tiền theo thời gian giữ ấm, kể cả
khi không có request nào — đây là chỗ hoá đơn serverless bắt đầu giống hoá đơn EC2.
Dùng khi có SLA độ trễ p99 nghiêm ngặt, và thường kết hợp Application Auto Scaling
để chỉ bật ấm trong giờ cao điểm.

**SnapStart.** Lambda chạy INIT một lần, chụp **snapshot** của memory và disk đã
khởi tạo, mã hoá và cache lại; các invoke sau khôi phục từ snapshot thay vì INIT
lại. Miễn phí thêm (chỉ trả phí khôi phục và lưu cache tuỳ runtime — kiểm tra lại
trang pricing). Ràng buộc phải thuộc:

- Chỉ có ở **Java 11+, Python 3.12+, .NET 8+**. Không có ở Node.js, Ruby, runtime
  OS-only, hay container image.
- **Không dùng chung với provisioned concurrency.** Chọn một.
- Không dùng được với EFS, hay ephemeral storage lớn hơn 512 MB.
- Chỉ áp dụng cho **version đã publish** và alias trỏ tới version — không áp dụng
  cho `$LATEST`.
- Snapshot làm cho state khởi tạo bị **nhân bản**: nếu bạn sinh số ngẫu nhiên hay
  mở kết nối trong pha INIT, mọi environment khôi phục từ snapshot sẽ có cùng giá
  trị / cùng kết nối chết. Đây là bẫy đúng nghĩa.

**Viết code cho đúng.** Rẻ nhất và luôn nên làm trước hai cái trên: package nhỏ,
import có chọn lọc, khởi tạo client ngoài handler, không nhét toàn bộ SDK vào.

> Bẫy thi: "giảm cold start cho hàm Java, không muốn trả thêm phí giữ ấm" →
> **SnapStart**. "Đảm bảo độ trễ ổn định cho lưu lượng dự đoán được, chấp nhận trả
> tiền" → **provisioned concurrency**.

---

## 4. Concurrency — reserved và provisioned là hai thứ khác hẳn nhau

Công thức nền: **concurrency = số request/giây × thời gian xử lý trung bình (giây)**.
100 rps × 200 ms = 20 concurrency.

| | Reserved concurrency | Provisioned concurrency |
|---|---|---|
| Nó làm gì | **Giới hạn trên** và đồng thời **đặt chỗ** | Giữ sẵn N environment đã ấm |
| Có tốn thêm tiền không | **Không** | **Có** — trả theo thời gian giữ ấm |
| Ảnh hưởng cold start | Không | Loại bỏ trong phạm vi N |
| Dùng để | Chặn một hàm ăn hết quota của cả account; bảo vệ database phía sau khỏi quá tải | Ổn định độ trễ p99 |
| Đặt = 0 | **Tắt hoàn toàn hàm** — nút dừng khẩn cấp | Không có ý nghĩa tương tự |

Quota mặc định mỗi account, mỗi region: **1.000** concurrent execution. Trong đó
Lambda **luôn giữ lại 100** cho các hàm không đặt reserved — nên bạn chỉ đặt
reserved được tối đa 900 (với quota mặc định). Vượt quota thì:

- Gọi **đồng bộ** → lỗi `429 TooManyRequestsException`, caller phải tự retry.
- Gọi **bất đồng bộ** hoặc **event source mapping** → Lambda tự retry, message
  không mất ngay.

Đây là lý do reserved concurrency là một công cụ **kiến trúc**, không phải công cụ
tối ưu: nó biến Lambda thành một cái van, giữ cho RDS phía sau không bị 3.000
kết nối cùng lúc.

---

## 5. Giới hạn cứng — bảng bạn phải thuộc

| Thứ | Giá trị | Ghi chú |
|---|---|---|
| Memory | 128 MB – 10.240 MB, bước 1 MB | 1.769 MB = 1 vCPU |
| Timeout | tối đa **900 giây (15 phút)** | Việc dài hơn → Fargate / Step Functions |
| Payload đồng bộ | **6 MB** mỗi chiều | Response stream: tới 200 MB |
| Payload bất đồng bộ | **1 MB** | Lý do phải dùng "claim check" qua S3 |
| Ephemeral storage `/tmp` | 512 MB – 10.240 MB | Mặc định 512 MB |
| Layer | tối đa **5** layer mỗi hàm | |
| Package .zip | 50 MB nén / **250 MB** giải nén (gồm cả layer) | Lớn hơn → container image tới 10 GB |
| Biến môi trường | 4 KB tổng cộng | |
| Concurrency mặc định | 1.000 / account / region | Tăng được qua Service Quotas |

Ba giới hạn ra thi nhiều nhất: **15 phút**, **6 MB đồng bộ**, **10.240 MB memory**.

**Layer** là archive .zip chứa thư viện dùng chung, mount vào `/opt` lúc chạy —
gần giống một layer trong Docker image, nhưng gắn ở mức cấu hình hàm chứ không
build vào image. Dùng để tách dependency nặng khỏi code và chia sẻ giữa nhiều hàm.

---

## 6. Ba kiểu gọi Lambda và hệ quả về retry/DLQ

Đây là mục đáng học nhất trong bài. Rất nhiều câu hỏi SAA chỉ là "message lỗi thì
nó đi đâu", và đáp án phụ thuộc **hoàn toàn** vào kiểu gọi.

### Đồng bộ (request-response)

Nguồn: API Gateway, ALB, Lambda Function URL, Cognito trigger, Step Functions
(task thường), `Invoke` với `RequestResponse`.

- Lambda **không** retry. Trả lỗi về cho caller.
- **Không có DLQ.** Muốn không mất request thì caller phải tự retry hoặc bạn phải
  đặt một queue trước Lambda.
- Timeout của caller thường chặt hơn timeout của Lambda: HTTP API tối đa
  **30 giây** cho integration; REST API mặc định **29 giây**.

### Bất đồng bộ (event)

Nguồn: S3 event notification, SNS, EventBridge, CloudWatch Logs, `Invoke` với
`Event`.

- Lambda đưa event vào **hàng đợi nội bộ** rồi trả `202` ngay cho caller.
- Lỗi từ code → **retry 2 lần** (chỉnh được 0–2), có backoff.
- Bị throttle hoặc lỗi hệ thống → giữ trong hàng đợi tối đa **6 giờ**
  (`maximum event age`, chỉnh được 60 giây – 6 giờ).
- Hết cách → event bị **discard**, trừ khi bạn cấu hình:
  - **DLQ** (SQS hoặc SNS) — cơ chế cũ, chỉ nhận payload gốc; hoặc
  - **On-failure destination** (SQS, SNS, Lambda, EventBridge; S3 chỉ cho
    on-failure) — cơ chế mới, kèm cả context lỗi và response. Có cả
    on-success destination.
- Reserved concurrency = 0 → **không retry gì cả**.

### Poll-based (event source mapping)

Nguồn: SQS, Kinesis Data Streams, DynamoDB Streams, Amazon MSK / Kafka tự quản,
Amazon MQ.

Điểm mấu chốt: **Lambda không bị gọi**. Dịch vụ Lambda chạy một bộ poller đọc
nguồn rồi mới gọi hàm của bạn theo batch. Nghĩa là logic retry nằm ở **nguồn**,
không nằm ở function.

| Nguồn | Retry hoạt động thế nào | DLQ nằm ở đâu |
|---|---|---|
| **SQS** | Batch lỗi → message hiện lại sau **visibility timeout** → thử lại | **Trên queue**, qua `maxReceiveCount` của redrive policy |
| **Kinesis / DynamoDB Streams** | Retry cho tới khi thành công hoặc record hết hạn — **chặn cả shard** | On-failure destination của event source mapping; kèm `maximumRetryAttempts`, `bisectBatchOnFunctionError` |

Tham số SQS đáng nhớ: `BatchSize` mặc định 10, tối đa **10.000** cho standard queue
và **10** cho FIFO. `MaximumBatchingWindowInSeconds` gom batch lâu hơn để bớt
invoke (không dùng được với FIFO). Bật `ReportBatchItemFailures` để chỉ message
hỏng bị thử lại thay vì cả batch — chi tiết này giải thích phần lớn hiện tượng
"sao message đó được xử lý hai lần".

> Câu hỏi thi kinh điển: *"Lambda đọc SQS bị lỗi, làm sao giữ lại message hỏng để
> điều tra?"* → cấu hình **DLQ trên SQS queue**, không phải DLQ trên Lambda.

---

## 7. Lambda trong VPC — vì sao ngày xưa chậm và giờ khác thế nào

Mô hình cũ (trước 2019): mỗi execution environment được gắn một ENI riêng trong
subnet của bạn, **tạo lúc cold start**. Tạo ENI mất hàng giây tới hàng chục giây.
Cold start của Lambda-trong-VPC vì thế nổi tiếng là thảm hoạ, và số ENI còn giới
hạn luôn khả năng scale.

Mô hình hiện tại dùng **Hyperplane ENI** — cùng nền tảng chạy NAT Gateway và
PrivateLink:

- ENI được tạo lúc **tạo hàm hoặc cập nhật cấu hình VPC**, không phải lúc invoke.
- ENI **dùng chung** cho mọi environment; mỗi cặp *security group : subnet* chỉ
  cần một số ít ENI. Hai hàm cùng cặp đó dùng chung ENI.
- Scale của hàm không còn bị buộc vào số ENI.

Kết luận thực tế: **cold start do VPC gần như không còn là lý do để né VPC.**
Nhưng ba thứ vẫn đúng và vẫn ra thi:

1. Execution role vẫn cần quyền tạo/xoá ENI (`AWSLambdaVPCAccessExecutionRole`).
2. Hàm trong VPC **không có đường ra internet** trừ khi bạn đặt nó ở private subnet
   có route qua **NAT Gateway**, hoặc dùng **VPC endpoint** cho đúng dịch vụ cần gọi.
   Gắn Public IP cho Lambda là chuyện không tồn tại.
3. **Đa số Lambda không cần vào VPC.** DynamoDB, S3, SQS, SNS đều là API công khai
   gọi qua endpoint AWS. Chỉ đặt vào VPC khi phải chạm tài nguyên **riêng tư**:
   RDS, ElastiCache, một service nội bộ sau ALB nội bộ, hoặc on-premise qua VPN/DX.

> Nhớ lại [Tuần 2](w02-vpc-networking.md): S3 và DynamoDB có **Gateway Endpoint
> miễn phí**; các dịch vụ khác dùng Interface Endpoint (~$0,01/giờ/AZ). NAT Gateway
> ~$0,045/giờ cộng phí mỗi GB là kẻ giết credit số 1 — đừng bật nó chỉ để một hàm
> Lambda gọi được DynamoDB.

---

## 8. Execution role và resource policy — hai hướng của cùng một câu hỏi

Nhắc lại [Tuần 1](w01-iam-foundations.md), vì đây là chỗ người mới lẫn nhiều nhất:

| | Execution role | Resource-based policy |
|---|---|---|
| Trả lời câu hỏi | **Hàm được phép làm gì?** | **Ai được phép gọi hàm?** |
| Gắn vào | Function, dạng IAM role | Function, dạng policy JSON |
| Ví dụ | `dynamodb:Query` trên đúng một bảng | `apigateway.amazonaws.com` được `lambda:InvokeFunction` |
| Thiếu nó thì | Hàm chạy rồi lỗi `AccessDenied` **trong log** | API trả `500`, **log Lambda trống trơn** |

Dòng cuối là mẹo chẩn đoán đắt giá: **log trống nghĩa là hàm chưa từng được gọi**,
nên hãy đi soi tầng cho phép chứ đừng đọc lại code.

Nguyên tắc bất di bất dịch của đề thi: execution role phải **least privilege** —
đúng action, đúng resource ARN. Gắn `AmazonDynamoDBFullAccess` luôn là đáp án sai.

---

## 9. API Gateway — ba loại API và cách chọn

| | **HTTP API** (v2) | **REST API** (v1) | **WebSocket API** |
|---|---|---|---|
| Mô hình | Request/response | Request/response | **Hai chiều, kết nối bền** |
| Giá | Rẻ hơn đáng kể | Đắt hơn | Theo phút kết nối + message |
| Độ trễ | Thấp hơn | Cao hơn | — |
| Integration timeout | tối đa **30 giây** | mặc định **29 giây** (tăng được cho regional/private) | — |
| Payload | 10 MB | 10 MB | 128 KB mỗi frame |
| JWT authorizer sẵn có | **Có** | Không (dùng Cognito authorizer hoặc Lambda authorizer) | Chỉ ở route `$connect` |
| Cognito user pool authorizer | Không (dùng JWT authorizer) | **Có** | — |
| Lambda authorizer | Có (REQUEST) | Có (TOKEN và REQUEST) | Có |
| API key + usage plan | **Không** | **Có** | Không |
| Request/response validation, mapping template | Không | **Có** | — |
| Caching | **Không** | **Có** | — |
| WAF gắn trực tiếp | Không | **Có** | Không |
| Private API trong VPC | Không | **Có** | Không |
| Loại endpoint | Regional | Edge-optimized / Regional / Private | Regional |
| Deploy | `auto_deploy` được | Phải deploy sang stage thủ công | Phải deploy |

**Quy tắc chọn:** mặc định **HTTP API**. Chuyển sang **REST API** chỉ khi cần một
trong: API key + usage plan, request validation, mapping template, caching, WAF
trực tiếp, hay private API. Cần server đẩy dữ liệu về client (chat, bảng giá,
thông báo realtime) → **WebSocket API**.

### Authorizer — ba loại, ba tình huống

| Loại | Client mang gì | Dùng khi |
|---|---|---|
| **IAM authorization** (SigV4) | Chữ ký SigV4 bằng credential AWS | Caller là service AWS khác, hoặc client đã có credential qua Cognito identity pool |
| **Cognito user pool / JWT authorizer** | JWT do user pool (hoặc OIDC provider) cấp | Ứng dụng có người dùng đăng nhập — API Gateway tự verify chữ ký, bạn không viết code |
| **Lambda authorizer** | Bất cứ thứ gì (token lạ, header, mTLS metadata) | Logic uỷ quyền tuỳ biến, hệ auth cũ. Trả về IAM policy; **kết quả cache được** (mặc định 300 giây) để khỏi gọi lại mỗi request |

### Stage, throttling, usage plan, caching

- **Stage** là một bản deploy có tên (`dev`, `prod`) với URL riêng. Có **stage
  variable** — bắc cầu: giống biến môi trường, dùng để một stage trỏ tới alias
  Lambda khác nhau.
- **Throttling ba tầng:** account (mặc định **10.000 rps**, burst **5.000**) →
  stage/method → usage plan gắn với API key. Bị chặn thì client nhận `429`, và bạn
  **không trả tiền cho invoke Lambda** vì Lambda chưa được gọi. Đây là hàng rào
  chi phí, không phải phiền toái.
- **Usage plan + API key** (chỉ REST API) cho phép đặt rate, burst và **quota**
  (ví dụ 10.000 request/tháng) cho từng khách hàng. Đây là câu trả lời cho
  "bán API cho bên thứ ba, giới hạn theo gói".
  Lưu ý: API key **không phải cơ chế xác thực** — nó để đo đếm và phân hạn.
- **Caching** (chỉ REST API): bật ở mức stage, TTL mặc định **300 giây**, tối đa
  **3.600 giây**, response tối đa 1 MB được cache. Tính tiền **theo giờ** theo
  kích thước cache và **không nằm trong free tier** — nhớ kỹ điều này trước khi bật.

### ALB làm trigger Lambda — khi nào

| | API Gateway | ALB |
|---|---|---|
| Giá | Theo request | **Theo giờ** + LCU (~$17/tháng dù không ai gọi) |
| Response tối đa | 6 MB (giới hạn Lambda) | **1 MB** |
| Auth | IAM / Cognito / Lambda authorizer | OIDC hoặc Cognito ở mức listener rule |
| Throttling, usage plan, API key | Có (REST) | Không |
| Trộn target | Chỉ Lambda / HTTP / dịch vụ AWS | **Lambda + EC2 + IP + container trong cùng một LB** |
| Định tuyến | Theo resource/method | Theo host, path, header, query, method |

Chọn ALB khi: **bạn đã có ALB rồi**, và muốn đưa một vài đường dẫn sang Lambda mà
vẫn giữ phần còn lại trên EC2/ECS — mẫu strangler khi hiện đại hoá monolith. Chọn
API Gateway khi bắt đầu từ đầu, lưu lượng thưa, hoặc cần tính năng API management.

---

## 10. Step Functions — khi nào chuỗi Lambda là sai

Dấu hiệu bạn cần orchestration, không phải thêm Lambda:

- Lambda A gọi Lambda B rồi chờ kết quả → bạn **trả tiền cho thời gian A ngồi chờ**.
- Cần retry riêng cho từng bước, với backoff khác nhau.
- Cần chờ lâu (duyệt thủ công, chờ job bên ngoài xong) — vượt 15 phút.
- Cần biết quy trình đang đứng ở bước nào khi có sự cố.
- Cần bồi hoàn (compensating transaction) khi bước thứ ba hỏng.

Step Functions là một **state machine** khai báo bằng Amazon States Language (JSON).
Bắc cầu: gần với ý tưởng của một Argo Workflow hơn là một Ansible playbook — có
`Retry`, `Catch`, `Choice`, `Parallel`, `Map`, `Wait`.

| | **Standard** | **Express** |
|---|---|---|
| Thời gian chạy tối đa | **1 năm** | **5 phút** |
| Ngữ nghĩa | **Exactly-once** | **At-least-once** |
| Tốc độ khởi chạy | trên 2.000/giây | trên 100.000/giây |
| Lịch sử thực thi | Lưu trong Step Functions, xem 90 ngày | Chỉ CloudWatch Logs |
| Tính tiền | Theo **state transition** | Theo số lần chạy × thời lượng × memory |
| Chọn khi | Quy trình dài, cần audit, hành động **không idempotent** (thanh toán, dựng cluster) | Tần suất cao, luồng ngắn, hành động **idempotent** (biến đổi dữ liệu) |

Chi tiết tối ưu chi phí hay ra thi: state `Wait` trong Standard workflow **không
tính tiền theo thời gian chờ** — chờ 30 ngày cũng chỉ là một state transition.
Chờ bằng `time.sleep()` trong Lambda thì bạn trả GB-giây cho thời gian ngủ.

---

## 11. Phổ compute — Lambda nằm ở đâu

| | **EC2** | **ECS trên EC2** | **ECS/EKS Fargate** | **Lambda** |
|---|---|---|---|---|
| Bạn quản lý | OS, patch, scaling, AMI | OS của node + task | Chỉ task definition | Chỉ code |
| Đơn vị triển khai | Instance | Container trên node bạn sở hữu | Container, không thấy node | Hàm |
| Đơn vị tính tiền | Giờ (hoặc giây) instance | Giờ instance | **vCPU-giây + GB-giây của task** | **GB-giây + số request** |
| Scale về 0 | Không | Không (node vẫn chạy) | Gần được (task = 0) | **Được** |
| Thời gian chạy tối đa | Vô hạn | Vô hạn | Vô hạn | **15 phút** |
| Khởi động | Phút | Giây | Chục giây | Mili giây (warm) |
| Tối ưu chi phí | Spot, RI, Savings Plan | Spot cho node, bin-packing | Fargate Spot | Không có RI; chỉ chỉnh memory |
| Chọn khi | Cần kiểm soát OS, license theo core, workload đặc thù (GPU) | Có sẵn đội vận hành node, cần bin-packing chặt, cần daemon trên node | Container nhưng không muốn quản node | Sự kiện rời rạc, tải bùng nổ, glue code |

**EKS** trong phạm vi SAA chỉ cần biết: Kubernetes có quản lý, control plane tính
tiền theo giờ, chọn khi bạn đã có hệ sinh thái Kubernetes hoặc cần chạy đa cloud
với cùng manifest. Đề SAA hiếm khi hỏi sâu hơn — và trong khoá học này thì
**tuyệt đối không bật** (~$73/tháng chỉ riêng control plane).

Con đường suy luận nhanh khi gặp câu hỏi:

```
Chạy quá 15 phút? ──yes──► không phải Lambda
   │ no
Đã đóng gói container? ──no──► Lambda
   │ yes
Cần kiểm soát OS/node (GPU, license, daemon)? ──yes──► ECS trên EC2 hoặc EC2
   │ no
Đã dùng Kubernetes ở nơi khác? ──yes──► EKS ──no──► ECS Fargate
```

---

## 12. Cognito — user pool và identity pool

Hai thứ này tên gần giống nhau, làm hai việc hoàn toàn khác nhau, và đề thi thích
điều đó.

| | **User pool** | **Identity pool** (federated identities) |
|---|---|---|
| Làm gì | **Xác thực** — thư mục người dùng, đăng ký, đăng nhập, MFA, quên mật khẩu | **Uỷ quyền** — đổi token lấy **credential AWS tạm thời** |
| Trả về | JWT (ID token, access token, refresh token) | Access key + secret + session token qua STS |
| Dùng với | API Gateway Cognito/JWT authorizer, ALB OIDC | Client gọi thẳng S3, DynamoDB… bằng SDK |
| Hỗ trợ khách vãng lai | Không | **Có** — guest access với role riêng |
| Nguồn danh tính | Chính nó, hoặc social/SAML/OIDC | User pool, social, SAML, OIDC, hoặc user pool |

Mẫu ghép đầy đủ: người dùng đăng nhập **user pool** → nhận JWT → nếu chỉ gọi API
qua API Gateway thì dừng ở đây; nếu client cần upload thẳng lên S3 thì đưa JWT cho
**identity pool** để đổi lấy credential AWS gắn với một IAM role có quyền hẹp.

---

## 13. Đánh đổi chi phí — chỗ serverless hết rẻ

Đây là mục dễ bị bỏ qua nhất, và là Domain 4 thuần tuý.

Lambda tính tiền theo **GB-giây** cộng **số request**. Không có Reserved Instance,
không có Savings Plan cho Lambda (Compute Savings Plan có phủ Lambda và Fargate —
kiểm tra lại trang pricing trước khi tin). EC2 và Fargate tính theo thời gian
**máy sống**, bất kể có request hay không, nhưng có Spot/RI/Savings Plan giảm sâu.

Hệ quả:

```
tải thưa, bùng nổ, khó đoán  ──► Lambda rẻ hơn nhiều lần (rảnh = $0)
        │  utilization tăng dần
        ▼
tải đều, cao, chạy 24/7      ──► EC2/Fargate rẻ hơn (Spot/RI/Savings Plan)
```

Cách suy nghĩ đúng khi đọc đề: hỏi **"máy sẽ rảnh bao nhiêu phần trăm thời gian?"**
Rảnh nhiều → serverless. Chạy full tải liên tục → instance có cam kết dài hạn.

Ba chi phí ẩn của serverless mà đề thi hay cài:

1. **CloudWatch Logs giữ vĩnh viễn theo mặc định.** Một hàm lỗi lặp vô hạn ăn hết
   5 GB miễn phí trong vài giờ. Luôn đặt retention.
2. **Provisioned concurrency** biến Lambda thành thứ tính tiền theo thời gian —
   đúng cái bạn định tránh.
3. **NAT Gateway** cho Lambda-trong-VPC đắt hơn nhiều lần bản thân các invoke.

---

## Bảng quyết định

| Tình huống | Chọn | Vì sao không chọn cái kia |
|---|---|---|
| API REST mới, muốn rẻ và nhanh nhất | **HTTP API** | REST API đắt hơn, chậm hơn, thừa tính năng |
| Cần API key + quota theo khách hàng | **REST API + usage plan** | HTTP API không có usage plan |
| Cần cache response ở tầng API | **REST API caching** | HTTP API không có caching; CloudFront là lựa chọn khác |
| Cần WAF trực tiếp trên API | **REST API** (hoặc đặt CloudFront trước HTTP API) | HTTP API không gắn WAF trực tiếp |
| Đã có ALB, muốn thêm vài route serverless | **ALB → Lambda** | API Gateway thêm một tầng và một hoá đơn nữa |
| Client cần server đẩy dữ liệu về | **WebSocket API** | HTTP không giữ kết nối hai chiều |
| Giảm cold start Java, không muốn trả phí giữ ấm | **SnapStart** | Provisioned concurrency tốn tiền liên tục |
| SLA p99 chặt, lưu lượng dự đoán được | **Provisioned concurrency** | SnapStart không đảm bảo mọi invoke đều ấm |
| Chặn một hàm ăn hết quota account | **Reserved concurrency** | Provisioned concurrency không giới hạn trên |
| Bảo vệ RDS khỏi bùng nổ kết nối từ Lambda | **Reserved concurrency + RDS Proxy** | Tăng quota chỉ làm vấn đề tệ hơn |
| Job chạy 40 phút | **Fargate** hoặc Step Functions chia nhỏ | Lambda cứng 15 phút |
| Xử lý ảnh 500 MB | **Fargate** hoặc Lambda + S3 (claim check) | Payload Lambda 6 MB đồng bộ |
| Cần retry/catch/chờ giữa nhiều bước | **Step Functions Standard** | Chuỗi Lambda gọi nhau tốn tiền chờ và không quan sát được |
| Xử lý 200.000 sự kiện/giây, luồng ngắn | **Step Functions Express** | Standard giới hạn tốc độ khởi chạy thấp hơn nhiều |
| Người dùng đăng nhập rồi gọi API | **User pool + JWT authorizer** | Identity pool không phải nơi lưu người dùng |
| Client cần upload thẳng lên S3 bằng SDK | **Identity pool** cấp credential | JWT không gọi được API AWS |
| Lambda chỉ đọc DynamoDB và S3 | **Không đặt trong VPC** | Vào VPC là tự chuốc NAT Gateway |
| Lambda phải gọi RDS trong private subnet | **Đặt trong VPC** | Không có đường nào khác |

## Số phải thuộc

| Số | Ý nghĩa |
|---|---|
| **900 giây (15 phút)** | Timeout tối đa của Lambda |
| **128 MB – 10.240 MB** | Dải memory; **1.769 MB = 1 vCPU** |
| **6 MB / 1 MB** | Payload đồng bộ / bất đồng bộ |
| **512 MB – 10.240 MB** | Ephemeral storage `/tmp`, mặc định 512 MB |
| **50 MB / 250 MB / 10 GB** | Package .zip nén / giải nén / container image |
| **5** | Số layer tối đa mỗi hàm |
| **1.000** | Concurrency mặc định mỗi account mỗi region (100 luôn để dành) |
| **2 lần retry, 6 giờ** | Retry và event age tối đa của invoke bất đồng bộ |
| **10.000 / 10** | BatchSize tối đa của event source mapping SQS standard / FIFO |
| **29 s / 30 s** | Integration timeout REST API / HTTP API |
| **10.000 rps, burst 5.000** | Throttle mặc định API Gateway mỗi account mỗi region |
| **300 s / 3.600 s** | TTL mặc định / tối đa của REST API cache |
| **1 năm / 5 phút** | Thời gian chạy tối đa Step Functions Standard / Express |

## Bẫy kinh điển

**"Lambda cần đọc DynamoDB nên phải đặt trong VPC."** Sai. DynamoDB, S3, SQS, SNS
là API công khai. Đặt vào VPC chỉ khi cần chạm tài nguyên riêng tư. Làm thừa thì
bạn nhận thêm phức tạp và một NAT Gateway $33/tháng.

**"Bật provisioned concurrency là hết cold start."** Chỉ hết trong phạm vi N
environment đã đặt. Vượt N thì tràn sang on-demand và cold start như thường.

**"SnapStart và provisioned concurrency dùng chung cho chắc."** Không dùng chung
được. Và SnapStart chỉ có ở Java 11+, Python 3.12+, .NET 8+, chỉ trên version đã
publish.

**"Lambda đọc SQS lỗi thì cấu hình DLQ trên Lambda."** Sai hướng. Với event source
mapping SQS, retry và DLQ thuộc về **queue** (`maxReceiveCount` + redrive policy).
DLQ trên Lambda chỉ áp dụng cho invoke **bất đồng bộ**.

**"API key của API Gateway là cơ chế xác thực."** Không. Nó để đo đếm và phân hạn
qua usage plan. Xác thực là việc của IAM, Cognito hoặc Lambda authorizer.

**"HTTP API rẻ hơn nên luôn chọn HTTP API."** Đúng làm mặc định, nhưng nếu đề nhắc
tới usage plan, request validation, caching, WAF trực tiếp hay private API thì đáp
án là REST API.

**"Tăng memory Lambda thì đắt hơn."** Không nhất thiết. CPU tỉ lệ với memory; hàm
nặng CPU chạy ở 512 MB thường **rẻ hơn** ở 128 MB vì xong nhanh hơn nhiều lần.

**"Reserved concurrency giúp giảm cold start."** Không. Nó là giới hạn trên kiêm
đặt chỗ. Cái làm ấm là provisioned concurrency.

**"Lambda tự trải nhiều AZ nên không cần nghĩ về HA."** Đúng phần Lambda, nhưng
nếu bạn đặt nó trong VPC mà chỉ khai báo **một** subnet ở một AZ thì bạn vừa tạo
lại điểm hỏng đơn lẻ.

**"Chuỗi Lambda gọi nhau đồng bộ cũng như Step Functions thôi."** Bạn trả tiền GB-
giây cho mọi giây hàm gọi ngồi chờ hàm bị gọi, và mất hoàn toàn khả năng quan sát
quy trình đang đứng ở đâu.

## Nối với lab

[`labs/w06-serverless-api/`](../../learn-aws/labs/w06-serverless-api/) dựng đúng
mẫu kinh điển **HTTP API Gateway → Lambda → DynamoDB** bằng Terraform.

Khi chạy, quan sát bốn thứ ứng với bốn mục trên:

| Mục lý thuyết | Quan sát gì trong lab |
|---|---|
| Execution model (mục 2) | `ansible-playbook site.yml --tags coldstart` đo chênh lệch lạnh/ấm bằng ms. Client boto3 đặt ngoài handler chính là lý do lần thứ hai nhanh hơn. |
| Throttling (mục 9) | `--tags throttle` — thấy `429` và hiểu rằng request bị chặn **không** tính tiền Lambda |
| Execution role (mục 8) | `verify.sh` mục 7 kiểm tra role **không** có `dynamodb:Scan`. Thử bỏ `aws_lambda_permission` để thấy `500` + log trống |
| Không vào VPC (mục 7) | Hàm không có `vpc_config` mà vẫn gọi được DynamoDB — tự tay chứng minh mục 7 |

Lab này là lab duy nhất **không destroy** — nó nằm trong hạn mức always-free và là
xương sống của capstone. Nhớ chạy `scripts/set-log-retention.sh 7`.

## Tự kiểm tra

<details><summary>1. Vì sao đặt `boto3.resource(...)` bên trong handler là lỗi hiệu năng, chứ không chỉ là chuyện phong cách code?</summary>

Vì code ngoài handler chỉ chạy một lần trong pha INIT của mỗi execution
environment, còn code trong handler chạy mỗi request. Đặt bên trong nghĩa là mỗi
request phải dựng lại client, phân giải endpoint và bắt tay TLS lại từ đầu. Với
hàm được gọi thường xuyên, phần lớn invoke là warm start — bạn đang trả tiền cho
việc lặp lại công việc mà lẽ ra chỉ làm một lần.
</details>

<details><summary>2. Một hàm bị gọi 500 request/giây, mỗi request 400 ms. Cần bao nhiêu concurrency? Điều gì xảy ra ở quota mặc định?</summary>

500 × 0,4 = **200 concurrency**. Nằm gọn trong quota 1.000 mặc định. Nhưng nếu
account còn hàm khác cùng dùng chung 1.000 đó, hãy đặt reserved concurrency cho
hàm quan trọng để nó không bị hàng xóm ăn mất chỗ.
</details>

<details><summary>3. S3 event notification gọi Lambda, hàm lỗi liên tục. Message đi đâu?</summary>

Invoke **bất đồng bộ**: retry 2 lần, giữ tối đa 6 giờ, rồi **discard** — trừ khi
có DLQ (SQS/SNS) hoặc on-failure destination. Không cấu hình thì event mất im lặng.
</details>

<details><summary>4. Vì sao Lambda-trong-VPC ngày nay không còn cold start thảm hoạ, nhưng vẫn cần cân nhắc?</summary>

Vì Hyperplane ENI được tạo lúc tạo/cập nhật hàm chứ không phải lúc invoke, và
dùng chung cho mọi environment theo cặp security-group:subnet. Nhưng hàm trong VPC
vẫn **không có đường ra internet** nếu không có NAT Gateway hoặc VPC endpoint, và
execution role vẫn cần quyền quản lý ENI.
</details>

<details><summary>5. Bạn bán API cho ba khách hàng với ba mức quota khác nhau. Chọn gì và vì sao?</summary>

**REST API + usage plan + API key** cho từng khách. HTTP API không có usage plan.
Lưu ý API key chỉ để đo đếm và phân hạn — vẫn cần một cơ chế xác thực thật (IAM,
Cognito, hoặc Lambda authorizer) bên cạnh.
</details>

<details><summary>6. Khi nào Step Functions rẻ hơn viết logic chờ trong Lambda?</summary>

Khi có thời gian chờ. State `Wait` trong Standard workflow tính như một state
transition, không tính theo thời gian chờ. Chờ trong Lambda thì bạn trả GB-giây
cho từng giây ngủ. Với quy trình chờ vài phút trở lên, chênh lệch là hàng bậc.
</details>

<details><summary>7. Bạn cần đưa một phần monolith trên EC2 sang serverless, giữ nguyên domain và phần còn lại. Tầng vào chọn gì?</summary>

**ALB**. Bạn đã có ALB trước monolith; thêm một target group kiểu Lambda và một
listener rule theo path là xong, phần còn lại vẫn về EC2. Đưa API Gateway vào
nghĩa là thêm một tầng, một hoá đơn và một chỗ phải đồng bộ cấu hình DNS/TLS.
Nhớ giới hạn response 1 MB của ALB→Lambda.
</details>

<details><summary>8. Ứng dụng chạy full tải 24/7, CPU đều 70%. Vì sao Lambda là lựa chọn tồi?</summary>

Vì lợi thế của Lambda là không trả tiền khi rảnh — ở đây không có lúc nào rảnh.
Bạn sẽ trả full giá GB-giây liên tục, trong khi EC2 hoặc Fargate với Savings Plan
hay Spot rẻ hơn đáng kể cho cùng lượng compute. Thêm nữa, ở utilization cao thì
giới hạn 15 phút và mô hình một-request-một-environment trở thành ràng buộc thuần
tuý bất lợi.
</details>

<details><summary>9. Vì sao `429` từ API Gateway lại là tin tốt về mặt chi phí?</summary>

Vì API Gateway chặn **trước khi** gọi Lambda. Request bị chặn không sinh invoke,
không sinh GB-giây, không sinh log. Throttling do đó là hàng rào chi phí — không
có nó, một vòng lặp lỗi trong script test có thể đốt sạch hạn mức miễn phí trong
vài phút rồi bắt đầu tính tiền thật.
</details>

## Ngoài phạm vi

- **Lambda Function URL** — endpoint HTTPS gắn thẳng vào hàm, không có API
  management. Biết là có, đủ. [Doc](https://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html)
- **Lambda response streaming, Extensions, Telemetry API** — mức developer/observability chuyên sâu.
- **API Gateway mapping template (VTL)** — cú pháp là kiến thức developer.
- **Step Functions Distributed Map, callback `.waitForTaskToken`** — mức Professional.
- **EKS chi tiết** (node group, Karpenter, add-on) — ngoài phạm vi SAA.
- **App Runner, Elastic Beanstalk** — biết tồn tại là đủ; Beanstalk quay lại ở tuần 10.

## Nguồn

- [Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [Configure ephemeral storage for Lambda functions](https://docs.aws.amazon.com/lambda/latest/dg/configuration-ephemeral-storage.html)
- [Understanding Lambda function scaling (concurrency quotas)](https://docs.aws.amazon.com/lambda/latest/dg/lambda-concurrency.html)
- [Improving startup performance with Lambda SnapStart](https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html)
- [Asynchronous invocation](https://docs.aws.amazon.com/lambda/latest/dg/invocation-async.html)
- [Lambda parameters for Amazon SQS event source mappings](https://docs.aws.amazon.com/lambda/latest/dg/services-sqs-parameters.html)
- [Giving Lambda functions access to resources in an Amazon VPC](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
- [Announcing improved VPC networking for AWS Lambda functions](https://aws.amazon.com/blogs/compute/announcing-improved-vpc-networking-for-aws-lambda-functions/)
- [Amazon API Gateway quotas](https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html)
- [Quotas for configuring and running an HTTP API](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-quotas.html)
- [Cache settings for REST APIs in API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-caching.html)
- [Usage plans and API keys for REST APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html)
- [Use Lambda functions as targets of an Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/lambda-functions.html)
- [Choosing workflow type in Step Functions](https://docs.aws.amazon.com/step-functions/latest/dg/choosing-workflow-type.html)
- [What's the difference between Amazon Cognito user pools and identity pools?](https://repost.aws/knowledge-center/cognito-user-pools-identity-pools)
- [AWS Lambda FAQs](https://aws.amazon.com/lambda/faqs/)
