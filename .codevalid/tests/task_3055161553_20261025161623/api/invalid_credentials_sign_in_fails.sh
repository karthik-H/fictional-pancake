#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer" $LINENO
SFX=$(cv_suffix)
EMAIL="wrongpw.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
SKU="CV-WRONGPW-${SFX}"
register_user "$EMAIL" "Wrong Pw" "$PASSWORD" $LINENO

# When
cv_step When "sign in with wrong password then POST /products without a valid session" $LINENO
login_request "$EMAIL" "Nope-${SFX}"
LOGIN_STATUS=$CV_HTTP_STATUS
TOK=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
cv_http POST /products "$(product_body "Wrong pw" "$SKU" 100)" -H "Authorization: Bearer ${TOK:-none}"

# Then
cv_step Then "sign-in fails with 401 and POST /products is rejected with 401" $LINENO
[ "$LOGIN_STATUS" = "401" ] || cv_fail "expected 401 from login got $LOGIN_STATUS" $LINENO
[ -z "$TOK" ] || cv_fail "expected no token from failed login got one" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 from POST /products got $CV_HTTP_STATUS" $LINENO
if catalog_has_sku "$SKU"; then cv_fail "expected sku $SKU absent from catalog got present" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:invalid_credentials_sign_in_fails"
