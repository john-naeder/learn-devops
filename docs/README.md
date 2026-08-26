# docs — Lý thuyết

Phần **đọc hiểu**. Phần **làm** nằm ở `learn-aws/labs/` và `learn-k8s/`.

```
docs/
├── CONVENTIONS.md    quy ước viết (đọc nếu bạn muốn tự thêm bài)
├── aws/              lý thuyết SAA-C03, ánh xạ 1:1 với 12 tuần trong kế hoạch
├── notebook/         sổ tay tra cứu theo CHỦ ĐỀ — tầng sâu nhất, nhảy vào giữa
└── k8s/              lý thuyết Kubernetes (sẽ bổ sung)
```

Hai thư mục AWS khác nhau ở **trục**, không ở độ khó:

| | Trục | Trả lời | Cách đọc |
|---|---|---|---|
| [`aws/`](aws/) | thời gian | "Tuần này học gì?" | một lần, theo thứ tự |
| [`notebook/`](notebook/) | chủ đề | "Cái này chạy thế nào? Chọn cái nào?" | tra cứu, nhảy vào giữa |

Đừng đọc `notebook/` thay cho phần 12 tuần — nó không có thứ tự sư phạm.
Xem [`notebook/README.md`](notebook/README.md) để biết mở file nào khi nào.

## Vòng lặp học một tuần

```
1. Đọc   docs/aws/wNN-<chủ-đề>.md              ← hiểu tại sao
2. Đào   docs/notebook/<chủ-đề>.md             ← chỗ nào muốn sâu hơn
3. Tự viết  learn-aws/labs-self/wNN-*/         ← từ file trống, không có lời giải
4. Đọc   labs-self/wNN-*/DOI-CHIEU.md          ← nối việc vừa làm với ngôn ngữ đề thi
5. Đối chiếu  learn-aws/labs/wNN-*/            ← xem người khác giải cách nào
6. Trả lời phần "Tự kiểm tra" cuối bài         ← không mở đáp án trước
7. Ghi   notes/YYYY-MM-DD-<chủ-đề>.md          ← cái bạn hiểu sai, cái bạn hỏi thêm
```

Bước 3 là bước tốn thời gian nhất và cũng là bước duy nhất dạy bạn **nghĩ ra**
kiến trúc thay vì đọc hiểu kiến trúc người khác đã viết. Bước 5 đặt sau bước 3
là có chủ đích: đọc lời giải trước khi tự vật lộn thì bạn chỉ học được cách đọc.

Bước 6 và 7 mới là chỗ kiến thức đọng lại. Đọc và làm mà bỏ hai bước đó thì
sau ba tuần bạn sẽ không nhớ tuần 1 có gì.

## Liên quan

- [`learn-aws/aws-saa-plan.md`](../learn-aws/aws-saa-plan.md) — kế hoạch 12 tuần, lịch, chi phí
- [`learn-aws/labs/README.md`](../learn-aws/labs/README.md) — lab có lời giải sẵn, quy trình một buổi
- [`learn-aws/labs-self/README.md`](../learn-aws/labs-self/README.md) — lab **tự viết**, kèm hàng rào an toàn ba tầng
- [`notes/`](../notes/) — ghi chép từ các buổi trao đổi
