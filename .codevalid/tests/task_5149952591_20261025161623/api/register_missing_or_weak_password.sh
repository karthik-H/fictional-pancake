#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "an unused email for each bad-password variant" $LINENO
SFX=$(cv_suffix)
E1="nopw.${SFX}@example.test"
E2="emptypw.${SFX}@example.test"
E3="shortpw.${SFX}@example.test"

# When
cv_step When "register with missing, empty and too-short (7 chars) passwords" $LINENO
cv_http POST /auth/register "$(jq -nc --arg e "$E1" '{email:$e,name:"No Pw"}')"
S1=$CV_HTTP_STATUS
register_request "$E2" "Empty Pw" ""
S2=$CV_HTTP_STATUS
register_request "$E3" "Short Pw" "Ab1-xyz"
S3=$CV_HTTP_STATUS

# Then
cv_step Then "each request is rejected with 400 and no account exists" $LINENO
[ "$S1" = "400" ] || cv_fail "expected 400 for missing password got $S1" $LINENO
[ "$S2" = "400" ] || cv_fail "expected 400 for empty password got $S2" $LINENO
[ "$S3" = "400" ] || cv_fail "expected 400 for 7-char password got $S3" $LINENO
login_request "$E3" "Ab1-xyz"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected no account for short password (login 401) got $CV_HTTP_STATUS" $LINENO
register_user "$E1" "No Pw" "Valid-Pass-${SFX}" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:register_missing_or_weak_password"
