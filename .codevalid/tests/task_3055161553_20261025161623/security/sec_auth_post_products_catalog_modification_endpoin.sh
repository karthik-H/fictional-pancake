#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

TITLE="Catalog modification endpoint exposed without any authentication mechanism"
cv_step Given "no sign-in, no auth header" $LINENO
SFX=$(cv_suffix)
SKU="SEC-ANON-${SFX}"
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || { echo "app unreachable: GET /products $CV_HTTP_STATUS"; exit 1; }

cv_step When "POST /products anonymously, and with a bogus bearer token" $LINENO
cv_http POST /products "$(product_body "Test" "$SKU" 100)"
S1=$CV_HTTP_STATUS
cv_http POST /products "$(product_body "Test" "${SKU}-B" 100)" -H "Authorization: Bearer forged.token"
S2=$CV_HTTP_STATUS

cv_step Then "check whether either request created a product" $LINENO
CREATED=0
catalog_has_sku "$SKU" && CREATED=1
catalog_has_sku "${SKU}-B" && CREATED=1
EVID="no-auth POST /products ${S1}; forged bearer ${S2}; product created=${CREATED}"
if [ "$S1" = "201" ] || [ "$S2" = "201" ] || [ "$CREATED" = "1" ]; then
  printf 'CV_SECURITY|vulnerable|auth|serious|%s|%s\n' "$TITLE" "$EVID"
else
  printf 'CV_SECURITY|secure|auth|serious|%s|%s\n' "$TITLE" "$EVID"
fi
exit 0
