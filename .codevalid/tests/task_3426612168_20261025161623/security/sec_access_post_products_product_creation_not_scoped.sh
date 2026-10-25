#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

cv_step Given "two signed-in users A and B" $LINENO
SFX=$(cv_suffix)
TOKENS=()
for who in a b; do
  body=$(jq -nc --arg e "cv.sec.$who.$SFX@example.test" --arg p "Secret-$SFX" '{email:$e,name:"CV Sec",password:$p}')
  cv_http POST /auth/register "$body"
  [ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register $who got $CV_HTTP_STATUS"; exit 1; }
  body=$(jq -nc --arg e "cv.sec.$who.$SFX@example.test" --arg p "Secret-$SFX" '{email:$e,password:$p}')
  cv_http POST /auth/login "$body"
  t=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty' 2>/dev/null)
  [ -n "$t" ] || { echo "setup failed: login $who got $CV_HTTP_STATUS"; exit 1; }
  TOKENS+=("$t")
done
SKU="SKU-SEC-$SFX"

cv_step When "user A creates sku, user B creates the same sku" $LINENO
cv_http POST /products "$(product_body "A product" "$SKU" 100)" -H "Authorization: Bearer ${TOKENS[0]}"
A_STATUS=$CV_HTTP_STATUS
[ "$A_STATUS" = "201" ] || { echo "setup failed: user A create got $A_STATUS"; exit 1; }
cv_http POST /products "$(product_body "B product" "$SKU" 200)" -H "Authorization: Bearer ${TOKENS[1]}"
B_STATUS=$CV_HTTP_STATUS
B_ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty' 2>/dev/null | tr -d '|')
sku_count "$SKU" -H "Authorization: Bearer ${TOKENS[1]}"
B_SEES=$SKU_COUNT

cv_step Then "decide verdict" $LINENO
T="Product creation not scoped to user but catalog required to be user-specific"
if [ "$B_STATUS" = "409" ] || { [ "$B_SEES" != "0" ] && [ "$B_STATUS" != "201" ]; }; then
  printf 'CV_SECURITY|vulnerable|access|serious|%s|%s\n' "$T" "user A POST 201; user B POST same sku got $B_STATUS ($B_ERR); B sees $B_SEES product(s) with that sku in shared catalog"
else
  printf 'CV_SECURITY|secure|access|serious|%s|%s\n' "$T" "user A POST 201; user B POST same sku got $B_STATUS; catalogs independent"
fi
exit 0
