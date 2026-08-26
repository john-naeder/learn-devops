---
ngày: 2026-08-17
chủ đề: Tách mặt phẳng quản trị (Tailscale) khỏi mặt phẳng cluster (LAN)
liên quan: learn-k8s/infra/ansible/
---

## Câu hỏi đã đặt ra

1. Bộ Ansible đang có nhiều workaround để chạy k8s qua VPN — giờ 3 node cùng LAN
   rồi thì gỡ được cái nào?
2. Dùng Jinja template (`.j2`) cho vài cấu hình nhỏ có hợp lý không?
3. Playbook này provision dựa trên IP Tailscale hay IP LAN? Kiểm tra bằng cách nào?

## Chốt lại được gì

**Hai mặt phẳng, không được lẫn.**

| | Management plane | Cluster plane |
|---|---|---|
| Đường | Tailscale `tailscale0` | LAN |
| Địa chỉ | `ansible_host` | `node_ip` |
| Dùng cho | Ansible SSH, kubectl từ xa | apiserver, etcd, kubelet, pod |

Ansible **đi qua** Tailscale để ra lệnh, nhưng thứ nó **ghi vào** node toàn là IP
LAN. Tắt Tailscale sau khi dựng xong thì cluster vẫn chạy — chỉ mất SSH và
kubectl từ xa. Ngoại lệ duy nhất: IP Tailscale của master nằm trong apiserver
cert SANs.

**Khi nào dùng `.j2`, khi nào không:**

- File tĩnh, không có `{{ }}` nào → `copy:` với `content:` inline. Dùng
  `template:` ở đây phát tín hiệu sai: nó nói "nội dung thay đổi theo host"
  trong khi không hề, và bắt người đọc mở thêm một file mới biết là không có gì.
- File có biến → `template:` là đúng. Giá trị thật của nó là **ràng buộc hai chỗ
  phải khớp nhau** (ví dụ `cidr: {{ pod_cidr }}` trong Calico Installation luôn
  khớp `--pod-network-cidr` truyền cho `kubeadm init`), không phải để "chứa nội
  dung file".

**Nguyên tắc rút ra:** một cấu hình chỉ nên có **một** cơ chế thiết lập.
`--node-ip` từng được set ở 3 chỗ cùng lúc (`/etc/default/kubelet`, systemd
drop-in, vá `kubeadm-flags.env`). Giữ lại một chỗ duy nhất.

## Chỗ tôi hiểu sai

- Tưởng "provision dựa trên IP Tailscale" nghĩa là cluster chạy trên VPN. Thực ra
  đường **vận chuyển lệnh** và đường **cluster chạy** là hai thứ độc lập.
- Chưa để ý `node_ip` được **suy ra** từ default route chứ không khai báo. Node
  nào bật Tailscale exit-node thì default route qua `tailscale0` → cluster âm
  thầm quay lại chạy trên VPN mà không có lỗi nào báo. Đây là lý do
  `make preflight` tồn tại.

## Bug tìm được trong repo cũ

| Bug | Hậu quả |
|---|---|
| Calico v3.28.2 với k8s 1.36 | 3.28 chỉ test tới k8s 1.30 → không tương thích |
| `service_cidr: 10.95.0.0/12` | Không phải network hợp lệ (`/12` của 10.95.x là 10.80.0.0/12) |
| Thiếu `DEFAULT_FORWARD_POLICY=ACCEPT` | UFW mặc định DROP forward → pod-to-pod chết |
| `stdout_callback = yaml` | Plugin đã bị xoá ở community.general 12.0 → mọi lệnh chết ngay dòng đầu |
| `worker_join` chạy `kubeadm reset` mỗi lần | Mỗi `make setup` là đá worker ra rồi join lại |

Bài học: `--syntax-check` **không** bắt được lỗi callback plugin. Phải chạy thật
(dù chỉ với inventory giả trỏ localhost) mới lộ ra.

## Còn treo

- [ ] Chạy `make ping && make preflight` khi Tailscale up lại — chưa verify trên node thật
- [ ] Cân nhắc `encapsulation: VXLANCrossSubnet` (traffic cùng subnet đi native, đỡ 50 byte header)
- [ ] `BAOCAO-TIENDO-CALICO.md` còn mô tả các workaround đã gỡ — đọc lại xem giữ hay viết lại
