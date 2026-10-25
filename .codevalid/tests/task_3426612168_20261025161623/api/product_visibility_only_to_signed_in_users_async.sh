#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a product added by a signed-in user" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-A" $LINENO
cv_http POST /products "$(product_json "Members Only" "${SKU_PREFIX}-A" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "unauthenticated and signed-in clients read the catalog" $LINENO
cv_http GET /products
ANON_ST="$CV_HTTP_STATUS"; ANON_BODY="$CV_HTTP_BODY"
cv_http GET /products "" -H "Authorization: Bearer $AUTH_TOKEN"
AUTH_ST="$CV_HTTP_STATUS"; AUTH_BODY="$CV_HTTP_BODY"

# Then
cv_step Then "anonymous client sees nothing, signed-in user sees the product" $LINENO
case "$ANON_ST" in 2??) cv_fail "expected unauthenticated catalog read rejected got $ANON_ST" $LINENO ;; esac
if printf '%s' "$ANON_BODY" | grep -q -e "$PID" -e '"products"'; then cv_fail "expected no catalog contents for anonymous got $ANON_BODY" $LINENO; fi
[ "$AUTH_ST" = "200" ] || cv_fail "expected 200 for signed-in user got $AUTH_ST" $LINENO
C=$(printf '%s' "$AUTH_BODY" | jq --arg id "$PID" '[.products[] | select(.id == $id)] | length')
[ "$C" = "1" ] || cv_fail "expected product visible to signed-in user got count $C" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:product_visibility_only_to_signed_in_users_async"
