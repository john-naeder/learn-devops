# Tuần 12 — Biến kiến thức của bạn thành dữ liệu, rồi để máy chấm lại bạn  (tự viết)

`Cả 4 domain · D1 Secure 30% · D2 Resilient 26% · D3 High-Performing 24% · D4 Cost-Optimized 20%`

| | |
|---|---|
| **Chi phí khi chạy** | **$0,00/giờ** — không một tài nguyên nào trong lab này tính tiền theo giờ. Đây là ràng buộc cứng, và `verify.sh` chấm nó |
| **Quên 1 tháng** | **$0,00** — vài chục lượt ghi và vài trăm lượt đọc DynamoDB on-demand cộng lại chưa tới một xu; Lambda nằm trong hạn mức luôn miễn phí |
| **Thời gian** | ~5 giờ viết + ~3 phút chạy `verify.sh`. Nhưng phần lớn 5 giờ đó là **nghĩ**, không phải gõ |
| **Điều kiện** | đã xong 11 lab trước. Đọc [`docs/aws/w12-exam-review.md`](../../../docs/aws/w12-exam-review.md) mục 1 và [`docs/notebook/22-bang-so-sanh.md`](../../../docs/notebook/22-bang-so-sanh.md) trước khi mở editor |

> **Lab này không dạy một dịch vụ mới.** Nó hỏi một câu khác hẳn mười một lab
> kia: *bạn đã thật sự nhớ gì?* Cách hỏi: viết kiến thức của mình xuống dưới
> dạng **dữ liệu máy đọc được**, nạp lên, rồi để một hệ thống bạn tự dựng chấm
> lại chính bạn. Bảng so sánh viết ra giấy nháp thì bạn tự chấm mình đạt; viết
> thành item có schema bắt buộc thì chỗ nào nhớ mơ hồ sẽ lộ ra ngay lúc gõ.

---

## Bối cảnh

Bạn đăng ký thi trong mười hai ngày nữa. Ba tuần vừa rồi bạn đọc lại toàn bộ sổ
tay và cảm thấy đã nắm hết. Cảm giác đó chính là vấn đề: đọc lại một trang đã
đọc sáu lần tạo ra sự trôi chảy, và bộ não nhầm sự trôi chảy với sự thông thạo.

Hôm qua bạn làm thử 20 câu và sai 9. Đọc đáp án thì câu nào cũng "à đúng rồi, tôi
biết mà" — nhưng lúc còn hai lựa chọn trên màn hình, bạn không rút ra được dòng
nào để chốt. Cái bạn thiếu không phải thông tin, mà là **khả năng truy xuất thông
tin dưới áp lực và dưới hình thức bị bóp méo**: đề không hỏi "SQS là gì", nó tả
một tình huống rồi bắt bạn nhận ra đó là SQS.

Nên buổi lab cuối này bạn không dựng hệ thống cho công ty tưởng tượng nào cả.
Bạn dựng **một máy chấm cho chính mình**.

---

## Yêu cầu

Mỗi yêu cầu ánh xạ 1:1 với một nhóm check trong `verify.sh`.

1. **Có một kho ôn tập, và nó không tính tiền lúc bạn không dùng.**
   Kho phải trả lời hai câu hỏi truy xuất khác nhau mà **không quét toàn bộ dữ
   liệu**: "cho tôi tất cả bảng so sánh" và "cho tôi tất cả câu hỏi miền D1" —
   hai câu đó cần hai đường vào khác nhau. Chế độ tính tiền phải là **theo lượt
   dùng**, không phải đặt trước dung lượng; xem "Hàng rào" để biết vì sao đây là
   một dòng về **tiền**, không phải về hiệu năng.

2. **Mười bảng so sánh, do chính bạn viết.**
   Ít nhất **10** bảng. Mỗi bảng có: các lựa chọn đem ra so sánh, ít nhất **3
   trục** so sánh, và — thứ quan trọng nhất — **từ khoá trong đề thi** trỏ về
   từng lựa chọn. Bảng chỉ liệt kê tính năng là bảng vô dụng trong phòng thi;
   thứ cứu bạn là cột "đề dùng chữ nào thì chọn hàng này".

   Tổng số lựa chọn trong cả 10 bảng phải từ **28** trở lên, số tên lựa chọn
   **khác nhau** từ **24** trở lên — con số đó khiến bạn không viết được 10 biến
   thể của cùng một bảng.

