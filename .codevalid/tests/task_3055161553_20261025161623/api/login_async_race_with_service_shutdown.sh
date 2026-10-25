#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer exists and a sign-in token is obtained just before shutdown" $LINENO
SUF=$(cv_suffix)
EMAIL="login-race-${SUF}@example.test"
PASS="Pw-race-${SUF}"
SKU="LR-${SUF}"
register_user "$EMAIL" "Race Customer" "$PASS" $LINENO
login_user "$EMAIL" "$PASS" $LINENO
TMPD=$(mktemp -d)
echo "$AUTH_TOKEN" > "$TMPD/token.pre"
LOGIN_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')

# When
cv_step When "fire sign-in requests while the service is restarted" $LINENO
for i in 1 2 3 4 5; do
  ( command curl -sS -m 15 -X POST -H 'Content-Type: application/json' --data "$LOGIN_BODY" \
      -o "$TMPD/body.$i" -w '%{http_code}' "$BASE_URL/auth/login" > "$TMPD/code.$i" 2>/dev/null ) &
done
command curl -s -m 5 "$APP_RESTART_URL" >/dev/null 2>&1 || true
wait
sleep 1
wait_app_healthy 60 || cv_fail "app did not come back after restart" $LINENO

# Then
cv_step Then "no token issued around the shutdown is usable after restart" $LINENO
TOKENS=("$(cat "$TMPD/token.pre")")
for i in 1 2 3 4 5; do
  CODE=$(cat "$TMPD/code.$i" 2>/dev/null); CODE=${CODE:-000}; BODY=$(cat "$TMPD/body.$i" 2>/dev/null || true)
  echo "race login $i -> $CODE $BODY"
  case "$BODY" in *"$PASS"*) cv_fail "expected no password in race login body $i" $LINENO ;; esac
  T=$(printf '%s' "$BODY" | jq -r '.token // empty' 2>/dev/null || true)
  [ -n "$T" ] && TOKENS+=("$T")
done
n=0
for T in "${TOKENS[@]}"; do
  n=$((n+1))
  PB=$(jq -nc --arg s "$SKU-$n" '{name:"Race item",sku:$s,priceCents:1}')
  cv_http POST /products "$PB" -H "Authorization: Bearer $T"
  [ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for pre-restart session $n after restart got $CV_HTTP_STATUS" $LINENO
done

# Cleanup
cv_step Cleanup "remove products, user and temp files" $LINENO
delete_products_like "$SKU-%"
delete_user_email "$EMAIL"
rm -rf "$TMPD"
echo "CODEVALID_TEST_ASSERTION_OK:login_async_race_with_service_shutdown"
