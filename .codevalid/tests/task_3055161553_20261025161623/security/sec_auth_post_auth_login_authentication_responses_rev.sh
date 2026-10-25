#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

cv_step Given "register a customer; pick an unregistered email" $LINENO
SUF=$(cv_suffix)
EMAIL="sec-enum-${SUF}@example.test"
NOEMAIL="sec-enum-none-${SUF}@example.test"
PASS="Pw-enum-${SUF}"
cv_http POST /auth/register "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,name:"Enum",password:$p}')"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register $CV_HTTP_STATUS"; exit 1; }

cv_step When "compare missing-field, existing-email and unknown-email login responses and timings" $LINENO
cv_http POST /auth/login '{}'
MISSING="$CV_HTTP_STATUS"
EX_MS=0; NO_MS=0; EX_CODES=""; NO_CODES=""; EX_BODY=""; NO_BODY=""
for i in 1 2 3 4 5 6; do
  cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e,password:"Wrong-pass-123"}')"
  EX_MS=$((EX_MS + CV_HTTP_MS)); EX_CODES="$EX_CODES$CV_HTTP_STATUS "; EX_BODY="$CV_HTTP_BODY"
  cv_http POST /auth/login "$(jq -nc --arg e "$NOEMAIL" '{email:$e,password:"Wrong-pass-123"}')"
  NO_MS=$((NO_MS + CV_HTTP_MS)); NO_CODES="$NO_CODES$CV_HTTP_STATUS "; NO_BODY="$CV_HTTP_BODY"
done
EX_AVG=$((EX_MS / 6)); NO_AVG=$((NO_MS / 6))

cv_step Then "decide whether existing accounts are distinguishable" $LINENO
delete_user_email "$EMAIL"
EV="missing fields=$MISSING; existing codes=${EX_CODES% } avg=${EX_AVG}ms; unknown codes=${NO_CODES% } avg=${NO_AVG}ms; bodies equal=$([ "$EX_BODY" = "$NO_BODY" ] && echo yes || echo no)"
DIFF=$((EX_AVG - NO_AVG))
if [ "$EX_CODES" != "$NO_CODES" ] || [ "$EX_BODY" != "$NO_BODY" ] || { [ "$DIFF" -ge 15 ] && [ "$EX_AVG" -ge $((NO_AVG * 2)) ]; }; then
  printf 'CV_SECURITY|vulnerable|auth|warning|Authentication responses reveal that an account exists for a given email|%s\n' "$EV"
else
  printf 'CV_SECURITY|secure|auth|warning|Authentication responses reveal that an account exists for a given email|%s\n' "$EV"
fi
exit 0
