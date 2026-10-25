#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "at least three products exist in the catalog" $LINENO
SFX=$(cv_suffix)
PFX="CVPG-$SFX"
trap 'delete_products_by_sku_prefix "$PFX"' EXIT
for x in A B C; do
  seed_product "CV Page $x $SFX" "page item" 1000 "$PFX-$x" >/dev/null || cv_fail "expected product $x seeded got psql error" $LINENO
done
TOTAL=$(psql -qtA -c "SELECT count(*) FROM products")
[ "$TOTAL" -ge 3 ] || cv_fail "expected at least 3 products got $TOTAL" $LINENO

# When
cv_step When "anonymous client requests page 1 and page 2 with pageSize=2, twice for page 1" $LINENO
cv_http GET "/products?page=1&pageSize=2" 200
P1="$CV_HTTP_BODY"
cv_http GET "/products?page=1&pageSize=2" 200
P1B="$CV_HTTP_BODY"
cv_http GET "/products?page=2&pageSize=2" 200
P2="$CV_HTTP_BODY"

# Then
cv_step Then "pages hold at most pageSize items, stable order, no overlap, and pagination metadata" $LINENO
N1=$(printf '%s' "$P1" | jq '.products | length')
[ "$N1" = "2" ] || cv_fail "expected 2 products on page 1 (pageSize=2) got $N1" $LINENO
[ "$(printf '%s' "$P1" | jq -c '[.products[].id]')" = "$(printf '%s' "$P1B" | jq -c '[.products[].id]')" ] || cv_fail "expected identical ordering on repeated page 1 got different" $LINENO
N2=$(printf '%s' "$P2" | jq '.products | length')
[ "$N2" -ge 1 ] && [ "$N2" -le 2 ] || cv_fail "expected 1-2 products on page 2 got $N2" $LINENO
OVER=$(jq -n --argjson a "$P1" --argjson b "$P2" '[$a.products[].id] - ([$a.products[].id] - [$b.products[].id]) | length')
[ "$OVER" = "0" ] || cv_fail "expected no overlap between page 1 and page 2 got $OVER shared ids" $LINENO
printf '%s' "$P1" | jq -e '(.. | objects | select(has("total") or has("totalCount") or has("totalItems"))) | length > 0' >/dev/null 2>&1   || cv_fail "expected pagination metadata (total/page/pageSize) got none in $(printf '%s' "$P1" | jq -c 'del(.products)')" $LINENO

# Cleanup
cv_step Cleanup "delete seeded products" $LINENO
delete_products_by_sku_prefix "$PFX"
echo "CODEVALID_TEST_ASSERTION_OK:async_catalog_pagination_consistency"
