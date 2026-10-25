#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "an email that is already registered" $LINENO
SFX=$(cv_suffix)
EMAIL="dup.user.${SFX}@example.test"
register_user "$EMAIL" "First Owner" "First-Pass-${SFX}" $LINENO

# When
cv_step When "register again with the same email and a different password" $LINENO
register_request "$EMAIL" "Second Owner" "Other-Pass-${SFX}"

# Then
cv_step Then "409 conflict, and the original account keeps its password" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 for duplicate email got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.user' >/dev/null 2>&1 && cv_fail "expected no user object in duplicate response got one" $LINENO
login_request "$EMAIL" "Other-Pass-${SFX}"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected second password rejected (401) got $CV_HTTP_STATUS" $LINENO
login_request "$EMAIL" "First-Pass-${SFX}"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected original password still valid (200) got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:register_duplicate_email_rejected"
