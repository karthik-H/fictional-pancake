#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "registered customer and a unique secret password marker" $LINENO
SUF=$(cv_suffix)
EMAIL="login-malf-${SUF}@example.test"
PASS="Pw-malf-${SUF}"
register_user "$EMAIL" "Malformed Customer" "$PASS" $LINENO
RESULTS=()

# When
cv_step When "send malformed JSON, missing fields and extra-field payloads to login" $LINENO
cv_http POST /auth/login "{\"email\":\"$EMAIL\",\"password\":\"$PASS\""
RESULTS+=("malformed-json|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /auth/login "$(jq -nc --arg p "$PASS" '{password:$p}')"
RESULTS+=("missing-email|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" '{email:$e}')"
RESULTS+=("missing-password|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,pass:$p,role:"admin",extra:{x:1}}')"
RESULTS+=("extra-fields-no-password|$CV_HTTP_STATUS|$CV_HTTP_BODY")
cv_http POST /auth/login "$(jq -nc --arg e "$EMAIL" --arg p "$PASS" '{email:$e,password:[$p]}')"
RESULTS+=("password-wrong-type|$CV_HTTP_STATUS|$CV_HTTP_BODY")

# Then
cv_step Then "each request is a 4xx validation or parse error without password or internals" $LINENO
for r in "${RESULTS[@]}"; do
  NAME=${r%%|*}; REST=${r#*|}; CODE=${REST%%|*}; BODY=${REST#*|}
  case "$CODE" in 4??) ;; *) cv_fail "expected 4xx for $NAME got $CODE" $LINENO ;; esac
  case "$BODY" in *"$PASS"*) cv_fail "expected no password echo for $NAME got it in body" $LINENO ;; esac
  case "$BODY" in *token*) cv_fail "expected no token for $NAME" $LINENO ;; esac
  if printf '%s' "$BODY" | grep -Eq 'at [A-Za-z0-9_.<>]+ \(|/app/|node_modules|SyntaxError|password_hash'; then
    cv_fail "expected no internal details for $NAME got: $BODY" $LINENO
  fi
done

# Cleanup
cv_step Cleanup "remove the user" $LINENO
delete_user_email "$EMAIL"
echo "CODEVALID_TEST_ASSERTION_OK:login_async_malformed_payload_no_password_leak"
