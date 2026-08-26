# Lý thuyết AWS — SAA-C03

Ánh xạ **1:1** với 12 tuần trong [`aws-saa-plan.md`](../../learn-aws/aws-saa-plan.md).
Đọc bài lý thuyết trước, làm lab cùng tuần sau.

| | Đọc | Rồi làm |
|---|---|---|
| — | [Nền tảng AWS](00-nen-tang-aws.md) — Region/AZ, shared responsibility, Well-Architected | *(không có lab)* |
| 1 | [IAM: danh tính, quyền hạn, ranh giới](w01-iam-foundations.md) | [`w01-iam-foundations`](../../learn-aws/labs/w01-iam-foundations/) |
| 2 | [VPC: xương sống của mọi câu hỏi](w02-vpc-networking.md) | [`w02-vpc-networking`](../../learn-aws/labs/w02-vpc-networking/) |
| 3 | [EC2, EBS, Load Balancer, Auto Scaling](w03-ec2-alb-asg.md) | [`w03-ec2-alb-asg`](../../learn-aws/labs/w03-ec2-alb-asg/) |
| 4 | [S3 và các tầng lưu trữ](w04-s3-cloudfront.md) | [`w04-s3-cloudfront`](../../learn-aws/labs/w04-s3-cloudfront/) |
| 5 | [Cơ sở dữ liệu](w05-databases.md) | [`w05-databases`](../../learn-aws/labs/w05-databases/) |
| 6 | [Serverless: Lambda, API Gateway](w06-serverless-api.md) | [`w06-serverless-api`](../../learn-aws/labs/w06-serverless-api/) |
| 7 | [Tách rời hệ thống và tích hợp](w07-decoupling.md) | [`w07-decoupling`](../../learn-aws/labs/w07-decoupling/) |
| 8 | [DNS, CDN và tầng biên](w08-dns-cdn-edge.md) | [`w08-dns-cdn-edge`](../../learn-aws/labs/w08-dns-cdn-edge/) |
| 9 | [Bảo mật chuyên sâu](w09-security-deep.md) | [`w09-security-deep`](../../learn-aws/labs/w09-security-deep/) |
| 10 | [Giám sát, vận hành, IaC](w10-observability-iac.md) | [`w10-observability-iac`](../../learn-aws/labs/w10-observability-iac/) |
| 11 | [Di trú, hybrid, DR](w11-dr-hybrid.md) | [`w11-dr-hybrid`](../../learn-aws/labs/w11-dr-hybrid/) |
| 12 | [Ôn tập: bảng đối chiếu, chiến thuật thi](w12-exam-review.md) | [`w12-exam-review`](../../learn-aws/labs/w12-exam-review/) |

## Cách đọc một bài

Mỗi bài mở đầu bằng **"Học xong bài này bạn phải trả lời được"** — 5–8 câu hỏi.
Đó là hợp đồng. Đọc xong mà chưa trả lời được câu nào thì quay lại mục tương ứng,
đừng đi tiếp.

Mỗi bài kết thúc bằng **Tự kiểm tra** với đáp án gập lại. Trả lời ra giấy trước
khi mở. Chỗ bạn trả lời sai chính là thứ đáng ghi vào [`notes/`](../../notes/).

Hai mục ăn điểm nhiều nhất trong đề thi là **Bảng quyết định** (chọn X thay vì Y)
và **Bẫy kinh điển**. Nếu thời gian gấp, đọc hai mục đó trước.

## Phạm vi

Chỉ SAA-C03. Mỗi bài có mục **Ngoài phạm vi** liệt kê thứ liên quan nhưng không
ra thi, kèm link — để bạn biết nó tồn tại mà không sa đà. Quy ước đầy đủ ở
[`../CONVENTIONS.md`](../CONVENTIONS.md).
