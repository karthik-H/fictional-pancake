#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

cv_step Given "register a known account" $LINENO
SFX=$(cv_suffix)
EMAIL="brute.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
BODY=$(jq -nc --arg e "$EMAIL" --arg n "Brute" --arg p "$PASSWORD" '{email:$e,name:$n,password:$p}')
cv_http POST /auth/register "$BODY"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; }

cv_step When "send 25 rapid wrong-password logins then the correct one" $LINENO
C401=0; C429=0; OTHER=0; MAXMS=0
for i in $(seq 1 25); do
  login_request "$EMAIL" "guess-${i}-${SFX}"
  case "$CV_HTTP_STATUS" in 401) C401=$((C401+1));; 429) C429=$((C429+1));; *) OTHER=$((OTHER+1));; esac
  [ "$CV_HTTP_MS" -gt "$MAXMS" ] && MAXMS=$CV_HTTP_MS
done
login_request "$EMAIL" "$PASSWORD"
FINAL=$CV_HTTP_STATUS

cv_step Then "decide whether any throttling or lockout occurred" $LINENO
EVID="25 wrong-password attempts: ${C401}x401 ${C429}x429 ${OTHER}x other; max ${MAXMS}ms; correct password afterwards ${FINAL}"
if [ "$C429" -eq 0 ] && [ "$OTHER" -eq 0 ] && [ "$FINAL" = "200" ]; then
  printf 'CV_SECURITY|vulnerable|auth|serious|%s|%s\n' "No rate limiting or lockout on POST_login allows credential stuffing and brute-force attacks" "$EVID"
else
  printf 'CV_SECURITY|secure|auth|serious|%s|%s\n' "No rate limiting or lockout on POST_login allows credential stuffing and brute-force attacks" "$EVID"
fi
exit 0
