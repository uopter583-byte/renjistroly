#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$ROOT_DIR/Sources/RenJistrolySystemBridge/Resources/NemotronASR"

required_files=(
  "pre_encode.onnx"
  "conformer.onnx"
  "decoder.onnx"
  "prompt.onnx"
  "joint.onnx"
  "tokens.txt"
  "model_info.json"
  "preprocessor.json"
  "prompts.json"
  "tokenizer.json"
)

if ! command -v git-lfs >/dev/null 2>&1; then
  echo "error: git-lfs is not installed or not on PATH" >&2
  exit 1
fi

if ! git -C "$ROOT_DIR" lfs version >/dev/null 2>&1; then
  echo "error: git lfs is not initialized for this Git install" >&2
  exit 1
fi

if [[ ! -d "$ASSET_DIR" ]]; then
  echo "error: missing asset directory: $ASSET_DIR" >&2
  exit 1
fi

missing=0
for file in "${required_files[@]}"; do
  if [[ ! -f "$ASSET_DIR/$file" ]]; then
    echo "error: missing required Nemotron ASR file: $file" >&2
    missing=1
  fi
done

if [[ "$missing" -ne 0 ]]; then
  exit 1
fi

large_patterns=(
  "$ASSET_DIR/conformer.onnx"
  "$ASSET_DIR/onnx__MatMul_7697"
  "$ASSET_DIR/layers.0.conv.depthwise_conv.weight"
  "$ASSET_DIR/Constant_1919_attr__value"
)

for path in "${large_patterns[@]}"; do
  if [[ ! -f "$path" ]]; then
    continue
  fi
  filter="$(git -C "$ROOT_DIR" check-attr filter -- "$path" | awk -F': ' '{print $3}')"
  if [[ "$filter" != "lfs" ]]; then
    echo "error: expected LFS filter for $path, got '$filter'" >&2
    exit 1
  fi
done

file_count="$(find "$ASSET_DIR" -maxdepth 1 -type f | wc -l | tr -d ' ')"
size="$(du -sh "$ASSET_DIR" | awk '{print $1}')"

echo "Nemotron ASR assets OK"
echo "files: $file_count"
echo "size: $size"
echo "git-lfs: $(git -C "$ROOT_DIR" lfs version)"
