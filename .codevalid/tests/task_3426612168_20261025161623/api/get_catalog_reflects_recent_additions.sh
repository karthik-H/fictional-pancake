#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "two signed-in users each adding products in this run" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
TOKEN1="$AUTH_TOKEN"
EMAIL2="cv2-${SUF}@example.test"
cv_prereq "register and log in a second user" $LINENO
register_and_login "$EMAIL2" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL2 got none" $LINENO
TOKEN2="$AUTH_TOKEN"
AUTH_TOKEN="$TOKEN1"
cv_prereq "add product ${SKU_PREFIX}-1" $LINENO
cv_http POST /products "$(product_json "Recent One" "${SKU_PREFIX}-1" 100)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
P1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$P1" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO
cv_prereq "add product ${SKU_PREFIX}-2" $LINENO
cv_http POST /products "$(product_json "Recent Two" "${SKU_PREFIX}-2" 200)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
P2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$P2" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO
AUTH_TOKEN="$TOKEN2"
cv_prereq "add product ${SKU_PREFIX}-3" $LINENO
cv_http POST /products "$(product_json "Recent Three" "${SKU_PREFIX}-3" 300)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
P3=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$P3" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO

# When
cv_step When "both signed-in users request GET /products" $LINENO
cv_http GET /products "" -H "Authorization: Bearer $TOKEN1"
BODY1="$CV_HTTP_BODY"; ST1="$CV_HTTP_STATUS"
cv_http GET /products "" -H "Authorization: Bearer $TOKEN2"
BODY2="$CV_HTTP_BODY"; ST2="$CV_HTTP_STATUS"

# Then
cv_step Then "each response includes all three added products" $LINENO
[ "$ST1" = "200" ] || cv_fail "expected 200 for user1 got $ST1" $LINENO
[ "$ST2" = "200" ] || cv_fail "expected 200 for user2 got $ST2" $LINENO
for B in "$BODY1" "$BODY2"; do
  for ID in "$P1" "$P2" "$P3"; do
    C=$(printf '%s' "$B" | jq --arg id "$ID" '[.products[] | select(.id == $id)] | length')
    [ "$C" = "1" ] || cv_fail "expected product $ID in catalog got count $C" $LINENO
  done
done

# Cleanup
cv_step Cleanup "remove test products and users" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
delete_user "$EMAIL2"
echo "CODEVALID_TEST_ASSERTION_OK:get_catalog_reflects_recent_additions"