3. **Một ngân hàng câu hỏi thi thử, cũng do chính bạn viết.**
   Ít nhất **20** câu. Mỗi câu: một tình huống (không phải câu định nghĩa), **đúng
   4** phương án A/B/C/D, **một** đáp án đúng, và **lý do loại từng phương án
   sai** — đủ ba lý do, mỗi lý do là một câu giải thích thật.

   > Đây là yêu cầu nặng nhất của lab. Biết đáp án đúng là 25% giá trị; 75% còn
   > lại nằm ở chỗ nói được **vì sao ba cái kia sai** — đúng việc bạn phải làm
   > khi đề cố tình để lại hai đáp án nghe đều hợp lý.

   Mỗi câu phải trỏ về **một bảng so sánh có thật** trong kho. Câu hỏi không nối
   được về bảng nào nghĩa là bạn đang kiểm tra một thứ bạn chưa hệ thống hoá.

4. **Phân bổ đúng trọng số đề thi.**
   Số câu theo miền khớp trọng số thật của SAA-C03 — **D1 30%, D2 26%, D3 24%,
   D4 20%** — sai số không quá **6 điểm phần trăm** mỗi miền. Ôn nhiều nhất thứ
   ra thi nhiều nhất là chiến thuật, không phải hình thức.

5. **Một giám khảo chấm được, và chấm sai là sai.**
   Một dịch vụ nhận vào mã câu hỏi cùng một lựa chọn, rồi trả lời: đúng hay sai,
   đáp án đúng là gì, và **nếu sai thì vì sao lựa chọn đó bị loại**. Nó phải xử
   lý được cả mã câu hỏi không tồn tại mà không sập.

6. **Giám khảo bốc được một đề thi thử đúng trọng số.**
   Xin `n` câu thì trả về đúng `n` mã, không trùng nhau, đều có thật trong kho,
   và **phân bổ bốn miền vẫn bám trọng số đề** chứ không bốc ngẫu nhiên đều. Đây
   là chỗ trọng số ở yêu cầu 4 biến từ một con số thành một hành vi.

7. **Giám khảo chỉ đọc, và bị nhốt trong trần quyền.**
   Danh tính giám khảo chạy dưới đó phải mang **permissions boundary** của bộ
   lab, và phải **không** sửa được kho ôn tập: một máy chấm ghi được vào ngân
   hàng đề là một máy chấm sửa được điểm của chính nó.

8. **PHỦ ĐỊNH — không gì trong lab này tính tiền theo giờ.** `verify.sh` quét
   theo tag `lab=w12` và sẽ đỏ nếu tìm thấy.

### Hợp đồng dữ liệu
**Schema bắt buộc**, không phải gợi ý — `verify.sh` đọc kho bằng đúng những tên
dưới đây.

**Khoá của kho:** khoá phân vùng `phan_loai` (chuỗi), khoá sắp xếp `ma` (chuỗi).
Đường vào thứ hai (yêu cầu 1) có khoá phân vùng `mien` (chuỗi) và khoá sắp xếp
`ma` (chuỗi) — khai tên nó vào output `chi_muc_mien`.

**Item bảng so sánh** — `phan_loai = "BANG"`, `ma` bắt đầu bằng `bang#`:
| Thuộc tính | Kiểu | Ràng buộc |
|---|---|---|
| `mien` | chuỗi | đúng một trong `D1`, `D2`, `D3`, `D4` |
| `tieu_de` | chuỗi | tên bảng, không trùng bảng khác, ≥ 10 ký tự |
| `lua_chon` | danh sách chuỗi | các lựa chọn đem so sánh, ≥ 2 phần tử |
| `truc_so_sanh` | danh sách chuỗi | các trục so sánh, ≥ 3 phần tử |
| `tu_khoa_de` | map chuỗi → chuỗi | khoá là **đúng tập** `lua_chon`; giá trị là cụm từ trong đề trỏ về lựa chọn đó, ≥ 8 ký tự, không trùng nhau trong cùng bảng |

