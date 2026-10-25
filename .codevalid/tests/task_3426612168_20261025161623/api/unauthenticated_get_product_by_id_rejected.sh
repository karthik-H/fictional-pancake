#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "an existing product added by a signed-in user" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-A" $LINENO
cv_http POST /products "$(product_json "Private Item" "${SKU_PREFIX}-A" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "unauthenticated client requests GET /products/{id}" $LINENO
cv_http GET "/products/$PID"

# Then
cv_step Then "request rejected and product details not returned" $LINENO
case "$CV_HTTP_STATUS" in 2??) cv_fail "expected unauthenticated GET /products/$PID rejected got $CV_HTTP_STATUS" $LINENO ;; esac
if printf '%s' "$CV_HTTP_BODY" | grep -q -e "$PID" -e "${SKU_PREFIX}-A"; then cv_fail "expected no product details got $CV_HTTP_BODY" $LINENO; fi

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_get_product_by_id_rejected"
