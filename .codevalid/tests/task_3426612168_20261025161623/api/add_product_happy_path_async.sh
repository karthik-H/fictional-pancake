#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a signed-in user and a unique sku" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
SKU="${SKU_PREFIX}-A"

# When
cv_step When "user POSTs a valid product" $LINENO
cv_http POST /products "$(product_json "Async Widget" "$SKU" 2599 "A fine widget")" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "201 with the product and it is visible in the catalog" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id got $CV_HTTP_BODY" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg s "$SKU" '.product.name == "Async Widget" and .product.description == "A fine widget" and .product.priceCents == 2599 and .product.sku == $s' >/dev/null \
  || cv_fail "expected created product fields to match input got $CV_HTTP_BODY" $LINENO
cv_http GET /products "" -H "Authorization: Bearer $AUTH_TOKEN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 from catalog got $CV_HTTP_STATUS" $LINENO
C=$(printf '%s' "$CV_HTTP_BODY" | jq --arg id "$PID" '[.products[] | select(.id == $id)] | length')
[ "$C" = "1" ] || cv_fail "expected new product in catalog got count $C" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:add_product_happy_path_async"
