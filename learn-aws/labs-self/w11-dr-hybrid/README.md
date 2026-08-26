# Tuần 11 — Chọn một chiến lược DR, rồi chứng minh bạn đã dựng đúng cái mình chọn  (tự viết)

`Domain 2 · Design Resilient Architectures (26% đề)`

| | |
|---|---|
| **Chi phí khi chạy** | **$0,00/giờ** — không thành phần bắt buộc nào tính tiền theo giờ |
| **Quên 1 tháng** | **$0,00** (một tuỳ chọn duy nhất tốn tiền, $0,50/tháng, và nó không bắt buộc — xem "Hàng rào của lab này") |
| **Thời gian** | ~5 giờ viết + ~8 phút chạy `verify.sh` |
| **Điều kiện** | nên xong `w04-s3-cloudfront`, `w05-databases` và `w10-observability-iac`. Đọc [`docs/aws/w11-dr-hybrid.md`](../../../docs/aws/w11-dr-hybrid.md) mục 1 và 2 **trước** khi mở editor — lab này bắt bạn ra một quyết định, và quyết định đó cần bảng RTO/RPO trong đầu |

> **Lab này khác mười lab trước ở một điểm.** Mười lab kia hỏi *"bạn có dựng
> được thứ này không"*. Lab này hỏi *"bạn chọn cái gì, và hạ tầng bạn dựng có
> đúng là cái bạn chọn không"*. `verify.sh` chấm **cả hai vế**, và vế thứ nhất
> chấm trước — chọn sai thì dựng đẹp cỡ nào cũng đỏ.
>
> Đó đúng là cách đề SAA chấm bạn.

---

## Bối cảnh

Bạn vận hành hệ thống bán vé sự kiện của công ty Cửa Sổ. 3 giờ sáng thứ Ba, một
sự cố hạ tầng ở Region chính làm **toàn bộ dữ liệu trong Region đó không truy
cập được** trong bảy tiếng. Không mất vĩnh viễn — nhưng bảy tiếng không bán được
vé, không tra được vé đã bán, và không ai trong đội biết phải làm gì theo thứ tự
nào.

Cuộc họp sau sự cố kết thúc bằng bốn câu, và cả bốn đều là ràng buộc kiến trúc:

- **Giám đốc vận hành:** "Lần sau, tôi cần hệ thống chạy lại **trong vòng một
  tiếng**, và tôi chấp nhận mất tối đa **mười lăm phút** giao dịch cuối cùng.
  Không hơn."
- **Kế toán trưởng:** "Ngân sách cho khả năng chống thảm hoạ là **năm đô la một
  tháng**. Tôi không duyệt một máy chủ dự phòng nào ngồi không cả năm để chờ một
  đêm."
- **Trưởng nhóm nội dung:** "Hôm kia có người xoá nhầm một thư mục ảnh sự kiện.
  Chuyện đó phải không bao giờ mất dữ liệu nữa, kể cả khi không có thảm hoạ nào."
- **Người trực đêm hôm đó:** "Tôi không biết phải bấm gì. Tài liệu quy trình
  nằm trên wiki — và wiki chạy trong chính Region đang chết."

Câu thứ tư là câu đắt nhất trong bốn câu, và nó thường bị bỏ qua trong mọi bản
thiết kế DR.

---

## Yêu cầu

### Bảng cam kết — đây là đề bài, không phải gợi ý

| Cần bảo vệ | RTO (phục hồi trong) | RPO (mất tối đa) |
|---|---|---|
| Kho vé đã bán (dữ liệu giao dịch) | **≤ 60 phút** | **≤ 15 phút** |
| Ảnh sự kiện, hoá đơn PDF, tài liệu (dữ liệu tệp) | **≤ 60 phút** | **≤ 5 phút** |
| **Trần ngân sách cho toàn bộ khả năng DR** | **$5/tháng** | |

Nhắc lại hai định nghĩa, vì nhầm chúng là cách mất điểm phổ biến nhất:
**RTO** là *bao lâu thì chạy lại được*. **RPO** là *mất bao nhiêu dữ liệu*. Một
con số đo **thời gian ngừng**, một con số đo **dữ liệu mất**. Chúng độc lập với
nhau và mỗi cái mua bằng một loại tiền khác nhau.

