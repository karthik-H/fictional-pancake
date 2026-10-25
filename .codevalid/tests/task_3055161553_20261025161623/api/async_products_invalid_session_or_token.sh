#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "customer signs in and invalid/expired variants of the token are built" $LINENO
SUF=$(cv_suffix)
EMAIL="prod-inv-${SUF}@example.test"
PASS="Pw-inv-${SUF}"
SKU="PI-${SUF}"
register_user "$EMAIL" "Invalid Token Customer" "$PASS" $LINENO
login_user "$EMAIL" "$PASS" $LINENO
BODY_PART=${AUTH_TOKEN%%.*}
SIG_PART=${AUTH_TOKEN#*.}
PAYLOAD=$(printf '%s' "$BODY_PART" | tr '_-' '/+' | { b=$(cat); while [ $(( ${#b} % 4 )) -ne 0 ]; do b="$b="; done; printf '%s' "$b"; } | base64 -d)
EXPIRED_BODY=$(printf '%s' "$PAYLOAD" | jq -c '.exp = 1000' | base64 -w0 | tr '/+' '_-' | tr -d '=')
EXPIRED_TOKEN="${EXPIRED_BODY}.${SIG_PART}"
LAST=${SIG_PART: -1}; if [ "$LAST" = "A" ]; then NEWLAST=B; else NEWLAST=A; fi
TAMPERED_TOKEN="${BODY_PART}.${SIG_PART%?}${NEWLAST}"
PB=$(jq -nc --arg s "$SKU" '{name:"Invalid token item",sku:$s,priceCents:700}')

# When
cv_step When "post products with expired, tampered and garbage tokens" $LINENO
cv_http POST /products "$PB" -H "Authorization: Bearer $EXPIRED_TOKEN"
C1="$CV_HTTP_STATUS"
cv_http POST /products "$PB" -H "Authorization: Bearer $TAMPERED_TOKEN"
C2="$CV_HTTP_STATUS"
cv_http POST /products "$PB" -H "Authorization: Bearer not-a-real-token"
C3="$CV_HTTP_STATUS"

# Then
cv_step Then "all are rejected with 401 and no product is created" $LINENO
[ "$C1" = "401" ] || cv_fail "expected 401 for expired token got $C1" $LINENO
[ "$C2" = "401" ] || cv_fail "expected 401 for tampered token got $C2" $LINENO
[ "$C3" = "401" ] || cv_fail "expected 401 for garbage token got $C3" $LINENO
CNT=$(db_psql -tA -c "SELECT count(*) FROM products WHERE sku = '$SKU'")
[ "$CNT" = "0" ] || cv_fail "expected 0 products for $SKU got $CNT" $LINENO

# Cleanup
cv_step Cleanup "remove product and user" $LINENO
delete_product_sku "$SKU"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:async_products_invalid_session_or_token"
