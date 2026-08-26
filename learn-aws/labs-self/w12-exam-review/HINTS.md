# Gợi ý — tuần 12

Lab này khác mười một lab kia: chỗ khó **không** nằm ở Terraform. Khuôn hạ tầng
chỉ có ba thứ (một kho, một đường vào thứ hai, một hàm) và bạn đã dựng cả ba ở
tuần 5 và tuần 6. Chỗ khó nằm ở việc **nghĩ ra nội dung** — và không tầng gợi ý
nào giúp được bạn phần đó, vì phần đó chính là bài thi.

Nên ba tầng dưới đây chỉ gỡ cho bạn phần khuôn. Phần ruột là của bạn.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bài này có **bốn mảnh**, và mảnh thứ tư nặng bằng ba mảnh đầu cộng lại.

**Mảnh 1 — kho ôn tập trả lời được hai câu hỏi khác nhau.**
Đọc lại yêu cầu 1 và đếm: bạn cần lấy ra "mọi bảng so sánh" và "mọi câu hỏi của
miền D1". Thử vẽ ra giấy một kho chỉ có **một** cách tra, rồi tự hỏi câu thứ hai
phải trả lời bằng cách nào. Bạn sẽ thấy hoặc là quét hết rồi lọc, hoặc là cần
một thứ nữa. Khái niệm cần tra: **secondary index**, và cụ thể hơn là sự khác
nhau giữa hai loại của nó — chỉ một loại cho phép khoá phân vùng khác với kho
gốc, và bạn cần đúng loại đó.

Câu hỏi tự kiểm trước khi apply: *sơ đồ khoá của tôi có cho phép lấy đúng 10
bảng mà chỉ chạm vào 10 item không, hay nó bắt tôi đọc cả 30 rồi vứt đi 20?*
`verify.sh` đo chính xác điều đó và so hai con số.

**Mảnh 2 — nạp nội dung vào kho bằng Terraform.**
Có một resource cho việc "đặt sẵn một dòng dữ liệu vào kho" — tra nó, và đọc kỹ
phần nói về **kiểu dữ liệu**. Kho này không lưu JSON thường; nó lưu JSON có gắn
nhãn kiểu cho từng giá trị, và nhãn sai thì lỗi báo rất mơ hồ. Nạp **hai** item
trước rồi đọc lại chúng bằng tay. Đừng nạp ba mươi.

Chú ý một hành vi sẽ cắn bạn về sau: resource đó chỉ quản item nào **nó tạo ra**.
Bạn đổi khoá của một item thì item cũ nằm lại trong kho mãi mãi, và `verify.sh`
sẽ đếm cả nó.

**Mảnh 3 — giám khảo.**
Ba chế độ trong "Hợp đồng của giám khảo" xếp theo độ khó tăng dần, và chúng dùng
lại nhau: `kiem_ke` chỉ cần đếm, `cham` cần đọc một item, `de_thi` cần đọc theo
miền rồi chọn. Viết `kiem_ke` trước — nó là mảnh nhỏ nhất chứng minh được rằng
hàm của bạn **đọc được kho**, và một khi nó chạy thì hai chế độ kia chỉ là logic.

`de_thi` là chỗ duy nhất có chút toán. Bạn có bốn trọng số cộng lại bằng 100 và
một số `n`. Nhân ra thì được số lẻ. Nghĩ trước: bạn làm tròn thế nào để tổng vẫn
đúng bằng `n`? (Sai số cho phép của `verify.sh` là ±1,5 câu mỗi miền, nên bạn
không cần thuật toán chia ghế của quốc hội — nhưng tổng thì phải khớp tuyệt đối.)

**Mảnh 4 — nội dung.** Mười bảng và hai mươi câu. Ba giờ. Không có gợi ý nào ở
đây cả; có thì đã là lời giải cho bài thi của bạn. Ba lời khuyên về **cách làm**:

- Viết bảng **trước**, viết câu hỏi **sau**, và mỗi câu hỏi sinh ra từ một bảng.
  Làm ngược lại thì bạn sẽ có 20 câu rời rạc và một tập bảng chắp vá.
- Mỗi lý do loại phải trả lời được câu *"phương án này sai vì cơ chế nào của
  dịch vụ đó không làm được điều đề yêu cầu"*. Nếu bạn chỉ viết được "vì nó đắt
  hơn" thì bạn chưa hiểu phương án đó — và đề thi sẽ hỏi đúng chỗ ấy.
