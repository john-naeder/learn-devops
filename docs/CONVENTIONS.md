# Quy ước viết tài liệu trong `docs/`

Mọi tài liệu lý thuyết trong repo này — do tôi hay do subagent viết — đều theo
bản quy ước này. Mục đích: 13 bài đọc như một người viết, và học xong bài nào
thì làm được lab tuần đó.

---

## 1. Đối tượng đọc

Một kỹ sư đã quen Linux, Docker, Kubernetes, Ansible, Terraform — **chưa từng
dùng AWS**. Không cần giải thích "container là gì", "DNS là gì", "TLS là gì".
Cần giải thích "AWS gọi thứ đó là gì, khác cái bạn đã biết ở chỗ nào".

Bắc cầu từ cái đã biết là cách dạy hiệu quả nhất ở đây:

> Security Group ≈ iptables gắn vào ENI, nhưng **stateful và chỉ có ALLOW**.
> Không có rule DENY — muốn chặn thì dùng NACL (stateless, có DENY).

## 2. Phạm vi — kỷ luật quan trọng nhất

Viết cho **SAA-C03**, không phải cho "biết tuốt về AWS".

**Có viết:** dịch vụ nằm trong 4 domain của đề, ở mức một Solutions Architect
phải quyết định được *chọn cái nào và vì sao*.

**Không viết:** dịch vụ đặc thù ngành (Ground Truth, HealthLake, IoT TwinMaker),
tính năng chỉ dân chuyên sâu chạm tới (Aurora Global Database write forwarding,
Transit Gateway Connect, VPC Lattice), thao tác Console từng click, hay bất kỳ
thứ gì thuộc mức Professional/Specialty.

Không chắc thì hỏi: **"Câu hỏi SAA có thể xoay quanh điều này không?"** Không →
tối đa một dòng ở mục *Ngoài phạm vi*, kèm link, rồi đi tiếp.

Thà sâu 15 dịch vụ ra thi còn hơn lướt 60 dịch vụ.

## 3. Nguồn

Bám **tài liệu chính thức của AWS** (docs.aws.amazon.com, whitepaper, FAQ).
Không bịa số. Mỗi bài kết thúc bằng mục **Nguồn** liệt kê link đã dùng.

Con số thay đổi theo thời gian (giá, quota, giới hạn). Con số nào ra thi thì
ghi vào bảng *Số phải thuộc*; con số nào chỉ để tham khảo thì kèm
`(kiểm tra lại trang pricing/quota trước khi tin)`.

## 4. Bố cục bắt buộc

Mỗi bài `docs/aws/wNN-*.md` theo đúng thứ tự sau:

```
# Tuần NN — <Tên chủ đề>

> Một đoạn: tuần này trả lời câu hỏi kiến trúc nào.

## Học xong bài này bạn phải trả lời được
  5–8 câu hỏi. Đây là hợp đồng của bài — phần thân phải trả lời hết.

## Bản đồ khái niệm
  Sơ đồ ASCII hoặc bảng: các mảnh ghép với nhau ra sao.

## <Các mục lý thuyết>
  Phần thân. Chia theo khái niệm, không theo tên dịch vụ.
  Mỗi khái niệm: nó là gì → giải quyết vấn đề gì → đánh đổi gì.

## Bảng quyết định
  Cột "Khi nào dùng X thay vì Y". Đây là dạng câu hỏi SAA hay ra nhất.

## Số phải thuộc
  Bảng số liệu chắc chắn ra thi. Ngắn. Chỉ cái thật sự cần nhớ.

## Bẫy kinh điển
  Ngộ nhận thường gặp + vì sao sai. Cái này ăn điểm nhiều nhất.

## Nối với lab
  Trỏ tới `labs/wNN-*/`: lab chạm vào khái niệm nào, quan sát gì khi chạy.

## Tự kiểm tra
  6–10 câu hỏi, đáp án gập trong <details>. Hỏi *vì sao*, không hỏi định nghĩa.

## Ngoài phạm vi
  Thứ liên quan nhưng không ra thi SAA, mỗi thứ một dòng + link.

## Nguồn
```

## 5. Giọng văn

- Tiếng Việt. Thuật ngữ kỹ thuật giữ nguyên tiếng Anh (subnet, endpoint,
  throughput) — **không dịch** thành "mạng con", "điểm cuối".
- Xưng hô: gọi người đọc là **bạn**. Không "chúng ta cùng tìm hiểu".
- Câu khẳng định, ngắn. Không văn hoa, không "trong thế giới điện toán đám mây
  ngày nay...".
- Giải thích **tại sao** trước **cái gì**. Người đọc tra được định nghĩa;
  cái họ không tra được là lý do tồn tại và đánh đổi.
- Bảng > danh sách > đoạn văn dài, khi so sánh nhiều thứ.
- Không emoji trong thân bài.

## 6. Độ dài

400–700 dòng mỗi bài. Ngắn hơn thì hời hợt; dài hơn thì đang lan man —
kiểm tra lại mục 2.

## 7. Liên kết

- Sang lab: `../../labs/w03-ec2-alb-asg/`
- Sang kế hoạch: `../../learn-aws/aws-saa-plan.md`
- Giữa các bài: `[Tuần 2](w02-vpc-networking.md)`

Bài sau được phép giả định bài trước đã đọc. Không lặp lại kiến thức đã dạy —
**trỏ ngược lại**.