### Việc phải làm

1. **Ra quyết định, và ghi nó xuống dưới dạng máy đọc được.**
   Chọn **một** chiến lược khôi phục thảm hoạ và khai nó vào ba output:
   `chien_luoc_dr` (một trong bốn giá trị ở Hợp đồng output), `rto_phut`,
   `rpo_phut` — hai con số bạn **cam kết đạt được** với chiến lược đó.

   `verify.sh` kiểm tra ba điều, theo thứ tự: hai con số bạn cam kết có **đạt
   bảng trên** không; chiến lược bạn chọn có **thật sự đạt được** hai con số đó
   không (mỗi chiến lược có một dải RTO/RPO của nó, và dải đó là kiến thức đề
   thi); và hạ tầng bạn dựng có **khớp** với chiến lược bạn khai không.

   > Khai `pilot_light` rồi chỉ bật sao lưu là **trượt**. Khai
   > `backup_restore` với RTO 30 phút cũng là **trượt** — không phải vì hạ tầng
   > sai, mà vì con số bạn hứa không thuộc về chiến lược bạn chọn. Trong đời
   > thật, đó là kiểu cam kết làm người ta mất việc sau một sự cố.

2. **Dữ liệu tệp sống sót qua thao tác xoá của con người.**
   Sau khi một tệp bị xoá bằng lệnh xoá thông thường, nội dung cũ của nó vẫn
   phải lấy lại được, không cần khôi phục từ đâu khác. `verify.sh` sẽ xoá thật
   một tệp thử rồi đòi lấy lại nội dung.

3. **Dữ liệu tệp có một bản sao thứ hai, và bản sao đó tự cập nhật.**
   "Tự cập nhật" nghĩa là **không có ai bấm gì và không có lịch chạy nào**:
   `verify.sh` đặt một tệp mới vào kho chính rồi ngồi chờ nó xuất hiện ở kho thứ
   hai. Cửa sổ chờ là **5 phút** — đúng bằng RPO cam kết cho dữ liệu tệp.

4. **Dữ liệu giao dịch khôi phục được về một thời điểm bất kỳ, không phải về
   lần chụp gần nhất.**
   Và **độ trễ thật** của cơ chế đó — khoảng cách từ mốc khôi phục gần nhất tới
   hiện tại — phải **nhỏ hơn hoặc bằng `rpo_phut` bạn cam kết**. `verify.sh`
   không tin lời khai; nó đọc mốc thật và tự trừ.

5. **Quy trình chuyển vùng phải sống sót cùng sự cố.**
   Các bước phải làm khi Region chính chết phải nằm ở dạng tệp trong kho dữ
   liệu, **và phải có mặt ở cả bản sao thứ hai**. Nội dung tối thiểu: chiến lược
   bạn đã chọn (đúng chuỗi bạn khai ở `chien_luoc_dr`), hai con số RTO/RPO, và
   các bước theo thứ tự. `verify.sh` đọc tệp đó ở **cả hai** nơi.

   > Đây là câu của người trực đêm hôm đó. Một runbook chỉ tồn tại ở nơi vừa
   > chết thì không phải runbook, chỉ là một kỷ niệm.

6. **Có một tín hiệu tự động cho biết Region chính đã hỏng, và tín hiệu đó đổi
   trạng thái được.**
   Máy phải đọc được nó (không phải một email cho người), nó phải đang ở trạng
   thái "khoẻ" khi hệ thống bình thường, và phải chuyển sang "hỏng" **trong vòng
   5 phút** khi sự cố xảy ra. `verify.sh` **mô phỏng sự cố**, chờ tín hiệu đổi,
   rồi trả nó về trạng thái cũ.

   *Bắt buộc khi bạn khai `pilot_light` trở lên.*

7. **Phía dự phòng có sẵn năng lực tính toán đã khai báo nhưng đang tắt.**
   Bật lên được bằng một thao tác, và **không tốn một xu nào khi đang tắt**.
   Đây chính là chữ "đèn mồi" trong tên của chiến lược: bấc đã tẩm dầu, chỉ chờ
   châm lửa.

   *Bắt buộc khi bạn khai `pilot_light` trở lên.*

