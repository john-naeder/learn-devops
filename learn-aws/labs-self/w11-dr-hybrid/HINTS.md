# Gợi ý — tuần 11

Mở từng tầng một. Hai chỗ tốn nhiều giờ nhất không phải chỗ bạn đoán: **quyết
định ở mảnh 0** (chọn nhãn chiến lược trước khi biết nó ràng buộc mình cái gì)
và **cảnh báo kẹt ở "không đủ dữ liệu"**. Cả hai nằm ở tầng 3.

`verify.sh` chạy 5–12 phút vì nó **chờ thời gian thật trôi qua**. Đừng dùng nó
làm vòng lặp debug — mỗi mảnh đều có một lệnh `describe`/`get` tự kiểm trong
hai giây.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Sáu mảnh, và mảnh số 0 không sinh ra tài nguyên nào nhưng quyết định năm mảnh
còn lại.

**Mảnh 0 — quyết định.** Bốn giá trị `chien_luoc`, `rto_phut`, `rpo_phut`,
`vung_phu` phải **nhất quán với nhau** trước khi bạn gõ resource đầu tiên.
`verify.sh` kiểm ba lớp, theo thứ tự:

1. Hai con số có đạt hai trần nghiệp vụ đề bài cho sẵn không.
2. Hai con số có **nằm trong khung của chiến lược bạn khai** không. Mỗi chiến
   lược có một dải RTO/RPO riêng — bảng bốn chiến lược ở
   [`docs/notebook/13-khoi-phuc-tham-hoa.md`](../../../docs/notebook/13-khoi-phuc-tham-hoa.md)
   mục 3. Khai `backup_restore` với RTO 30 phút là trượt vì **lời hứa không
   thuộc về chiến lược đó**, không phải vì hạ tầng sai.
3. Hạ tầng có khớp nhãn không — ba trong bốn nhãn bắt buộc phải có tài nguyên
   thật, mang tag `lab=w11`, đang tồn tại ở `vung_phu`.

Câu tự trả lời trước khi chọn: đề cho RTO tới **4 giờ** và ngân sách
**$5/tháng**. Trong bốn chiến lược, **cái rẻ nhất vẫn đạt** là cái nào? Đề SAA
hỏi đúng câu đó, và đáp án đúng không bao giờ là cái mạnh nhất.

> Chọn nhãn cần Region thứ hai thì đọc mục "Một Region" trong README trước:
> phải mở rào bằng profile admin, và bạn nhận trách nhiệm dọn Region đó.

**Mảnh 1 — kho tệp.** Ba thuộc tính, ba resource riêng biệt (provider AWS v5
tách chúng khỏi khối kho). Đòi đủ **bốn** công tắc chặn public cùng `true`, và
có một check phủ định: người **không có credential** phải bị từ chối.

**Mảnh 2 — kho đơn hàng và cam kết RPO.** Khái niệm cần tra: **point-in-time
recovery**. `verify.sh` không tin lời khai — nó đọc **mốc khôi phục gần nhất**,
trừ đi hiện tại, rồi so với `rpo_phut`. Bạn phải biết cơ chế đó **trễ bao
nhiêu** trước khi khai một con số.

**Mảnh 3 — sao lưu theo lịch, tách khỏi bản gốc.** Bốn thứ cần tra tên riêng:
*kế hoạch* (có lịch), *quy tắc chọn tài nguyên*, *kho lưu trữ*, *vòng đời*.
Hai bẫy: cron của bạn **sẽ không chạy** trong buổi lab nhưng `verify.sh` vẫn
đòi một bản sao lưu **đã hoàn thành**; và bản sao lưu phải có **ngày hết hạn**,
thiếu nó thì mỗi lần sao lưu là một khoản tính tiền mãi mãi.

**Mảnh 4 — tín hiệu sự cố.** Ba tầng nối nhau: một **địa chỉ công khai trả
200** → một **thứ thăm dò nó từ nhiều nơi trên thế giới** → một **cảnh báo đọc
kết quả thăm dò**. Ràng buộc khó nhất ở tầng dưới cùng: địa chỉ đó phải **không
tính tiền theo giờ**.

**Mảnh 5 — runbook.** Bị chấm **nội dung**: ít nhất 5 bước **đánh số**, gọi
đích danh những gì bạn khai ở output, và có **hai phiên bản khác nội dung
nhau** — tải lên, sửa thật, tải lên lần nữa. Câu hỏi thật đằng sau: người sửa
nhầm runbook lúc 3 giờ sáng có lấy lại được bản đúng không?

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Cho việc "khôi phục về một thời điểm bất kỳ" (mảnh 2)** — ba cơ chế, và chúng
**không thay thế nhau**:

| Cơ chế | RPO thật | Giá | Điểm yếu |
|---|---|---|---|
| **Khôi phục liên tục** — khôi phục về bất kỳ giây nào trong cửa sổ giữ | **~5 phút** (mốc luôn trễ một nhịp) | $0,20/GB-tháng theo kích thước bảng | cửa sổ **cố định 35 ngày** |
| **Sao lưu điểm rời rạc** — ảnh chụp theo lịch hoặc theo tay | = khoảng cách giữa hai lần chạy | tiền lưu trữ | không có gì giữa hai lần chụp |
| **Bảng nhân bản đa Region** — mọi ghi lan sang Region khác | **~1 giây** | ghi nhân bản + truyền ra Region | sao chép cả sai lầm của bạn |

Ba câu để tự chọn: (1) `rpo_phut` bạn định khai là bao nhiêu — dưới 5 phút thì
cơ chế thứ nhất đã không đủ, bạn đang hứa con số hạ tầng không đạt; (2) cần giữ
bao lâu — trên 35 ngày thì cơ chế thứ nhất không trả lời được phần đó, và đó là
lý do lab bắt dựng cả hai; (3) bạn chống **mất Region** hay chống **mất dữ liệu
do con người** — hai câu trả lời dẫn tới hai cơ chế khác nhau (sổ tay 13 mục
2), và đề thi phạt nặng ai nhầm.

**Cho việc "sao lưu theo chính sách" (mảnh 3)** — hai đường: tự dựng (hẹn giờ +
hàm chụp + hàm dọn: rẻ, nhưng bạn vừa nhận nuôi ba thứ và không có báo cáo tuân
thủ nào), hoặc một **mặt phẳng điều khiển tập trung** có lịch, vòng đời, chọn
tài nguyên **theo tag**, sao chép sang Region/tài khoản khác, khoá WORM. Câu
hỏi giúp chọn: tuần sau thêm một kho dữ liệu nữa, bạn muốn **sửa kế hoạch** hay
muốn nó **tự được bảo vệ**? Đó cũng là lý do đề thi chọn dịch vụ này mỗi khi
câu hỏi có mùi "nhiều dịch vụ, nhiều tài khoản, chính sách tập trung".

**Cho việc "một địa chỉ công khai trả 200 mà không tính tiền theo giờ"** — ba
ứng viên, cả ba đều nằm trong hàng rào:

| Ứng viên | Giá khi đứng yên | Giao thức | Chỗ vướng |
|---|---|---|---|
| Kho object bật chế độ phục vụ web tĩnh | $0 | **HTTP** (không HTTPS) | phải mở public **có chủ đích** — và đây **không** phải cái kho bị check phủ định |
| URL gọi thẳng một hàm không máy chủ | $0 | HTTPS | thăm dò bằng HTTPS là **tuỳ chọn tính thêm tiền** của tín hiệu sức khoẻ |
| Một cổng API dạng HTTP | $0 | HTTPS | như trên, cộng một tầng phải cấu hình |

Cột "giao thức" là câu hỏi **chi phí kiến trúc**, không phải chi tiết vụn — xem
đoạn giá ở tầng 3.
**Cho việc "tín hiệu tự động báo Region chính đã chết"** — có **ba loại** tín
hiệu sức khoẻ ở tầng DNS, và đề thi hỏi loại thứ ba nhiều hơn hai loại kia:
loại **gọi thẳng** vào một địa chỉ public từ nhiều trạm quan sát; loại **cộng
gộp** nhiều tín hiệu con bằng logic "N trong M"; và loại **đọc trạng thái một
cảnh báo** — cách **duy nhất** theo dõi thứ nằm trong mạng riêng. `verify.sh`
đòi **≥ 2 trạm quan sát báo Success**, nên nó chấm được loại nào? Đọc lại câu
đó rồi tự trả lời: đây là chỗ phân biệt "đã tạo" với "đang chạy thật".

**Cho câu "có cần Region thứ hai không"** — `verify.sh` đếm tài nguyên mang tag
`lab=w11` ở `vung_phu` bằng một API đọc theo tag; rào chưa mở thì API đó **cũng
bị từ chối** và trả 0, trông y hệt "Region phụ trống rỗng". Với `warm_standby`
trở lên nó còn đếm riêng phần **tính toán** đang chờ. Đừng khai một nhãn mà bạn
không định trả giá cho nó.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**`AccessDenied` ở `aws_iam_role`.** Thiếu `permissions_boundary`. Lấy ARN:
`terraform -chdir=../../_boundary output -raw lab_boundary_arn`. Lab bắt buộc
có ít nhất một role — dịch vụ sao lưu đóng vai nó để đọc dữ liệu của bạn và ghi
vào kho lưu trữ. Đã có boundary mà vẫn hỏng: kiểm tra tiền tố `self-w11-` trong
tên role, vì sai tiền tố cho ra thông điệp **y hệt**.

