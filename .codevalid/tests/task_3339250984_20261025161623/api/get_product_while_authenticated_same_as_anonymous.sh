#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a signed-in user (valid token) and a unique product" $LINENO
cv_seed_product

# When
cv_step When "GET /products/{id} anonymously and with the valid bearer token" $LINENO
cv_http GET "/products/$CV_PRODUCT_ID"
anon_status=$CV_HTTP_STATUS
anon=$(printf '%s' "$CV_HTTP_BODY" | jq -S -c '.')
cv_http GET "/products/$CV_PRODUCT_ID" "" -H "Authorization: Bearer $CV_TOKEN"

# Then
cv_step Then "both 200 with identical product details" $LINENO
[ "$anon_status" = "200" ] || cv_fail "expected anonymous 200 got $anon_status" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected authenticated 200 got $CV_HTTP_STATUS" $LINENO
authd=$(printf '%s' "$CV_HTTP_BODY" | jq -S -c '.')
[ "$(printf '%s' "$authd" | jq -r '.product.id')" = "$CV_PRODUCT_ID" ] || cv_fail "expected product id $CV_PRODUCT_ID got $authd" $LINENO
[ "$authd" = "$anon" ] || cv_fail "expected identical bodies; anon=$anon auth=$authd" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:get_product_while_authenticated_same_as_anonymous"
