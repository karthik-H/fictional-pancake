#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a well-formed product id that is not in the catalog" $LINENO
missing=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || printf '00000000-0000-4000-8000-%012d' "$((RANDOM * RANDOM))")
cv_http GET /products 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$missing" 'any(.products[]; .id == $id) | not' >/dev/null || cv_fail "expected $missing to be absent from catalog" $LINENO

# When
cv_step When "anonymous GET /products/{missing id}" $LINENO
cv_http GET "/products/$missing"

# Then
cv_step Then "404 not-found with an error message" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.error | type == "string" and length > 0' >/dev/null || cv_fail "expected .error message got $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e 'has("product") | not' >/dev/null || cv_fail "expected no product in body got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_single_product_not_found"
