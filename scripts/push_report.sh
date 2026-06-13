#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

bash scripts/check_vps.sh

git add reports/latest_status.txt reports/status_*.txt

git commit -m "Update VPS status report $(date -Is)" || true

git push
