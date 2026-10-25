#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a unique product exists in the catalog" $LINENO
cv_seed_product

# When
cv_step When "anonymous GET /products/{id} for that product" $LINENO
cv_http GET "/products/$CV_PRODUCT_ID"

# Then
cv_step Then "200 with the product's details" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
p=$(printf '%s' "$CV_HTTP_BODY" | jq -c '.product')
[ "$(printf '%s' "$p" | jq -r '.id')" = "$CV_PRODUCT_ID" ] || cv_fail "expected id $CV_PRODUCT_ID got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.name')" = "CV Product $CV_SUFFIX" ] || cv_fail "expected name 'CV Product $CV_SUFFIX' got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.sku')" = "CV-SKU-$CV_SUFFIX" ] || cv_fail "expected sku CV-SKU-$CV_SUFFIX got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.priceCents')" = "1234" ] || cv_fail "expected priceCents 1234 got $p" $LINENO
[ "$(printf '%s' "$p" | jq -r '.description')" = "cv test product" ] || cv_fail "expected description 'cv test product' got $p" $LINENO
printf '%s' "$p" | jq -e '.createdAt | type == "string"' >/dev/null || cv_fail "expected createdAt string got $p" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_single_product_valid"
