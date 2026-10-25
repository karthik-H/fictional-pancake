#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer and a catalog change that is refused before sign-in" $LINENO
SFX=$(cv_suffix)
EMAIL="login.ok.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
SKU="CV-LOGIN-OK-${SFX}"
register_user "$EMAIL" "Login Ok" "$PASSWORD" $LINENO
cv_prereq "catalog change without sign-in is refused" $LINENO
cv_http POST /products "$(product_body "Before sign-in" "$SKU" 1500)"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for POST /products before sign-in got $CV_HTTP_STATUS" $LINENO

# When
cv_step When "sign in with valid email and password" $LINENO
login_request "$EMAIL" "$PASSWORD"

# Then
cv_step Then "login returns token and user, and the token unlocks catalog changes" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from login got $CV_HTTP_STATUS" $LINENO
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || cv_fail "expected non-empty token got none" $LINENO
GOT_EMAIL=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.email // empty')
[ "$GOT_EMAIL" = "$EMAIL" ] || cv_fail "expected user.email $EMAIL got $GOT_EMAIL" $LINENO
GOT_ID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.user.id // empty')
[ "$GOT_ID" = "$USER_ID" ] || cv_fail "expected user.id $USER_ID got $GOT_ID" $LINENO
cv_http POST /products "$(product_body "After sign-in" "$SKU" 1500)" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 for POST /products after sign-in got $CV_HTTP_STATUS" $LINENO
GOT_SKU=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.sku // empty')
[ "$GOT_SKU" = "$SKU" ] || cv_fail "expected product.sku $SKU got $GOT_SKU" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:login_happy_path_valid_credentials"
