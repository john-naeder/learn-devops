# Luật viết lab tự thực hành

> File này ràng buộc mọi thứ trong `learn-aws/labs-self/`. Đọc hết trước khi viết.

## Khác gì `learn-aws/labs/`?

`labs/` là **lab có lời giải**: Terraform viết sẵn, chạy `terraform apply` rồi
`./verify.sh` là xong. Học được cách đọc code, không học được cách nghĩ ra code.

`labs-self/` là **đề bài**. Người học tự viết Terraform từ file trống. Bộ này
cung cấp đúng bốn thứ, và không bao giờ cung cấp lời giải:

1. **Đề bài** — bối cảnh nghiệp vụ + yêu cầu, không phải danh sách resource
2. **Hợp đồng output** — tên output Terraform bắt buộc, để chấm được
3. **`verify.sh`** — trọng tài khách quan, chấm hạ tầng THẬT trên AWS
4. **Boundary** — hàng rào an toàn, sai cỡ nào cũng không cháy ví

### Luật vàng: KHÔNG lời giải

- Không `main.tf` mẫu, không đoạn HCL nào đủ để copy-paste thành lời giải.
- `HINTS.md` chỉ gợi ý **hướng nghĩ** và **tên khái niệm cần tra**, không đưa code.
- Được phép trích tối đa **3 dòng** HCL, và chỉ để minh hoạ *cú pháp lạ*
  (ví dụ `jsonencode`, `dynamic` block), không phải để giải bài.
- Đề bài mô tả **kết quả cần đạt**, không mô tả resource cần tạo. Viết
  "instance ở private subnet phải ra được internet để `apt update`" — KHÔNG viết
  "tạo một `aws_nat_gateway`". Chọn cơ chế nào là việc của người học.

## Boundary — hàng rào an toàn

Đây là điểm khác biệt lớn nhất so với `labs/`, và nó vừa là **cơ chế an toàn**
vừa là **bài học Domain 1**: `permission boundary` là kiến thức tuần 9 của đề thi.

Boundary có ba tầng, tầng nào cũng phải nêu rõ trong README mỗi lab:

| Tầng | Là gì | Chặn được gì |
|---|---|---|
| **IAM permission boundary** | policy gắn vào role `lab-builder` | AWS **từ chối** API call vượt rào — người học không cần nhớ gì |
| **Ngân sách** | AWS Budgets $5/tháng + cảnh báo 50/80/100% | phát hiện muộn, nhưng bắt được cái boundary bỏ lọt |
| **Kỷ luật** | `guard.sh` trước, `terraform destroy` sau | bắt lỗi "quên tắt" — nguyên nhân đốt tiền số 1 |

Mỗi lab README phải có mục **Hàng rào của lab này** nêu:
- Trần chi phí (USD/giờ khi chạy, USD nếu quên 1 tháng)
- Boundary chặn cụ thể cái gì trong lab này, và **tại sao chặn**
- Nếu người học gặp `AccessDenied` thì đó là boundary hay là bug của họ —
  phân biệt thế nào

**Không bao giờ** bảo người học tắt boundary để làm bài. Nếu một lab cần thứ
boundary chặn, thì lab đó thiết kế sai — đổi đề bài, không đổi hàng rào.

## Bố cục một lab

```
wXX-ten-lab/
├── README.md          đề bài  ← file duy nhất người học đọc trước khi làm
├── HINTS.md           gợi ý 3 tầng, mỗi tầng trong <details>
├── DOI-CHIEU.md       nối lab với lý thuyết SAA, đọc SAU khi verify xanh
├── verify.sh          chấm khách quan, chạy được nhiều lần
└── terraform/
    ├── versions.tf    cho sẵn (pin provider)
    ├── providers.tf   cho sẵn (profile + region + default_tags)
    ├── main.tf        CHO SẴN NHƯNG TRỐNG — chỉ có comment đề bài
    └── .gitignore     .terraform/, *.tfstate*, .terraform.lock.hcl
```

### `README.md` — bố cục bắt buộc

```markdown
# Tuần XX — <Tên>  (tự viết)

`Domain N · Tên miền (NN% đề)`

| | |
|---|---|
| **Chi phí khi chạy** | $X/giờ |
| **Quên 1 tháng** | $Y |
| **Thời gian** | ~N giờ |
| **Điều kiện** | đã xong `labs/wXX-*` (hoặc: không cần) |

## Bối cảnh
Một tình huống nghiệp vụ thật, 3–6 câu. Không nhắc tên resource AWS nào.

## Yêu cầu
Đánh số. Mỗi yêu cầu là một điều KIỂM CHỨNG ĐƯỢC, ánh xạ 1:1 với một check
trong verify.sh. Nói kết quả, không nói cách làm.

## Hợp đồng output
Bảng: tên output Terraform → kiểu → verify.sh dùng nó để làm gì.
Thiếu một output = verify.sh không chấm được. Đây là giao diện, không phải gợi ý.

## Hàng rào của lab này
Boundary chặn gì, vì sao. Chi phí trần. Cách phân biệt AccessDenied của boundary
với bug của mình.

## Tiêu chí đạt
Checklist. `./verify.sh` xanh hết là điều kiện CẦN, không phải điều kiện ĐỦ —
liệt kê thêm thứ verify.sh không chấm được (ví dụ: "giải thích được vì sao
bạn chọn X thay vì Y").

## Quy trình
source env.sh → guard.sh → viết terraform → apply → verify.sh → DOI-CHIEU.md → destroy

## Dọn dẹp
Lệnh cụ thể + cách kiểm tra đã sạch.
```

