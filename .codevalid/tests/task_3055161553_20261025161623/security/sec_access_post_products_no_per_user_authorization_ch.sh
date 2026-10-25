#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

cv_step Given "register an ordinary customer and sign in" $LINENO
SUF=$(cv_suffix)
EMAIL="sec-acc-${SUF}@example.test"
PASS="Pw-acc-${SUF}"
SKU="SEC-${SUF}"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,name:"Ordinary",password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register $CV_HTTP_STATUS"; exit 1; }
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')"
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty' 2>/dev/null)
[ -n "$TOKEN" ] || { echo "setup failed: login $CV_HTTP_STATUS"; delete_user_email "$EMAIL"; exit 1; }

cv_step When "ordinary customer posts a new product" $LINENO
cv_http POST /products "$(jq -nc --arg s "$SKU" '{name:"Test",sku:$s,priceCents:100}')" -H "Authorization: Bearer $TOKEN"
CODE="$CV_HTTP_STATUS"
CNT=$(db_psql -tA -c "SELECT count(*) FROM products WHERE sku = '$SKU'" 2>/dev/null || echo "?")

cv_step Then "decide whether catalog modification was authorized for a regular customer" $LINENO
delete_product_sku "$SKU"
delete_user_email "$EMAIL"
if [ "$CODE" = "201" ]; then
  printf 'CV_SECURITY|vulnerable|access|serious|No per-user authorization checks on catalog modification|regular customer POST /products returned 201 and product rows=%s\n' "$CNT"
else
  printf 'CV_SECURITY|secure|access|serious|No per-user authorization checks on catalog modification|regular customer POST /products returned %s product rows=%s\n' "$CODE" "$CNT"
fi
exit 0
