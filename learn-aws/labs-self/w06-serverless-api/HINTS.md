# Gợi ý — tuần 6

Mở từng tầng một. Hai chỗ gần như ai cũng mất thời gian ở lab này:
`permissions_boundary` (tầng 1) và "input sai phải ra 400 chứ không phải 500"
(tầng 3). Cả hai đều không phải vấn đề Terraform.

<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>

Bài này có **sáu mảnh**. Làm xong mảnh nào apply mảnh đó và tự kiểm bằng tay —
chạy `verify.sh` để gỡ lỗi là cách chậm nhất, vì nó chấm cả sáu mảnh cùng lúc.

**Mảnh 0 — trần quyền, làm trước tiên.** Trước khi viết dòng nào, lấy ARN của
permission boundary và để sẵn trên màn hình. Mọi IAM role bạn tạo trong bộ lab
này đều phải khai nó. Không có nó thì `terraform apply` gãy ở resource IAM đầu
tiên với một thông điệp không nhắc gì tới code của bạn. README mục "Hàng rào của
lab này" có lệnh lấy ARN.

**Mảnh 1 — kho dữ liệu.** Một câu hỏi duy nhất phải trả lời trước khi tạo:
*"tra cứu của tôi luôn bắt đầu từ cái gì?"* Ở bài này người dùng đưa mã ngắn và
hỏi URL gốc. Khoá chính nên là gì thì đã rõ. Chọn chế độ tính tiền theo lượt
dùng (yêu cầu 11) — đổi khoá chính về sau nghĩa là xoá bảng và tạo lại.

**Mảnh 2 — danh tính của phần xử lý.** Hai policy khác nhau, đừng gộp:
- ai được **đóng vai** role này (trust policy — service principal của Lambda)
- role này **làm được gì** (identity policy — đúng hai action trên đúng một bảng,
  cộng quyền ghi log)

Yêu cầu 7 liệt kê sẵn cái gì phải bị **từ chối**. Viết policy theo danh sách đó.

**Mảnh 3 — nhóm log.** Mảnh dễ nhất, hay bị bỏ sót nhất. Nếu để dịch vụ tự tạo
nhóm log thì mặc định là **giữ vĩnh viễn** và Terraform không quản lý nó — nên
`destroy` cũng không xoá. Câu hỏi: làm sao để nhóm log nằm trong tay Terraform
*trước khi* dịch vụ kịp tự tạo nó? (Tra: quy ước đặt tên nhóm log của Lambda, và
`depends_on`.)

**Mảnh 4 — phần xử lý.** Viết và gọi tay bằng `aws lambda invoke` cho tới khi
đúng, **trước khi** ghép API vào. Gỡ lỗi qua hai tầng cùng lúc là cách tốn thời
gian nhất. Chú ý: khi API gọi vào, hàm nhận một **cấu trúc sự kiện** chứ không
nhận thẳng thân JSON — thân nằm trong một trường, và nó là **chuỗi**, không phải
đối tượng đã parse.

**Mảnh 5 — API.** Ba việc nhỏ: khai route, nối route vào phần xử lý, và cho phép
dịch vụ API **gọi** phần xử lý. Việc thứ ba là hướng quyền ngược lại với mảnh 2
và là bẫy tuần này — thiếu nó thì API trả 500 và **log của hàm trống trơn**.

**Mảnh 6 — trần tốc độ.** Một thuộc tính trên stage. Đọc kỹ: có trần theo *tốc
độ* (request/giây) và trần theo *bùng nổ* (burst). Yêu cầu 11 nói về cái thứ nhất.

</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>

**Chọn loại API.** API Gateway có ba loại, và hai loại đầu đều làm được bài này:

| | REST API | HTTP API |
|---|---|---|
| Giá | $3,50/triệu request | **$1,00/triệu** |
| Độ trễ thêm vào | cao hơn | thấp hơn |
| Có gì thêm | usage plan + API key, request validator, WAF, caching, canary deploy, endpoint kiểu private | authorizer JWT sẵn, CORS đơn giản |
| Thiếu gì | — | không có API key/usage plan, không có caching, không có request validator |

Ba câu hỏi để tự chọn:
1. Bạn có cần **API key và hạn ngạch theo từng khách hàng** không? Đó là thứ chỉ
   loại thứ nhất có, và nó là lý do phổ biến nhất để chọn nó.
2. Bạn có cần **validate request ngay tại tầng API** không? Nếu có thì yêu cầu 4
   của lab này sẽ nhẹ đi đáng kể — nhưng hãy đọc tiếp tầng 3 trước khi mừng.
