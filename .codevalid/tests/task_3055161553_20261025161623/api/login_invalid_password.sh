#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer" $LINENO
SFX=$(cv_suffix)
EMAIL="login.badpw.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
SKU="CV-BADPW-${SFX}"
register_user "$EMAIL" "Bad Password" "$PASSWORD" $LINENO

# When
cv_step When "sign in with the registered email and a wrong password" $LINENO
login_request "$EMAIL" "Wrong-${SFX}"

# Then
cv_step Then "login is rejected with 401, no token, and catalog changes stay denied" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 from login got $CV_HTTP_STATUS" $LINENO
TOK=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -z "$TOK" ] || cv_fail "expected no token on failed login got one" $LINENO
cv_http POST /products "$(product_body "Bad pw" "$SKU" 900)"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for POST /products without session got $CV_HTTP_STATUS" $LINENO
if catalog_has_sku "$SKU"; then cv_fail "expected sku $SKU absent from catalog got present" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:login_invalid_password"
