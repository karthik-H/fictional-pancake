#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer exists" $LINENO
SUF=$(cv_suffix)
EMAIL="login-conc-${SUF}@example.test"
PASS="Pw-conc-${SUF}"
register_user "$EMAIL" "Concurrent Customer" "$PASS" $LINENO
USER_ID="$REG_USER_ID"
TMPD=$(mktemp -d)
N=6
LOGIN_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')

# When
cv_step When "send $N concurrent sign-in requests for the same account" $LINENO
for i in $(seq 1 $N); do
  ( command curl -sS -X POST -H 'Content-Type: application/json' --data "$LOGIN_BODY" \
      -o "$TMPD/body.$i" -w '%{http_code}' "$BASE_URL/auth/login" > "$TMPD/code.$i" 2>/dev/null ) &
done
wait

# Then
cv_step Then "every sign-in succeeds with a usable token for the same user and no password" $LINENO
for i in $(seq 1 $N); do
  CODE=$(cat "$TMPD/code.$i" 2>/dev/null); CODE=${CODE:-000}
  BODY=$(cat "$TMPD/body.$i" 2>/dev/null || true)
  cv_http POST "$BASE_URL/auth/login" "$CODE" 0
  echo "RESPONSE_BODY:"; echo "$BODY"
  [ "$CODE" = "200" ] || cv_fail "expected 200 for concurrent login $i got $CODE" $LINENO
  case "$BODY" in *"$PASS"*) cv_fail "expected no password in login response $i" $LINENO ;; esac
  [ "$(printf '%s' "$BODY" | jq -r '.user.id')" = "$USER_ID" ] || cv_fail "expected user.id $USER_ID in response $i" $LINENO
  T=$(printf '%s' "$BODY" | jq -r '.token // empty')
  [ -n "$T" ] || cv_fail "expected token in response $i" $LINENO
  SKU="LC-${SUF}-$i"
  PB=$(jq -nc --arg s "$SKU" '{name:"Concurrent item",sku:$s,priceCents:100}')
  cv_http POST /products "$PB" 201 -H "Authorization: Bearer $T"
done
COUNT=$(db_psql -tA -c "SELECT count(*) FROM users WHERE email = '$EMAIL'")
[ "$COUNT" = "1" ] || cv_fail "expected exactly 1 account row after concurrent logins got $COUNT" $LINENO

# Cleanup
cv_step Cleanup "remove products, user and temp files" $LINENO
delete_products_like "LC-${SUF}-%"
delete_user_email "$EMAIL"
rm -rf "$TMPD"
echo "CODEVALID_TEST_ASSERTION_OK:login_async_concurrent_sign_ins_same_account"