### `HINTS.md` — ba tầng, không hơn

```markdown
<details><summary>Tầng 1 — bí ở bước nào (mở khi ngồi 15 phút không ra)</summary>
Chia bài thành các bước nhỏ. Nêu tên khái niệm cần tra cứu. Không đáp án.
</details>

<details><summary>Tầng 2 — chọn dịch vụ nào (mở khi biết làm gì, không biết dùng gì)</summary>
Thu hẹp còn 2–3 lựa chọn, kèm câu hỏi giúp tự chọn. Vẫn không đáp án.
</details>

<details><summary>Tầng 3 — kẹt kỹ thuật (mở khi đúng hướng nhưng lỗi)</summary>
Lỗi thường gặp và nguyên nhân. Tên resource/attribute Terraform cần tra.
Link docs. TỐI ĐA 3 dòng HCL, chỉ cho cú pháp lạ.
</details>
```

### `verify.sh` — hợp đồng kỹ thuật

- `#!/usr/bin/env bash` + `set -uo pipefail` (KHÔNG `-e`: phải chấm hết mọi check)
- `source ../_lib/check.sh` — dùng hàm chung, không tự viết lại
- Đọc hạ tầng qua `terraform output -raw <ten>` theo đúng Hợp đồng output
- Chưa apply → in hướng dẫn rồi `exit 1`, không đổ stack trace
- **Chấm hành vi thật, không chấm code.** Gọi AWS API để hỏi trạng thái thật.
  Không `grep` file `.tf`. Người học có thể giải bằng cách khác — vẫn phải đạt.
- Mỗi check in một dòng: `✓`/`✗` + mô tả tiếng Việt + giá trị thực tế
- Check `✗` phải nói **kỳ vọng gì** và **nhận được gì**, không chỉ "failed"
- Có ít nhất một **negative check**: thứ đáng lẽ phải bị chặn mà chặn được thật
  (ví dụ: bucket từ chối request không mã hoá). Đây là chỗ dạy nhiều nhất.
- Kết thúc: tổng kết Đạt/Hỏng + 2 câu hỏi tự vấn khi xanh hết
- Chạy lại nhiều lần cho cùng kết quả. Không tạo/sửa/xoá gì. Chỉ đọc.

### `DOI-CHIEU.md` — nối tay với đầu

Đọc sau khi verify xanh. Bố cục:

```markdown
## Bạn vừa làm gì, theo ngôn ngữ đề thi
Ánh xạ mỗi yêu cầu → khái niệm SAA → link `docs/notebook/*.md#anchor` và `docs/aws/wXX-*.md`

## Ba cách khác để giải bài này
Mỗi cách: khi nào tốt hơn, khi nào tệ hơn, đề thi hỏi thế nào.
Đây là mục quan trọng nhất — đề SAA hỏi "giải pháp NÀO TỐT NHẤT", không hỏi
"giải pháp nào chạy được".

## Nếu đề thi hỏi
4–6 câu SAA thật sự (4 lựa chọn), lấy bối cảnh từ chính lab. Đáp án + giải
thích vì sao 3 lựa chọn kia sai, trong <details>.

## Chỗ dễ hiểu sai
Khác biệt giữa "chạy được trong lab" và "đúng trong production".
```

## Chung

- Tiếng Việt, thuật ngữ kỹ thuật giữ tiếng Anh. Không emoji trong heading.
- Mọi resource **bắt buộc** mang tag `lab = "wXX"` và `owner = "labs-self"` —
  đặt trong `default_tags` của provider (đã cho sẵn trong `providers.tf`).
  `_lib/cleanup.sh` và `find-orphans.sh` dựa vào tag này để dọn.
- Đặt tên resource có prefix `self-wXX-`. Boundary có điều kiện dựa trên prefix.
- Region cố định `us-east-1`. Profile `lab-builder` (không phải `learn`).
- Mọi lab phải destroy được sạch bằng `terraform destroy` một lần. Nếu có
  resource cần xử lý thêm (S3 có version, ENI treo), nêu rõ ở mục Dọn dẹp.
- Chi phí: lab nào vượt $0,10/giờ phải nêu lý do trong README và có cách làm rẻ hơn.

## Kiểm tra trước khi báo xong

```bash
bash -n verify.sh                      # cú pháp
shellcheck verify.sh 2>/dev/null       # nếu có
terraform -chdir=terraform init -backend=false && terraform -chdir=terraform validate
grep -c '<details>' HINTS.md           # phải = số </details> và >= 3
grep -qF '## Hợp đồng output' README.md && grep -qF '## Hàng rào của lab này' README.md
# Không rò lời giải: main.tf chỉ được có comment và dòng trống
grep -vE '^\s*(#|//|$)' terraform/main.tf && echo "RÒ LỜI GIẢI trong main.tf"
```
