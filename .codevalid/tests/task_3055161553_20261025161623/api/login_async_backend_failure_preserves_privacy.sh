#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer exists and the users store is made to error" $LINENO
SUF=$(cv_suffix)
EMAIL="login-bf-${SUF}@example.test"
PASS="Pw-bf-${SUF}"
SKU="LB-${SUF}"
register_user "$EMAIL" "Backend Failure Customer" "$PASS" $LINENO
BAK="users_cvbak_${SUF}"
restore() { db_psql -q -c "ALTER TABLE IF EXISTS $BAK RENAME TO users" >/dev/null 2>&1 || true; }
trap restore EXIT
cv_prereq "rename users table so the auth store query throws" $LINENO
db_psql -q -c "ALTER TABLE users RENAME TO $BAK" || cv_fail "could not break the users store for the test" $LINENO

# When
cv_step When "customer signs in while the auth store is unavailable" $LINENO
LOGIN_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')
cv_http POST /auth/login "$LOGIN_BODY" -m 20
CODE="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "login fails with a generic server error, no token, no password, no internals" $LINENO
case "$CODE" in 5??) ;; *) cv_fail "expected 5xx error response during backend failure got $CODE" $LINENO ;; esac
case "$BODY" in *"$PASS"*) cv_fail "expected no password in error body" $LINENO ;; esac
case "$BODY" in *token*) cv_fail "expected no token in error body got $BODY" $LINENO ;; esac
if printf '%s' "$BODY" | grep -Eiq 'ECONNREFUSED|ECONNRESET|toxiproxy|5432|at [A-Za-z0-9_.<>]+ \(|/app/|node_modules|password_hash'; then
  cv_fail "expected no internal exception details got: $BODY" $LINENO
fi
restore
wait_app_healthy 30 || cv_fail "app not healthy after users store restored" $LINENO
PB=$(jq -nc --arg s "$SKU" '{name:"Should not exist",sku:$s,priceCents:1}')
cv_http POST /products "$PB" 401
EXISTS=$(db_psql -tA -c "SELECT count(*) FROM products WHERE sku = '$SKU'")
[ "$EXISTS" = "0" ] || cv_fail "expected no product created without access got $EXISTS" $LINENO

# Cleanup
cv_step Cleanup "restore users store and remove the user" $LINENO
restore
delete_product_sku "$SKU"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:login_async_backend_failure_preserves_privacy"
