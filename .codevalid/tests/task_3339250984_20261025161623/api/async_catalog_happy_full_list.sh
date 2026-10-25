#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "two uniquely named products exist in the catalog" $LINENO
SFX=$(cv_suffix)
PFX="CVHF-$SFX"
trap 'delete_products_by_sku_prefix "$PFX"' EXIT
ID1=$(seed_product "CV Mug $SFX" "first" 1500 "$PFX-A") || cv_fail "expected product A seeded got psql error" $LINENO
ID2=$(seed_product "CV Towel $SFX" "second" 2500 "$PFX-B") || cv_fail "expected product B seeded got psql error" $LINENO
[ -n "$ID1" ] && [ -n "$ID2" ] || cv_fail "expected two product ids got '$ID1' '$ID2'" $LINENO

# When
cv_step When "anonymous client lists products via GET /products" $LINENO
cv_http GET /products 200

# Then
cv_step Then "response holds the full product list including both seeded products" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e '.products | type == "array"' >/dev/null || cv_fail "expected products array got $CV_HTTP_BODY" $LINENO
for sku in MUG-12 TWL-LN; do
  printf '%s' "$CV_HTTP_BODY" | jq -e --arg s "$sku" '.products | any(.sku == $s)' >/dev/null || cv_fail "expected default catalog product $sku in full list got none" $LINENO
done
for id in "$ID1" "$ID2"; do
  printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$id" '.products[] | select(.id == $id) | (.name|type=="string") and (.priceCents|type=="number") and (.sku|type=="string") and (.description|type=="string") and (.createdAt|type=="string")' >/dev/null     || cv_fail "expected product $id with name/description/priceCents/sku/createdAt got none" $LINENO
done
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$ID1" '.products[] | select(.id == $id) | .priceCents == 1500 and .sku == "'"$PFX"'-A"' >/dev/null   || cv_fail "expected product A priceCents 1500 sku $PFX-A got mismatch" $LINENO

# Cleanup
cv_step Cleanup "delete seeded products" $LINENO
delete_products_by_sku_prefix "$PFX"
echo "CODEVALID_TEST_ASSERTION_OK:async_catalog_happy_full_list"
