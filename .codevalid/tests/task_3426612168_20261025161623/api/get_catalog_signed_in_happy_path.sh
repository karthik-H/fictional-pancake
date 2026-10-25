#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "signed-in user who added a product this run" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-A" $LINENO
cv_http POST /products "$(product_json "Happy Catalog Item" "${SKU_PREFIX}-A" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "signed-in user requests GET /products" $LINENO
cv_http GET /products "" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "200 with a products array including the added product" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected products array got $CV_HTTP_BODY" $LINENO
FOUND=$(printf '%s' "$CV_HTTP_BODY" | jq --arg id "$PID" --arg s "${SKU_PREFIX}-A" '[.products[] | select(.id == $id and .sku == $s and .name == "Happy Catalog Item" and .priceCents == 1999)] | length')
[ "$FOUND" = "1" ] || cv_fail "expected added product $PID in catalog got count $FOUND" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:get_catalog_signed_in_happy_path"
