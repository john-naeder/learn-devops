# Tuần 5 — Đọc đúng thứ mình cần  (tự viết)

`Domain 3 · Performance (24%)` `Domain 2 · Resilient (26%)` `Domain 4 · Cost (20%)`

| | |
|---|---|
| **Chi phí khi chạy** | **~$0,000/giờ** — không thành phần nào tính theo giờ |
| **Quên 1 tháng** | **< $0,01** |
| **Thời gian** | ~3 giờ, phần lớn dành cho việc *nghĩ ra khoá*, không phải gõ |
| **Điều kiện** | không cần lab nào trước. Nhưng nếu chưa xong `w01-iam-foundations` thì để dành nó cho tuần sau — không liên quan tới bài này |

> Đây là lab rẻ nhất cả bộ và cũng là lab **duy nhất** mà toàn bộ điểm số nằm ở
> một quyết định thiết kế bạn đưa ra trong 20 phút đầu. Sai khoá thì viết bao
> nhiêu Terraform cũng không cứu được, và `verify.sh` sẽ nói thẳng vào mặt bạn
> bằng hai con số.

---

## Bối cảnh

Một cửa hàng trực tuyến. Bảng đơn hàng, vài triệu bản ghi, và ba màn hình đang
dùng nó:

- **Trang tài khoản của khách**: mở ra thấy các đơn của *chính khách đó*, mới
  nhất xếp trên. Có bộ lọc "chỉ hiện đơn từ ngày X trở đi".
- **Bảng điều khiển của đội vận hành**: một màn hình treo trên tường, cứ 30 giây
  tự làm mới, hiện *mọi đơn đang giao* của *mọi khách*.
- **Nút "theo dõi đơn"**: mỗi lần khách bấm, hệ thống ghi một bản ghi tạm để
  chống bấm liên tục. Bản ghi đó chỉ có nghĩa trong vài giờ.

Trưởng nhóm hạ tầng vừa chuyển từ một công ty mà cái bảng-treo-tường kia đọc
toàn bộ bảng đơn hàng mỗi 30 giây. Hoá đơn tháng đó gấp bốn mươi lần bình
thường, và không ai nhận ra trong ba tuần vì màn hình vẫn chạy đúng.

Nên anh ta đặt một điều kiện cứng, và đây là toàn bộ đề bài:

> **Trả lời một câu hỏi nghiệp vụ không được đọc nhiều bản ghi hơn số bản ghi
> thực sự trả về.**

Đội tài chính thêm một câu: kho dữ liệu này phải nằm trong hạn mức miễn phí, và
phải khôi phục được nếu ai đó chạy nhầm một lệnh xoá.

---

## Yêu cầu

1. **Có sẵn dữ liệu để chấm**: ít nhất **80 đơn hàng**, thuộc ít nhất **10
   khách** khác nhau. Khách mà bạn khai trong hợp đồng output phải có **ít nhất
   8 đơn**.
2. **Câu hỏi 1 trả lời được**: "các đơn của khách K" — đúng số lượng, và
   **mới nhất trước**.
3. **Câu hỏi 1 có bộ lọc thời gian**: "các đơn của khách K từ mốc T trở đi" —
   đúng số lượng.
4. **Câu hỏi 2 trả lời được**: "mọi đơn đang ở trạng thái S, của mọi khách" —
   đúng số lượng.
5. **Điều kiện cứng ở cả ba câu trên: số bản ghi ĐỌC bằng đúng số bản ghi TRẢ
   VỀ.** `verify.sh` gọi thật vào kho dữ liệu và in ra hai con số cạnh nhau.
   Lệch một bản ghi cũng đỏ.
6. **PHỦ ĐỊNH — không thể trả lời câu hỏi 1 khi chỉ biết mốc thời gian mà không
   biết khách nào.** Đọc kỹ: đây không phải "không nên", mà là "kho dữ liệu phải
   **từ chối** cả câu hỏi đó".
7. **PHỦ ĐỊNH — cách làm "đọc cả bảng rồi lọc" phải cho ra ĐÚNG CÙNG một câu trả
   lời, nhưng đọc nhiều hơn hẳn.** `verify.sh` chạy cả hai cách rồi in ra tỉ lệ.
   Đây là check dạy nhiều nhất của lab: nó chứng minh rằng "chạy đúng" và "thiết
   kế đúng" là hai chuyện khác nhau, và hoá đơn chỉ biết chuyện thứ hai.
