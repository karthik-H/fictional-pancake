#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

cv_step Given "unique email for conflict probing" $LINENO
SUF=$(cv_suffix)
EMAIL="sec-au-${SUF}@example.test"
TMP=$(mktemp -d)

cv_step When "register the same email concurrently (ConflictError path) and then again (pre-check path)" $LINENO
for i in 1 2 3; do
  ( command curl -sS -m 20 -o "$TMP/b$i" -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
      --data "$(reg_body "$EMAIL" "Dup $i" "Pw-au-$i-${SUF}")" "$(app_url /auth/register)" > "$TMP/c$i" || echo 000 > "$TMP/c$i" ) &
done
wait
for i in 1 2 3; do echo "concurrent $i: $(cat "$TMP/c$i") $(cat "$TMP/b$i")"; done
cv_http POST /auth/register "$(reg_body "$EMAIL" "Dup 4" "Pw-au-4-${SUF}")"
S4="$CV_HTTP_STATUS"; B4="$CV_HTTP_BODY"
CREATED=0; for i in 1 2 3; do [ "$(cat "$TMP/c$i")" = "201" ] && CREATED=$((CREATED+1)); done
if [ "$CREATED" -lt 1 ]; then echo "setup failed: no registration succeeded"; rm -rf "$TMP"; delete_user_email "$EMAIL"; exit 1; fi
MSGS=$(for i in 1 2 3; do [ "$(cat "$TMP/c$i")" = "409" ] && jq -r '.error // empty' "$TMP/b$i"; done; printf '%s' "$B4" | jq -r '.error // empty' 2>/dev/null)
MSGS=$(printf '%s' "$MSGS" | sort -u | tr '\n|' '; ')

cv_step Then "verdict" $LINENO
rm -rf "$TMP"; delete_user_email "$EMAIL"
TITLE="Identification of existing accounts via detailed conflict error messages"
if [ "$S4" = "409" ] || printf '%s' "$MSGS" | grep -Eiq 'already|exists|registered|unique|duplicate'; then
  printf 'CV_SECURITY|vulnerable|auth|warning|%s|%s\n' "$TITLE" "duplicate email -> $S4 with error messages: $MSGS"
else
  printf 'CV_SECURITY|secure|auth|warning|%s|%s\n' "$TITLE" "duplicate email -> $S4 with generic messages: $MSGS"
fi
exit 0
