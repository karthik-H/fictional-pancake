#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a fresh service run with no products added" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "restart the service" $LINENO
restart_app 90 || cv_fail "expected app healthy after restart got not healthy" $LINENO
cv_prereq "log in again after restart" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token after restart got none" $LINENO

# When
cv_step When "signed-in user requests GET /products" $LINENO
cv_http GET /products "" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "200 with an empty catalog" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
N=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length' 2>/dev/null || echo invalid)
[ "$N" = "0" ] || cv_fail "expected empty products array after restart got $N products" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:get_catalog_empty_for_new_service_run"
