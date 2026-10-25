#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "signed-in customer creates a product, then the service restarts" $LINENO
SFX=$(cv_suffix)
EMAIL="restart.clear.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
SKU1="CV-RS1-${SFX}"
SKU2="CV-RS2-${SFX}"
register_user "$EMAIL" "Restart Clear" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO
cv_http POST /products "$(product_body "Before restart" "$SKU1" 100)" 201 -H "Authorization: Bearer $TOKEN"
cv_prereq "restart the service" $LINENO
restart_app || cv_fail "expected service restart to complete got no healthy app" $LINENO

# When
cv_step When "POST /products with the old token and no re-sign-in" $LINENO
cv_http POST /products "$(product_body "After restart" "$SKU2" 100)" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the request fails, the old account cannot sign in, and nothing is created" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 after restart without re-sign-in got $CV_HTTP_STATUS" $LINENO
if catalog_has_sku "$SKU2"; then cv_fail "expected $SKU2 absent got present" $LINENO; fi
login_request "$EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 login after restart (account not retained) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:service_restart_clears_sign_in_state"
