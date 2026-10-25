#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

cv_step Given "an already registered email" $LINENO
SUF=$(cv_suffix)
EXIST="sec-de-ex-${SUF}@example.test"; FRESH="sec-de-new-${SUF}@example.test"
PASS="Pw-de-${SUF}-secret"
cv_http POST /auth/register "$(reg_body "$EXIST" "Existing" "$PASS")"
if [ "$CV_HTTP_STATUS" != "201" ]; then echo "setup failed: $CV_HTTP_STATUS"; exit 1; fi

cv_step When "register again with registered and unregistered email" $LINENO
cv_http POST /auth/register "$(reg_body "$EXIST" "Probe" "$PASS")"
SA="$CV_HTTP_STATUS"; BA=$(printf '%s' "$CV_HTTP_BODY" | tr -d '|\n')
cv_http POST /auth/register "$(reg_body "$FRESH" "Probe" "$PASS")"
SB="$CV_HTTP_STATUS"; BB=$(printf '%s' "$CV_HTTP_BODY" | jq -c 'if .user then .user|={id:"<id>"} else . end' 2>/dev/null | tr -d '|\n')

cv_step Then "verdict" $LINENO
delete_user_email "$EXIST"; delete_user_email "$FRESH"
TITLE="Registration endpoint leaks existence of email addresses via distinct conflict responses"
if [ "$SA" != "$SB" ] || printf '%s' "$BA" | grep -qi 'already registered'; then
  printf 'CV_SECURITY|vulnerable|design|warning|%s|%s\n' "$TITLE" "registered email -> $SA $BA; unregistered email -> $SB"
else
  printf 'CV_SECURITY|secure|design|warning|%s|%s\n' "$TITLE" "registered and unregistered emails both returned $SA with indistinguishable bodies"
fi
exit 0
