#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer exists and catalog change is refused before sign-in" $LINENO
SUF=$(cv_suffix)
EMAIL="login-happy-${SUF}@example.test"
PASS="Pw-happy-${SUF}"
SKU="LH-${SUF}"
register_user "$EMAIL" "Happy Customer" "$PASS" $LINENO
USER_ID="$REG_USER_ID"
PRODUCT_BODY=$(jq -nc --arg s "$SKU" '{name:"Login happy item",description:"made after sign-in",sku:$s,priceCents:1500}')
cv_prereq "POST /products without sign-in is rejected" $LINENO
cv_http POST /products "$PRODUCT_BODY"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 before sign-in got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "customer signs in with valid email and password" $LINENO
LOGIN_BODY=$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')
cv_http POST /auth/login "$LOGIN_BODY"
LOGIN_STATUS="$CV_HTTP_STATUS"
LOGIN_RESP="$CV_HTTP_BODY"

# Then
cv_step Then "login returns a token and public user, token unlocks catalog changes" $LINENO
[ "$LOGIN_STATUS" = "200" ] || cv_fail "expected 200 from login got $LOGIN_STATUS" $LINENO
TOKEN=$(printf '%s' "$LOGIN_RESP" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected a token in login response got none" $LINENO
[ "$(printf '%s' "$LOGIN_RESP" | jq -r '.user.id')" = "$USER_ID" ] || cv_fail "expected user.id $USER_ID in login response" $LINENO
[ "$(printf '%s' "$LOGIN_RESP" | jq -r '.user.email')" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL in login response" $LINENO
case "$LOGIN_RESP" in *"$PASS"*) cv_fail "expected no password in login response got it echoed" $LINENO ;; esac
printf '%s' "$LOGIN_RESP" | jq -e '.user | has("password") or has("passwordHash") or has("password_hash")' >/dev/null && cv_fail "expected no password fields on user got some" $LINENO
cv_http POST /products "$PRODUCT_BODY" 201 -H "Authorization: Bearer $TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id in create response" $LINENO
cv_http GET "/products/$PID" 200
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.sku')" = "$SKU" ] || cv_fail "expected product sku $SKU in catalog" $LINENO

# Cleanup
cv_step Cleanup "remove created product and user" $LINENO
delete_product_sku "$SKU"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:login_async_happy_path_valid_credentials"
