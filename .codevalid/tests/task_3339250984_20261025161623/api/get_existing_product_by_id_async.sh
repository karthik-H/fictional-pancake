#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a product exists with known fields" $LINENO
SFX=$(cv_suffix)
PFX="CVGE-$SFX"
trap 'delete_products_by_sku_prefix "$PFX"' EXIT
ID=$(seed_product "CV Lamp $SFX" "Brass desk lamp" 4999 "$PFX-A") || cv_fail "expected product seeded got psql error" $LINENO
[ -n "$ID" ] || cv_fail "expected product id got empty" $LINENO

# When
cv_step When "anonymous client fetches GET /products/{id}" $LINENO
cv_http GET "/products/$ID" 200

# Then
cv_step Then "response carries the product details" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$ID" --arg n "CV Lamp $SFX" --arg s "$PFX-A"   '.product.id == $id and .product.name == $n and .product.description == "Brass desk lamp" and .product.priceCents == 4999 and .product.sku == $s and (.product.createdAt|type=="string")' >/dev/null   || cv_fail "expected product $ID details got $CV_HTTP_BODY" $LINENO

# Cleanup
cv_step Cleanup "delete seeded product" $LINENO
delete_products_by_sku_prefix "$PFX"
echo "CODEVALID_TEST_ASSERTION_OK:get_existing_product_by_id_async"
