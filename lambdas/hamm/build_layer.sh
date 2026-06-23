#!/usr/bin/env bash
# build_layer.sh — Builds the hamm Lambda Layer using the AWS Lambda Docker image.
# This ensures native libs (PyArrow, PyIceberg) are compiled for Linux x86_64,
# regardless of the host OS (macOS, Windows, etc.).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_BUILD_DIR="${SCRIPT_DIR}/dist/layer/python"
LAYER_ZIP="${SCRIPT_DIR}/dist/hamm_layer.zip"

echo "==> Cleaning previous build..."
rm -rf "${SCRIPT_DIR}/dist/layer"
mkdir -p "${LAYER_BUILD_DIR}"

echo "==> Installing dependencies inside Lambda Docker image (python3.12 / x86_64)..."
docker run --rm \
  --platform linux/amd64 \
  --entrypoint pip \
  -v "${LAYER_BUILD_DIR}:/out" \
  -v "${SCRIPT_DIR}/requirements.txt:/requirements.txt:ro" \
  public.ecr.aws/lambda/python:3.12 \
  install \
    -r /requirements.txt \
    -t /out \
    --no-cache-dir \
    --quiet

echo "==> Zipping layer..."
cd "${SCRIPT_DIR}/dist"
zip -r9 hamm_layer.zip layer/ --quiet

echo "==> Layer built: ${LAYER_ZIP}"
du -sh "${LAYER_ZIP}"