**Item câu hỏi** — `phan_loai = "CAUHOI"`, `ma` bắt đầu bằng `cauhoi#`:
| Thuộc tính | Kiểu | Ràng buộc |
|---|---|---|
| `mien` | chuỗi | `D1`…`D4` |
| `noi_dung` | chuỗi | tình huống, ≥ 80 ký tự |
| `phuong_an` | map chuỗi → chuỗi | đúng 4 khoá `A`,`B`,`C`,`D`; mỗi giá trị ≥ 15 ký tự |
| `dap_an` | chuỗi | một trong `A`,`B`,`C`,`D` |
| `ly_do_loai` | map chuỗi → chuỗi | đúng 3 khoá = `{A,B,C,D}` trừ `dap_an`; mỗi giá trị ≥ 30 ký tự |
| `bang_lien_quan` | chuỗi | `ma` của một item bảng có thật trong kho |

### Hợp đồng của giám khảo

`verify.sh` gọi thẳng giám khảo bằng ba loại payload. Trả về phải là **một đối
tượng JSON** (không bọc trong vỏ HTTP nào).

```json
{"che_do": "cham", "ma_cau_hoi": "<ma>", "tra_loi": "A"}
   -> {"tim_thay": true, "dung": false, "dap_an_dung": "C", "ly_do_loai": "<vì sao A sai>"}
   -> {"tim_thay": false}                       khi mã không có trong kho

{"che_do": "kiem_ke"}
   -> {"tong_bang": 10, "tong_cau_hoi": 20,
       "cau_hoi_theo_mien": {"D1": 6, "D2": 5, "D3": 5, "D4": 4}}

{"che_do": "de_thi", "so_cau": 10}
   -> {"so_cau": 10, "ma_cau_hoi": ["cauhoi#...", "..."]}
```

`dung = true` thì `ly_do_loai` không cần có; `dung = false` thì nó **bắt buộc**
có, và phải là lý do loại đúng phương án vừa được chọn.

---

## Hợp đồng output

Thiếu một output = `verify.sh` dừng ngay, không chấm được gì.

| Output | Kiểu | `verify.sh` dùng để làm gì |
|---|---|---|
| `bang_on_tap` | string | Tên kho ôn tập. verify truy vấn nó trực tiếp, đọc chế độ tính tiền và sơ đồ khoá |
| `chi_muc_mien` | string | Tên đường vào thứ hai (theo `mien`). verify đếm câu hỏi từng miền qua đây |
| `ham_giam_khao` | string | Tên giám khảo để gọi. verify cũng lần theo nó ra danh tính giám khảo chạy dưới |
| `chi_phi` | number | USD/giờ bạn **khai** là lab này tốn. verify đối chiếu lời khai với thực tế |

Đặt tên tài nguyên với tiền tố **`self-w12-`**.
> **Vì sao `chi_phi` là output chứ không phải một dòng trong README của bạn:**
> lời khai và hiện thực phải nằm cạnh nhau để so được. `verify.sh` đọc con số
> bạn khai rồi tự quét xem có gì tính tiền theo giờ không. Trong đời thật đó là
> khoảng cách giữa bản thiết kế và hoá đơn, và nó luôn khác 0.

---

## Hàng rào của lab này

### Trần chi phí: $0,00/giờ
| Khoản | Giá thật | Lab này dùng |
|---|---|---|
| Kho dữ liệu **theo lượt dùng** | $1,25/triệu lượt ghi, $0,25/triệu lượt đọc, 25 GB lưu trữ luôn miễn phí | ~50 ghi + ~1.000 đọc → **dưới $0,01** |
| Kho dữ liệu **đặt trước dung lượng** | 25 WCU + 25 RCU luôn miễn phí, sau đó tính **theo giờ** dù không ai gọi | **0 — bị cấm ở yêu cầu 1** |
| Giám khảo (Lambda) | 1 triệu lượt gọi + 400.000 GB-giây mỗi tháng, luôn miễn phí | ~40 lượt gọi → **$0,00** |
| Nhật ký của giám khảo | 5 GB nạp vào/tháng miễn phí | vài KB → **$0,00** |

