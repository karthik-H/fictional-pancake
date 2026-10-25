#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a registered, signed-in user and a unique product code" $LINENO
signed_in_user happy $LINENO
SKU="CV-HAPPY-$(cv_suffix)"
BODY=$(product_body "Happy mug" "$SKU" 1999 "Speckled glaze mug")

# When
cv_step When "POST /products with name, description, priceCents and unique sku" $LINENO
cv_http POST /products "$BODY" -H "Authorization: Bearer $TOKEN"
CREATE_STATUS=$CV_HTTP_STATUS
CREATE_BODY=$CV_HTTP_BODY

# Then
cv_step Then "201 with the product, and the product is in the catalog for the signed-in user" $LINENO
[ "$CREATE_STATUS" = "201" ] || cv_fail "expected 201 got $CREATE_STATUS" $LINENO
PID=$(printf '%s' "$CREATE_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id in response got none" $LINENO
for f in name:"Happy mug" description:"Speckled glaze mug" sku:"$SKU"; do
  k=${f%%:*}; v=${f#*:}
  got=$(printf '%s' "$CREATE_BODY" | jq -r --arg k "$k" '.product[$k] // empty')
  [ "$got" = "$v" ] || cv_fail "expected product.$k=$v got $got" $LINENO
done
got=$(printf '%s' "$CREATE_BODY" | jq -r '.product.priceCents')
[ "$got" = "1999" ] || cv_fail "expected product.priceCents=1999 got $got" $LINENO
sku_count "$SKU" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected GET /products 200 got $CV_HTTP_STATUS" $LINENO
[ "$SKU_COUNT" = "1" ] || cv_fail "expected 1 catalog entry with sku $SKU got $SKU_COUNT" $LINENO
cv_http GET "/products/$PID" 200 -H "Authorization: Bearer $TOKEN"
got=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.sku // empty')
[ "$got" = "$SKU" ] || cv_fail "expected GET /products/$PID sku $SKU got $got" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:add_product_happy_path_post_requireauth"
