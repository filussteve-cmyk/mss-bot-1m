#!/usr/bin/env bash
# MSS-1M paper-mode launcher (1-minute experimental variant).
#
# Forces paper mode (MSS1M_FORCE_PAPER=1) even if config.yaml was edited,
# so this script can never place an order. (The bot also refuses to
# start in any mode other than paper — live is not implemented.)
#
# Credentials: set TOPSTEPX_USERNAME / TOPSTEPX_API_KEY / TOPSTEPX_ACCOUNT_ID
# in your environment before running. This script does NOT read
# ~/workspace/trading-bot/.env and never prints credentials.
#
# Usage: ./run_paper.sh        # starts bot.py detached in paper mode
set -euo pipefail
cd "$(dirname "$0")"

export MSS1M_FORCE_PAPER=1

[ -n "${TOPSTEPX_USERNAME:-}" ] && [ -n "${TOPSTEPX_API_KEY:-}" ] \
  || { echo "Set TOPSTEPX_USERNAME and TOPSTEPX_API_KEY in the environment first." >&2; exit 1; }

if [ -x .venv/bin/python ]; then PY=.venv/bin/python;
elif [ -x ~/workspace/s4-bot/.venv/bin/python ]; then PY=~/workspace/s4-bot/.venv/bin/python;
else PY=python3; fi
"$PY" -m pip install -q -r requirements.txt

LOG="paper-$(date +%F).log"
nohup "$PY" bot.py > "$LOG" 2>&1 &
echo "MSS-1M paper bot started, PID $!. Log: $LOG"
echo "Paper mode: reads ES 1m bars, detects ICT market structure shifts, simulates fills, places ZERO orders."
echo "Offline check instead (no auth, no orders): $PY bot.py --smoke"
