#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "no session and a snapshot of the catalog size" $LINENO
SFX=$(cv_suffix)
SKU="CV-UNAUTH-${SFX}"
cv_http GET /products 200
BEFORE=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | map(select(.sku == "'"$SKU"'")) | length')

# When
cv_step When "POST /products without authorization" $LINENO
cv_http POST /products "$(product_body "Anonymous" "$SKU" 100)"

# Then
cv_step Then "401 and the catalog does not contain the sku" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 got $CV_HTTP_STATUS" $LINENO
[ "$BEFORE" = "0" ] || cv_fail "expected sku absent before request got $BEFORE" $LINENO
if catalog_has_sku "$SKU"; then cv_fail "expected sku $SKU absent from catalog got present" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_post_products_rejected"
