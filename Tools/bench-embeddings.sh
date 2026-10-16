#!/bin/sh
# Замер смыслового поиска на Mac: те же файлы провайдеров, что в приложении.
# GEMINI_API_KEY=... Tools/bench-embeddings.sh — добавит облако для сравнения.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
llm="$root/Remember/Remember/AI/LLM"
out="${TMPDIR:-/tmp}/embedding-bench"
swiftc -O -swift-version 5 -o "$out" \
  "$llm/LLMProvider.swift" "$llm/OnDeviceEmbeddingProvider.swift" "$llm/GeminiProvider.swift" \
  "$root/Tools/embedding-bench/main.swift"
"$out" "$root/Benchmarks/semantic-search.json"