3. Chi phí và độ trễ có quan trọng hơn hai thứ trên không?

> Lựa chọn nào cũng qua được `verify.sh` — nó tra trần tốc độ theo cả hai kiểu.
> Nhưng bạn phải **giải thích được** vì sao chọn cái mình chọn. Đó đúng là câu
> hỏi thi.

**Chọn kiểu tích hợp.** Có kiểu "proxy" (đẩy nguyên request vào hàm, hàm tự dựng
toàn bộ phản hồi) và kiểu tích hợp có ánh xạ (API tự tách/ghép request và phản
hồi). Câu hỏi để chọn: bạn muốn **hình dạng phản hồi HTTP** do code quyết định
hay do cấu hình API quyết định? Với yêu cầu 2 (chuyển hướng kèm header
`Location`) và yêu cầu 4 (mã lỗi theo từng loại input sai), hãy nghĩ xem cái nào
làm bạn phải sửa ít chỗ hơn khi đổi luật nghiệp vụ.

**Chuyển hướng — đừng dựng lại bánh xe.** HTTP đã có sẵn một họ mã trạng thái
cho việc "đi chỗ khác". Chọn mã nào thì có hệ quả thật:

| Mã | Nghĩa | Hệ quả bạn phải biết |
|---|---|---|
| 301 | chuyển vĩnh viễn | trình duyệt và CDN **nhớ rất lâu**; đổi đích về sau thì người dùng cũ vẫn đi chỗ cũ |
| 302 | chuyển tạm thời | không được nhớ; mỗi lần đều hỏi lại bạn — nên bạn đếm được lượt click |

Với một dịch vụ rút gọn link của phòng marketing, việc **đếm được lượt click**
có đáng giá hơn việc tiết kiệm vài request không? Câu trả lời của bạn quyết định
chọn mã nào, và đó là một câu hỏi kiến trúc thật.

**Sinh mã ngắn.** Ba hướng, và cả ba đều đúng ở quy mô lab:
- băm URL rồi cắt vài ký tự — cùng URL ra cùng mã (**idempotent**), nhưng có thể đụng
- số ngẫu nhiên đủ dài — gần như không đụng, nhưng mỗi lần POST ra một mã mới
- một bộ đếm tăng dần — ngắn nhất, nhưng đoán được mã của người khác

Câu hỏi tự chọn: hai lần POST cùng một URL nên ra một mã hay hai mã? Và nếu mã
**đoán được** thì ai đọc được cái gì?

**Đừng đặt phần xử lý vào mạng riêng.** Nếu bạn định làm, hãy dừng lại và trả
lời: hàm đang gọi kho dữ liệu qua đường nào? Nếu đưa nó vào mạng riêng thì đường
đó còn không, và mở lại nó tốn bao nhiêu một tháng? README có bảng giá.

</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>

**`terraform apply`: `AccessDenied ... iam:CreateRole ... explicit deny in a permissions boundary policy`.**
Thiếu `permissions_boundary` trên resource role. Lấy ARN:
`terraform -chdir=../../_boundary output -raw lab_boundary_arn`.
Nếu đã có mà vẫn hỏng **và** thông điệp vẫn nhắc boundary: kiểm tra tên role đã
có tiền tố `self-w06-` chưa. Sai tiền tố cho ra thông điệp y hệt.

**API trả 500, log của hàm TRỐNG HOÀN TOÀN.**
Request chưa bao giờ tới hàm. Đây là hướng quyền thứ hai: dịch vụ API cần được
**cho phép gọi** hàm, bằng một resource policy trên chính hàm đó. Tra
`aws_lambda_permission`. Nhớ giới hạn `source_arn` — không thì bất kỳ API nào
trong tài khoản cũng gọi được hàm của bạn (đây là confused deputy, đúng chủ đề
tuần 9).

**API trả 500, log có `AccessDeniedException ... dynamodb:PutItem`.**
Hướng quyền thứ nhất. Identity policy của role thiếu action, hoặc cho action
đúng nhưng trên sai ARN. Từ khoá phân biệt trong thông điệp:
`no identity-based policy allows` = policy của bạn, không phải hàng rào.

**API trả 500, log có `KeyError` / `TypeError` khi đọc thân request.**
Sự kiện API gửi vào **không phải** là JSON của bạn. Thân nằm trong một trường
riêng và nó là **chuỗi** — phải parse. Ngoài ra nó có thể được mã hoá base64
(có một cờ boolean trong sự kiện nói cho bạn biết). In cả sự kiện ra log một lần
để nhìn tận mắt, rồi xoá dòng in đó đi.

