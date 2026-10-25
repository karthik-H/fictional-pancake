#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer who has signed in once" $LINENO
SFX=$(cv_suffix)
EMAIL="restart.acct.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
register_user "$EMAIL" "Restart Account" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO
cv_prereq "restart the service" $LINENO
restart_app || cv_fail "expected service restart to complete got no healthy app" $LINENO

# When
cv_step When "sign in again with the same credentials after restart" $LINENO
login_request "$EMAIL" "$PASSWORD"

# Then
cv_step Then "sign-in fails because the account is gone, and works after re-registration" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 after restart got $CV_HTTP_STATUS" $LINENO
register_user "$EMAIL" "Restart Account" "$PASSWORD" $LINENO
login_request "$EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 after re-registration got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:account_info_after_service_restart"
