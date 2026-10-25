#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer with a distinctive password" $LINENO
SFX=$(cv_suffix)
EMAIL="noleak.${SFX}@example.test"
PASSWORD="LeakPw-${SFX}-qq"
register_user "$EMAIL" "No Leak" "$PASSWORD" $LINENO
REG_BODY=$CV_HTTP_BODY

# When
cv_step When "failed login, successful login, authed and unauthed POST /products" $LINENO
login_request "$EMAIL" "Bad-${SFX}"
B1=$CV_HTTP_BODY; S1=$CV_HTTP_STATUS
login_request "$EMAIL" "$PASSWORD"
B2=$CV_HTTP_BODY; S2=$CV_HTTP_STATUS
TOKEN=$(printf '%s' "$B2" | jq -r '.token // empty')
cv_http POST /products "$(product_body "Leak check" "CV-LEAK-${SFX}" 100)" -H "Authorization: Bearer $TOKEN"
B3=$CV_HTTP_BODY; S3=$CV_HTTP_STATUS
cv_http POST /products "$(product_body "Leak check anon" "CV-LEAK2-${SFX}" 100)"
B4=$CV_HTTP_BODY; S4=$CV_HTTP_STATUS

# Then
cv_step Then "no response contains the password, a hash, or a password field" $LINENO
[ "$S1" = "401" ] || cv_fail "expected 401 wrong-password login got $S1" $LINENO
[ "$S2" = "200" ] || cv_fail "expected 200 login got $S2" $LINENO
[ "$S3" = "201" ] || cv_fail "expected 201 authed POST /products got $S3" $LINENO
[ "$S4" = "401" ] || cv_fail "expected 401 anonymous POST /products got $S4" $LINENO
for B in "$REG_BODY" "$B1" "$B2" "$B3" "$B4"; do
  if body_leaks_password "$B" "$PASSWORD"; then cv_fail "expected no password data in response got $B" $LINENO; fi
done

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:password_not_exposed_in_api_responses"
