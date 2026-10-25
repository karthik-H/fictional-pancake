#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

cv_step Given "register a customer with a known email" $LINENO
SUF=$(cv_suffix)
EMAIL="sec-bf-${SUF}@example.test"
PASS="Pw-bf-${SUF}"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,name:"Brute",password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register $CV_HTTP_STATUS"; exit 1; }

cv_step When "send 25 wrong-password login attempts then the correct one" $LINENO
C401=0; C429=0; OTHER=0; FIRST_MS=0; LAST_MS=0
for i in $(seq 1 25); do
  cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "wrong-$i-$SUF" '{email:$e,password:$p}')"
  case "$CV_HTTP_STATUS" in 401) C401=$((C401+1));; 429) C429=$((C429+1));; *) OTHER=$((OTHER+1));; esac
  [ "$i" = "1" ] && FIRST_MS=$CV_HTTP_MS
  LAST_MS=$CV_HTTP_MS
done
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:$p}')"
FINAL=$CV_HTTP_STATUS

cv_step Then "decide whether any throttling or lockout occurred" $LINENO
delete_user_email "$EMAIL"
EV="25 wrong attempts: 401=$C401 429=$C429 other=$OTHER; first=${FIRST_MS}ms last=${LAST_MS}ms; correct password after = $FINAL"
if [ "$C401" = "25" ] && [ "$FINAL" = "200" ] && [ "$LAST_MS" -lt $((FIRST_MS * 5 + 1000)) ]; then
  printf 'CV_SECURITY|vulnerable|auth|serious|Login endpoint allows unlimited password attempts (no brute-force protection)|%s\n' "$EV"
else
  printf 'CV_SECURITY|secure|auth|serious|Login endpoint allows unlimited password attempts (no brute-force protection)|%s\n' "$EV"
fi
exit 0
