#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="xfemcustom"
ROOT_DIR="${HOME}/Documents/xfemcustom"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="$2"; shift 2;;
    --root) ROOT_DIR="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [--env NAME] [--root DIR]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if ! command -v conda >/dev/null 2>&1; then
  echo "Error: conda not found in PATH." >&2
  exit 1
fi
# Conda activation hooks rely on unset variables; temporarily relax -u.
set +u
eval "$(conda shell.bash hook)"
conda activate "${ENV_NAME}"
set -u

BUILD_DIR="${ROOT_DIR}/build/ngsxfem"
if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build directory not found: ${BUILD_DIR}" >&2
  exit 1
fi

echo "Rebuilding ngsxfem in env ${ENV_NAME} from ${BUILD_DIR} ..."
cmake --build "${BUILD_DIR}" -j"$(nproc)"
cmake --install "${BUILD_DIR}"
echo "Done."
