#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a signed-in user adds products and sees them in the catalog" $LINENO
signed_in_user life $LINENO
SFX=$(cv_suffix)
SKU1="CV-LIFE1-$SFX"; SKU2="CV-LIFE2-$SFX"
for s in "$SKU1" "$SKU2"; do
  cv_http POST /products "$(product_body "Lifecycle $s" "$s" 700)" -H "Authorization: Bearer $TOKEN"
  [ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected create 201 got $CV_HTTP_STATUS" $LINENO
  sku_count "$s" -H "Authorization: Bearer $TOKEN"
  [ "$SKU_COUNT" = "1" ] || cv_fail "expected $s in catalog before restart got $SKU_COUNT" $LINENO
done

# When
cv_step When "restart the service, sign in again, and read the catalog" $LINENO
restart_app || cv_fail "expected service restart to complete got no healthy app" $LINENO
signed_in_user life2 $LINENO
cv_http GET /products 200 -H "Authorization: Bearer $TOKEN"
LIST=$CV_HTTP_BODY

# Then
cv_step Then "previously added products are gone and the same code can be added fresh" $LINENO
for s in "$SKU1" "$SKU2"; do
  if printf '%s' "$LIST" | jq -e --arg s "$s" '.products | any(.sku == $s)' >/dev/null; then cv_fail "expected $s absent after restart got present" $LINENO; fi
done
cv_http POST /products "$(product_body "Fresh" "$SKU1" 700)" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected re-adding $SKU1 after restart 201 got $CV_HTTP_STATUS" $LINENO
sku_count "$SKU1" -H "Authorization: Bearer $TOKEN"
[ "$SKU_COUNT" = "1" ] || cv_fail "expected exactly 1 $SKU1 after re-add got $SKU_COUNT" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:product_ephemeral_across_service_restart"
