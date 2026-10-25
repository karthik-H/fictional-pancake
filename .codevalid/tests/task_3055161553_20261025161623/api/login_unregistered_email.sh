#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "an email that was never registered" $LINENO
SFX=$(cv_suffix)
EMAIL="nobody.${SFX}@example.test"
SKU="CV-UNREG-${SFX}"

# When
cv_step When "sign in with the unregistered email" $LINENO
login_request "$EMAIL" "Whatever-${SFX}"

# Then
cv_step Then "login is rejected with 401, no token, and catalog changes stay denied" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 from login got $CV_HTTP_STATUS" $LINENO
TOK=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -z "$TOK" ] || cv_fail "expected no token on failed login got one" $LINENO
cv_http POST /products "$(product_body "Unregistered" "$SKU" 900)"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 for POST /products without session got $CV_HTTP_STATUS" $LINENO
if catalog_has_sku "$SKU"; then cv_fail "expected sku $SKU absent from catalog got present" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:login_unregistered_email"