8. **PHỦ ĐỊNH — không thành phần nào tính tiền theo giờ.**
   Đây là cách trần ngân sách $5/tháng được thực thi, và nó cũng là lý do hai
   trong bốn chiến lược DR **không phải đáp án của bối cảnh này**. `verify.sh`
   quét theo tag `lab=w11`.

9. **PHỦ ĐỊNH — không ai ngoài tài khoản đọc được dữ liệu.**
   Bản sao dự phòng là một bản sao **đầy đủ** của dữ liệu sản xuất. Rất nhiều
   vụ lộ dữ liệu bắt đầu từ chỗ này: kho chính được siết kỹ, kho backup thì
   không ai nhớ tới.

---

## Hợp đồng output

Thiếu một output bắt buộc = `verify.sh` dừng ngay, không chấm được gì.

| Output | Kiểu | Bắt buộc khi | `verify.sh` dùng để làm gì |
|---|---|---|---|
| `chien_luoc_dr` | string | **luôn** | Đúng một trong: `backup_restore`, `pilot_light`, `warm_standby`, `multi_site`. Đây là **quyết định** của bạn, và mọi check sau đều rẽ nhánh theo nó |
| `rto_phut` | number | **luôn** | RTO bạn cam kết, tính bằng **phút** |
| `rpo_phut` | number | **luôn** | RPO bạn cam kết, tính bằng **phút** |
| `kho_chinh` | string | **luôn** | Tên kho dữ liệu tệp chính. verify ghi/xoá/đọc tệp thử ở đây |
| `kho_du_phong` | string | **luôn** | Tên kho chứa bản sao thứ hai |
| `duong_dan_runbook` | string | **luôn** | Đường dẫn (key) của tệp quy trình chuyển vùng, **trong cả hai kho** |
| `bang_giao_dich` | string | **luôn** | Tên kho dữ liệu giao dịch. verify đọc mốc khôi phục thật của nó |
| `ten_canh_bao_su_co` | string | `pilot_light` trở lên | Tên tín hiệu sự cố. verify đọc trạng thái, **ép nó đổi**, rồi trả lại |
| `nhom_den_moi` | string | `pilot_light` trở lên | Tên nhóm năng lực tính toán đang tắt ở yêu cầu 7 |
| `ma_tin_hieu_dns` | string | **tuỳ chọn** | Nếu bạn dựng thêm tín hiệu ở tầng DNS (xem "Hàng rào"), khai id của nó vào đây và verify sẽ chấm thêm. Bỏ trống thì không bị trừ |
| `chi_phi` | string | **luôn** | In ra trước khi gõ `yes` |

Đặt tên tài nguyên với tiền tố **`self-w11-`**.

> **Vì sao `chien_luoc_dr` là một output chứ không phải một dòng trong README
> của bạn:** vì một quyết định kiến trúc không được ghi ở nơi máy đọc được thì
> nó không tồn tại đối với hệ thống. Sáu tháng sau, người kế nhiệm bạn sẽ đọc
> `terraform output`, không đọc trí nhớ của bạn.

---

## Hàng rào của lab này

### Trần chi phí: $0,00/giờ

| Thành phần | Giá thật | Lab này tốn |
|---|---|---|
| Kho object + phiên bản cũ | $0,023/GB-tháng | vài KB → **$0,00** |
| Sao chép giữa hai kho **cùng Region** | $0,015/GB truyền + phí request | vài KB → **$0,00** |
| Khôi phục liên tục cho kho giao dịch (PITR) | $0,20/GB-tháng theo kích thước bảng | bảng vài KB → **$0,00** |
| Nhóm năng lực tính toán đang tắt (0 máy) | $0 khi không có máy nào chạy | **$0,00** |
| Cảnh báo CloudWatch | **10 cái đầu miễn phí**, sau đó $0,10/cái/tháng | 1–2 → **$0,00** |
| *(tuỳ chọn)* tín hiệu sức khoẻ ở tầng DNS | **$0,50/tháng** mỗi cái, không có bậc miễn phí | 0 hoặc 1 |

**Tuỳ chọn duy nhất tốn tiền** là yêu cầu 6 giải bằng một **Route 53 health
check**. Đề bài **không bắt** bạn làm thế: yêu cầu 6 nói "một tín hiệu tự động,
máy đọc được, đổi trạng thái được", và một cảnh báo CloudWatch thoả điều đó với
giá $0. Nhưng health check là thứ **Route 53 thật sự dùng để tự đổi DNS** khi
sự cố xảy ra, nên nếu bạn muốn chạm vào cơ chế thật thì hãy dựng nó, khai
`ma_tin_hieu_dns`, và **xoá sau khi xong**:

```bash
aws route53 delete-health-check --profile lab-builder --health-check-id <id>
# hoặc đơn giản: terraform destroy
```

`DOI-CHIEU.md` so sánh hai đường và nói rõ đường nào là đáp án đề thi.

### Một Region — và vì sao đó lại là bài học chứ không phải hạn chế

`DenyOutsideAllowedRegions` chặn mọi API call ngoài `us-east-1`. Nghĩa là
**cross-region replication bị chặn** ở cấu hình mặc định, và bạn sẽ dựng toàn bộ
lab này trong **một** Region.

Nghe có vẻ vô lý cho một lab về DR. Nó không vô lý, vì ba lý do:

1. **Cơ chế giống hệt nhau.** Same-Region Replication và Cross-Region
   Replication dùng chung một cấu hình, chung một IAM role, chung một cách xử lý
   delete marker, chung một `ReplicationStatus`. Thứ duy nhất khác là giá trị
   của một trường: kho đích nằm ở đâu. Bạn học đúng cơ chế mà không mở thêm một
   Region để rồi bỏ quên tài nguyên trong đó — đó là cách đốt credit phổ biến
   nhất.
2. **Phần "cross-region" mà đề thi hỏi là phần thiết kế**, không phải phần gõ.
   Đề hỏi "RTO/RPO nào cần Region thứ hai", "cái gì replicate được và cái gì
   không", "chi phí data transfer ra khỏi Region là bao nhiêu" — bạn trả lời
   những câu đó bằng `DOI-CHIEU.md`, không bằng `terraform apply`.
3. Một bản sao **cùng Region** vẫn cứu bạn khỏi ba trong bốn loại sự cố thật:
   xoá nhầm, ghi đè nhầm, và mã độc mã hoá dữ liệu. Nó không cứu bạn khỏi sự cố
   toàn Region. `DOI-CHIEU.md` có bảng đầy đủ.

**Nếu bạn thật sự muốn chạm vào hai Region** — đây là đường mở rào **có chủ
đích**, không phải cách lách:

```bash
# 1. Bằng profile ADMIN (learn), KHÔNG phải lab-builder:
cd ../_boundary
terraform apply -var 'notify_email=...' \
                -var 'allowed_regions=["us-east-1","us-west-2"]'

# 2. Trong terraform/providers.tf của lab này, BỎ COMMENT khối provider có
#    alias = "phu". Nó đã được viết sẵn cho bạn ở đó, kèm giải thích.

# 3. Làm xong, ĐÓNG RÀO LẠI NGAY — vẫn bằng profile learn:
cd ../_boundary && terraform apply -var 'notify_email=...'
```

Biến `allowed_regions` giới hạn **tối đa 2 phần tử**, cố ý. Và nhớ: mở rào
nghĩa là bạn nhận trách nhiệm dọn Region thứ hai —
`../../scripts/find-orphans.sh --all` quét mọi Region, chạy nó trước khi đóng rào.

> Khối `provider` có alias trong `providers.tf` để ở dạng **comment** chứ không
> phải dạng sống: một provider khai sẵn cho Region đang bị chặn sẽ làm
> `terraform apply` gãy ngay lúc cấu hình provider, trước khi tới resource nào.
> Bỏ comment **sau** khi rào đã mở, không phải trước.

### Boundary chặn gì ở lab này