**API trả 403 `{"message":"Forbidden"}`.**
Route hoặc phương thức chưa được khai báo, hoặc bạn gọi nhầm stage. Đây là API
Gateway trả lời, không phải hàm của bạn. Kiểm tra `api_url` có kèm tên stage
không — với stage tên `$default` thì không cần, với stage tên khác thì cần.

**Chuyển hướng không chạy: client nhận 200 kèm JSON thay vì đi tiếp.**
Bạn đang trả mã 200. Phản hồi chuyển hướng cần **cả hai**: mã 301/302 **và**
header `Location`. Thiếu một trong hai thì trình duyệt đứng yên.

**`verify.sh` báo "header Location đúng bằng URL đã gửi" mà giá trị lệch.**
URL thử nghiệm có chuỗi truy vấn (`?utm_source=...&utm_id=...`). Nhiều lời giải
cắt mất phần đó vì lỡ tách chuỗi theo dấu `?`, hoặc vì lưu URL sau khi đã
`urlparse` rồi ghép lại thiếu. Lưu nguyên chuỗi người dùng gửi.

**Yêu cầu 4 — ba loại input sai, ba lần trả 400.**
Đây là chỗ tốn thời gian nhất của lab. Bố cục hàm nên là:

```
đọc thân  -> hỏng? trả 400 "thân không phải JSON"
lấy url   -> thiếu? trả 400 "thiếu trường url"
kiểm giao thức -> không http/https? trả 400 "giao thức không hỗ trợ"
... tới đây mới bắt đầu làm việc thật
```

Bốn điều dễ sai:
- Một `try/except` bọc **cả hàm** rồi trả 500 cho mọi thứ là cách nhanh nhất để
  trượt yêu cầu 4. Bắt lỗi **hẹp**, ở đúng chỗ bạn biết nó có thể hỏng.
- Kiểm giao thức bằng cách tìm chuỗi `"http"` trong URL sẽ cho `ftp://x/http`
  đi lọt. Dùng công cụ phân tích URL của runtime.
- Thân trả về phải là JSON có trường **`loi`** — verify đọc đúng tên đó.
- Nếu bạn dùng kiểu tích hợp không-proxy thì mã trạng thái do cấu hình API quyết
  định, và bạn phải ánh xạ lỗi sang mã bằng cấu hình chứ không bằng code. Biết
  trước điều đó trước khi chọn.

**Yêu cầu 5 — mã không tồn tại phải 404.**
"Tra không thấy" là kết quả **bình thường** của một phép tra cứu, không phải lỗi
hệ thống. Ở DynamoDB, `GetItem` không tìm thấy sẽ trả về phản hồi **thành công**
với phần `Item` vắng mặt — không ném exception. Nếu code của bạn đọc thẳng
`response["Item"]` thì nó nổ và thành 500.

**Cold start cao bất thường.**
Ba nguyên nhân, theo thứ tự tác động: khởi tạo client **bên trong** hàm xử lý
thay vì ở phạm vi module (mỗi lần gọi lại dựng lại kết nối), gói triển khai to
(đừng nhét cả SDK vào gói — runtime đã có sẵn), và bộ nhớ cấp quá thấp — bộ nhớ
quyết định luôn **phần CPU** được chia, nên 128 MB có thể khởi động chậm hơn
512 MB *và* tốn nhiều tiền hơn vì chạy lâu hơn.

**Cú pháp lạ đáng trích** — chỗ duy nhất trong lab không đoán được là gắn
boundary và đọc thân request:

```hcl
permissions_boundary = data.terraform_remote_state.x.outputs.lab_boundary_arn
```

(hoặc đơn giản là một `variable` bạn truyền vào — miễn là nó trỏ đúng ARN
`labs-self-boundary`.)

**Tài liệu cần tra:**
- `aws_lambda_function`, `aws_lambda_permission`, `aws_cloudwatch_log_group`
- `aws_apigatewayv2_api` / `aws_apigatewayv2_route` / `aws_apigatewayv2_integration`
  / `aws_apigatewayv2_stage` (`default_route_settings`) — hoặc họ `aws_api_gateway_*`
  nếu bạn chọn REST API (`aws_api_gateway_method_settings`)
- `aws_iam_role` (`permissions_boundary`, `assume_role_policy`),
  `aws_iam_role_policy`, `aws_dynamodb_table`
- [Lambda proxy integration — hình dạng sự kiện và hình dạng phản hồi](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html)
- [Throttling cho API Gateway](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html)
- [Lambda execution role vs resource-based policy](https://docs.aws.amazon.com/lambda/latest/dg/lambda-permissions.html)

</details>