8. **Bản ghi tạm tự biến mất**, không cần ai chạy job dọn. Cơ chế hết hạn phải
   đang bật, **và** phải có bản ghi thật mang thuộc tính hết hạn đó, **và** giá
   trị phải đúng kiểu, đúng đơn vị, mốc ở tương lai.
   > Đây là chỗ hỏng im lặng kinh điển: cơ chế bật, thuộc tính có, mà không bao
   > giờ có gì hết hạn. `verify.sh` bắt đúng ba cách hỏng đó.
9. **Dữ liệu không dồn vào một chỗ**: giá trị dùng làm khoá phân hoạch phải có ít
   nhất 10 giá trị khác nhau trong bảng.
10. **Khôi phục được về bất kỳ thời điểm nào trong 35 ngày qua**, không cần ai
    nhớ chụp ảnh dữ liệu.
11. **Chế độ tính tiền nằm trong hạn mức miễn phí** — xem mục Hàng rào để biết
    hai lựa chọn nào được chấp nhận và vì sao.

> Đề bài không nói bạn phải dùng dịch vụ nào, cũng không nói bảng có mấy khoá.
> Nó chỉ nói ba câu hỏi phải trả lời được và một điều kiện về chi phí đọc. Ánh
> xạ từ đó sang thiết kế khoá là toàn bộ bài học.

---

## Hợp đồng output

| Output | Kiểu | `verify.sh` dùng để |
|---|---|---|
| `table_name` | string | tra cấu trúc khoá, chạy mọi truy vấn |
| `gsi_name` | string | tên chỉ mục phụ trả lời câu hỏi 2 |
| `khach_mau` | string | giá trị khoá phân hoạch của một khách **có sẵn dữ liệu** |
| `so_don_cua_khach_mau` | number | số đơn của khách đó — dùng để đối chiếu kết quả truy vấn |
| `trang_thai_mau` | string | giá trị trạng thái dùng cho câu hỏi 2 |
| `so_don_trang_thai_mau` | number | số đơn đang ở trạng thái đó |
| `chi_phi` | string | in ra trước khi gõ `yes` |

**`verify.sh` không biết bạn đặt tên thuộc tính là gì, và cố ý không cần biết.**
Nó hỏi thẳng AWS xem bảng của bạn có khoá nào, tên gì, kiểu gì, rồi tự dựng câu
truy vấn. Bạn đặt tên `khach_hang`, `pk`, hay `customer_id` đều được. Cái nó
không tha thứ là **hình dạng khoá sai**.

---

## Hàng rào của lab này

### Trần chi phí

| Thành phần | Giá | Nếu quên 1 tháng |
|---|---|---|
| Lưu trữ | 25 GB **miễn phí vĩnh viễn**; bảng của bạn ~50 KB | $0 |
| Đọc/ghi ở chế độ provisioned ≤ 25 RCU và ≤ 25 WCU | **miễn phí vĩnh viễn** | $0 |
| Đọc/ghi ở chế độ theo request (~100 ghi + vài nghìn đọc) | $1,25/triệu ghi, $0,25/triệu đọc | < $0,001 |
| Chỉ mục phụ | tính như bảng, cùng hạn mức | $0 |
| Khôi phục theo thời điểm | $0,20/GB-tháng trên ~50 KB | ~$0,00001 |
| **Tổng** | **~$0,000/giờ** | **< $0,01** |

Hai chế độ tính tiền đều đạt yêu cầu 11, nhưng chúng miễn phí theo hai kiểu khác
nhau, và biết phân biệt là một câu hỏi Domain 4 thật:

- **Provisioned ≤ 25/25**: nằm trong hạn mức *always free*, tức là **$0 tuyệt
  đối**, mãi mãi. Đổi lại: vượt trần thì bị `ProvisionedThroughputExceeded`.
- **Theo request (on-demand)**: **không** nằm trong hạn mức always free, nhưng
  với khối lượng của lab thì tiền là phần nghìn xu. Đổi lại: không bao giờ bị
  chặn, và không phải đoán trước tải.

`verify.sh` chấp nhận cả hai, nhưng nếu bạn chọn provisioned thì tổng RCU và
tổng WCU của bảng **cộng với mọi chỉ mục phụ** phải cùng nằm trong 25.

