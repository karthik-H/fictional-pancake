#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3426612168_20261025161623/api/_infra.sh

# Given
cv_step Given "products added and visible in the current run" $LINENO
SUF=$(cv_suffix)
EMAIL="cv-${SUF}@example.test"
PASS="Passw0rd-${SUF}"
SKU_PREFIX="CV-${SUF}"
cv_prereq "register and log in a user" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token for $EMAIL got none" $LINENO
cv_prereq "add product ${SKU_PREFIX}-1" $LINENO
cv_http POST /products "$(product_json "Ephemeral One" "${SKU_PREFIX}-1" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
P1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$P1" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO
cv_prereq "add product ${SKU_PREFIX}-2" $LINENO
cv_http POST /products "$(product_json "Ephemeral Two" "${SKU_PREFIX}-2" 1999)" 201 -H "Authorization: Bearer $AUTH_TOKEN"
P2=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product.id // empty')
[ -n "$P2" ] || cv_fail "expected product id in POST response got $CV_HTTP_BODY" $LINENO
cv_prereq "confirm both present before restart" $LINENO
cv_http GET /products "" 200 -H "Authorization: Bearer $AUTH_TOKEN"
C=$(printf '%s' "$CV_HTTP_BODY" | jq --arg a "$P1" --arg b "$P2" '[.products[] | select(.id == $a or .id == $b)] | length')
[ "$C" = "2" ] || cv_fail "expected both products before restart got $C" $LINENO

# When
cv_step When "service restarts and signed-in user reads the catalog" $LINENO
restart_app 90 || cv_fail "expected app healthy after restart got not healthy" $LINENO
register_and_login "$EMAIL" "$PASS"
[ -n "$AUTH_TOKEN" ] || cv_fail "expected a login token after restart got none" $LINENO
cv_http GET /products "" -H "Authorization: Bearer $AUTH_TOKEN"

# Then
cv_step Then "previously added products are gone" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
C=$(printf '%s' "$CV_HTTP_BODY" | jq --arg a "$P1" --arg b "$P2" '[.products[] | select(.id == $a or .id == $b)] | length')
[ "$C" = "0" ] || cv_fail "expected 0 pre-restart products after restart got $C" $LINENO

# Cleanup
cv_step Cleanup "remove test products and user" $LINENO
delete_products_like "$SKU_PREFIX"
delete_user "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:product_ephemeral_across_service_restart_async"
