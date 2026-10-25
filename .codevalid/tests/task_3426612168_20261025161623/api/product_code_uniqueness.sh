#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a signed-in user who already added a product with a unique code" $LINENO
signed_in_user dup $LINENO
SKU="CV-DUP-$(cv_suffix)"
cv_http POST /products "$(product_body "Original" "$SKU" 1200 "Original description")" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected first create 201 got $CV_HTTP_STATUS" $LINENO
ORIG_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$ORIG_ID" ] || cv_fail "expected product.id from first create got none" $LINENO

# When
cv_step When "POST /products again with the same product code" $LINENO
cv_http POST /products "$(product_body "Duplicate" "$SKU" 3400 "Other description")" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "second request fails (409) and the catalog keeps only the original product" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 for duplicate sku got $CV_HTTP_STATUS" $LINENO
sku_count "$SKU" -H "Authorization: Bearer $TOKEN"
[ "$SKU_COUNT" = "1" ] || cv_fail "expected exactly 1 product with sku $SKU got $SKU_COUNT" $LINENO
cv_http GET "/products/$ORIG_ID" 200 -H "Authorization: Bearer $TOKEN"
N=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.name'); P=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.priceCents')
[ "$N" = "Original" ] && [ "$P" = "1200" ] || cv_fail "expected original product unchanged (Original/1200) got $N/$P" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:product_code_uniqueness"