### Một lỗ của hàng rào mà chính lab này dạy bạn nhìn thấy

Permission boundary **không** chặn được bạn tạo kho dữ liệu ở chế độ đặt trước
dung lượng — IAM không có khoá điều kiện nào cho việc đó. Tầng 1 của hàng rào,
tầng duy nhất không cần bạn nhớ gì, **bỏ lọt** đúng cái sai lầm chi phí mà lab
này quan tâm. Đó là lý do yêu cầu 1 tồn tại.

Điều tổng quát đáng nhớ hơn ca cụ thể: **hàng rào kỹ thuật chặn theo API, còn
hoá đơn tính theo trục khác** — dung lượng đặt trước, byte truyền,
số request, số số đo. Trục nào boundary không có khoá điều kiện thì trục đó phải
được bắt bằng ngân sách hoặc bằng kỷ luật.

### Boundary chặn gì ở lab này
| Chặn | Bạn gặp nó lúc nào |
|---|---|
| `iam:CreateRole` không kèm `permissions_boundary` | Giám khảo cần một danh tính để chạy dưới. Đây là chỗ duy nhất trong lab bạn va vào hàng rào. Lấy ARN: `terraform -chdir=../../_boundary output -raw lab_boundary_arn` |
| tên tài nguyên IAM không có tiền tố `self-w12-` | `DenyCredentialEscalation` dùng `NotResource` trên `self-w*`. Sai tiền tố cho ra `AccessDenied` **nói là do permissions boundary** trong khi thật ra chỉ là lỗi đặt tên |
| `lambda:PutProvisionedConcurrencyConfig` | provisioned concurrency tính tiền cả khi không có lượt gọi nào. `verify.sh` có một check phủ định riêng cho nó |
| `es:*`, `opensearch:*`, `aoss:*`, `elasticache:Create*` | cám dỗ có thật ở lab này: "ngân hàng câu hỏi thì nên đánh chỉ mục toàn văn chứ". Cụm nhỏ nhất ~$25/tháng, và 30 item không cần chỉ mục toàn văn nào cả |
| mọi API ngoài `us-east-1` | như mười một lab trước |

### Gặp lỗi — hàng rào hay bug của bạn?
| Thông điệp chứa | Nghĩa là | Làm gì |
|---|---|---|
| `explicit deny in a permissions boundary` khi tạo IAM role | hàng rào — thiếu `permissions_boundary` | thêm nó, đừng gỡ rào |
| `explicit deny in a permissions boundary` khi **sửa** IAM role | rất có thể chỉ là **sai tiền tố tên** | kiểm tra `self-w12-` trước khi nghi ngờ kiến trúc |
| `ValidationException: One or more parameter values were invalid` khi nạp item | **bug của bạn** — không nhắc boundary. Gần như luôn là kiểu dữ liệu: chuỗi rỗng, số gửi dưới dạng số thay vì chuỗi, hoặc thiếu khoá sắp xếp |
| `AccessDeniedException` từ chính giám khảo lúc chạy | **bug của bạn** — danh tính của giám khảo thiếu quyền đọc kho, hoặc thiếu quyền đọc **đường vào thứ hai** (đó là một ARN khác với ARN của kho) |

---

## Tiêu chí đạt

`./verify.sh` xanh hết là điều kiện **cần**. Ở lab này khoảng cách giữa "cần" và
"đủ" lớn nhất cả bộ — máy đếm được item, máy không đếm được cái gì trong đầu bạn.

- [ ] `./verify.sh` xanh hết — trong đó có **5 check phủ định**
- [ ] **Tự làm 20 câu của chính bạn, không mở kho, không mở sổ tay.** Chấm bằng
      giám khảo bạn vừa dựng. Sai quá 3 câu do chính mình viết nghĩa là bạn viết
      chúng bằng cách chép, không bằng cách hiểu
- [ ] Với mỗi câu bạn sai, **nói thành lời** vì sao ba phương án kia sai —
      trước khi mở `ly_do_loai` ra đọc
