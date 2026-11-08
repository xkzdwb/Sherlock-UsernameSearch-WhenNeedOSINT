#!/usr/bin/env bash
# 同上，macOS / Linux 版
#
#   ./run.sh github
#   ./run.sh github --print-all
#
# 自动补 --local，理由见 README。
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -x .venv/bin/python ]; then
  echo "找不到虚拟环境 .venv，先跑：python3 -m pip install -r requirements.txt" >&2
  exit 1
fi

mkdir -p results
cd results
exec ../.venv/bin/python -m sherlock_project "$@" --local
