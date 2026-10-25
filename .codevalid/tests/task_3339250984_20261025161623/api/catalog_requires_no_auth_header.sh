#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a unique product exists in the catalog" $LINENO
cv_seed_product

# When
cv_step When "GET /products with no Authorization or Cookie header" $LINENO
cv_http GET /products "" -H "Authorization:" -H "Cookie:"

# Then
cv_step Then "200 with product data" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | length > 0' >/dev/null || cv_fail "expected non-empty .products got $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$CV_PRODUCT_ID" 'any(.products[]; .id == $id)' >/dev/null || cv_fail "expected product $CV_PRODUCT_ID in list" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_requires_no_auth_header"
