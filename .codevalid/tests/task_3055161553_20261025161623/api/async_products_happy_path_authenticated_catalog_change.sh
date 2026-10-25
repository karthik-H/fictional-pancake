#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer signs in" $LINENO
SUF=$(cv_suffix)
EMAIL="prod-happy-${SUF}@example.test"
PASS="Pw-prod-${SUF}"
SKU="PH-${SUF}"
register_user "$EMAIL" "Product Customer" "$PASS" $LINENO
login_user "$EMAIL" "$PASS" $LINENO
PB=$(jq -nc --arg s "$SKU" '{name:"Async mug",description:"Blue glaze",sku:$s,priceCents:2100}')

# When
cv_step When "signed-in customer creates a product via POST /products" $LINENO
cv_http POST /products "$PB" -H "Authorization: Bearer $AUTH_TOKEN"
CODE="$CV_HTTP_STATUS"; BODY="$CV_HTTP_BODY"

# Then
cv_step Then "product is created, visible in catalog, no password exposed" $LINENO
[ "$CODE" = "201" ] || cv_fail "expected 201 got $CODE" $LINENO
PID=$(printf '%s' "$BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id in response" $LINENO
printf '%s' "$BODY" | jq -e --arg s "$SKU" '.product.sku==$s and .product.name=="Async mug" and .product.description=="Blue glaze" and .product.priceCents==2100' >/dev/null \
  || cv_fail "expected product fields to match request got $BODY" $LINENO
case "$BODY" in *"$PASS"*) cv_fail "expected no password in create response" $LINENO ;; esac
cv_http GET /products 200
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$PID" --arg s "$SKU" 'any(.products[]; .id==$id and .sku==$s)' >/dev/null \
  || cv_fail "expected product $PID in catalog listing" $LINENO
case "$CV_HTTP_BODY" in *"$PASS"*) cv_fail "expected no password in catalog listing" $LINENO ;; esac
cv_http GET "/products/$PID" 200
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.priceCents')" = "2100" ] || cv_fail "expected priceCents 2100 on product detail" $LINENO

# Cleanup
cv_step Cleanup "remove product and user" $LINENO
delete_product_sku "$SKU"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:async_products_happy_path_authenticated_catalog_change"
