# Tuần 10 — Cảnh báo phải kêu, và phải kêu tới được người trực  (tự viết)

`Domain 2 · Resilient (26%) + Domain 4 · Cost-Optimized (20%)`

| | |
|---|---|
| **Chi phí khi chạy** | **$0,00/giờ** — Lambda, CloudWatch Logs, SQS, S3, DynamoDB on-demand đều nằm trong hạn mức miễn phí ở quy mô lab |
| **Quên 1 tháng** | **$0,00** nếu bạn giữ đúng 1 số đo tuỳ chỉnh và ≤ 10 alarm (xem "Hàng rào của lab này") |
| **Thời gian** | ~4 giờ viết + ~10 phút chạy `verify.sh` |
| **Điều kiện** | nên xong `w07-decoupling` trước (lab này dùng lại hàng đợi). Đọc [`docs/aws/w10-observability-iac.md`](../../../docs/aws/w10-observability-iac.md) |

> `verify.sh` **cố tình làm hỏng hệ thống của bạn** rồi ngồi chờ xem có ai được
> báo động không. Nó mất khoảng 10 phút và in tiến độ suốt. Đừng bắt đầu khi chỉ
> còn 5 phút.

---

## Bối cảnh

Thứ Bảy tuần trước, dịch vụ tính phí của bạn hỏng lúc 2 giờ sáng và tự chạy lại
được lúc 8 giờ. Sáu tiếng đó không ai biết. Khách hàng biết trước bạn.

Cuộc họp sau sự cố rút ra bốn điều, và sếp muốn cả bốn được **chứng minh**, không
phải được hứa:

- Đội trực nói "chúng tôi có dashboard mà". Có, nhưng 2 giờ sáng không ai nhìn
  dashboard. Cái thiếu là thứ **chủ động đánh thức người**.
- Người ta có mở log ra xem, nhưng phải cuộn tay qua hàng nghìn dòng. Không ai
  trả lời được "trong sáu tiếng đó có bao nhiêu lỗi" mà không đếm bằng mắt.
- Hoá đơn CloudWatch tháng trước gấp ba lần bình thường. Log group mặc định giữ
  nhật ký **vĩnh viễn**, và không ai đặt hạn.
- Hạ tầng dựng bằng Terraform, nhưng state nằm trên laptop của một người. Người
  đó đang đi nghỉ và không ai dám `apply` gì cả trong suốt sự cố.

Nhiệm vụ của bạn: dựng lại đủ nhỏ để chứng minh cả bốn điều trên đã được sửa.

---

## Yêu cầu

Mỗi yêu cầu ánh xạ 1:1 với một nhóm check trong `verify.sh`.

1. **Có một dịch vụ chạy được và nói cho ta biết nó đang làm gì.** Nó nhận yêu
   cầu, xử lý, và ghi lại một dòng nhật ký **có cấu trúc** cho mỗi yêu cầu. Nó
   phải cư xử đúng theo Hợp đồng đầu vào bên dưới — `verify.sh` là người gọi.

2. **Nhật ký không được giữ vĩnh viễn.** Hạn giữ tối đa **7 ngày**. Đây là dòng
   duy nhất trong cả lab liên quan trực tiếp tới hoá đơn tháng trước.

3. **Số lỗi nghiệp vụ phải trở thành một con số đo được**, sinh ra từ **chính
   nhật ký**, không phải do dịch vụ gọi thêm một API để báo cáo. Và khi hệ thống
   khoẻ, con số đó phải là **0** — không phải "không có dữ liệu". Hai trạng thái
   này khác nhau, và sự khác nhau đó là nguyên nhân của một loại sự cố im lặng.

4. **Khi lỗi vượt ngưỡng trong 2 chu kỳ liên tiếp thì phải có cảnh báo, và cảnh
   báo phải tới được người trực.** Ngưỡng cụ thể để chấm được:
   **từ 3 lỗi trở lên trong một chu kỳ 60 giây, xảy ra ở 2 chu kỳ liên tiếp.**
   "Tới được người trực" nghĩa là thông điệp cảnh báo phải **thật sự xuất hiện**
   ở một hộp thư đọc được (xem `hop_thu_truc` trong Hợp đồng output).
   `verify.sh` sẽ đẩy hệ thống vào trạng thái lỗi rồi ngồi chờ thông điệp đó.

