#!/usr/bin/env bash
set -euo pipefail
source .codevalid/tests/task_3339250984_20261025161623/api/_infra.sh

# Given
cv_step Given "the catalog holds at least 3 products (2 seeded + 1 created)" $LINENO
cv_seed_product
cv_http GET /products 200
total=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$total" -ge 3 ] || cv_fail "expected at least 3 products in catalog got $total" $LINENO

# When
cv_step When "anonymous GET /products?page=1&pageSize=1" $LINENO
cv_http GET "/products?page=1&pageSize=1"

# Then
cv_step Then "200 with a paginated subset of exactly 1 product" $LINENO
[ "$CV_HTTP_STATUS" = "200" ] || cv_fail "expected 200 got $CV_HTTP_STATUS" $LINENO
n=$(printf '%s' "$CV_HTTP_BODY" | jq '.products | length')
[ "$n" = "1" ] || cv_fail "expected 1 product for pageSize=1 got $n (of $total total)" $LINENO

# Cleanup
cv_step Cleanup "nothing to remove: the app has no product/user delete endpoint and its store is in-memory; data is unique per run" $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:catalog_filtered_or_paginated"