**Kế hoạch sao lưu tạo xong nhưng không có bản sao lưu nào.** Đúng thiết kế:
rule chạy theo cron, cron chưa tới giờ. Kích hoạt **một** lần theo yêu cầu
(`aws backup start-backup-job`, cần ARN tài nguyên + tên kho lưu trữ + ARN
role). Bản đầu tiên của một bảng nhỏ mất 1–5 phút mới `COMPLETED`.

**Bản sao lưu không có ngày hết hạn.** Thiếu khối vòng đời trong rule. Tên khối
là `lifecycle`, và đây đúng là chỗ cú pháp gây bối rối vì Terraform cũng có một
**meta-argument** trùng tên — hai thứ khác hẳn nhau:

```hcl
rule { lifecycle { delete_after = 7 } }   # vòng đời của BẢN SAO LƯU
```

Khai thêm `cold_storage_after` thì AWS ép `delete_after >= cold_storage_after
+ 90` — nguồn của một lỗi validate khó hiểu.

**Mốc khôi phục luôn trễ hơn `rpo_phut` bạn khai.** Khôi phục liên tục không
bao giờ cho mốc bằng "ngay bây giờ" — luôn trễ khoảng **5 phút**, và mới bật
thì mất vài phút nữa mới có mốc đầu tiên. Khai `rpo_phut = 1` thì không cấu
hình nào cứu được: **con số sai**, không phải hạ tầng sai. Tự kiểm:
`aws dynamodb describe-continuous-backups --table-name <ten>` rồi so
`LatestRestorableDateTime` với đồng hồ.

**Đừng nhầm hai cơ chế của kho đơn hàng — lab đòi cả hai.** Khôi phục liên tục
(bật trên chính bảng, cửa sổ 35 ngày, khôi phục ra một **bảng mới**) trả lời
"mất tối đa bao nhiêu phút". Sao lưu điểm rời rạc (nằm trong kho lưu trữ, có
vòng đời, sao chép đi nơi khác được) trả lời "giữ được bao lâu, tách khỏi bản
gốc tới đâu".

**Tín hiệu sức khoẻ: `AccessDenied`, hoặc cảnh báo không thấy dữ liệu.** Dịch
vụ DNS này **global** và API chỉ nói chuyện qua `us-east-1`. Hệ quả quan trọng
hơn: số đo `HealthCheckStatus` **chỉ phát ra ở `us-east-1`** — cảnh báo phải
nằm đúng ở đó, nếu không nó vĩnh viễn mù. Cả bộ lab đã cố định `us-east-1` nên
bạn được lợi miễn phí; biết lý do vẫn tốt hơn, vì đề thi hỏi.

**"0 trạm quan sát báo Success".** Theo thứ tự hay gặp: tín hiệu mới tạo chưa
có báo cáo (chờ 2–3 phút); địa chỉ không nhận kết nối **từ internet**; sai cổng
/ giao thức / `resource_path` (thiếu dấu `/` đầu). Tự kiểm như verify:
`curl -sI <URL>` phải ra `200`, không phải `301` hay `403` — kho object có
**hai** dạng địa chỉ, REST và website, chỉ một trả về trang mặc định khi gọi `/`.

**`interval × threshold` phải ≤ 90 giây, và đó là câu hỏi tiền.** Nhịp thăm dò
chỉ có hai giá trị hợp lệ — **30 giây** (chuẩn) và **10 giây** (nhanh, **tính
thêm tiền**) — ngưỡng 1–10, nên 30 × 3 = 90 vừa đủ đạt với giá cơ bản. Bảng giá
đáng nhớ: **$0,50/tháng** cho một tín hiệu cơ bản trỏ tới endpoint AWS, cộng
khoảng **$1,00/tháng mỗi tuỳ chọn** — nhịp nhanh, so khớp chuỗi, **và HTTPS**.

**Cảnh báo kẹt ở `INSUFFICIENT_DATA`.** Chỗ tốn thời gian nhất của lab. Bốn
nguyên nhân: sai `dimensions` (phải trỏ đúng id tín hiệu sức khoẻ); sai
namespace hoặc tên số đo (`verify.sh` so **nguyên văn**); cảnh báo nằm ngoài
`us-east-1`; hoặc chưa đủ thời gian — số đo phát mỗi phút, cảnh báo cần vài
chu kỳ.