5. **Khi hệ thống khoẻ thì im lặng — nhưng không được im lặng vì mù.** Cảnh báo
   không được kêu lúc bình thường, **và** không được nằm ở trạng thái "không đủ
   dữ liệu". Một cảnh báo kẹt ở "không đủ dữ liệu" trông giống hệt một cảnh báo
   khoẻ mạnh trên dashboard, và nó sẽ không bao giờ kêu.

6. **Trả lời được "10 yêu cầu chậm nhất giờ qua là những cái nào" mà không cuộn
   tay.** Truy vấn phải được **lưu sẵn** trong hệ thống (không phải gõ lại mỗi
   lần sự cố), chạy được trên nhóm nhật ký của lab, và trả về ít nhất một dòng.
   Kết quả phải có một cột tên `ms` và **sắp xếp giảm dần theo cột đó**.

7. **State của Terraform phải nằm ở nơi cả đội dùng được.** Bốn điều kiểm chứng
   được: có **lịch sử phiên bản** (để quay lại khi state hỏng), được **mã hoá**,
   **không ai ngoài account đọc được**, và có **cơ chế khoá** chống hai người ghi
   cùng lúc.

8. **Không thứ gì trong lab này được tính tiền theo giờ.** `verify.sh` quét và
   sẽ đỏ nếu tìm thấy.

### Hợp đồng đầu vào của dịch vụ

`verify.sh` gọi hàm của bạn bằng ba loại payload JSON. Mỗi lệnh gọi phải sinh ra
**đúng một dòng** nhật ký, và dòng đó phải là **JSON một dòng** chứa ít nhất ba
trường:

| Trường | Kiểu | Nghĩa |
|---|---|---|
| `muc` | chuỗi | `"INFO"` hoặc `"ERROR"` |
| `ma_yeu_cau` | chuỗi | chép lại đúng giá trị nhận được trong payload |
| `ms` | số | thời gian xử lý, tính bằng mili-giây |

Ba loại payload:

```json
{"che_do": "binh_thuong", "ma_yeu_cau": "<chuỗi>"}   -> ghi muc = "INFO"
{"che_do": "loi",         "ma_yeu_cau": "<chuỗi>"}   -> ghi muc = "ERROR"
{"che_do": "cham",        "ma_yeu_cau": "<chuỗi>", "ms": 1500}
                                                      -> xử lý ít nhất 1500 ms,
                                                         rồi ghi muc = "INFO"
                                                         với ms là số thật đo được
```

Hàm trả về gì không quan trọng. `verify.sh` chỉ đọc nhật ký, số đo và cảnh báo —
đúng như một hệ thống giám sát thật, nó không nhìn vào bên trong ứng dụng.

> Chế độ `loi` **không bắt buộc** phải làm hàm ném exception. Bài này đo **lỗi
> nghiệp vụ** — thứ ứng dụng tự biết là sai và tự ghi lại — chứ không đo lỗi
> runtime. Phân biệt hai thứ đó là một mục trong `DOI-CHIEU.md`.

---

## Hợp đồng output

Thiếu một output = `verify.sh` dừng ngay, không chấm được gì.

| Output | Kiểu | `verify.sh` dùng để làm gì |
|---|---|---|
| `ten_ham` | string | Tên hàm để gọi (`aws lambda invoke`). Đây là cách verify đẩy hệ thống vào trạng thái lỗi |
| `nhom_nhat_ky` | string | Tên nhóm nhật ký. Đọc hạn giữ, và chạy truy vấn ở yêu cầu 6 |
| `so_do_khong_gian` | string | Namespace của số đo lỗi |
| `so_do_ten` | string | Tên số đo lỗi |
| `ten_canh_bao` | string | Tên cảnh báo. verify đọc trạng thái, cấu hình và hành động của nó |
| `hop_thu_truc` | string (URL) | Hộp thư mà verify **đọc** để chứng minh cảnh báo tới nơi. verify hỗ trợ URL của một hàng đợi SQS |
| `ten_truy_van` | string | Tên truy vấn đã lưu ở yêu cầu 6 |
| `kho_state` | string | Tên kho chứa state Terraform |
| `duong_dan_state` | string | Đường dẫn (key) của object state trong kho đó |
| `bang_khoa_state` | string | Tên bảng dùng làm khoá chống ghi đồng thời |

Đặt tên resource với prefix `self-w10-`.

