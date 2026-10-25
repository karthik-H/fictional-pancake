#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a unique product exists in the catalog (created by a fresh user)" $LINENO
cv_seed_product

# When
cv_step When "anonymous GET /products with no headers or query params" $LINENO
cv_http GET /products

# Then
cv_step Then "200 with the full list including the created product and the seeded catalog" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected .products array got $CV_HTTP_BODY" $LINENO
n=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$n" -ge 3 ] || cv_fail "expected at least 3 products (2 seeded + created) got $n" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$CV_PRODUCT_ID" 'any(.products[]; .id == $id)' >/dev/null || cv_fail "expected product $CV_PRODUCT_ID in list got none" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e 'any(.products[]; .sku == "MUG-12") and any(.products[]; .sku == "TWL-LN")' >/dev/null || cv_fail "expected seeded MUG-12 and TWL-LN in list" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e 'all(.products[]; has("id") and has("name") and has("priceCents") and has("sku"))' >/dev/null || cv_fail "expected every product to have id,name,priceCents,sku" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_happy_all_products"
