#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_5149952591_20261025161623/api/_infra.sh

# Given
cv_step Given "store writes for the email are delayed so both uniqueness pre-checks interleave" $LINENO
SUF=$(cv_suffix)
EMAIL="reg-il-${SUF}@example.test"
TAG="il_${SUF}"
trap 'drop_insert_trigger "$TAG"' EXIT
cv_prereq "install a users insert trigger that delays 3s for $EMAIL only" $LINENO
add_insert_trigger "$TAG" "$EMAIL" "PERFORM pg_sleep(3); RETURN NEW;" \
  || cv_fail "could not install delay trigger" $LINENO
TMP=$(mktemp -d)

# When
cv_step When "two registrations for the same email are sent concurrently" $LINENO
for i in 1 2; do
  ( command curl -sS -m 30 -o "$TMP/b$i" -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
      --data "$(reg_body "$EMAIL" "Racer $i" "Pw-il-$i-${SUF}")" "$(app_url /auth/register)" > "$TMP/c$i" ) &
done
wait
C1=$(cat "$TMP/c1" 2>/dev/null); C2=$(cat "$TMP/c2" 2>/dev/null)
C1=${C1:-000}; C2=${C2:-000}
echo "responses: $C1 $(cat "$TMP/b1") | $C2 $(cat "$TMP/b2")"
cv_http POST "$(app_url /auth/register)" "$C1" 0
cv_http POST "$(app_url /auth/register)" "$C2" 0

# Then
cv_step Then "exactly one 201 and one 409, one stored account" $LINENO
SORTED=$(printf '%s\n%s\n' "$C1" "$C2" | sort | tr '\n' ' ')
[ "$SORTED" = "201 409 " ] || cv_fail "expected one 201 and one 409 got $C1 and $C2" $LINENO
COUNT=$(user_count "$EMAIL")
[ "$COUNT" = "1" ] || cv_fail "expected exactly 1 account for $EMAIL got $COUNT" $LINENO

# Cleanup
cv_step Cleanup "remove trigger, user and temp files" $LINENO
drop_insert_trigger "$TAG"
delete_user_email "$EMAIL"
rm -rf "$TMP"
echo "CODEVALID_TEST_ASSERTION_OK:register_async_interleaved_uniqueness_enforced"
