#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered and signed-in customer" $LINENO
SFX=$(cv_suffix)
EMAIL="create.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
SKU="CV-CREATE-${SFX}"
register_user "$EMAIL" "Create" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO

# When
cv_step When "POST /products with bearer token" $LINENO
cv_http POST /products "$(jq -nc --arg s "$SKU" '{name:"Created item",description:"desc",sku:$s,priceCents:4200}')" -H "Authorization: Bearer $TOKEN"

# Then
cv_step Then "201 and the product is visible in the catalog afterwards" $LINENO
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected 201 got $CV_HTTP_STATUS" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.description')" = "desc" ] || cv_fail "expected description 'desc' got $CV_HTTP_BODY" $LINENO
[ "$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.priceCents')" = "4200" ] || cv_fail "expected priceCents 4200 got $CV_HTTP_BODY" $LINENO
catalog_has_sku "$SKU" || cv_fail "expected sku $SKU in GET /products got absent" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:create_product_authenticated_customer"
