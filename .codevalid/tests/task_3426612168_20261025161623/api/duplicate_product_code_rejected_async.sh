#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a product already added with a given sku" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
SKU="${SKU_PREFIX}-DUP"
cv_prereq "add product ${SKU}" $LINENO
cv_http POST /products "$(product_json "Original" "${SKU}" 1500)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "same user adds another product with the same sku" $LINENO
cv_http POST /products "$(product_json "Impostor" "$SKU" 999)" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "request fails with 409 and only the original remains" $LINENO
[ "$CV_HTTP_STATUS" = "409" ] || cv_fail "expected 409 got $CV_HTTP_STATUS" $LINENO
cv_http GET /products "" -H "Authorization: Bearer $AUTH_TOKEN"
MATCH=$(printf '%s' "$CV_HTTP_BODY" | jq -c --arg s "$SKU" '[.products[] | select(.sku == $s) | {id,name,priceCents}]')
EXPECTED=$(jq -nc --arg id "$PID" '[{id:$id,name:"Original",priceCents:1500}]')
[ "$MATCH" = "$EXPECTED" ] || cv_fail "expected only original product $EXPECTED got $MATCH" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:duplicate_product_code_rejected_async"
