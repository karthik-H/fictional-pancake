#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

cv_step Given "register two accounts with the same distinctive password" $LINENO
SUF=$(cv_suffix)
E1="sec-cr1-${SUF}@example.test"; E2="sec-cr2-${SUF}@example.test"
PASS="CvPlainCanary-${SUF}"
cv_http POST /auth/register "$(reg_body "$E1" "Crypto One" "$PASS")"
S1="$CV_HTTP_STATUS"; B1="$CV_HTTP_BODY"
cv_http POST /auth/register "$(reg_body "$E2" "Crypto Two" "$PASS")"
S2="$CV_HTTP_STATUS"
if [ "$S1" != "201" ] || [ "$S2" != "201" ]; then echo "setup failed: register $S1/$S2"; delete_user_email "$E1"; delete_user_email "$E2"; exit 1; fi

cv_step When "inspect stored user rows" $LINENO
H1=$(db_psql -tA -c "SELECT password_hash FROM users WHERE email = '$E1'") || { echo "db read failed"; exit 1; }
H2=$(db_psql -tA -c "SELECT password_hash FROM users WHERE email = '$E2'")
ROWDUMP=$(db_psql -tA -c "SELECT row_to_json(u)::text FROM users u WHERE email IN ('$E1','$E2')")

cv_step Then "verdict" $LINENO
TITLE="Plaintext password passed to createUser without visible hashing"
VULN=""
case "$ROWDUMP" in *"$PASS"*) VULN="plaintext password found in users row" ;; esac
case "$B1" in *"$PASS"*) VULN="${VULN:-plaintext password echoed in register response}" ;; esac
[ "$H1" = "$H2" ] && VULN="${VULN:-identical stored values for identical passwords (unsalted)}"
printf '%s' "$H1" | grep -Eq '^[0-9a-f]{32}:[0-9a-f]{128}$' || VULN="${VULN:-stored value not in salted-hash format}"
delete_user_email "$E1"; delete_user_email "$E2"
if [ -n "$VULN" ]; then
  printf 'CV_SECURITY|vulnerable|crypto|critical|%s|%s\n' "$TITLE" "$VULN"
else
  printf 'CV_SECURITY|secure|crypto|critical|%s|%s\n' "$TITLE" "register 201; stored password_hash is salt:scrypt-hex (len ${#H1}) and differs for equal passwords; no plaintext in row or response"
fi
exit 0
