---
ngày: 2026-08-22
chủ đề: Sổ tay tra cứu theo chủ đề, và bộ lab tự viết có hàng rào an toàn
liên quan: docs/notebook/, learn-aws/labs-self/, aws-saa-c03/ (submodule)
---

## Câu hỏi đã đặt ra

1. Đã clone repo lý thuyết của bên thứ ba vào làm submodule. Phần tổng hợp bên đó
   khá ổn — mở rộng và chi tiết hoá nó thành một sổ tay tra cứu được không?
2. Lab hiện có đã viết sẵn hết code, chỉ còn đọc và chạy lệnh. Làm một bộ lab
   **tự viết, tự nghĩ** thì làm thế nào?
3. Tự viết thì dễ đốt tiền và dễ hỏng. Đặt "boundary" cho từng lab kiểu gì?

## Chốt lại được gì

**Ba tầng tài liệu, phân biệt bằng TRỤC chứ không bằng độ khó.**

| | Trục | Trả lời | Cách đọc |
|---|---|---|---|
| `docs/aws/w01..w12` | thời gian | "Tuần này học gì?" | một lần, theo thứ tự |
| `docs/notebook/` | chủ đề | "Cái này chạy thế nào?" | nhảy vào giữa |
| `aws-saa-c03/` | nguồn | "Người khác tóm tắt sao?" | đối chiếu, không sửa |

**Luật lọc nguồn.** Submodule là cheat sheet: đúng nhưng nông. Mỗi mục lấy từ đó
phải thêm được ít nhất **hai trong ba**: *cơ chế* (chạy thế nào bên dưới),
*con số* (giới hạn/giá/độ trễ, kèm mốc thời gian), *bẫy* (chỗ đề gài, chỗ tài
liệu cũ dạy sai). Chỉ chép lại được thì **cắt mục đó đi**. Đây là thứ giữ sổ tay
khỏi biến thành bản sao dài dòng của nguồn.

**Nguồn thiếu đúng nửa quan trọng nhất.** README của submodule liệt kê 7 file
F, G, H, I, J, N, O — **không file nào tồn tại**. Đó là toàn bộ phần giải bài
toán theo domain, tức là **đúng cách SAA-C03 ra đề**. Bốn file `10`–`13` của sổ
tay là phần viết mới để lấp chỗ đó, không phải phần mở rộng.

**Hàng rào ba tầng, và tầng 1 vừa là hàng rào vừa là bài học.**

| Tầng | Là gì | Chặn được gì |
|---|---|---|
| IAM permission boundary | policy gắn vào role `lab-builder` | AWS **từ chối** API call vượt rào |
| Ngân sách | Budgets $5/tháng, cảnh báo 50/80/100% | phát hiện muộn |
| Kỷ luật | `guard.sh` trước, `terraform destroy` sau | bắt lỗi "quên tắt" |

Permission boundary chính là chủ đề Domain 1 của tuần 9. Nên người học **sống bên
trong** một boundary suốt 12 tuần, rồi tuần 9 bài tập là **tự dựng ra nó**.

**Luật không bao giờ được phá:** không lab nào được yêu cầu tắt hàng rào để làm
bài. Lab cần thứ hàng rào chặn ⇒ **lab đó thiết kế sai**, đổi đề bài chứ không
đổi hàng rào. Tuần 2 minh hoạ: NAT Gateway bị chặn, nên ràng buộc đó **trở thành
đề bài** — "đưa instance ở subnet riêng ra internet mà không dùng NAT Gateway".

**Khi tài liệu và hàng rào vênh nhau: siết hàng rào cho khớp lời hứa**, không bao
giờ hạ lời hứa cho khớp hàng rào. Chỉ sửa lời khi việc siết là **bất khả thi về
mặt kỹ thuật** — như chuyện IAM không có condition key cho loại load balancer.

**Chấm hành vi, không chấm cấu hình.** `verify.sh` hỏi AWS về trạng thái thật,
**không bao giờ `grep` file `.tf`**. Hệ quả: lời giải khác mà vẫn đúng thì vẫn
xanh. Cùng nguyên tắc với `make preflight` bên `learn-k8s`.

## Chỗ tôi hiểu sai

