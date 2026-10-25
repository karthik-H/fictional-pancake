#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "a product payload with a unique sku and no sign-in" $LINENO
SUF=$(cv_suffix)
SKU="PU-${SUF}"
PB=$(jq -nc --arg s "$SKU" '{name:"Anon item",sku:$s,priceCents:500}')
cv_http GET /products 200
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')

# When
cv_step When "anonymous client posts products with no and non-bearer authorization" $LINENO
cv_http POST /products "$PB"
C1="$CV_HTTP_STATUS"
cv_http POST /products "$PB" -H "Authorization: Basic dXNlcjpwYXNz"
C2="$CV_HTTP_STATUS"

# Then
cv_step Then "requests are rejected with 401 and catalog is unchanged" $LINENO
[ "$C1" = "401" ] || cv_fail "expected 401 without auth got $C1" $LINENO
[ "$C2" = "401" ] || cv_fail "expected 401 with Basic auth got $C2" $LINENO
cv_http GET /products 200
AFTER=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
printf '%s' "$CV_HTTP_BODY" | jq -e --arg s "$SKU" 'any(.products[]; .sku==$s)' >/dev/null && cv_fail "expected sku $SKU absent from catalog" $LINENO
CNT=$(db_psql -tA -c "SELECT count(*) FROM products WHERE sku = '$SKU'")
[ "$CNT" = "0" ] || cv_fail "expected 0 product rows for $SKU got $CNT" $LINENO
echo "catalog size before=$BEFORE after=$AFTER"

# Cleanup
cv_step Cleanup "remove any product with the test sku" $LINENO
delete_product_sku "$SKU"
echo "CODEVALID_TEST_ASSERTION_OK:async_products_unauthenticated_rejected"
