#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

cv_step Given "register an account" $LINENO
SFX=$(cv_suffix)
EMAIL="profile.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
BODY=$(jq -nc --arg e "$EMAIL" --arg n "Profile Probe" --arg p "$PASSWORD" '{email:$e,name:$n,password:$p}')
cv_http POST /auth/register "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; }

cv_step When "sign in with valid credentials" $LINENO
login_request "$EMAIL" "$PASSWORD"
[ "$CV_HTTP_STATUS" = "200" ] || { echo "setup failed: login returned $CV_HTTP_STATUS"; exit 1; }

cv_step Then "inspect the user object returned beside the token" $LINENO
TOP=$(printf '%s' "$CV_HTTP_BODY" | jq -r 'keys | join(",")')
UKEYS=$(printf '%s' "$CV_HTTP_BODY" | jq -r '(.user // {}) | keys | join(",")')
TITLE="Login endpoint returns detailed user profile alongside token, increasing exposure on auth route"
if [ -n "$UKEYS" ]; then
  printf 'CV_SECURITY|vulnerable|design|warning|%s|%s\n' "$TITLE" "200 login body keys [${TOP}] with user fields [${UKEYS}] beside token"
else
  printf 'CV_SECURITY|secure|design|warning|%s|%s\n' "$TITLE" "200 login body keys [${TOP}] and no user profile"
fi
exit 0
