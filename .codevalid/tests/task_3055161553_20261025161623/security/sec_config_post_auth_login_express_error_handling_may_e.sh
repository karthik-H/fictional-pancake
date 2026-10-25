#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

cv_step Given "no data needed; craft inputs that make the login flow throw" $LINENO
cv_http GET /products
[ "$CV_HTTP_STATUS" = "200" ] || { echo "app unreachable: $CV_HTTP_STATUS"; exit 1; }

cv_step When "send malformed JSON and unexpected types to POST /auth/login" $LINENO
LEAK=""; CODES=""
for payload in '{"email":"a@b.c","password":' '{"email":{"$ne":1},"password":"x"}' '{"email":"a@b.c","password":"\u0000"}' '[1,2,3]' '"just-a-string"'; do
  cv_http POST /auth/login "$payload"
  CODES="$CODES$CV_HTTP_STATUS "
  if printf '%s' "$CV_HTTP_BODY" | grep -Eiq 'at [A-Za-z0-9_.<>]+ \(|node_modules|/app/|SyntaxError|stack|<pre>|Error:'; then
    LEAK="$LEAK[$(printf '%s' "$CV_HTTP_BODY" | tr -d '|\n' | head -c 80)]"
  fi
done
cv_http POST /auth/login 'not json at all' -H 'Content-Type: application/json'
CODES="$CODES$CV_HTTP_STATUS"
if printf '%s' "$CV_HTTP_BODY" | grep -Eiq 'at [A-Za-z0-9_.<>]+ \(|node_modules|/app/|SyntaxError|stack|<pre>|Error:'; then
  LEAK="$LEAK[$(printf '%s' "$CV_HTTP_BODY" | tr -d '|\n' | head -c 80)]"
fi

cv_step Then "decide whether internals leaked" $LINENO
if [ -n "$LEAK" ]; then
  printf 'CV_SECURITY|vulnerable|config|warning|Express error handling may expose internal errors from login route|codes=%s leaked=%s\n' "$CODES" "$LEAK"
else
  printf 'CV_SECURITY|secure|config|warning|Express error handling may expose internal errors from login route|codes=%s; no stack traces paths or exception text in bodies\n' "$CODES"
fi
exit 0