### Vì sao lab này không có RDS

Kế hoạch tuần 5 có cả RDS. Bộ lab tự thực hành bỏ nó ra, có lý do:

- `db.t3.micro` là **$0,017/giờ ≈ $12,4/tháng**. Hạn mức miễn phí RDS chỉ có 12
  tháng đầu của một tài khoản mới — nếu tài khoản bạn quá hạn đó thì một buổi
  lab quên tắt là mất gần nửa ngân sách cả khoá.
- Thứ đề thi thật sự hỏi về RDS — **Multi-AZ so với Read Replica** — là một
  **bảng**, không phải một thứ bạn phải bật lên mới hiểu. Tệ hơn: standby của
  Multi-AZ **không phục vụ đọc**, nên bật nó lên bạn cũng chẳng quan sát được
  gì ngoài hoá đơn gấp đôi.
- Hàng rào chặn Aurora hoàn toàn (xem dưới), nên nửa nội dung RDS thú vị nhất
  cũng không chạy được.

Phần RDS học bằng `DOI-CHIEU.md` và bằng `docs/aws/w05-databases.md` mục 2 và 3.
Nếu bạn vẫn muốn chạy RDS một lần để lấy nhiệm vụ credit, làm ở `labs/` chứ
không ở đây, và **đặt hẹn giờ 2 tiếng**.

### Boundary chặn gì, vì sao

| Boundary chặn | Vì sao, và bạn gặp nó lúc nào |
|---|---|
| **`rds:CreateDBCluster` — chặn HOÀN TOÀN** | Aurora, DocumentDB, Neptune đều là "cluster". Không có instance nhỏ rẻ. Cơ chế chặn đáng nhớ hơn cả thứ bị chặn: điều kiện dùng `StringNotEquals` trên khoá `rds:DatabaseClass`, mà request tạo cluster **không mang khoá đó** — và trong IAM, **khoá vắng mặt làm điều kiện phủ định trở thành đúng**, nên Deny áp cho mọi request. Đề thi hỏi đúng hành vi này |
| `rds:CreateDBInstance` với class ngoài `db.t3.micro`, `db.t4g.micro` | gõ nhầm một chữ là $200/tháng |
| RDS Multi-AZ | nhân đôi hoá đơn, không dạy thêm gì so với một sơ đồ |
| `elasticache:Create*` | node nhỏ nhất cũng ~$12/tháng |
| **`kinesis:CreateStream`** | shard provisioned ~$11/tháng mỗi shard. Đây là chỗ dễ nhầm nhất tuần này: **DynamoDB Streams** và **Kinesis Data Streams** là hai thứ khác nhau. Cái đầu miễn phí, gắn liền với bảng, không cần tạo stream nào. Nếu bạn thấy mình sắp gọi `kinesis:CreateStream` thì bạn đang đi nhầm đường |
| mọi API ngoài `us-east-1` | như mọi tuần. Hệ quả cho tuần này: **không làm được Global Tables**, vì nó cần region thứ hai. Phần đó học bằng bảng RTO/RPO trong `DOI-CHIEU.md` |

**Gặp lỗi — boundary hay bug?**

- `AccessDenied ... explicit deny in a permissions boundary` khi tạo cluster
  → **boundary, đúng thiết kế.** Bài này không cần cluster nào.
- `ValidationException: Query condition missed key schema element`
  → **không phải boundary.** Đây là kho dữ liệu nói rằng câu hỏi của bạn thiếu
  khoá phân hoạch — và đó chính là yêu cầu 6 đang hoạt động đúng.
- `ValidationException: Query key condition not supported`
  → bạn đang dùng toán tử khoảng (`>=`, `between`) trên **khoá phân hoạch**.
  Khoá phân hoạch chỉ nhận `=`. Không phải boundary.
- `ResourceNotFoundException`
  → tên bảng hoặc tên chỉ mục sai, hoặc chỉ mục còn đang `CREATING`. Chỉ mục
  phụ mất vài chục giây tới vài phút để `ACTIVE` sau khi apply.
