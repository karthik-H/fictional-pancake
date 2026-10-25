#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a product exists and a registered user holds a valid token" $LINENO
SFX=$(cv_suffix)
PFX="CVIA-$SFX"
EMAIL="cv-ia-$SFX@example.com"
trap 'delete_products_by_sku_prefix "$PFX"; delete_user_by_email "$EMAIL"' EXIT
ID=$(seed_product "CV Chair $SFX" "oak chair" 15000 "$PFX-A") || cv_fail "expected product seeded got psql error" $LINENO
cv_prereq "register and log in user" $LINENO
register_and_login "$EMAIL" "Passw0rd-$SFX"

# When
cv_step When "fetch GET /products/{id} anonymously and authenticated" $LINENO
cv_http GET "/products/$ID"
ANON_S="$CV_HTTP_STATUS"; ANON=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.')
cv_http GET "/products/$ID" -H "Authorization: Bearer $CV_TOKEN"
AUTH_S="$CV_HTTP_STATUS"; AUTH=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.')

# Then
cv_step Then "both calls return 200 with identical product details" $LINENO
[ "$ANON_S" = "200" ] || cv_fail "expected anonymous 200 got $ANON_S" $LINENO
[ "$AUTH_S" = "200" ] || cv_fail "expected authenticated 200 got $AUTH_S" $LINENO
printf '%s' "$ANON" | jq -e --arg id "$ID" '.product.id == $id and .product.priceCents == 15000' >/dev/null || cv_fail "expected product $ID got $ANON" $LINENO
[ "$ANON" = "$AUTH" ] || cv_fail "expected identical bodies got anon=$ANON auth=$AUTH" $LINENO

# Cleanup
cv_step Cleanup "delete seeded product and user" $LINENO
delete_products_by_sku_prefix "$PFX"
delete_user_by_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:get_product_async_ignores_authentication"
