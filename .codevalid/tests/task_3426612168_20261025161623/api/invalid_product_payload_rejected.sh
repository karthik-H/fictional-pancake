#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a signed-in user and a set of invalid product payloads" $LINENO
signed_in_user invalid $LINENO
SFX=$(cv_suffix)
cv_http GET /products 200 -H "Authorization: Bearer $TOKEN"
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
PAYLOADS=(
  "$(jq -nc --arg s "CV-INV1-$SFX" '{name:"Str price",description:"d",sku:$s,priceCents:"abc"}')"
  "$(jq -nc --arg s "CV-INV2-$SFX" '{name:"Neg price",description:"d",sku:$s,priceCents:-100}')"
  "$(jq -nc --arg s "CV-INV3-$SFX" '{description:"d",sku:$s,priceCents:100}')"
  "$(jq -nc '{name:"No sku",description:"d",priceCents:100}')"
  "$(jq -nc --arg s "CV-INV5-$SFX" '{name:"No price",description:"d",sku:$s}')"
)
SKUS=("CV-INV1-$SFX" "CV-INV2-$SFX" "CV-INV3-$SFX" "CV-INV5-$SFX")

# When
cv_step When "POST /products with non-numeric price, negative price, missing name, missing sku, missing price" $LINENO
STATUSES=()
for p in "${PAYLOADS[@]}"; do
  cv_http POST /products "$p" -H "Authorization: Bearer $TOKEN"
  STATUSES+=("$CV_HTTP_STATUS:$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty' 2>/dev/null)")
done

# Then
cv_step Then "each request is rejected with 400 and an error, and the catalog is unchanged" $LINENO
for s in "${STATUSES[@]}"; do
  [ "${s%%:*}" = "400" ] || cv_fail "expected 400 got ${s%%:*}" $LINENO
  [ -n "${s#*:}" ] || cv_fail "expected validation error message got none" $LINENO
done
cv_http GET /products 200 -H "Authorization: Bearer $TOKEN"
AFTER=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
for sku in "${SKUS[@]}"; do
  if printf '%s' "$CV_HTTP_BODY" | jq -e --arg s "$sku" '.products | any(.sku == $s)' >/dev/null; then cv_fail "expected sku $sku absent got present" $LINENO; fi
done
if printf '%s' "$CV_HTTP_BODY" | jq -e '.products | any(.name == "No sku")' >/dev/null; then cv_fail "expected product 'No sku' absent got present" $LINENO; fi
echo "catalog size before=$BEFORE after=$AFTER"

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:invalid_product_payload_rejected"
