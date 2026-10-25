#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a unique sku not yet in the catalog" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
SKU_PREFIX="CV-${SUF}"
SKU="${SKU_PREFIX}-A"
N=$(psql -qtAc "SELECT count(*) FROM products WHERE sku = '$SKU'") || cv_fail "expected DB reachable got psql error" $LINENO
[ "$N" = "0" ] || cv_fail "expected sku absent got count $N" $LINENO

# When
cv_step When "unauthenticated client POSTs a product" $LINENO
cv_http POST /products "$(product_json "Anon Widget" "$SKU" 1000)"

# Then
cv_step Then "401/403 and no product added" $LINENO
case "$CV_HTTP_STATUS" in 401|403) ;; *) cv_fail "expected 401 or 403 got $CV_HTTP_STATUS" $LINENO ;; esac
N=$(psql -qtAc "SELECT count(*) FROM products WHERE sku = '$SKU'")
[ "$N" = "0" ] || cv_fail "expected no product with sku $SKU got count $N" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:unauthenticated_add_product_rejected_async"