- Ba phương án sai nên sai theo **ba kiểu khác nhau**: một cái *chạy được nhưng
  không tối ưu*, một cái *hiểu nhầm cơ chế* (chọn thứ không làm được việc đề
  hỏi), một cái *đúng cho một bối cảnh khác*. Đề thật giăng bẫy đúng ba kiểu đó,
  và tự viết ra chúng là cách nhanh nhất để lần sau bạn nhận ra chúng.

Nếu bí ý tưởng cho bảng, đừng bịa ra chủ đề mới: mở
[`docs/notebook/22-bang-so-sanh.md`](../../../docs/notebook/22-bang-so-sanh.md)
và [`docs/notebook/20-cay-quyet-dinh.md`](../../../docs/notebook/20-cay-quyet-dinh.md),
lấy mười cặp mà bạn **hay nhầm nhất**, rồi **đóng hai file đó lại** và viết bảng
từ trí nhớ. Chép lại thì không tính là ôn tập; chỗ nào viết không ra mới đúng là
chỗ bạn cần đọc lại.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Cho kho ôn tập.** Đề bài đã chốt gần hết cho bạn: yêu cầu 1 nói "không tính
tiền lúc bạn không dùng" và "hai đường tra khác nhau", `chi_muc_mien` trong Hợp
đồng output nói kho phải có secondary index. Thứ còn lại để bạn chọn là **sơ đồ
khoá**, và đó mới là câu hỏi thật:

| Cách mô hình hoá | Lấy 10 bảng | Lấy câu hỏi D1 | Vấn đề |
|---|---|---|---|
| Mỗi loại một kho riêng | rẻ | rẻ | hai kho, hai đường quyền, hai lần dọn — và không dùng được `chi_muc_mien` như hợp đồng |
| Một kho, khoá phân vùng là mã item | phải quét hết | phải quét hết | mọi câu hỏi truy xuất đều thành quét toàn kho |
| Một kho, khoá phân vùng là **loại item**, khoá sắp xếp có **tiền tố** | rẻ | cần index | đây là hướng README mô tả, và tiền tố `bang#`/`cauhoi#` không phải trang trí |

Vì sao tiền tố quan trọng: index của bạn có khoá phân vùng là `mien`, nên một
truy vấn "miền D1" trả về **cả** bảng lẫn câu hỏi của miền đó. Muốn tách ra mà
không phải đọc rồi vứt, bạn cần một điều kiện đặt ngay trên **khoá sắp xếp** —
tra toán tử `begins_with` và đọc kỹ chỗ nói nó dùng được ở đâu: trong điều kiện
khoá thì rẻ, trong bộ lọc thì bạn đã trả tiền đọc rồi mới lọc.

**Cho giám khảo.** Nó chạy vài chục lần mỗi buổi lab, mỗi lần vài chục mili-giây,
rồi ngủ. So ba nhóm compute theo trục "trả tiền cho cái gì" và bạn sẽ thấy chỉ
có một nhóm khớp trần $0,00/giờ. Đây đúng là câu hỏi Domain 4 mà bảng "Lambda ·
Fargate · ECS trên EC2 · EC2" của bạn phải trả lời được — nếu bạn còn phải nghĩ
lâu ở đây, hãy viết bảng đó trước rồi quay lại.

**Cho quyền của giám khảo.** Hai câu hỏi tự chốt:
1. Nó cần đọc **những ARN nào**? Đếm cho đủ — kho và index là hai tài nguyên
   khác nhau trong mắt IAM, dù chúng cùng chứa một dữ liệu.
2. Nó có cần ghi không? Đọc lại yêu cầu 7 rồi trả lời. `verify.sh` hỏi bộ máy
   đánh giá quyền của IAM đúng câu đó, và nó không hỏi cấu hình của bạn — nó hỏi
   *"nếu principal này gọi hành động này thì kết quả là gì"*.

**Cho việc đóng gói mã giám khảo.** Hai đường: nén tay ra một tệp zip rồi trỏ
vào, hoặc để Terraform nén lúc apply. Đường thứ hai cần một provider phụ, và
Terraform **tự tải nó về** — `versions.tf` cho sẵn không cần sửa. Đường thứ nhất
đơn giản hơn nhưng bạn phải nhớ nén lại mỗi lần sửa mã, và quên nén là cách mất
20 phút debug một hàm "không chịu đổi hành vi".

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**`terraform apply` báo `AccessDenied` ở `aws_iam_role`.**
Thiếu `permissions_boundary`. Lấy ARN:
`terraform -chdir=../../_boundary output -raw lab_boundary_arn`.
Đã có mà vẫn hỏng **và** thông điệp nhắc tới permissions boundary: kiểm tra tên
role có tiền tố `self-w12-` chưa. Sai tiền tố cho ra thông điệp y hệt.

