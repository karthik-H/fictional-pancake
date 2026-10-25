#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "customer signs in; a unique password marker is known" $LINENO
SUF=$(cv_suffix)
EMAIL="prod-leak-${SUF}@example.test"
PASS="Pw-leak-${SUF}"
SKU="PL-${SUF}"
register_user "$EMAIL" "Leak Customer" "$PASS" $LINENO
login_user "$EMAIL" "$PASS" $LINENO
RESULTS=()

# When
cv_step When "exercise success, validation, conflict, unauthorized and malformed product calls" $LINENO
AH="Authorization: Bearer $AUTH_TOKEN"
cv_http POST /products "$(jq -nc --arg s "$SKU" '{name:"Leak item",sku:$s,priceCents:300}')" -H "$AH"
RESULTS+=("success|201|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /products "$(jq -nc --arg s "$SKU" '{name:"Leak item",sku:$s,priceCents:300}')" -H "$AH"
RESULTS+=("duplicate|409|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /products "$(jq -nc --arg p "$PASS" '{name:$p,priceCents:-1}')" -H "$AH"
RESULTS+=("validation|400|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /products '{"name":"broken",' -H "$AH"
RESULTS+=("malformed|ANY|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /products "$(jq -nc --arg s "$SKU-x" '{name:"x",sku:$s,priceCents:1}')" -H "Authorization: Bearer $PASS"
RESULTS+=("password-as-token|401|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http GET /products 200
RESULTS+=("catalog|200|$CV_HTTP_STATUS|$CV_HTTP_BODY")

# Then
cv_step Then "statuses are as expected and no body contains password, hash or stack trace" $LINENO
HASH=$(db_psql -tA -c "SELECT password_hash FROM users WHERE email = '$EMAIL'")
HASH_PART=${HASH#*:}; HASH_PART=${HASH_PART:0:24}
for r in "${RESULTS[@]}"; do
  NAME=${r%%|*}; R=${r#*|}; EXP=${R%%|*}; R=${R#*|}; CODE=${R%%|*}; BODY=${R#*|}
  [ "$EXP" = "ANY" ] || [ "$CODE" = "$EXP" ] || cv_fail "expected $EXP for $NAME got $CODE" $LINENO
  case "$BODY" in *"$PASS"*) cv_fail "expected no password in $NAME response" $LINENO ;; esac
  [ -n "$HASH_PART" ] && case "$BODY" in *"$HASH_PART"*) cv_fail "expected no password hash in $NAME response" $LINENO ;; esac
  if printf '%s' "$BODY" | grep -Eiq 'passwordHash|password_hash|at [A-Za-z0-9_.<>]+ \(|node_modules|/app/'; then
    cv_fail "expected no sensitive/internal data in $NAME got: $BODY" $LINENO
  fi
done

# Cleanup
cv_step Cleanup "remove product and user" $LINENO
delete_products_like "$SKU%"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:async_products_no_password_leak_in_async_flow"
