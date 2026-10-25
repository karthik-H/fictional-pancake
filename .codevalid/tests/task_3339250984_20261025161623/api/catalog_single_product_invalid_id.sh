#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a malformed product id (product ids are UUIDs)" $LINENO
cv_seed_product
bad="not-a-uuid-$CV_SUFFIX"

# When
cv_step When "anonymous GET /products/{malformed id}" $LINENO
cv_http GET "/products/$bad"

# Then
cv_step Then "400 validation error, not a lookup result" $LINENO
[ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 400 for malformed id got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.error | type == "string" and length > 0' >/dev/null || cv_fail "expected .error message got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_single_product_invalid_id"
