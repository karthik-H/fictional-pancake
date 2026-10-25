#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a product retrievable by id in the current run" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-A" $LINENO
cv_http POST /products "$(product_json "Restart Item" "${SKU_PREFIX}-A" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO
cv_prereq "confirm product retrievable before restart" $LINENO
cv_http GET "/products/$PID" "" 200 -H "Authorization: Bearer $AUTH_TOKEN"

# When
cv_step When "service restarts and signed-in user requests the same id" $LINENO
restart_app 90 || cv_fail "expected app healthy after restart got not healthy" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token after restart got none" $LINENO
cv_http GET "/products/$PID" "" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "404 because the in-memory catalog was reset" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 after restart got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:get_product_after_service_restart_returns_not_found"
