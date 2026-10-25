#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "an unused email, a name and a valid password" $LINENO
SFX=$(cv_suffix)
EMAIL="new.user.${SFX}@example.test"
PASSWORD="Valid-Pass-${SFX}"

# When
cv_step When "POST /auth/register with the new email" $LINENO
register_request "$EMAIL" "New User" "$PASSWORD"

# Then
cv_step Then "201 with the created public user, and the account can sign in" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ -n "$ID" ] || cv_fail "expected user.id in response got none" $LINENO
GOT_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $GOT_EMAIL" $LINENO
GOT_NAME=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.name // empty')
[ "$GOT_NAME" = "New User" ] || cv_fail "expected user.name 'New User' got $GOT_NAME" $LINENO
login_request "$EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected login of new account 200 got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:register_success_new_email"
