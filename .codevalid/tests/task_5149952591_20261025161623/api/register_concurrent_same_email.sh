#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "an unused email and two request bodies with different passwords" $LINENO
SFX=$(cv_suffix)
EMAIL="race.${SFX}@example.test"
PW_A="Race-Pass-A-${SFX}"
PW_B="Race-Pass-B-${SFX}"
TMPD=$(mktemp -d)
cv_http GET /products 200

# When
cv_step When "send both registrations concurrently" $LINENO
for t in A B; do
  pw=PW_$t
  ( command curl -sS -o "$TMPD/$t.body" -w '%{http_code}' -H 'Content-Type: application/json' \
      --data "$(reg_body "$EMAIL" "Racer $t" "${!pw}")" "$BASE_URL/auth/register" > "$TMPD/$t.code" ) &
done
wait
SA=$(cat "$TMPD/A.code"); SB=$(cat "$TMPD/B.code")
cv_http POST "$BASE_URL/auth/register" "$SA" 0
cv_http POST "$BASE_URL/auth/register" "$SB" 0
echo "A: $SA $(cat "$TMPD/A.body")"
echo "B: $SB $(cat "$TMPD/B.body")"

# Then
cv_step Then "exactly one 201 and one 409, and only the winner's password signs in" $LINENO
SORTED=$(printf '%s\n%s\n' "$SA" "$SB" | sort | tr '\n' ' ')
[ "$SORTED" = "201 409 " ] || cv_fail "expected one 201 and one 409 got A=$SA B=$SB" $LINENO
if [ "$SA" = "201" ]; then WIN=$PW_A; LOSE=$PW_B; else WIN=$PW_B; LOSE=$PW_A; fi
login_request "$EMAIL" "$WIN"
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected winner password login 200 got $CV_HTTP_STATUS" $LINENO
login_request "$EMAIL" "$LOSE"
[ "$CV_HTTP_STATUS" = "401" ] || cv_fail "expected loser password login 401 got $CV_HTTP_STATUS" $LINENO

# Cleanup
cv_step Cleanup "remove temp files; users live in app memory with no delete route" $LINENO
rm -rf "$TMPD"

echo "CODEVALID_TEST_ASSERTION_OK:register_concurrent_same_email"
