#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "a new email and a distinctive password" $LINENO
SFX=$(cv_suffix)
EMAIL="privacy.${SFX}@example.test"
PASSWORD="Privacy-Secret-${SFX}"

# When
cv_step When "POST /auth/register" $LINENO
register_request "$EMAIL" "Privacy User" "$PASSWORD"

# Then
cv_step Then "201 and the body has no password, hash or salt" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
case "$CV_HTTP_BODY" in *"$PASSWORD"*) cv_fail "expected plaintext password absent from response got it present" $LINENO ;; esac
LEAK=$(printf '%s' "$CV_HTTP_BODY" | jq -r '[paths | map(tostring) | join(".") | select(test("pass|hash|salt"; "i"))] | join(",")')
[ -z "$LEAK" ] || cv_fail "expected no password-related fields got: $LEAK" $LINENO
KEYS=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user | keys | sort | join(",")')
[ "$KEYS" = "email,id,name" ] || cv_fail "expected user keys email,id,name got $KEYS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:register_password_privacy_in_response"
