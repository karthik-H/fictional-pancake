#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "a signed-in user and the current catalog size" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
BEFORE=$(psql -qtAc "SELECT count(*) FROM products") || cv_fail "expected DB reachable got psql error" $LINENO

# When
cv_step When "user POSTs invalid payloads (missing name, string price, negative price)" $LINENO
cv_http POST /products "$(jq -nc --arg s "${SKU_PREFIX}-1" '{description:"x",sku:$s,priceCents:100}')" -H "Authorization: Bearer $AUTH_TOKEN"
S1="$CV_HTTP_STATUS"; B1="$CV_HTTP_BODY"
cv_http POST /products "$(jq -nc --arg s "${SKU_PREFIX}-2" '{name:"Bad",description:"x",sku:$s,priceCents:"abc"}')" -H "Authorization: Bearer $AUTH_TOKEN"
S2="$CV_HTTP_STATUS"; B2="$CV_HTTP_BODY"
cv_http POST /products "$(jq -nc --arg s "${SKU_PREFIX}-3" '{name:"Bad",description:"x",sku:$s,priceCents:-5}')" -H "Authorization: Bearer $AUTH_TOKEN"
S3="$CV_HTTP_STATUS"; B3="$CV_HTTP_BODY"

# Then
cv_step Then "each rejected with 400 and an error, catalog unchanged" $LINENO
for P in "$S1|$B1" "$S2|$B2" "$S3|$B3"; do
  ST="${P%%|*}"; BD="${P#*|}"
  [ "$ST" = "400" ] || cv_fail "expected 400 got $ST ($BD)" $LINENO
  printf '%s' "$BD" | jq -e '.error | type == "string" and length > 0' >/dev/null || cv_fail "expected validation error message got $BD" $LINENO
done
N=$(psql -qtAc "SELECT count(*) FROM products WHERE sku LIKE '${SKU_PREFIX}%'")
[ "$N" = "0" ] || cv_fail "expected no products created got $N" $LINENO
AFTER=$(psql -qtAc "SELECT count(*) FROM products")
[ "$AFTER" = "$BEFORE" ] || cv_fail "expected catalog size $BEFORE got $AFTER" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:invalid_product_payload_rejected_async"