**"Lab cũ chỉ còn đọc và chạy lệnh" — đúng hiện tượng, sai kết luận.**
Tôi định thay `labs/` bằng `labs-self/`. Không nên. Hai bộ dạy hai kỹ năng khác
nhau: `labs-self/` dạy **nghĩ ra** kiến trúc, `labs/` dạy **đọc hiểu** hạ tầng
người khác viết — và trong việc thật thì kỹ năng thứ hai dùng nhiều hơn hẳn.
Thứ tự đúng: tự viết → verify xanh → đọc `DOI-CHIEU.md` → **rồi mới** mở `labs/`.
Đọc lời giải trước khi tự vật lộn thì chỉ học được cách đọc.

**Submodule commit chỉ lưu con trỏ, không lưu nội dung.** Thư mục `aws-saa-c03/`
rỗng dù `.gitmodules` đã commit. Phải `git submodule update --init --recursive`.
Tránh về sau: `git clone --recurse-submodules`, hoặc bật một lần
`git config --global submodule.recurse true`.

**Boundary chặn được ít hơn tôi tưởng — và chỗ nó không chặn được mới là bài học.**
ASG launch instance bằng service-linked role `AWSServiceRoleForAutoScaling`, **không
phải** danh tính của bạn. Nên boundary của bạn **không** rào được instance type mà
ASG bung ra; trần duy nhất là `MaxSize`. Đúng khái niệm đề thi kiểm qua `iam:PassRole`.
Tương tự, boundary **không** chặn được billing mode của DynamoDB.

## Sai sót đã bắt được (đáng nhớ hơn phần làm đúng)

**`terraform output -raw` ghi cảnh báo "No outputs found" ra *stdout* và exit 0.**
Hàm chấm nuốt luôn dòng cảnh báo đó làm giá trị rồi **báo PASS**. Một cái máy
chấm cho điểm khống. Sửa bằng cách dò trước với `output -json` (cái này exit 1
đúng). Cùng họ với lỗi `stdout_callback = yaml` phiên trước: **chỉ lộ khi chạy
thật, kiểm tra tĩnh không thấy** vì file nào cũng hợp lệ.

**`printf "%-50s"` đếm BYTE.** Tiếng Việt có dấu làm lệch hết cột. Phải đệm theo
**ký tự** bằng `${#s}`.

**Tuần 11 ra đề một bài, chấm một bài khác.** `README.md` và `verify.sh` dùng hai
bộ tên output hoàn toàn khác nhau (`chien_luoc_dr` vs `chien_luoc`, `kho_chinh` vs
`kho_tai_san`…), khác cả tên chiến lược thứ tư (`multi_site` vs `active_active`).
Người học làm đúng đề sẽ **trượt ngay dòng đầu**, không check nào chạy tới.
Đã viết lại barem theo đề. Bài học tổng quát: **hệ thống có hai nửa phải khớp
nhau thì thứ cần kiểm là CHỖ NỐI, không phải từng nửa** — cả hai file đều hợp lệ,
chúng chỉ không nói chuyện với nhau. Đã thêm phép kiểm hợp đồng **hai chiều** cho
cả 12 lab.

## Còn treo

- **`aws sts get-caller-identity` trả về gì?** Nếu ARN chứa `:root` thì phải sửa
  trước mọi thứ khác. Gấp hơn bình thường: MFA cho root giờ **bắt buộc** với mọi
  loại tài khoản, hạn 35 ngày.
- Áp `_boundary/` bằng profile admin (`learn`), xác nhận mail Budgets — **budget
  chưa xác nhận thì cảnh báo không bao giờ tới**.
- Chạy thử `verify.sh` thật ít nhất một lab. Toàn bộ 12 lab mới chỉ được kiểm
  **tĩnh** (`bash -n`, hợp đồng, link). Lỗi `output -raw` ở trên là bằng chứng
  kiểm tĩnh không đủ.
- Khái niệm "AWS là một tập API" đã chắc chưa, để bước sang IAM (tuần 1)?
- Từ note k8s: `make ping && make preflight` với node thật khi Tailscale lên;
  cân nhắc `encapsulation: VXLANCrossSubnet`; xử lý `BAOCAO-TIENDO-CALICO.md` cũ.
