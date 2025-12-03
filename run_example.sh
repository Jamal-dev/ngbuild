#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="xfemcustom"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="$2"; shift 2;;
    -h|--help) echo "Usage: $0 [--env NAME]"; exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Running example CppExtension.py using env ${ENV_NAME} ..."
conda run -n "${ENV_NAME}" python -u "${REPO_ROOT}/CppExtension.py"

