#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "signed-in customer creates a product" $LINENO
SFX=$(cv_suffix)
EMAIL="hidden.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
SKU="CV-HIDDEN-${SFX}"
register_user "$EMAIL" "Hidden" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO
cv_http POST /products "$(product_body "Hidden change" "$SKU" 700)" 201 -H "Authorization: Bearer $TOKEN"
PID=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$PID" ] || cv_fail "expected product.id from create got none" $LINENO

# When
cv_step When "an unauthenticated client reads the catalog and tries to change it" $LINENO
cv_http GET /products
LIST_STATUS=$CV_HTTP_STATUS; LIST_BODY=$CV_HTTP_BODY
cv_http GET "/products/$PID"
ONE_STATUS=$CV_HTTP_STATUS
cv_http POST /products "$(product_body "Anon change" "CV-ANON-${SFX}" 700)"
POST_STATUS=$CV_HTTP_STATUS

# Then
cv_step Then "the unauthenticated client neither sees the change nor can perform one" $LINENO
[ "$POST_STATUS" = "401" ] || cv_fail "expected 401 for anonymous POST /products got $POST_STATUS" $LINENO
if [ "$LIST_STATUS" = "200" ] && printf '%s' "$LIST_BODY" | jq -e --arg s "$SKU" '.products | any(.sku == $s)' >/dev/null; then
  cv_fail "expected signed-in change $SKU hidden from unauthenticated GET /products got it listed" $LINENO
fi
[ "$ONE_STATUS" != "200" ] || cv_fail "expected unauthenticated GET /products/$PID denied got 200" $LINENO

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_changes_hidden_from_unauthenticated_access"
