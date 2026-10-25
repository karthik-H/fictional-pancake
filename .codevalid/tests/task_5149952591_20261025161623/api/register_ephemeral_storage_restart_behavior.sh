#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "a registered account, then the service is restarted" $LINENO
SFX=$(cv_suffix)
EMAIL="ephemeral.${SFX}@example.test"
PASSWORD="Ephemeral-Pass-${SFX}"
register_user "$EMAIL" "Ephemeral User" "$PASSWORD" $LINENO
cv_prereq "restart the service" $LINENO
restart_app || cv_fail "expected service restart to complete got no healthy app" $LINENO

# When
cv_step When "sign in and register again with the same email after restart" $LINENO
login_request "$EMAIL" "$PASSWORD"
LOGIN_STATUS=$CV_HTTP_STATUS
register_request "$EMAIL" "Ephemeral User" "$PASSWORD"

# Then
cv_step Then "old account is gone (login 401) and re-registration returns 201" $LINENO
[ "$LOGIN_STATUS" = "401" ] || cv_fail "expected login 401 after restart got $LOGIN_STATUS" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected re-registration 201 after restart got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:register_ephemeral_storage_restart_behavior"
