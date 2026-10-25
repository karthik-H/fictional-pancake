#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a well-formed UUID that matches no product" $LINENO
MISSING=$(psql -qtA -c "SELECT gen_random_uuid()")
[ -n "$MISSING" ] || cv_fail "expected generated uuid got empty" $LINENO
CNT=$(psql -qtA -v id="$MISSING" <<'SQL'
SELECT count(*) FROM products WHERE id = :'id';
SQL
)
[ "$CNT" = "0" ] || cv_fail "expected uuid unused got $CNT rows" $LINENO

# When
cv_step When "anonymous client fetches GET /products/{missing id}" $LINENO
cv_http GET "/products/$MISSING"

# Then
cv_step Then "response is 404 not found" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.error | type=="string"' >/dev/null || cv_fail "expected error message got $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e 'has("product") | not' >/dev/null || cv_fail "expected no product in body got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing was created" $LINENO
echo "CODEVALID_TEST_ASSERTION_OK:get_nonexistent_product_async_not_found"
