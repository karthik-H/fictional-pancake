#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3055161553_20261025161623/api/_infra.sh

# Given
cv_step Given "a real token, a tampered copy, a garbage token and an expired-looking token" $LINENO
SFX=$(cv_suffix)
EMAIL="badtok.${SFX}@example.test"
PASSWORD="Secret-${SFX}"
register_user "$EMAIL" "Bad Token" "$PASSWORD" $LINENO
login_user "$EMAIL" "$PASSWORD" $LINENO
SIG=${TOKEN#*.}
EXPIRED_BODY=$(printf '{"sub":"%s","email":"%s","exp":1000}' "$USER_ID" "$EMAIL" | base64 -w0 | tr '+/' '-_' | tr -d '=')
EXPIRED="${EXPIRED_BODY}.${SIG}"
TAMPERED="${TOKEN%.*}x.${SIG}"
GARBAGE="not-a-token-${SFX}"

# When
cv_step When "POST /products with each invalid token" $LINENO
cv_http POST /products "$(product_body "Bad tok 1" "CV-BADTOK1-${SFX}" 100)" -H "Authorization: Bearer $GARBAGE"
S1=$CV_HTTP_STATUS; E1=$(printf '%s' "$CV_HTTP_BODY" | jq -r '.error // empty')
cv_http POST /products "$(product_body "Bad tok 2" "CV-BADTOK2-${SFX}" 100)" -H "Authorization: Bearer $TAMPERED"
S2=$CV_HTTP_STATUS
cv_http POST /products "$(product_body "Bad tok 3" "CV-BADTOK3-${SFX}" 100)" -H "Authorization: Bearer $EXPIRED"
S3=$CV_HTTP_STATUS

# Then
cv_step Then "each request is rejected with 401 and no product is created" $LINENO
[ "$S1" = "401" ] || cv_fail "expected 401 for garbage token got $S1" $LINENO
[ "$E1" = "Invalid or expired token" ] || cv_fail "expected error 'Invalid or expired token' got '$E1'" $LINENO
[ "$S2" = "401" ] || cv_fail "expected 401 for tampered token got $S2" $LINENO
[ "$S3" = "401" ] || cv_fail "expected 401 for expired token got $S3" $LINENO
for n in 1 2 3; do
  if catalog_has_sku "CV-BADTOK${n}-${SFX}"; then cv_fail "expected CV-BADTOK${n} absent got present" $LINENO; fi
done

# Cleanup
cv_step Cleanup "nothing to delete: users and products live in app memory with no delete route; values are unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:create_product_with_invalid_or_expired_session"
