#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

trap 'products_restore' EXIT
# Given
cv_step Given "product retrieval is made to fail at the database (products table temporarily hidden)" $LINENO
cv_http GET /products 200
products_hide || cv_fail "expected products table hidden got psql error" $LINENO

# When
cv_step When "anonymous client lists products while the database query fails" $LINENO
cv_http GET /products --max-time 30
STATUS="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "response is 5xx with a generic error and no internal details" $LINENO
case "$STATUS" in 5??) ;; *) cv_fail "expected 5xx got $STATUS" $LINENO ;; esac
if printf '%s' "$BODY" | grep -Eiq 'ECONNREFUSED|ECONNRESET|toxiproxy|postgres|5432|stack|relation|does not exist|products_cv_hidden|at [A-Za-z_.<>]+ \(|/app/|node_modules|SELECT|price_cents'; then
  cv_fail "expected generic error body got internal details: $(printf '%s' "$BODY" | head -c 200)" $LINENO
fi
printf '%s' "$BODY" | jq -e '.error | type=="string"' >/dev/null 2>&1 || cv_fail "expected JSON error message got $(printf '%s' "$BODY" | head -c 200)" $LINENO

# Cleanup
cv_step Cleanup "restore the products table and confirm recovery" $LINENO
products_restore
for i in 1 2 3 4 5 6 7 8 9 10; do
  cv_http GET /products --max-time 10
  [ "$CV_HTTP_STATUS" = "200" ] && break
  sleep 1
done
echo "CODEVALID_TEST_ASSERTION_OK:async_catalog_surface_server_error_safely"
