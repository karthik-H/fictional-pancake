#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "a product payload and no credentials" $LINENO
SFX=$(cv_suffix)
SKU="CV-NOAUTH-${SFX}"

# When
cv_step When "POST /products without any token" $LINENO
cv_http POST /products "$(product_body "No auth" "$SKU" 100)"

# Then
cv_step Then "authorization failure and no catalog change" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 got $CV_HTTP_STATUS" $LINENO
P=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product // empty')
[ -z "$P" ] || cv_fail "expected no product in response got $P" $LINENO
if catalog_has_sku "$SKU"; then cv_fail "expected sku $SKU absent from catalog got present" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:create_product_without_authentication_rejected"