**Và `treat_missing_data` phải là `breaching`.** Với một tín hiệu sức khoẻ,
**im lặng chính là triệu chứng**: số đo ngừng phát nghĩa là thứ đang thăm dò
cũng chết, đúng lúc bạn cần cảnh báo kêu nhất. So với tuần 10 nơi
`notBreaching` mới đúng cho một số đo đếm lỗi — **cùng một tham số, hai đáp án
ngược nhau, vì bản chất số đo khác nhau.** Đề thi hỏi đúng chỗ đó.

**Runbook chỉ có một phiên bản, hoặc hai phiên bản giống hệt.** `verify.sh` tải
bản mới nhất lẫn một bản **không phải mới nhất** rồi so bằng `cmp`. Phải sửa
**nội dung thật** giữa hai lần tải lên. Kiểm:
`aws s3api list-object-versions --bucket <kho> --prefix <key>`.

**Runbook đủ dài nhưng vẫn đỏ.** Nó bị chấm theo **chuỗi**: phải chứa đúng giá
trị `chien_luoc`, tên kho đơn hàng, tên kho tệp, và giá trị `vung_phu` (kể cả
khi giá trị đó là `khong`); cộng ít nhất 5 dòng **bắt đầu** bằng số thứ tự
(`1.` hoặc `1)`, ở đầu dòng, không phải giữa câu).

**Check phủ định "không credential thì không đọc được" đỏ.** Bạn đang dùng một
kho vừa phục vụ web công khai vừa chứa runbook. Hai mục đích, hai kho.

**Nếu bạn làm thêm yêu cầu 3 của README (bản sao thứ hai tự cập nhật).**
`verify.sh` không có output cho kho thứ hai nên phần này không được chấm, nhưng
cơ chế thì đúng là thứ đề thi hỏi. Bốn lỗi bạn chắc chắn gặp:
- `Destination bucket must have versioning enabled` — **cả hai** kho phải bật
  lịch sử phiên bản **trước khi** cấu hình sao chép. Lỗi phụ thuộc thứ tự; dùng
  `depends_on` nếu Terraform tạo song song.
- `Role does not have permissions to replicate` — cơ chế sao chép cần **một IAM
  role của riêng nó**, và role đó cũng bắt buộc mang `permissions_boundary` +
  tiền tố `self-w11-`. Đọc kỹ: nó cần quyền ở **cả hai phía**, và hai bộ quyền
  đó **khác nhau**.
- Sao chép chỉ áp cho object tạo **sau** khi bật rule; object cũ nằm im mãi mãi
  trừ khi chạy một tác vụ sao chép hàng loạt. Câu này ra thi nguyên văn.
- Xoá ở nguồn có xoá ở đích không? Tra `delete_marker_replication`, mặc định
  **tắt** — nghĩ vì sao đó thường đúng cho DR, trước khi đọc `DOI-CHIEU.md`.

**`terraform destroy` gãy.** Ba chỗ: kho object còn phiên bản cũ (khai
`force_destroy` ngay từ đầu); kho lưu trữ sao lưu không xoá được khi còn
recovery point (`aws backup delete-recovery-point` trước); tín hiệu sức khoẻ bị
bỏ quên tốn $0,50/tháng **mãi mãi** và không mang tag như các dịch vụ khác.

**Tài liệu cần tra:**
- `aws_s3_bucket_versioning`, `aws_s3_bucket_public_access_block`,
  `aws_s3_bucket_website_configuration`, `aws_s3_object`
- `aws_dynamodb_table` (`point_in_time_recovery`); `aws_backup_vault`,
  `aws_backup_plan` (`rule`, `lifecycle`), `aws_backup_selection` (`iam_role_arn`)
- `aws_route53_health_check` (`request_interval`, `failure_threshold`,
  `resource_path`, `disabled`, `inverted`); `aws_cloudwatch_metric_alarm`
  (`dimensions`, `treat_missing_data`, `alarm_actions`); `aws_sns_topic`
- [Route 53 DNS failover](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-failover.html) — mục "Monitoring health checks using CloudWatch"
- [DynamoDB point-in-time recovery](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/PointInTimeRecovery.html)
- [AWS Backup developer guide](https://docs.aws.amazon.com/aws-backup/latest/devguide/whatisbackup.html) — mục "Backup plans" và "Lifecycle and storage tiers"
- [S3 replication requirements](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)

</details>
