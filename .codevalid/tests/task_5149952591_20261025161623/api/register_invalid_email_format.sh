#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "a malformed email with no @ and a valid password" $LINENO
SFX=$(cv_suffix)
BAD_EMAIL="bad.email.${SFX}.example.test"
PASSWORD="Valid-Pass-${SFX}"

# When
cv_step When "POST /auth/register with the malformed email" $LINENO
register_request "$BAD_EMAIL" "Bad Email" "$PASSWORD"

# Then
cv_step Then "400 validation error and no account is created" $LINENO
[ "$CV_HTTP_STATUS" = "400" ] || cv_fail "expected 400 for malformed email got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
[ -n "$ERR" ] || cv_fail "expected an error message got none" $LINENO
login_request "$BAD_EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected no account (login 401) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:register_invalid_email_format"
