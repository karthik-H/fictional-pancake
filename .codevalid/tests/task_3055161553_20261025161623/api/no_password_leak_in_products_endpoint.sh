#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "signed-in customer with a distinctive password" $LINENO
SFX=$(cv_suffix)
EMAIL="prodleak.${SFX}@example.test"
PASSWORD="ProdPw-${SFX}-kk"
SKU="CV-PRODLEAK-${SFX}"
register_user "$EMAIL" "Prod Leak" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO

# When
cv_step When "signed-in POST /products, then read the product and catalog" $LINENO
cv_http POST /products "$(product_body "Leak probe" "$SKU" 300)" -H "Authorization: Bearer $TOKEN"
S1=$CV_HTTP_STATUS; B1=$CV_HTTP_BODY
PID=$(printf '%s' "$B1" | jq -r '.product.id // empty')
cv_http GET "/products/$PID"
B2=$CV_HTTP_BODY
cv_http GET /products
B3=$CV_HTTP_BODY

# Then
cv_step Then "no password, hash, token or email appears in products responses" $LINENO
[ "$S1" = "201" ] || cv_fail "expected 201 got $S1" $LINENO
KEYS=$(printf '%s' "$B1" | jq -c '.product | keys')
[ "$KEYS" = '["createdAt","description","id","name","priceCents","sku"]' ] || cv_fail "expected product keys [createdAt,description,id,name,priceCents,sku] got $KEYS" $LINENO
for B in "$B1" "$B2" "$B3"; do
  if body_leaks_password "$B" "$PASSWORD"; then cv_fail "expected no password data got $B" $LINENO; fi
  if printf '%s' "$B" | grep -qF -- "$TOKEN"; then cv_fail "expected token not echoed got it" $LINENO; fi
  if printf '%s' "$B" | grep -qF -- "$EMAIL"; then cv_fail "expected customer email not exposed got it" $LINENO; fi
done

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:no_password_leak_in_products_endpoint"
