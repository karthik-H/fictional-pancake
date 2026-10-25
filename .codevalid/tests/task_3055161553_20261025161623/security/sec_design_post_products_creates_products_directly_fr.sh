#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

TITLE="Creates products directly from request body without ownership or role checks"
cv_step Given "an ordinary self-registered customer with no special role" $LINENO
SFX=$(cv_suffix)
EMAIL="role.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
BODY=$(jq -nc --arg e "$EMAIL" --arg n "Ordinary" --arg p "$PASSWORD" '{email:$e,name:$n,password:$p}')
cv_http POST /auth/register "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; }
login_request "$EMAIL" "$PASSWORD"
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
[ -n "$TOKEN" ] || { echo "setup failed: no token"; exit 1; }

cv_step When "ordinary customer and anonymous caller POST arbitrary products" $LINENO
SKU="SEC-ROLE-${SFX}"
cv_http POST /products "$(jq -nc --arg s "$SKU" '{name:"<b>arbitrary</b>",description:"set by any caller",sku:$s,priceCents:0}')" -H "Authorization: Bearer $TOKEN"
S_USER=$CV_HTTP_STATUS
OWNER=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.product | (.ownerId // .createdBy // .userId // empty)' 2>/dev/null)
cv_http POST /products "$(jq -nc --arg s "${SKU}-ANON" '{name:"anon",description:"x",sku:$s,priceCents:1}')"
S_ANON=$CV_HTTP_STATUS

cv_step Then "decide whether any role or ownership check exists" $LINENO
EVID="ordinary self-registered customer POST /products ${S_USER} (owner field: ${OWNER:-none}); anonymous ${S_ANON}"
if [ "$S_USER" = "201" ] || [ "$S_ANON" = "201" ]; then
  printf 'CV_SECURITY|vulnerable|design|serious|%s|%s\n' "$TITLE" "$EVID"
else
  printf 'CV_SECURITY|secure|design|serious|%s|%s\n' "$TITLE" "$EVID"
fi
exit 0
