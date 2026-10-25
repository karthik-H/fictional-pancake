#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "a new product payload and no sign-in" $LINENO
SFX=$(cv_suffix)
SKU="CV-NOLOGIN-${SFX}"

# When
cv_step When "POST /products without any authorization header" $LINENO
cv_http POST /products "$(product_body "No login" "$SKU" 1200)"

# Then
cv_step Then "access is denied with 401 and the catalog is unchanged" $LINENO
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected 401 got $CV_HTTP_STATUS" $LINENO
ERR=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
[ "$ERR" = "Missing bearer token" ] || cv_fail "expected error 'Missing bearer token' got '$ERR'" $LINENO
if catalog_has_sku "$SKU"; then cv_fail "expected sku $SKU absent from catalog got present" $LINENO; fi

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_access_without_login"
