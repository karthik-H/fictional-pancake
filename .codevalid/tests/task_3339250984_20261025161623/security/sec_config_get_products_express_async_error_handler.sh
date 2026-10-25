#!/usr/bin/env bash
set -uo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

T="Express async error handler can leak internal errors via default error middleware"
cv_step Given "app reachable; then make the products query fail so listProducts() throws" $LINENO
cv_http GET /products --max-time 15
[ "$CV_HTTP_STATUS" = "200" ] || { echo "app unreachable: $CV_HTTP_STATUS"; exit 1; }
trap 'products_restore' EXIT
products_hide || { echo "cannot hide products table"; exit 1; }

cv_step When "GET /products while the products query fails" $LINENO
cv_http GET /products --max-time 30
S="$CV_HTTP_STATUS"; B="$CV_HTTP_BODY"
CT=$(grep -i '^content-type:' "$CV_HTTP_HEADERS_FILE" | tr -d '\r' | head -1 | cut -d' ' -f2-)

products_restore
for i in 1 2 3 4 5 6 7 8 9 10; do
  cv_http GET /products --max-time 10
  [ "$CV_HTTP_STATUS" = "200" ] && break
  sleep 1
done

cv_step Then "inspect error body for stack traces or internals" $LINENO
SHORT=$(printf '%s' "$B" | tr -d '\n|' | head -c 80)
if printf '%s' "$B" | grep -Eiq 'ECONNREFUSED|ECONNRESET|toxiproxy|5432|at [A-Za-z_.<>]+ \(|/app/|node_modules|\.ts:|\.js:[0-9]|<pre>|Error: |relation|does not exist|products_cv_hidden|SELECT '; then
  printf 'CV_SECURITY|vulnerable|config|warning|%s|GET /products with failing DB query returned %s (%s) exposing internals: %s\n' "$T" "$S" "$CT" "$SHORT"
else
  printf 'CV_SECURITY|secure|config|warning|%s|GET /products with failing DB query returned %s (%s) generic body: %s\n' "$T" "$S" "$CT" "$SHORT"
fi
exit 0
