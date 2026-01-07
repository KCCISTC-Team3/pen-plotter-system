#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

ENV_NAME="python_env"

# Default target if no argument is provided
TARGET="${1:-main.py}"

conda run -n "${ENV_NAME}" python "${TARGET}"
