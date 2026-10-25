#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a product exists and the anonymous catalog response is captured" $LINENO
cv_seed_product
cv_http GET /products 200
anon=$(printf '%s' "$CV_HTTP_BODY" | jq -S -c '.')

# When
cv_step When "GET /products with an invalid bearer token" $LINENO
cv_http GET /products "" -H "Authorization: Bearer invalid.token-$CV_SUFFIX"

# Then
cv_step Then "200 with the same product data as anonymous" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
got=$(printf '%s' "$CV_HTTP_BODY" | jq -S -c '.')
printf '%s' "$got" | jq -e --arg id "$CV_PRODUCT_ID" 'any(.products[]; .id == $id)' >/dev/null || cv_fail "expected product $CV_PRODUCT_ID in list" $LINENO
[ "$got" = "$anon" ] || cv_fail "expected same body as anonymous got different" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_ignores_invalid_auth_header"
