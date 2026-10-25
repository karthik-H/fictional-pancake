#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a signed-in user adds a product with a unique code" $LINENO
signed_in_user vis $LINENO
SKU="CV-VIS-$(cv_suffix)"
cv_http POST /products "$(product_body "Visible mug" "$SKU" 800)" -H "Authorization: Bearer $TOKEN"
[ "$CV_HTTP_STATUS" = "201" ] || cv_fail "expected create 201 got $CV_HTTP_STATUS" $LINENO
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id got none" $LINENO

# When
cv_step When "read the catalog signed in, then without authentication" $LINENO
sku_count "$SKU" -H "Authorization: Bearer $TOKEN"
AUTH_STATUS=$CV_HTTP_STATUS; AUTH_COUNT=$SKU_COUNT
sku_count "$SKU"
ANON_LIST_STATUS=$CV_HTTP_STATUS; ANON_COUNT=$SKU_COUNT
cv_http GET "/products/$PID"
ANON_ITEM_STATUS=$CV_HTTP_STATUS; ANON_ITEM_BODY=$CV_HTTP_BODY

# Then
cv_step Then "signed-in read shows the product; unauthenticated reads do not expose it" $LINENO
[ "$AUTH_STATUS" = "200" ] || cv_fail "expected signed-in GET /products 200 got $AUTH_STATUS" $LINENO
[ "$AUTH_COUNT" = "1" ] || cv_fail "expected product visible to signed-in user got $AUTH_COUNT" $LINENO
if [ "$ANON_LIST_STATUS" = "200" ] && [ "$ANON_COUNT" != "0" ]; then
  cv_fail "expected unauthenticated GET /products to be rejected or hide sku $SKU got $ANON_LIST_STATUS with the product" $LINENO
fi
if [ "$ANON_ITEM_STATUS" = "200" ] && printf '%s' "$ANON_ITEM_BODY" | jq -e --arg s "$SKU" '.product.sku == $s' >/dev/null; then
  cv_fail "expected unauthenticated GET /products/$PID to be rejected got 200 with the product" $LINENO
fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:visibility_signed_in_only"