> **Vì sao `hop_thu_truc` phải là thứ máy đọc được:** cách "thật" nhất là gửi
> email cho người trực, nhưng không script nào chứng minh được email đã tới. Lab
> vẫn bắt bạn có **một subscription đã xác nhận** (verify kiểm tra), và thêm một
> đường nữa mà máy đọc được. Trong production, hai đường này chính là *người*
> và *hệ thống ticket*, và bạn cần cả hai.

---

## Hàng rào của lab này

**Trần chi phí: $0,00/giờ.** Không tài nguyên nào trong lab tính tiền theo giờ.
Nhưng lab này là lab **dễ trượt chi phí nhất** trong cả bộ, vì CloudWatch tính
tiền theo những trục mà boundary không nhìn thấy. Bốn con số thật:

| Khoản | Hạn mức miễn phí | Giá sau đó | Lab này dùng |
|---|---|---|---|
| Số đo tuỳ chỉnh (gồm cả số đo sinh từ metric filter) | **10 số đo** | $0,30/số đo/tháng | 1 |
| Alarm | **10 alarm** tiêu chuẩn | $0,10/alarm/tháng | 1–2 |
| Log ingest + lưu trữ | **5 GB/tháng** | $0,50/GB nạp vào, $0,03/GB-tháng lưu | vài KB |
| Logs Insights | không có bậc miễn phí riêng | **$0,005/GB quét** | vài KB mỗi truy vấn |

Hai điều rút ra, và cả hai đều là câu hỏi Domain 4: **số đo tuỳ chỉnh không miễn
phí** (mỗi tổ hợp dimension khác nhau là một số đo riêng — đây là cách hoá đơn
CloudWatch nổ), và **log không có hạn giữ là chi phí tăng mãi mãi**.

**Hai dịch vụ được phép nhưng lab không dùng, và bạn phải biết giá:**

| Dịch vụ | Giá thật | Vì sao lab không dùng |
|---|---|---|
| AWS Config | $0,003/mục cấu hình ghi lại + $0,001/đánh giá rule. Một account nhỏ vẫn ra vài đô/tháng nếu bật recorder cho mọi loại tài nguyên | Nó là **detective control** cho tuân thủ, không phải công cụ cảnh báo vận hành. Tắt: xoá configuration recorder, không chỉ xoá rule |
| GuardDuty | 30 ngày dùng thử, sau đó tính theo lượng CloudTrail event + DNS log + VPC Flow Log phân tích. Account lab nhỏ thì vài xu, nhưng nó **không tự tắt** sau khi hết thử | Nó phát hiện **mối đe doạ**, không phát hiện **lỗi ứng dụng**. Tắt: `aws guardduty delete-detector --detector-id <id>` |

**Boundary chặn gì ở lab này:**

- `lambda:PutProvisionedConcurrencyConfig` — provisioned concurrency tính tiền cả
  khi không có request. Lab không cần, và nếu bạn định "làm ấm" hàm thì đó là bài
  toán khác.
- `iam:CreateRole` không mang boundary → **role thực thi của hàm bắt buộc phải có**
  `permissions_boundary = "arn:aws:iam::<acct>:policy/labs-self-boundary"`.
  Lấy ARN: `terraform -chdir=../_boundary output -raw lab_boundary_arn`.
  Đây là lỗi số một khiến `terraform apply` gãy ở lab này.
- `kinesis:CreateStream` — nếu bạn định đẩy log qua Kinesis Data Streams thì bị
  chặn. Firehose **không** bị chặn. `DOI-CHIEU.md` bàn khi nào đường đó mới đúng.
- Mọi API ngoài `us-east-1`.

**Phân biệt `AccessDenied` của hàng rào với bug của bạn:**

| Thông điệp chứa | Nghĩa là | Làm gì |
|---|---|---|
| `explicit deny in a permissions boundary` | hàng rào của bộ lab | đọc lại mục trên, đừng gỡ rào |
| `explicit deny in a permissions boundary` **khi đang tạo IAM role** | có thể chỉ là **sai tên** | kiểm tra prefix `self-w10-` trước khi kiểm tra kiến trúc |
| `not authorized to perform: logs:CreateLogGroup` từ chính hàm của bạn | role thực thi thiếu quyền | bug của bạn |

---

## Tiêu chí đạt

`./verify.sh` xanh hết là điều kiện **cần**:

