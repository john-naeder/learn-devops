# Luật viết sổ tay (notebook)

> File này ràng buộc mọi file trong `docs/notebook/`. Đọc hết trước khi viết một chữ.

## Sổ tay này KHÁC gì `docs/aws/`?

| | `docs/aws/w01..w12` | `docs/notebook/` (file này) |
|---|---|---|
| Trục tổ chức | **thời gian** — 12 tuần, học tuần tự | **chủ đề** — tra theo dịch vụ / theo bài toán |
| Câu hỏi trả lời | "Tuần này học gì?" | "Cái này hoạt động thế nào? Chọn cái nào?" |
| Cách đọc | đọc một lần, theo thứ tự | nhảy vào giữa, đọc một mục, đóng lại |
| Độ sâu | vừa đủ để làm lab tuần đó | **sâu nhất trong repo** — đây là nơi tra cứu cuối cùng |

Không viết lại nội dung tuần. Nếu một khái niệm đã có ở `docs/aws/wXX`, sổ tay
vẫn viết lại **sâu hơn** (cơ chế, con số, giới hạn, bẫy) và link ngược về tuần.

## Nguồn

Cơ sở là submodule `aws-saa-c03/` (thư mục gốc repo). Nhiệm vụ là **mở rộng và
chi tiết hoá** nó, không phải chép lại.

Nguồn đó là cheat sheet: gạch đầu dòng, bảng, emoji, đúng nhưng **nông**. Với
mỗi mục bạn lấy từ đó, phải thêm được ít nhất hai trong ba thứ sau:

1. **Cơ chế** — nó chạy thế nào bên dưới, tại sao lại thế
2. **Con số** — giới hạn, ngưỡng, giá, độ trễ, quota (kèm mốc "tính đến 2026-08")
3. **Bẫy** — chỗ đề thi gài, chỗ tài liệu cũ dạy sai

Chỉ chép lại mà không thêm được gì → cắt mục đó đi.

**Nguồn đó có chỗ sai và chỗ thiếu.** README của nó liệt kê các file F, G, H, I,
J, N, O — không file nào tồn tại. Khi phát hiện sai/thiếu, sửa và ghi vào mục
"Nguồn nói khác" ở cuối file, kèm link docs chính thức.

Docs chính thức là trọng tài cuối cùng. Ưu tiên `mcp__plugin_deploy-on-aws_awsknowledge__aws___read_documentation`
và `..._search_documentation` hơn WebFetch — WebFetch tóm tắt PDF sai đã từng
xảy ra trong repo này.

## Phạm vi: SAA-C03, không hơn

Giữ nguyên kỷ luật của [`../CONVENTIONS.md`](../CONVENTIONS.md):

> Không chắc thì hỏi: *"Câu hỏi SAA có thể xoay quanh điều này không?"*
> Không → tối đa một dòng ở mục **Ngoài phạm vi**, kèm link, rồi đi tiếp.
> Thà sâu 15 dịch vụ ra thi còn hơn lướt 60 dịch vụ.

Sổ tay sâu hơn tuần, nhưng **không rộng hơn**. Sâu = thêm cơ chế và con số cho
thứ ra thi. Sâu ≠ thêm dịch vụ không ra thi.

## Bố cục bắt buộc

```markdown
# <Tên chủ đề>

> **Tra nhanh:** một câu — file này trả lời được câu hỏi gì.

`Domain X · Tên miền (NN% đề)`   ← miền thi mà chủ đề này đóng góp

## Bản đồ
Bảng 2 cột: mục trong file → "khi nào bạn cần đọc mục này".

## <Các mục nội dung>
...

## Bảng số phải nhớ
Chỉ con số RA THI. Không nhồi quota linh tinh.

## Bẫy đề thi
Mỗi bẫy: câu hỏi thường gặp → đáp án sai hấp dẫn → đáp án đúng → **vì sao**.

## Cây quyết định
Chọn giữa các dịch vụ trong file này. Dạng văn bản, không ASCII art rối.

## Nối với thực hành
Link tới lab có sẵn (`learn-aws/labs/wXX-*/`) và lab tự viết
(`learn-aws/labs-self/wXX-*/`). Nói rõ lab nào chạm vào mục nào.

## Nguồn nói khác
Chỗ `aws-saa-c03/` sai/cũ/thiếu, kèm docs chính thức. Bỏ mục này nếu không có.

## Ngoài phạm vi
Một dòng mỗi thứ, kèm link. Đây là nơi duy nhất được nhắc dịch vụ ngoài SAA.

## Tự kiểm tra
5–8 câu. Câu hỏi ở ngoài, đáp án trong `<details><summary>Đáp án</summary>`.
Câu hỏi phải buộc GIẢI THÍCH, không phải nhớ tên dịch vụ.
```

