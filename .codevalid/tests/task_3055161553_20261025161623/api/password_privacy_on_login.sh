#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer with a distinctive password" $LINENO
SFX=$(cv_suffix)
EMAIL="privacy.${SFX}@example.test"
PASSWORD="PrivPw-${SFX}-zz"
register_user "$EMAIL" "Privacy" "$PASSWORD" $LINENO
if body_leaks_password "$CV_HTTP_BODY" "$PASSWORD"; then cv_fail "expected register response without password got it" $LINENO; fi

# When
cv_step When "sign in successfully and also with a wrong password" $LINENO
login_request "$EMAIL" "$PASSWORD"
OK_STATUS=$CV_HTTP_STATUS
OK_BODY=$CV_HTTP_BODY
BAD_PW="BadPw-${SFX}-yy"
login_request "$EMAIL" "$BAD_PW"
BAD_STATUS=$CV_HTTP_STATUS
BAD_BODY=$CV_HTTP_BODY

# Then
cv_step Then "neither response contains the password, a hash or a password field" $LINENO
[ "$OK_STATUS" = "200" ] || cv_fail "expected 200 from valid login got $OK_STATUS" $LINENO
[ "$BAD_STATUS" = "401" ] || cv_fail "expected 401 from wrong-password login got $BAD_STATUS" $LINENO
if body_leaks_password "$OK_BODY" "$PASSWORD"; then cv_fail "expected success login body without password/hash got $OK_BODY" $LINENO; fi
if body_leaks_password "$BAD_BODY" "$BAD_PW"; then cv_fail "expected failed login body without password got $BAD_BODY" $LINENO; fi
if printf '%s' "$BAD_BODY" | grep -qF -- "$PASSWORD"; then cv_fail "expected failed login body without real password got it" $LINENO; fi
KEYS=$(printf '%s' "$OK_BODY" | jq -c '.user | keys')
[ "$KEYS" = '["email","id","name"]' ] || cv_fail "expected user keys [email,id,name] got $KEYS" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:password_privacy_on_login"
