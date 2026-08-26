# notes — Sổ tay học

Ghi lại những gì trao đổi trong quá trình học: câu hỏi bạn đặt ra, chỗ hiểu sai
đã được sửa, quyết định kỹ thuật và lý do.

Khác `docs/` ở chỗ: `docs/` là lý thuyết đã sắp xếp, `notes/` là **dấu vết suy
nghĩ** — thô, theo thời gian, và thường có giá trị hơn khi ôn lại, vì nó ghi
đúng chỗ bạn từng vấp.

## Quy ước

Một file cho một buổi: `YYYY-MM-DD-<chu-de>.md`

```markdown
---
ngày: 2026-08-18
chủ đề: <ngắn gọn>
liên quan: docs/aws/w02-vpc-networking.md, learn-k8s/infra/
---

## Câu hỏi đã đặt ra
## Chốt lại được gì
## Chỗ tôi hiểu sai
## Còn treo
```

Mục **Chỗ tôi hiểu sai** là mục quan trọng nhất — đừng bỏ trống cho đẹp.
Mục **Còn treo** là hàng đợi cho buổi sau.

## Mục lục

| Ngày | Chủ đề | Ghi chú |
|---|---|---|
| 2026-08-17 | [K8s: tách mặt phẳng quản trị khỏi mặt phẳng cluster](2026-08-17-k8s-tach-mgmt-va-cluster-plane.md) | Dọn Ansible, bỏ workaround VPN |
| 2026-08-22 | [Sổ tay tra cứu, và bộ lab tự viết có hàng rào](2026-08-22-so-tay-va-lab-tu-viet.md) | `docs/notebook/` + `labs-self/`; permission boundary vừa là rào vừa là bài học |