- `AccessDenied` nhắc boundary khi bạn **không** đụng gì tới IAM và tên tài
  nguyên **không** bắt đầu bằng `self-w05-` → kiểm tra tên trước khi kiểm tra
  kiến trúc. `DenyCredentialEscalation` dùng `NotResource` theo tiền tố, nên đặt
  tên sai sinh ra một thông điệp lỗi *nói là do boundary* trong khi thật ra chỉ
  là **sai tên**.

---

## Tiêu chí đạt

- [ ] `./verify.sh` xanh toàn bộ, gồm cả bốn check phủ định
- [ ] `terraform destroy` sạch trong một lần
- [ ] Ghi lại **tỉ lệ** mà `verify.sh` in ra ở check phủ định số 7 (đọc bao nhiêu
      bản ghi để lấy về bấy nhiêu). Nhân nó với một bảng 5 triệu dòng và một màn
      hình làm mới 30 giây một lần: ra bao nhiêu tiền mỗi tháng?
- [ ] Giải thích được vì sao câu hỏi 2 **không thể** trả lời bằng khoá chính,
      dù bạn đặt khoá chính khéo đến đâu
- [ ] Trả lời được: nếu bạn đổi khoá phân hoạch sang chính cái *trạng thái đơn*,
      thì câu hỏi 2 trở nên rất nhanh. Điều gì hỏng? (Gợi ý: đếm xem có bao nhiêu
      trạng thái khác nhau, rồi tra từ khoá **hot partition**)
- [ ] Trả lời được: chỉ mục phụ của bạn chiếu (project) những thuộc tính nào?
      Nếu chiếu tất cả thì tốn thêm gì, nếu chiếu ít thì hỏng ở đâu?
- [ ] Trả lời được: bản ghi tạm hết hạn lúc nào — đúng giây bạn đặt, hay muộn
      hơn? Và trong khoảng chênh đó, một truy vấn **có** trả về nó không?
- [ ] Viết được bằng lời của mình bảng so sánh **Multi-AZ với Read Replica**,
      không nhìn tài liệu

---

## Quy trình

```bash
source ../../env.sh
../guard.sh

cd terraform
terraform init
terraform apply                 # đọc chi_phi trước khi gõ yes

# Chỉ mục phụ cần vài chục giây tới vài phút để ACTIVE. Chờ trước khi verify:
watch -n 10 "aws dynamodb describe-table --profile lab-builder \
  --table-name \$(terraform output -raw table_name) \
  --query 'Table.GlobalSecondaryIndexes[].[IndexName,IndexStatus]' --output table"

cd .. && ./verify.sh

$PAGER DOI-CHIEU.md

cd terraform && terraform destroy
```

Lab này rẻ tới mức **giữ lại vài ngày cũng không sao** — và giữ lại là cách tốt
để thử nghiệm thêm: đổi khoá, thêm chỉ mục, xem con số đổi thế nào. Nhưng nếu
giữ, hãy giữ có ý thức, đừng giữ vì quên.

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Không có bẫy nào đặc biệt ở tuần này — bảng xoá là xoá thật, không có version
nào sót lại như tuần 4. Ba thứ cần kiểm tra:

```bash
# 1. Bảng đã biến mất
aws dynamodb list-tables --profile lab-builder \
  --query 'TableNames[?starts_with(@, `self-w05`)]' --output table

# 2. Bản sao lưu theo yêu cầu — chúng SỐNG LÂU HƠN bảng và vẫn tính tiền
aws dynamodb list-backups --profile lab-builder \
  --query 'BackupSummaries[].[TableName,BackupName,BackupSizeBytes]' --output table

# 3. Nếu bạn có lỡ thử RDS trong lúc nghịch: snapshot cũng sống lâu hơn instance
aws rds describe-db-snapshots --profile lab-builder --snapshot-type manual \
  --query 'DBSnapshots[].[DBSnapshotIdentifier,AllocatedStorage]' --output table

../../scripts/find-orphans.sh
```

**Bẫy chung của mọi dịch vụ dữ liệu, và nó ra thi:** ảnh chụp dữ liệu
(snapshot/backup) **không** bị xoá khi bạn xoá nguồn của nó. Đó là tính năng —
người ta muốn giữ được bản sao sau khi dẹp hệ thống — nhưng nó cũng là một trong
những khoản "vì sao tôi vẫn bị tính tiền" phổ biến nhất. Lệnh số 2 và số 3 ở
trên là nghi thức nên làm sau **mọi** lab có dữ liệu.
