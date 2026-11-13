#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# PocketDesk must not carry PairDesk's identifiers (a PairDesk phone must not
# pair with it, and the other way round). Fails if "pairdesk" or "madhushan"
# shows up outside the credits. Allowed: LICENSE, NOTICE, README.md, and any
# line that credits the upstream project or its author.
set -euo pipefail
cd "$(dirname "$0")/.."
hits=$(git grep -Iin -e 'pairdesk' -e 'madhushan' -- . \
  ':!LICENSE' ':!NOTICE' ':!README.md' ':!tools/check-names.sh' \
  | grep -viE 'Sandun Madhushan|sandunMadhushan/pairdesk|Based on PairDesk|official PairDesk app' || true)
paths=$(git ls-files | grep -iE 'pairdesk|madhushan' || true)
if [ -n "$hits$paths" ]; then
  echo "Leftover PairDesk identifiers:"
  [ -n "$hits" ] && echo "$hits"
  [ -n "$paths" ] && echo "$paths"
  exit 1
fi
echo "No leftover PairDesk identifiers."
