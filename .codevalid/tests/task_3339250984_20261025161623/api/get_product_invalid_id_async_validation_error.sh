#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a malformed product id that is not a UUID" $LINENO
BAD="not-a-uuid-$(cv_suffix)"

# When
cv_step When "anonymous client fetches GET /products/{malformed id}" $LINENO
cv_http GET "/products/$BAD"

# Then
cv_step Then "response is a validation/bad-request error (400 or 422)" $LINENO
case "$CV_HTTP_STATUS" in 400|422) ;; *) cv_fail "expected 400 or 422 validation error got $CV_HTTP_STATUS: $CV_HTTP_BODY" $LINENO ;; esac
printf '%s' "$CV_HTTP_BODY" | jq -e '.error | type=="string"' >/dev/null || cv_fail "expected error message got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:get_product_invalid_id_async_validation_error"