| Chặn | Bạn gặp nó lúc nào |
|---|---|
| `iam:CreateRole` không kèm `permissions_boundary` | Cơ chế sao chép giữa hai kho cần **một IAM role của riêng nó** — dịch vụ kho dữ liệu đóng vai role đó để đọc kho nguồn và ghi kho đích. Đây là chỗ bạn va vào hàng rào ở lab này. Lấy ARN: `terraform -chdir=../_boundary output -raw lab_boundary_arn` |
| tên tài nguyên IAM không có tiền tố `self-w11-` | `DenyCredentialEscalation` dùng `NotResource` trên `self-w*`. Đặt tên sai tiền tố cho ra `AccessDenied` **nói là do permission boundary** trong khi thật ra chỉ là lỗi đặt tên. Kiểm tra tên trước, kiểm tra kiến trúc sau |
| ASG có `MaxSize > 4` | yêu cầu 7 chỉ cần một nhóm nhỏ. Nhớ: boundary **không** chặn được instance type mà ASG launch (service-linked role không mang boundary của bạn) — trần duy nhất là số lượng |
| EC2 type ngoài `t2.micro`/`t3.micro`/`t3.small`/`t4g.micro`/`t4g.small` | áp lên `ec2:RunInstances` **do bạn gọi**. Với yêu cầu 7 thì không máy nào chạy cả, nên nó không cản bạn — nhưng vẫn đặt type nhỏ trong launch template, vì hàng rào **không** đỡ được lúc ASG scale out |
| NAT Gateway, Elastic IP, Transit Gateway, VPN, Direct Connect | Đây là phần "hybrid" của tuần 11. Cả bốn đều tính tiền theo giờ và bị chặn — chúng học bằng sơ đồ và bảng, và đó cũng đúng là phần đề thi hỏi. Xem [`docs/aws/w11-dr-hybrid.md`](../../../docs/aws/w11-dr-hybrid.md) mục 8 |
| Aurora, DocumentDB, Neptune (mọi `rds:CreateDBCluster`) | nếu bạn định dùng Aurora Global Database làm lời giải — đó là đáp án đúng cho một bối cảnh **khác**, có ngân sách khác |
| mọi API ngoài `us-east-1` | xem trên |

**Gặp lỗi — hàng rào hay bug của bạn?**

| Thông điệp chứa | Nghĩa là | Làm gì |
|---|---|---|
| `explicit deny in a permissions boundary` khi tạo IAM role | hàng rào — thiếu `permissions_boundary` | thêm nó, đừng gỡ rào |
| `explicit deny in a permissions boundary` khi **sửa** IAM role | rất có thể chỉ là **sai tiền tố tên** | kiểm tra `self-w11-` trước |
| `AccessDenied` khi gọi API ở `us-west-2` | hàng rào, đúng thiết kế | xem mục mở rào ở trên |
| `InvalidRequest: Destination bucket must have versioning enabled` | **bug của bạn** — cơ chế sao chép đòi cả hai kho cùng bật lịch sử phiên bản | không nhắc boundary → không phải hàng rào |
| `Role does not have permissions to replicate` | **bug của bạn** — role sao chép thiếu quyền trên kho nguồn hoặc kho đích | đọc kỹ: nó cần quyền ở **cả hai phía**, và chúng khác nhau |

---

## Tiêu chí đạt

`./verify.sh` xanh hết là điều kiện **cần**, không phải điều kiện **đủ**:

- [ ] `./verify.sh` xanh hết — trong đó có **4 check phủ định**
- [ ] Giải thích được vì sao **hai** trong bốn chiến lược DR bị loại bởi **một
      câu duy nhất** trong Bối cảnh, và đó là câu nào
- [ ] Trả lời được: RTO của bạn là 60 phút. **Đo từ lúc nào tới lúc nào?** Từ
      lúc hệ thống hỏng, hay từ lúc có người phát hiện ra? Chênh lệch giữa hai
      mốc đó gọi là gì, và cái gì rút ngắn nó?
- [ ] Trả lời được: bản sao ở kho thứ hai bảo vệ bạn khỏi **loại sự cố nào**, và
      **không** bảo vệ khỏi loại nào. Kể ít nhất một loại nó bó tay
- [ ] Trả lời được: nếu ai đó xoá một tệp ở kho chính, tệp ở kho thứ hai có bị
      xoá theo không? Câu trả lời **phụ thuộc một tuỳ chọn cấu hình** — nói được
      tên nó và nói được nên bật hay tắt cho mục đích DR
- [ ] Trả lời được: cơ chế khôi phục liên tục của kho giao dịch khôi phục về một
      **bảng mới** hay ghi đè lên bảng cũ? Điều đó ảnh hưởng thế nào tới RTO
      thật của bạn — và tới các bước trong runbook?
