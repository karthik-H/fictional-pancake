#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "signed-in user and an id not in the catalog" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-A" $LINENO
cv_http POST /products "$(product_json "Other Item" "${SKU_PREFIX}-A" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO
MISSING_ID="00000000-0000-4000-8000-$(printf '%012d' "$((RANDOM * RANDOM))")"
EXISTS=$(psql -qtAc "SELECT count(*) FROM products WHERE id = '$MISSING_ID'")
[ "$EXISTS" = "0" ] || cv_fail "expected $MISSING_ID absent from products got count $EXISTS" $LINENO

# When
cv_step When "signed-in user requests GET /products/{missing id}" $LINENO
cv_http GET "/products/$MISSING_ID" "" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "404 not-found without other product data" $LINENO
[ "$CV_HTTP_STATUS" = "404" ] || cv_fail "expected 404 got $CV_HTTP_STATUS" $LINENO
if printf '%s' "$CV_HTTP_BODY" | grep -q -e "$PID" -e "${SKU_PREFIX}" -e '"products"' -e '"product"'; then
  cv_fail "expected no product data in 404 body got $CV_HTTP_BODY" $LINENO
fi

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:get_product_nonexistent_id_not_found"