- [ ] `./verify.sh` xanh hết — trong đó có **5 negative check**
- [ ] Giải thích được khác nhau giữa `treat_missing_data` = `missing`,
      `notBreaching`, `breaching`, `ignore` — và vì sao mặc định là thứ gây ra
      "cảnh báo im lặng vì mù"
- [ ] Giải thích được vì sao `evaluation_periods = 2` khác
      `datapoints_to_alarm = 2` khi hai số đó không bằng nhau
- [ ] Nói được: metric filter với `default_value = 0` khác gì khi không đặt, và
      hậu quả lên cảnh báo là gì
- [ ] Nói được: vì sao **không** nên đưa `ma_yeu_cau` vào làm dimension của số đo,
      dù nghe rất tiện
- [ ] Chỉ ra được ba metric mà CloudWatch **không** có sẵn cho EC2 và giải thích
      vì sao (gợi ý: hypervisor nhìn thấy gì và không nhìn thấy gì)
- [ ] Trả lời được: nếu hai người cùng `terraform apply` trong 3 giây, người thứ
      hai nhận được gì, và điều gì xảy ra nếu **không** có cơ chế khoá

---

## Quy trình

Lab này có hai pha vì **state phải nằm ở nơi chưa tồn tại lúc bạn bắt đầu**. Đây
là bài toán mồi (bootstrap) thật, ai làm IaC cũng gặp một lần:

```bash
source ../../env.sh
../_boundary/guard.sh

cd terraform
terraform init                     # pha 1: state còn ở local
# viết main.tf + outputs.tf, gồm cả kho state và bảng khoá
terraform apply

# pha 2: dời state lên nơi vừa tạo
# thêm khối backend "s3" vào code của bạn, rồi:
terraform init -migrate-state      # Terraform hỏi "yes" để chép state lên
terraform apply                    # xác nhận state mới dùng được

cd ..
./verify.sh                        # ~10 phút, có báo tiến độ
cat DOI-CHIEU.md                   # chỉ khi đã xanh hết
```

> `verify.sh` **có ghi** vào hệ thống của bạn: nó gọi hàm nhiều lần và đọc/xoá
> thông điệp trong hộp thư trực. Đó là ngoại lệ có chủ ý — không gây lỗi thì
> không chứng minh được cảnh báo kêu. Nó không sửa cấu hình nào, và chạy lại
> nhiều lần cho cùng kết quả.

---

## Dọn dẹp

**Đọc trước khi gõ `destroy`.** Ở lab này `terraform destroy` sẽ cố xoá chính cái
kho đang giữ state của nó. Thứ tự đúng:

```bash
cd terraform

# 1. Đưa state về lại local: xoá (hoặc comment) khối backend "s3" trong code,
#    rồi kéo state từ S3 xuống
terraform init -migrate-state

# 2. Giờ mới destroy được
terraform destroy
```

Nếu bạn lỡ `destroy` trước: state vẫn nằm trong kho S3 (có versioning nên chưa
mất), nhưng Terraform không còn quyền đọc nó. Gỡ bằng `terraform init` trỏ về
backend cũ, hoặc tải object state về tay rồi `terraform init -migrate-state`.

Kiểm tra đã sạch:

```bash
aws lambda list-functions --profile lab-builder \
  --query "Functions[?starts_with(FunctionName,'self-w10')].FunctionName"
aws logs describe-log-groups --profile lab-builder \
  --log-group-name-prefix /aws/lambda/self-w10 --query 'logGroups[].logGroupName'
aws cloudwatch describe-alarms --profile lab-builder \
  --alarm-name-prefix self-w10 --query 'MetricAlarms[].AlarmName'
aws s3 ls --profile lab-builder | grep self-w10
aws dynamodb list-tables --profile lab-builder --query "TableNames[?starts_with(@,'self-w10')]"
```

Cả năm phải rỗng. **Chú ý nhóm nhật ký:** nếu bạn để Lambda tự tạo log group
thay vì khai trong Terraform, `destroy` sẽ **không** xoá nó — nó sẽ nằm lại, giữ
nhật ký vĩnh viễn, và đó đúng là nguyên nhân của hoá đơn trong Bối cảnh.

Kho state có bật versioning nên `destroy` có thể báo "bucket không rỗng". Đặt
`force_destroy = true` từ đầu, hoặc xoá version bằng tay.