- [ ] **Runbook của bạn đã được diễn tập chưa?** Đọc lại nó và tự hỏi từng bước:
      "tôi có lệnh cụ thể cho bước này không, hay tôi đang viết một danh từ?"
      Một runbook chưa từng chạy thử là một giả thuyết, không phải một kế hoạch —
      và đó chính là rủi ro lớn nhất của chiến lược bạn vừa chọn
- [ ] Vẽ được **cả bốn** sơ đồ DR cho hệ thống này (không chỉ cái bạn chọn), mỗi
      cái ghi rõ: có gì ở phía dự phòng, RTO/RPO ước tính, chi phí ước tính mỗi
      tháng, và các bước khi sự cố. Giữ lại — đây là nền cho dự án DR hybrid của
      bạn, và bốn sơ đồ này là thứ người phỏng vấn hỏi

---

## Quy trình

```bash
source ../../env.sh
../_boundary/guard.sh

# Lấy ARN trần quyền TRƯỚC — cơ chế sao chép cần một IAM role
terraform -chdir=../_boundary output -raw lab_boundary_arn

cd terraform
terraform init
terraform apply                 # đọc chi_phi trước khi gõ yes

cd .. && ./verify.sh            # ~8 phút, có báo tiến độ suốt
$PAGER DOI-CHIEU.md             # chỉ khi đã xanh hết

cd terraform && terraform destroy
```

> `verify.sh` **có ghi** vào hệ thống của bạn, và đó là ngoại lệ có chủ ý: nó
> đặt vài tệp thử vào kho chính, **xoá thật** một tệp để chứng minh bạn lấy lại
> được, và **ép tín hiệu sự cố đổi trạng thái** rồi trả về như cũ. Không gây ra
> chuyện gì thì không chứng minh được thứ gì — một kế hoạch DR chưa từng được
> thử nghiệm không phải là một kế hoạch. Nó dọn sạch mọi tệp thử của mình, không
> sửa một dòng cấu hình nào, và chạy lại nhiều lần cho cùng kết quả.

---

## Dọn dẹp

`terraform destroy` xoá được gần hết. Ba chỗ cần biết trước:

```bash
cd terraform && terraform destroy
```

**1. Kho có lịch sử phiên bản không tự rỗng.** Bật versioning nghĩa là mọi lần
"xoá" chỉ thêm một delete marker; kho vẫn còn object và `destroy` sẽ báo
`BucketNotEmpty`. Cách xử lý gọn nhất là khai `force_destroy` ngay từ đầu. Nếu
đã lỡ:

```bash
aws s3api list-object-versions --profile lab-builder --bucket <kho> \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' > /tmp/v.json
aws s3api delete-objects --profile lab-builder --bucket <kho> --delete file:///tmp/v.json
# rồi lặp lại cho DeleteMarkers[]
```

**2. Tín hiệu ở tầng DNS, nếu bạn có dựng.** Nó **không** mang tag `lab=w11`
theo cách các dịch vụ khác mang, nên `find-orphans.sh` có thể không thấy nó. Và
nó tốn $0,50/tháng, mãi mãi:

```bash
aws route53 list-health-checks --profile lab-builder \
  --query 'HealthChecks[].[Id,HealthCheckConfig.Type]' --output table
aws route53 delete-health-check --profile lab-builder --health-check-id <id>
```

**3. Nếu bạn có mở rào hai Region** — dọn Region thứ hai rồi mới đóng rào:

```bash
../../scripts/find-orphans.sh --all
```

Kiểm tra đã sạch:

```bash
aws s3 ls --profile lab-builder | grep self-w11
aws dynamodb list-tables --profile lab-builder --query "TableNames[?starts_with(@,'self-w11')]"
aws autoscaling describe-auto-scaling-groups --profile lab-builder \
  --query "AutoScalingGroups[?starts_with(AutoScalingGroupName,'self-w11')].AutoScalingGroupName"
aws cloudwatch describe-alarms --profile lab-builder \
  --alarm-name-prefix self-w11 --query 'MetricAlarms[].AlarmName'
aws route53 list-health-checks --profile lab-builder --query 'length(HealthChecks)'
aws iam list-roles --profile lab-builder \
  --query "Roles[?starts_with(RoleName,'self-w11')].RoleName"
```

Sáu lệnh, sáu kết quả rỗng (lệnh thứ năm ra `0`).