## Văn phong

- **Tiếng Việt**, thuật ngữ kỹ thuật giữ nguyên tiếng Anh (`permission boundary`,
  không "ranh giới quyền hạn"). Lần đầu xuất hiện thì mở ngoặc giải thích.
- Xưng **"bạn"**. Người đọc là kỹ sư, không phải sinh viên.
- **Không emoji trong tiêu đề.** Nguồn dùng emoji dày đặc — bỏ hết. Emoji làm
  Ctrl+F và anchor link vỡ.
- Câu khẳng định. "NAT Gateway scale 5 → 100 Gbps", không "NAT Gateway có thể
  được scale lên đến khoảng 100 Gbps tùy trường hợp".
- Code block phải chạy được. Lệnh AWS CLI kèm `--profile learn` khi có ý nghĩa.
- Bảng khi so sánh ≥ 3 thứ theo ≥ 2 tiêu chí. Dưới ngưỡng đó thì viết văn xuôi.

## Độ dài

600–900 dòng mỗi file. Ngắn hơn 600 = chưa đủ sâu. Dài hơn 900 = đang lan man,
cắt bớt hoặc tách file — nhưng **không tự ý tách**, tên file đã cố định (dưới).

## Tên file — CỐ ĐỊNH, các agent link chéo nhau bằng đúng tên này

```
README.md                      bản đồ sổ tay
00-nen-tang.md                 global infra, Well-Architected, shared responsibility
01-compute.md                  EC2, Lambda, ECS/EKS/Fargate, ASG, placement group
02-storage.md                  S3, EBS, EFS, FSx, Storage Gateway, instance store
03-database.md                 RDS, Aurora, DynamoDB, ElastiCache, Redshift, DocumentDB
04-networking.md               VPC, SG/NACL, endpoint, peering, TGW, ELB, Route 53, CloudFront
05-security.md                 IAM, KMS, Secrets Manager, ACM, WAF/Shield, GuardDuty, Macie
06-tich-hop.md                 SQS, SNS, EventBridge, Step Functions, API Gateway, Kinesis
07-quan-tri-giam-sat.md        CloudWatch, CloudTrail, Config, Organizations, SSM, CloudFormation
10-chi-phi.md                  Domain 4 — pricing model, chọn rẻ, bẫy tiền
11-san-sang-cao.md             Domain 2 — HA, fault tolerance, multi-AZ vs multi-Region
12-hieu-nang.md                Domain 3 — caching, chọn compute/storage/db theo tải
13-khoi-phuc-tham-hoa.md       DR: 4 chiến lược, RTO/RPO, 7R migration
20-cay-quyet-dinh.md           "gặp bài toán X thì chọn gì" — toàn bộ cây quyết định
21-tu-khoa-de-thi.md           từ khoá trong đề → dịch vụ, kèm bẫy từ khoá
22-bang-so-sanh.md             mọi bảng so sánh cặp đôi, gom một chỗ
```

Link chéo bằng đường dẫn tương đối: `[compute](01-compute.md#anchor)`.
File chưa ai viết vẫn cứ link — sẽ có người viết.

## Kiểm tra trước khi báo xong

```bash
# 1. Đủ mục bắt buộc
for s in "## Bản đồ" "## Bảng số phải nhớ" "## Bẫy đề thi" "## Cây quyết định" \
         "## Nối với thực hành" "## Ngoài phạm vi" "## Tự kiểm tra"; do
  grep -qF "$s" FILE.md || echo "THIẾU: $s"
done
# 2. <details> cân bằng
[ "$(grep -c '<details>' FILE.md)" = "$(grep -c '</details>' FILE.md)" ] || echo "LỆCH details"
# 3. Không emoji trong heading
grep -nP '^#{1,6} .*[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]' FILE.md && echo "CÒN EMOJI"
# 4. Link nội bộ trỏ tới file có thật
grep -oP '\]\(\K[^)#]+(?=[)#])' FILE.md | grep -v '^http' | while read -r p; do
  [ -e "$(dirname FILE.md)/$p" ] || echo "LINK HỎNG: $p"; done
```
