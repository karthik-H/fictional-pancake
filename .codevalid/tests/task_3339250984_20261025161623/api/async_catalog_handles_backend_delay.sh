#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

TOXIC="cv_delay_$$"
# Given
cv_step Given "a product exists and the database link has 1500ms added latency" $LINENO
SFX=$(cv_suffix)
PFX="CVDL-$SFX"
trap 'toxi_remove "$TOXIC"; delete_products_by_sku_prefix "$PFX"' EXIT
ID=$(seed_product "CV Delay $SFX" "delay item" 700 "$PFX-A") || cv_fail "expected product seeded got psql error" $LINENO
toxi_add_latency "$TOXIC" 1500 || cv_fail "expected latency toxic added got toxiproxy error" $LINENO

# When
cv_step When "anonymous client lists products under the slow database" $LINENO
cv_http GET /products 200 --max-time 30

# Then
cv_step Then "response is 200 with a well-formed list including the seeded product, delayed by the backend" $LINENO
printf '%s' "$CV_HTTP_BODY" | jq -e --arg id "$ID" '.products | type=="array" and any(.id == $id and .priceCents == 700)' >/dev/null   || cv_fail "expected products array containing $ID got $(printf '%s' "$CV_HTTP_BODY" | head -c 200)" $LINENO
[ "$CV_HTTP_MS" -ge 1400 ] || cv_fail "expected request to reflect >=1400ms backend delay got ${CV_HTTP_MS}ms" $LINENO

# Cleanup
cv_step Cleanup "remove latency toxic and delete seeded product" $LINENO
toxi_remove "$TOXIC"
delete_products_by_sku_prefix "$PFX"
echo "CODEVALID_TEST_ASSERTION_OK:async_catalog_handles_backend_delay"