**`ValidationException: One or more parameter values were invalid` khi nạp item.**
Bốn nguyên nhân, theo thứ tự hay gặp:
- Một giá trị chuỗi **rỗng** trong khoá. Kho này không nhận chuỗi rỗng làm giá
  trị khoá.
- Thiếu nhãn kiểu, hoặc nhãn sai: chuỗi là `S`, số là `N` (**và số vẫn phải viết
  dưới dạng chuỗi**), danh sách là `L`, map là `M`.
- Thiếu khoá sắp xếp trong item, hoặc thiếu khai nó ở phía resource.
- Map lồng trong map mà quên bọc thêm một tầng nhãn kiểu cho từng giá trị con.

Cú pháp lạ duy nhất đáng trích trong cả lab, để bạn thấy hai tầng nhãn:

```hcl
item = jsonencode({ phan_loai = { S = "BANG" }
                    lua_chon  = { L = [{ S = "SQS" }, { S = "SNS" }] } })
```

**`ValidationException: Query condition missed key schema element`.**
Bạn đang đặt điều kiện lên một thuộc tính không phải khoá của **đường vào bạn
đang dùng**. Nhớ: mỗi index có sơ đồ khoá riêng, và điều kiện khoá chỉ nói được
về khoá của chính index đó. Mọi thứ khác phải là bộ lọc — và bộ lọc chạy **sau
khi đã đọc và đã tính tiền**.

**Giám khảo chạy được ở chế độ `kiem_ke` nhưng `AccessDeniedException` ở `de_thi`.**
Gần như chắc chắn: policy của nó cấp quyền trên ARN của kho nhưng không cấp trên
ARN của index. ARN của index có dạng `<arn-kho>/index/<ten-index>` và IAM coi nó
là một tài nguyên riêng.

**Giám khảo trả về đúng nhưng `verify.sh` bảo không đọc được JSON.**
Ba nguyên nhân: hàm trả về **chuỗi** thay vì đối tượng; hàm bọc kết quả trong vỏ
`{"statusCode":200,"body":"..."}` (vỏ đó chỉ dành cho khi có API Gateway đứng
trước — ở đây `verify.sh` gọi thẳng); hoặc hàm ném exception và thứ về là dấu vết
lỗi. Kiểm nhanh bằng `aws lambda invoke ... /dev/stdout` rồi nhìn bằng mắt.

**`verify.sh` đếm ra nhiều bảng hơn số bạn viết.**
Bạn đã đổi khoá của một item ở lần apply trước. Resource nạp item chỉ xoá cái
**nó biết**; item cũ vẫn nằm trong kho. Xoá tay bằng `aws dynamodb delete-item`,
hoặc `terraform destroy` rồi apply lại — ở lab $0 thì cách thứ hai rẻ và sạch.

**`verify.sh` bảo "đường truy vấn của bạn không rẻ hơn đường quét".**
Bạn đang lọc thay vì đặt điều kiện khoá. Xem lại mảnh 1 ở tầng 1 và mục tiền tố
ở tầng 2.

**`verify.sh` bảo phân bổ miền lệch trọng số.**
Nó in ra số câu từng miền và số câu bạn còn thiếu hoặc thừa. Đừng sửa bằng cách
đổi nhãn `mien` của một câu đã viết — nhãn phải đúng với nội dung câu hỏi, nếu
không bạn đang tự làm hỏng chính công cụ ôn tập của mình. Viết thêm câu cho miền
thiếu, đó mới là việc đề bài muốn.

**Nghi ngờ hàm không thật sự đọc kho.**
Xoá tay một item bằng `aws dynamodb delete-item`, gọi lại `kiem_ke`, xem con số
có tụt không, rồi `terraform apply` để nạp lại. Một hàm trả về số cứng sẽ không
nhúc nhích — và `verify.sh` cũng đối chiếu số của hàm với số nó tự đếm được từ
kho, nên hai nguồn lệch nhau là đỏ.

**Tài liệu cần tra:**
- `aws_dynamodb_table` (`billing_mode`, `hash_key`, `range_key`,
  `global_secondary_index`), `aws_dynamodb_table_item`
- `aws_lambda_function`, `aws_iam_role` (`permissions_boundary`),
  `aws_iam_role_policy`, `aws_cloudwatch_log_group`, `data "archive_file"`
- [DynamoDB — Query and Scan](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Query.html) —
  đọc kỹ mục nói về `Count` và `ScannedCount`
- [DynamoDB — Global secondary indexes](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GSI.html)
- [DynamoDB — Read/write capacity mode](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html)
- [IAM — Policy Simulator API](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html)

</details>
