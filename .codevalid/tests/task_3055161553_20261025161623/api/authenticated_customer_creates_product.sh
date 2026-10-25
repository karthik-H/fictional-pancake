#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered and signed-in customer" $LINENO
SFX=$(cv_suffix)
EMAIL="creator.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
SKU="CV-AUTH-CREATE-${SFX}"
register_user "$EMAIL" "Creator" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO

# When
cv_step When "POST /products with the bearer token" $LINENO
cv_http POST /products "$(product_body "Signed-in product" "$SKU" 2500)" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "201 with the product, catalog lists it, no password in response" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
P=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')
[ "$(printf '%s' "$P" | jq -r '.sku')" = "$SKU" ] || cv_fail "expected product.sku $SKU got $P" $LINENO
[ "$(printf '%s' "$P" | jq -r '.name')" = "Signed-in product" ] || cv_fail "expected name 'Signed-in product' got $P" $LINENO
[ "$(printf '%s' "$P" | jq -r '.priceCents')" = "2500" ] || cv_fail "expected priceCents 2500 got $P" $LINENO
PID=$(printf '%s' "$P" | jq -r '.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id got none" $LINENO
if body_leaks_password "$CV_HTTP_BODY" "$PASSWORD"; then cv_fail "expected no password in response got $CV_HTTP_BODY" $LINENO; fi
cv_http GET "/products/$PID" 200
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.sku')" = "$SKU" ] || cv_fail "expected GET /products/$PID sku $SKU got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:authenticated_customer_creates_product"
