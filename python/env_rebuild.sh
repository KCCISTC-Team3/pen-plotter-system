#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
ENV_NAME="python_env"

conda env remove -n "${ENV_NAME}" -y || true
conda env create -f environment.yml