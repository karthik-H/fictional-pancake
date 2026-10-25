#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "signed-in user who added a product" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-A" $LINENO
cv_http POST /products "$(product_json "By Id Item" "${SKU_PREFIX}-A" 4500)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "signed-in user requests GET /products/{id}" $LINENO
cv_http GET "/products/$PID" "" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "200 with the matching product details" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" --arg s "${SKU_PREFIX}-A" \
  '.product.id == $id and .product.sku == $s and .product.name == "By Id Item" and .product.priceCents == 4500 and .product.description == "CodeValid test product"' >/dev/null \
  || cv_fail "expected product $PID with matching fields got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:get_product_happy_path_by_id"
