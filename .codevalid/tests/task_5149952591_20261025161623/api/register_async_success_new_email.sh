#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "a valid, unused email and a valid password" $LINENO
SUF=$(cv_suffix)
EMAIL="reg-ok-${SUF}@example.test"
NAME="Async Reg ${SUF}"
PASS="Pw-ok-${SUF}-secret"
[ "$(user_count "$EMAIL")" = "0" ] || cv_fail "expected email $EMAIL to be unused" $LINENO

# When
cv_step When "customer registers via POST /auth/register" $LINENO
cv_http POST /auth/register "$(reg_body "$EMAIL" "$NAME" "$PASS")"
CODE="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "201 with public user, no password exposed, account usable for sign-in" $LINENO
[ "$CODE" = "201" ] || cv_fail "expected 201 got $CODE: $BODY" $LINENO
UID_=$(printf '%s' "$BODY" | jq -r '.user.id // empty')
[ -n "$UID_" ] || cv_fail "expected user.id in response got $BODY" $LINENO
[ "$(printf '%s' "$BODY" | jq -r '.user.email')" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $BODY" $LINENO
[ "$(printf '%s' "$BODY" | jq -r '.user.name')" = "$NAME" ] || cv_fail "expected user.name $NAME got $BODY" $LINENO
case "$BODY" in *"$PASS"*) cv_fail "expected response not to contain the password" $LINENO ;; esac
printf '%s' "$BODY" | jq -e '.user | has("password") or has("passwordHash") or has("password_hash")' >/dev/null \
  && cv_fail "expected no password field in user got $BODY" $LINENO
[ "$(user_count "$EMAIL")" = "1" ] || cv_fail "expected exactly 1 stored account for $EMAIL" $LINENO
STORED=$(db_psql -tA -c "SELECT password_hash FROM users WHERE email = '$EMAIL'")
[ "$STORED" != "$PASS" ] || cv_fail "expected stored password to be hashed, got plaintext" $LINENO
case "$STORED" in *"$PASS"*) cv_fail "expected stored hash not to contain the plaintext password" $LINENO ;; esac
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected new account to sign in with 200 got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id')" = "$UID_" ] || cv_fail "expected login user.id $UID_ got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "remove the registered user" $LINENO
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:register_async_success_new_email"
