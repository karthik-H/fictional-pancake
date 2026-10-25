#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "unique product payloads and no valid credentials" $LINENO
SFX=$(cv_suffix)
SKU_NONE="CV-NOAUTH-$SFX"
SKU_BAD="CV-BADTOK-$SFX"
SKU_MALF="CV-MALF-$SFX"

# When
cv_step When "POST /products without a token, with an invalid token, and with a non-Bearer header" $LINENO
cv_http POST /products "$(product_body "No auth" "$SKU_NONE" 500)"
S_NONE=$CV_HTTP_STATUS
cv_http POST /products "$(product_body "Bad token" "$SKU_BAD" 500)" -H "Authorization: Bearer not.a-valid-token"
S_BAD=$CV_HTTP_STATUS
cv_http POST /products "$(product_body "Malformed" "$SKU_MALF" 500)" -H "Authorization: Basic Zm9vOmJhcg=="
S_MALF=$CV_HTTP_STATUS

# Then
cv_step Then "each request is rejected with 401/403 and no product is added" $LINENO
for s in "$S_NONE" "$S_BAD" "$S_MALF"; do
  case "$s" in 401|403) ;; *) cv_fail "expected 401 or 403 got $s" $LINENO ;; esac
done
signed_in_user observer $LINENO
for sku in "$SKU_NONE" "$SKU_BAD" "$SKU_MALF"; do
  sku_count "$sku" -H "Authorization: Bearer $TOKEN"
  [ "$SKU_COUNT" = "0" ] || cv_fail "expected sku $sku absent from catalog got $SKU_COUNT entries" $LINENO
done

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:reject_unauthenticated_requests"
