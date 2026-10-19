#!/bin/sh
# Замер всей выдачи поиска на Mac. -v — построчно по запросам.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
swift build -c release --package-path "$root/Tools/search-bench" -q
"$root/Tools/search-bench/.build/release/search-bench" "$root/Benchmarks/search.json" "$@"
