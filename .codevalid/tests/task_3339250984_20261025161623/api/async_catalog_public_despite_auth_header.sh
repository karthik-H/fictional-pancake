#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "a product exists and a registered user holds a valid token" $LINENO
SFX=$(cv_suffix)
PFX="CVAH-$SFX"
EMAIL="cv-ah-$SFX@example.com"
trap 'delete_products_by_sku_prefix "$PFX"; delete_user_by_email "$EMAIL"' EXIT
ID=$(seed_product "CV Auth $SFX" "auth header item" 900 "$PFX-A") || cv_fail "expected product seeded got psql error" $LINENO
cv_prereq "register and log in user" $LINENO
register_and_login "$EMAIL" "Passw0rd-$SFX"

# When
cv_step When "list products anonymously, with a valid token, and with an invalid token" $LINENO
cv_http GET /products 200
ANON=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.')
cv_http GET /products 200 -H "Authorization: Bearer $CV_TOKEN"
VALID=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.')
cv_http GET /products 200 -H "Authorization: Bearer not-a-real-token"
INVALID=$(printf '%s' "$CV_HTTP_BODY" | jq -cS '.')

# Then
cv_step Then "all three responses are 200 with identical public catalog data" $LINENO
printf '%s' "$ANON" | jq -e --arg id "$ID" '.products | any(.id == $id)' >/dev/null || cv_fail "expected seeded product $ID in anonymous list got none" $LINENO
[ "$VALID" = "$ANON" ] || cv_fail "expected valid-token catalog equal to anonymous got different" $LINENO
[ "$INVALID" = "$ANON" ] || cv_fail "expected invalid-token catalog equal to anonymous got different" $LINENO

# Cleanup
cv_step Cleanup "delete seeded product and user" $LINENO
delete_products_by_sku_prefix "$PFX"
delete_user_by_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:async_catalog_public_despite_auth_header"
