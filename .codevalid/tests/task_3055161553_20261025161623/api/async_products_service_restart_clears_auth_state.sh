#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "customer signs in and creates a product successfully" $LINENO
SUF=$(cv_suffix)
EMAIL="prod-rst-${SUF}@example.test"
PASS="Pw-rst-${SUF}"
register_user "$EMAIL" "Restart Customer" "$PASS" $LINENO
login_user "$EMAIL" "$PASS" $LINENO
OLD_TOKEN="$AUTH_TOKEN"
cv_http POST /products "$(jq -nc --arg s "PR-${SUF}-1" '{name:"Before restart",sku:$s,priceCents:10}')" 201 -H "Authorization: Bearer $OLD_TOKEN"

# When
cv_step When "service restarts, then old session posts a product" $LINENO
restart_app 60 || cv_fail "app did not come back after restart" $LINENO
cv_http POST /products "$(jq -nc --arg s "PR-${SUF}-2" '{name:"After restart old token",sku:$s,priceCents:10}')" -H "Authorization: Bearer $OLD_TOKEN"
OLD_CODE="$CV_HTTP_STATUS"

# Then
cv_step Then "old session is rejected; fresh sign-in restores catalog changes" $LINENO
[ "$OLD_CODE" = "401" ] || cv_fail "expected 401 for pre-restart session after restart got $OLD_CODE" $LINENO
CNT=$(db_psql -tA -c "SELECT count(*) FROM products WHERE sku = 'PR-${SUF}-2'")
[ "$CNT" = "0" ] || cv_fail "expected no product from stale session got $CNT" $LINENO
login_user "$EMAIL" "$PASS" $LINENO
cv_http POST /products "$(jq -nc --arg s "PR-${SUF}-3" '{name:"After re-sign-in",sku:$s,priceCents:10}')" 201 -H "Authorization: Bearer $AUTH_TOKEN"

# Cleanup
cv_step Cleanup "remove products and user" $LINENO
delete_products_like "PR-${SUF}-%"
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:async_products_service_restart_clears_auth_state"
