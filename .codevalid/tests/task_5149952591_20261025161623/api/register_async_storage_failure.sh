#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "persisting an account for this email is made to fail" $LINENO
SUF=$(cv_suffix)
EMAIL="reg-sf-${SUF}@example.test"
PASS="Pw-sf-${SUF}-secret"
TAG="sf_${SUF}"
trap 'drop_insert_trigger "$TAG"' EXIT
cv_prereq "install a users insert trigger that raises for $EMAIL only" $LINENO
add_insert_trigger "$TAG" "$EMAIL" "RAISE EXCEPTION 'cv simulated storage failure';" \
  || cv_fail "could not install storage-failure trigger" $LINENO

# When
cv_step When "customer submits a valid registration while storage fails" $LINENO
cv_http POST /auth/register "$(reg_body "$EMAIL" "Storage Fail" "$PASS")" -m 20
CODE="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "5xx error, no password or internals leaked, no partial account" $LINENO
case "$CODE" in 5??) ;; *) cv_fail "expected 5xx on storage failure got $CODE: $BODY" $LINENO ;; esac
case "$BODY" in *"$PASS"*) cv_fail "expected error body not to contain the password" $LINENO ;; esac
if printf '%s' "$BODY" | grep -Eiq 'cv simulated|password_hash|INSERT INTO|node_modules|/app/'; then
  cv_fail "expected no internal error details got $BODY" $LINENO
fi
[ "$(user_count "$EMAIL")" = "0" ] || cv_fail "expected no account created for $EMAIL" $LINENO
drop_insert_trigger "$TAG"
cv_http POST /auth/register "$(reg_body "$EMAIL" "Storage Fail" "$PASS")"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 re-registering after recovery (no partial state) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove trigger and user" $LINENO
drop_insert_trigger "$TAG"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:register_async_storage_failure"
