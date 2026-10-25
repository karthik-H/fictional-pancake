#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh
# The scrypt hash runs in-process and cannot be slowed from outside without changing app code,
# so the async account-creation step (hash + persist) is made excessively slow at the store boundary.

# Given
cv_step Given "the async account-creation step for this email is excessively slow" $LINENO
SUF=$(cv_suffix)
EMAIL="reg-to-${SUF}@example.test"
PASS="Pw-to-${SUF}-secret"
TAG="to_${SUF}"
trap 'drop_insert_trigger "$TAG"' EXIT
cv_prereq "install a users insert trigger that stalls 20s for $EMAIL only" $LINENO
add_insert_trigger "$TAG" "$EMAIL" "PERFORM pg_sleep(20); RETURN NEW;" \
  || cv_fail "could not install slow-create trigger" $LINENO

# When
cv_step When "customer registers and the client waits at most 12s" $LINENO
cv_http POST /auth/register "$(reg_body "$EMAIL" "Slow Hash" "$PASS")" -m 12
CODE="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "request fails (timeout or error) and no account is created" $LINENO
case "$CODE" in 201|200) cv_fail "expected registration to fail under stalled async step got $CODE" $LINENO ;; esac
case "$BODY" in *"$PASS"*) cv_fail "expected no password in response" $LINENO ;; esac
echo "request ended with status $CODE; waiting for the stalled operation to settle"
sleep 12
COUNT=$(user_count "$EMAIL")
[ "$COUNT" = "0" ] || cv_fail "expected no account created after failed/timed-out registration got $COUNT" $LINENO

# Cleanup
cv_step Cleanup "remove trigger and any user" $LINENO
drop_insert_trigger "$TAG"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:register_async_password_hash_timeout"
