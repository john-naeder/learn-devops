"""API ghi chú — CRUD đầy đủ trên DynamoDB.

Kiến trúc: HTTP API Gateway → Lambda (hàm này) → DynamoDB.

Đây là mẫu serverless kinh điển và là thứ đề thi SAA mô tả liên tục dưới dạng
"ứng dụng không cần quản lý máy chủ, tự co giãn, trả tiền theo mức dùng".

Vài lựa chọn trong file này là có chủ đích và đáng chú ý:

1. boto3 resource được tạo Ở NGOÀI handler, tại phạm vi module.
   Lambda giữ lại execution context giữa các lần gọi, nên đoạn này chỉ chạy
   một lần mỗi cold start chứ không phải mỗi request. Đặt nó bên trong handler
   là lỗi hiệu năng phổ biến nhất của Lambda — mỗi request sẽ phải dựng lại
   kết nối TLS tới DynamoDB.

2. Không dùng framework (Flask/FastAPI). Với một API nhỏ thì framework chỉ
   làm cold start chậm hơn mà không đem lại gì.

3. Trả về đúng định dạng mà HTTP API (payload format 2.0) mong đợi.
"""

import json
import os
import time
import uuid
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key

# --- Khởi tạo một lần mỗi cold start, KHÔNG phải mỗi request -----------------
TABLE = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
TTL_NGAY = int(os.environ.get("TTL_NGAY", "30"))


class _JSON(json.JSONEncoder):
    """DynamoDB trả về số dạng Decimal, mà json chuẩn không serialize được."""

    def default(self, o):
        if isinstance(o, Decimal):
            return int(o) if o % 1 == 0 else float(o)
        return super().default(o)


def _tra_loi(ma: int, than) -> dict:
    return {
        "statusCode": ma,
        "headers": {
            "content-type": "application/json; charset=utf-8",
            # CORS để trang tĩnh trên CloudFront gọi được API này.
            # Production thì thay "*" bằng đúng domain của bạn.
            "access-control-allow-origin": "*",
        },
        "body": json.dumps(than, cls=_JSON, ensure_ascii=False),
    }


def _nguoi_dung(event) -> str:
    """Định danh người dùng.

    Lab này chưa có xác thực nên tạm lấy từ header. Tuần 9 sẽ thay bằng
    Cognito JWT authorizer, và lúc đó giá trị này lấy từ claim đã được xác minh
    chứ không phải từ header người gọi tự đặt — đó mới là cách đúng.
    """
    headers = event.get("headers") or {}
    return headers.get("x-nguoi-dung", "khach")


def handler(event, context):
    route = event.get("routeKey", "")
    params = event.get("pathParameters") or {}
    nguoi_dung = _nguoi_dung(event)
    pk = f"NGUOIDUNG#{nguoi_dung}"

    try:
        # ---------------------------------------------------------- LIỆT KÊ
        if route == "GET /ghichu":
            # Query theo partition key — chỉ đọc đúng phần dữ liệu của người này.
            # Nếu dùng Scan ở đây thì mỗi request sẽ đọc dữ liệu của MỌI người
            # dùng và tính tiền tương ứng. Xem lab tuần 5.
            r = TABLE.query(KeyConditionExpression=Key("PK").eq(pk))
            return _tra_loi(200, {"ghichu": r["Items"], "so_luong": r["Count"]})

        # ------------------------------------------------------------- ĐỌC
        if route == "GET /ghichu/{id}":
            r = TABLE.get_item(Key={"PK": pk, "SK": f"GHICHU#{params['id']}"})
            if "Item" not in r:
                return _tra_loi(404, {"loi": "khong tim thay"})
            return _tra_loi(200, r["Item"])

        # ------------------------------------------------------------- TẠO
        if route == "POST /ghichu":
            than = json.loads(event.get("body") or "{}")
            noi_dung = (than.get("noi_dung") or "").strip()
            if not noi_dung:
                return _tra_loi(400, {"loi": "thieu truong noi_dung"})

            ghi_chu_id = uuid.uuid4().hex[:12]
            bay_gio = int(time.time())
            item = {
                "PK": pk,
                "SK": f"GHICHU#{ghi_chu_id}",
                "id": ghi_chu_id,
                "noi_dung": noi_dung[:4000],
                "tao_luc": bay_gio,
                # TTL: ghi chú tự biến mất sau TTL_NGAY. Giữ cho bảng lab không
                # phình mãi, và miễn phí hoàn toàn.
                "expires_at": bay_gio + TTL_NGAY * 86400,
            }
            TABLE.put_item(Item=item)
            return _tra_loi(201, item)

        # ------------------------------------------------------------- SỬA
        if route == "PUT /ghichu/{id}":
            than = json.loads(event.get("body") or "{}")
            noi_dung = (than.get("noi_dung") or "").strip()
            if not noi_dung:
                return _tra_loi(400, {"loi": "thieu truong noi_dung"})

            r = TABLE.update_item(
                Key={"PK": pk, "SK": f"GHICHU#{params['id']}"},
                UpdateExpression="SET noi_dung = :n, sua_luc = :t",
                ExpressionAttributeValues={":n": noi_dung[:4000], ":t": int(time.time())},
                # Chỉ sửa nếu item đã tồn tại — nếu không, update_item sẽ TẠO MỚI
                # một item trống. Đây là hành vi hay gây bất ngờ của DynamoDB.
                ConditionExpression="attribute_exists(PK)",
                ReturnValues="ALL_NEW",
            )
            return _tra_loi(200, r["Attributes"])

        # ------------------------------------------------------------- XOÁ
        if route == "DELETE /ghichu/{id}":
            TABLE.delete_item(Key={"PK": pk, "SK": f"GHICHU#{params['id']}"})
            return _tra_loi(204, {})

        # ------------------------------------------------ kiểm tra sức khoẻ
        if route == "GET /health":
            return _tra_loi(200, {
                "trang_thai": "ok",
                # Còn bao nhiêu ms trước khi Lambda bị cắt. Hữu ích để hiểu
                # timeout, và để hàm tự dừng gọn gàng khi sắp hết giờ.
                "con_lai_ms": context.get_remaining_time_in_millis(),
                "request_id": context.aws_request_id,
            })

        return _tra_loi(404, {"loi": f"khong co route: {route}"})

    except TABLE.meta.client.exceptions.ConditionalCheckFailedException:
        return _tra_loi(404, {"loi": "khong tim thay ghi chu de sua"})

    except json.JSONDecodeError:
        return _tra_loi(400, {"loi": "body khong phai JSON hop le"})

    except Exception as e:  # noqa: BLE001
        # In ra log để CloudWatch bắt được. Không trả chi tiết lỗi ra ngoài
        # vì đó là rò rỉ thông tin.
        print(json.dumps({"loi": type(e).__name__, "chi_tiet": str(e)}))
        return _tra_loi(500, {"loi": "loi noi bo"})
