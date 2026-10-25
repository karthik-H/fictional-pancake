#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "signed-in customer who created a product, then a service restart" $LINENO
SFX=$(cv_suffix)
EMAIL="restart.sess.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
register_user "$EMAIL" "Restart Session" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO
cv_http POST /products "$(product_body "Pre restart" "CV-PRE-${SFX}" 100)" 201 -H "Authorization: Bearer $TOKEN"
cv_prereq "restart the service" $LINENO
restart_app || cv_fail "expected service restart to complete got no healthy app" $LINENO

# When
cv_step When "POST /products again with the pre-restart token" $LINENO
cv_http POST /products "$(product_body "Post restart" "CV-POST-${SFX}" 100)" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "the request is rejected because the session/account is no longer retained" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 after restart got $CV_HTTP_STATUS" $LINENO
if catalog_has_sku "CV-POST-${SFX}"; then cv_fail "expected post-restart sku absent got present" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:session_invalid_after_service_restart"
