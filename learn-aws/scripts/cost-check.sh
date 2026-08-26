#!/usr/bin/env bash
# Chi tiêu N ngày gần nhất, tách theo service. Mặc định 7 ngày.
#   ./scripts/cost-check.sh        → 7 ngày
#   ./scripts/cost-check.sh 30     → 30 ngày
#
# Cost Explorer API tính phí $0,01 mỗi request. Chạy vài lần/ngày thì không đáng kể,
# nhưng đừng đưa nó vào vòng lặp.
set -euo pipefail

DAYS="${1:-7}"
PROFILE="${AWS_PROFILE:-learn}"

START=$(date -d "$DAYS days ago" +%F)
END=$(date -d "tomorrow" +%F)   # End là exclusive → +1 ngày để gồm cả hôm nay

echo "Chi tiêu từ $START đến hôm nay (profile: $PROFILE)"
echo

aws ce get-cost-and-usage \
  --profile "$PROFILE" \
  --time-period "Start=$START,End=$END" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json \
| python3 - <<'PY'
import json, sys

data = json.load(sys.stdin)["ResultsByTime"]
tong = 0.0
theo_svc = {}

for ngay in data:
    dong = []
    for g in ngay.get("Groups", []):
        gia = float(g["Metrics"]["UnblendedCost"]["Amount"])
        if gia > 0.0001:
            dong.append((g["Keys"][0], gia))
    if not dong:
        continue
    ngay_tong = sum(v for _, v in dong)
    tong += ngay_tong
    print("{}   ${:>9.4f}".format(ngay["TimePeriod"]["Start"], ngay_tong))
    for ten, gia in sorted(dong, key=lambda x: -x[1]):
        theo_svc[ten] = theo_svc.get(ten, 0.0) + gia
        print("             {:<44} ${:>9.4f}".format(ten, gia))

print()
print("{:<13} ${:>9.4f}".format("TONG CONG", tong))

if theo_svc:
    print()
    print("Xep hang service:")
    for ten, gia in sorted(theo_svc.items(), key=lambda x: -x[1]):
        print("  {:<46} ${:>9.4f}".format(ten, gia))

if tong > 5:
    print()
    print("!! Vuot $5. Chay ./scripts/find-orphans.sh xem co gi bi quen khong.")
PY
