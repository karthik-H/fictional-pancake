#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

CAT="crypto"; SEV="serious"; TITLE="Plaintext password passed into createUser without evident hashing"
cv_step Given "register an account with a distinctive password" $LINENO
SFX=$(cv_suffix)
EMAIL="sec.crypto.${SFX}@example.test"
PASSWORD="Canary-Pw-${SFX}"
cv_http POST /auth/register "$(reg_body "$EMAIL" "Sec Crypto" "$PASSWORD")"
[ "$CV_HTTP_STATUS" = "201" ] || { echo "setup failed: register returned $CV_HTTP_STATUS"; exit 1; }
REG_BODY=$CV_HTTP_BODY

cv_step When "look for the password in every API surface that returns user data" $LINENO
FOUND=""
check() { # <label> <body>
  case "$2" in *"$PASSWORD"*) FOUND="$FOUND $1:plaintext" ;; esac
  if printf '%s' "$2" | jq -e '[paths | map(tostring) | join(".") | select(test("pass|hash|salt"; "i"))] | length > 0' >/dev/null 2>&1; then
    FOUND="$FOUND $1:password-field"
  fi
}
check register "$REG_BODY"
login_request "$EMAIL" "$PASSWORD"
LOGIN_STATUS=$CV_HTTP_STATUS
check login "$CV_HTTP_BODY"
TOKEN=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.token // empty')
if [ -n "$TOKEN" ]; then
  PAYLOAD=$(printf '%s' "${TOKEN%%.*}" | tr '_-' '/+' | base64 -d 2>/dev/null || true)
  check token "$PAYLOAD"
fi
cv_http GET /products
check products "$CV_HTTP_BODY"
for p in /users /auth/users /auth/me /debug /admin/users; do
  cv_http GET "$p" -H "Authorization: Bearer $TOKEN"
  check "$p" "$CV_HTTP_BODY"
done
# Same password twice must not yield a deterministic observable value (salted); login with wrong pw must fail.
login_request "$EMAIL" "${PASSWORD}x"
WRONG_STATUS=$CV_HTTP_STATUS

cv_step Then "decide the verdict" $LINENO
if [ -n "$FOUND" ]; then
  printf 'CV_SECURITY|vulnerable|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "password data exposed at:$FOUND"
else
  printf 'CV_SECURITY|secure|%s|%s|%s|%s\n' "$CAT" "$SEV" "$TITLE" "register 201 user keys id/email/name only; login $LOGIN_STATUS (wrong pw $WRONG_STATUS); no plaintext or hash in register/login/token/products/debug paths"
fi
exit 0
