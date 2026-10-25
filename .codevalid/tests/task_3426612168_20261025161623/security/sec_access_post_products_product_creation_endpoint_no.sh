#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

cv_step Given "unauthenticated client and unique sku" $LINENO
SFX=$(cv_suffix)
SKU1="SKU-NOAUTH-$SFX"; SKU2="SKU-NOAUTH2-$SFX"
cv_http GET /products
[ "$CV_HTTP_STATUS" != "000" ] || { echo "app unreachable"; exit 1; }

cv_step When "POST /products without and with a forged bearer token" $LINENO
cv_http POST /products "$(jq -nc --arg s "$SKU1" '{name:"Test",description:"Desc",sku:$s,priceCents:100}')"
S1=$CV_HTTP_STATUS
cv_http POST /products "$(jq -nc --arg s "$SKU2" '{name:"Test",description:"Desc",sku:$s,priceCents:100}')" -H "Authorization: Bearer forged.token"
S2=$CV_HTTP_STATUS
sku_count "$SKU1"; C1=$SKU_COUNT
sku_count "$SKU2"; C2=$SKU_COUNT

cv_step Then "decide verdict" $LINENO
T="Product creation endpoint not protected despite feature requiring signed-in users"
if [ "$S1" = "201" ] || [ "$S2" = "201" ] || [ "$C1" != "0" ] || [ "$C2" != "0" ]; then
  printf 'CV_SECURITY|vulnerable|access|critical|%s|%s\n' "$T" "no-token POST $S1 forged-token POST $S2; catalog entries created $C1/$C2"
else
  printf 'CV_SECURITY|secure|access|critical|%s|%s\n' "$T" "no-token POST $S1 forged-token POST $S2; no product created"
fi
exit 0
