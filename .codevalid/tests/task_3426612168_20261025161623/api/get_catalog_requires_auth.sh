#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "catalog containing a product added by a signed-in user" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-A" $LINENO
cv_http POST /products "$(product_json "Hidden Catalog Item" "${SKU_PREFIX}-A" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "unauthenticated client requests GET /products" $LINENO
cv_http GET /products

# Then
cv_step Then "request rejected with 401/403 and no catalog data exposed" $LINENO
case "$CV_HTTP_STATUS" in 401|403) ;; *) cv_fail "expected 401 or 403 for unauthenticated GET /products got $CV_HTTP_STATUS" $LINENO ;; esac
if printf '%s' "$CV_HTTP_BODY" | grep -q "${SKU_PREFIX}-A"; then cv_fail "expected no catalog data in response got $CV_HTTP_BODY" $LINENO; fi

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:get_catalog_requires_auth"