- [ ] Đưa cho người khác 10 bảng của bạn và một câu hỏi SAA bất kỳ. Họ tra ra
      được bảng cần dùng trong 10 giây không? Nếu không, cột `tu_khoa_de` chưa
      làm đúng việc của nó
- [ ] Nói được: hai đường vào kho khác nhau chỗ nào về **chi phí đọc**, và vì
      sao quét toàn kho rồi lọc cho ra **cùng một kết quả** nhưng vẫn là câu trả
      lời sai trong bài thi
- [ ] Nói được: nếu ngân hàng có 2 triệu câu thay vì 20 thì cái gì trong thiết
      kế hiện tại hỏng trước tiên; và tính tiền theo lượt dùng **đắt hơn** đặt
      trước dung lượng kể từ mức tải nào
- [ ] Trả lời được: giám khảo đọc kho ôn tập bằng quyền của ai, và nếu mai bạn
      cho nó gọi thêm một dịch vụ nữa thì sửa ở đâu

---

## Quy trình

```bash
source ../../env.sh
../_boundary/guard.sh

cd terraform
# Lấy ARN trần quyền TRƯỚC — giám khảo cần một danh tính, và danh tính đó
# không tạo được nếu thiếu permissions_boundary
terraform -chdir=../../_boundary output -raw lab_boundary_arn

terraform init
terraform apply                 # đọc chi_phi trước khi gõ yes

cd .. && ./verify.sh            # ~3 phút
$PAGER DOI-CHIEU.md             # chỉ khi đã xanh hết

cd terraform && terraform destroy
```

Thứ tự làm gợi ý, apply sau mỗi bước: kho ôn tập và đường vào thứ hai (chưa item
nào) → **hai** bảng so sánh, apply, tự truy vấn bằng tay để chắc schema đúng →
giám khảo chế độ `kiem_ke` (dễ nhất, chứng minh nó đọc được kho) → hai câu hỏi
rồi chế độ `cham` → chế độ `de_thi` → **rồi mới** viết nốt 8 bảng và 18 câu còn
lại. Bước cuối chiếm ba trong năm giờ, và đó là ba giờ ôn thi thật sự — năm bước
đầu chỉ dựng cái khuôn để đựng nó.

> `verify.sh` gọi giám khảo khoảng 40 lần và truy vấn kho ôn tập vài chục lần.
> Nó **không** ghi, sửa hay xoá bất cứ thứ gì, và chạy lại nhiều lần cho cùng
> kết quả.

---

## Dọn dẹp

```bash
cd terraform && terraform destroy
```

Destroy sạch trong một lần — không kho có versioning, không ENI treo, không
subscription chờ xác nhận. **Một chỗ duy nhất cần biết:** nhóm nhật ký của giám
khảo. Để Lambda tự tạo nó thay vì khai trong Terraform thì `destroy` **không**
xoá nó, và nó nằm lại giữ nhật ký vĩnh viễn. Đúng bài học tuần 10.

Kiểm tra đã sạch:

```bash
aws dynamodb list-tables --profile lab-builder --query "TableNames[?starts_with(@,'self-w12')]"
aws lambda list-functions --profile lab-builder --query "Functions[?starts_with(FunctionName,'self-w12')].FunctionName"
aws iam list-roles --profile lab-builder --query "Roles[?starts_with(RoleName,'self-w12')].RoleName"
aws logs describe-log-groups --profile lab-builder --log-group-name-prefix /aws/lambda/self-w12 --query 'logGroups[].logGroupName'
```

Bốn lệnh, bốn kết quả rỗng.

> **Trước khi destroy: xuất kho ôn tập ra tệp và giữ lại.** Nó là thứ duy nhất
> trong 12 tuần lab đáng mang theo vào phòng thi trong đầu bạn.
>
> ```bash
> aws dynamodb scan --profile lab-builder --output json \
>   --table-name "$(terraform -chdir=terraform output -raw bang_on_tap)" > kho-on-tap.json
> ```
>
> Ngày cuối trước khi thi, mở tệp đó ra đọc — không phải đọc lại sổ tay. Bạn đọc
> chính chữ mình viết, và đó là thứ trí nhớ bám lâu nhất.
