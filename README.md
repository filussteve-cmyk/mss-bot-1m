# MSS-1M Bot — ICT Market Structure Shift, 1-minute variant (ES, paper only)

**Experimental A/B variant** of the MSS bot in `~/workspace/mss-bot`,
built Nov 19, 2026 at Steve's direction ("try a version where the
whole set up is on the 1m bar instead of the 15 minute bars"). This
bot is a self-contained copy: it has its own `config.yaml`,
`state.json`, and `paper-YYYY-MM-DD.log`, so it can run side by side
with the 15m original without colliding.

Paper-only bot that trades the ICT Market Structure Shift (MSS) setup
on ES front month. It frames HTF bias on 1H bars (unchanged — bias is
context, not part of the setup), detects a liquidity sweep →
displacement (FVG + order block) → market structure shift **on
1-minute bars**, and enters on the retracement into the displacement
FVG with a limit at the FVG midpoint, fill-checked on 1-minute bars.
It places **ZERO real orders** — fills are simulated in
`paper_exec.py`.

**Deliberate differences from the 15m original — exactly two:**
1. **Timeframe:** detection (sweep / displacement / FVG / order block /
   MSS) and execution (fill checks) run on 1m bars instead of
   15m detection + 5m execution.
2. **Pending-setup lifetime: 10 minutes** (10 × 1m bars,
   `setup_max_bars_1m: 10`) instead of 60 minutes (12 × 5m bars).
   Steve's choice, Nov 19, 2026.

Every other rule and threshold is identical to the original, so the
comparison isolates the timeframe plus that one lifetime change.

Sources (ICT / @innercircletrader):
- 2022 ICT Mentorship Ep.3 "Internal Range Liquidity & Market Structure
  Shifts" — https://www.youtube.com/watch?v=nQfHZ2DEJ8c
- "Essentials To ICT Market Structure" —
  https://www.youtube.com/watch?v=xGFCIUFxsbw
- 2022 Mentorship Ep.12 "Advanced Study On Market Structure" —
  https://www.youtube.com/watch?v=8GkQfdAXZP0

## Strategy rules (bullish described; bearish is the mirror)

1. **HTF bias first** — 1H swing structure (see `htf_bias()`). Trade
   only in the HTF direction; if bias is unclear, do nothing.
2. **Liquidity sweep** — on 1m bars, price trades below an old/equal
   swing low (sell stops) or above an old/equal swing high (buy
   stops). A sweep alone is NOT a signal.
3. **Displacement** — a sharp one-sided move away from the sweep that
   leaves a Fair Value Gap (FVG): 3-candle gap (bullish:
   `bar[i-2].high < bar[i].low`). Displacement also defines the order
   block (consecutive down-closed candles before a bullish move).
4. **Market Structure Shift** — price trades through the short-term
   swing high formed immediately before the swept low. No close
   above/below is required — trading through is enough (Ep.3).
5. **Entry** — wait for retracement into the displacement FVG. Limit
   at the FVG 50% midpoint, fill-checked on 1m bars. Never chase
   displacement. Entry window 09:30–15:50 ET (ICT teaches 8:30am–noon
   NY; Steve extended the window to 15:50 on Nov 17, 2026).
6. **Stops / invalidation** — stop beyond the swept level / order
   block. The idea is void if price gaps through the swept level
   without filling, if HTF bias flips away from the setup, if no fill
   comes **within 10 one-minute bars (10 minutes)**, or if the entry
   window ends.
7. **Targets** — opposing liquidity (nearest prior swing beyond the
   broken trigger level) if it pays ≥ 1.5R, else a 2R measured move.

## Mechanical choices

ICT teaches these concepts discretionarily. Every open point below is
a named parameter in `config.yaml` (`mss:` block) with the default
shown. Values match the 15m original except where marked.

| Open point | Mechanical choice (default) | Why |
|---|---|---|
| Displacement size threshold (ICT gives none) | `min_displacement_points: 3.5` ES points, leg starting within 5 bars of the sweep, at most 3 same-direction candles (bars are 1m here) | Same numbers as the 15m original, deliberately — on 1m bars a ≥3.5-pt leg inside ≤3 candles is a much sharper move than on 15m bars, which is part of what the A/B measures |
| Which swing counts | Fractal extreme of **±2 bars** on 1m (`swing_lookback_1m: 2`), same ±2 on 1H | ±2 is the short-term swing ICT draws by hand; on 1m bars swings confirm after 2 minutes instead of 30 |
| Order-block length | ≥ 2 consecutive opposite-closed candles to count (`ob_min_candles: 2`), at most 5 used for the zone (`ob_max_candles: 5`) | A single down candle is noise; 2+ is a real push. The OB zone is the full run's [low, high]. No OB found → the setup still trades (FVG is the entry zone, OB is secondary) |
| FVG entry level | Limit at the **FVG 50% midpoint** (`entry_zone: "fvg_mid"`); fill when a 1m bar trades through the midpoint | The midpoint is the ICT "equilibrium" of the gap and the standard retracement entry; a limit there cannot chase. `ob_mid` is available in config as an alternative |
| Pending-setup lifetime | **10 × 1m bars = 10 minutes** (`setup_max_bars_1m: 10`) — DIFFERS from the original's 12 × 5m bars = 60 minutes | Steve's choice for the 1m variant (Nov 19, 2026): on a 1-minute frame a retracement that hasn't come back in 10 minutes is a different idea, not a late fill |
| Stop distance | Beyond the swept level / OB by **1.0 pt + 1 tick** (`stop_buffer_points: 1.0`, `stop_buffer_ticks: 1`) = 1.25 pts on ES | 1 tick alone is stop-hunt bait; 1 pt + 1 tick clears the level with room for wick noise. Stop uses the lower of swept level / OB low (longs). Note: on 1m bars the swept level sits much closer to entry than on 15m, so risk per trade is typically far smaller — and 1.25 pts of buffer is a larger fraction of it |
| Target method | **Opposing liquidity first**: nearest confirmed swing beyond the broken trigger level, if it pays ≥ 1.5R (`min_rr: 1.5`); else **2R measured move** (`measured_move_rr: 2.0`) | The trigger itself is excluded — price already traded through it, so it is not opposing liquidity any more |
| HTF bias rule | 1H: bullish iff the last two confirmed swing highs ascend AND the last two swing lows ascend AND the last close holds above the last swing low (mirror for bearish); else neutral = no trade (`bias_lookback_1h_bars: 40`) | Mechanical reading of "market structure" on the higher timeframe (Ep.12). **Unchanged from the original** — the bias frame is context, not part of "the setup" |

**What could NOT be decided mechanically (documented, not hidden):**
- **Displacement vs. "just a strong bar":** ICT never quantifies how
  sharp displacement must be. The 3.5-point / 3-candle rule is a guess
  carried over unchanged from the 15m bot — on 1m bars it is a far
  stricter filter in time terms (3.5 pts inside 3 minutes). If the
  variant fires too rarely, this is the first knob to look at — but
  changing it would end the clean A/B, so it stays for now.
- **50% equilibrium as a target:** ICT lists the range's 50% level as
  a target option. This bot does not use it (opposing liquidity /
  measured move cover the cases); it is not in the code.
- **NY kill zone (7:00–10:00am ET):** the bot trades RTH only, so the
  7:00–9:30 pre-market portion of the kill zone is out of scope. The
  entry window (09:30–15:50) covers the kill zone's RTH portion and
  extends past it, per Steve's Nov 17, 2026 direction.
- **"Old/equal" liquidity age:** ICT prefers sweeping older, more
  obvious pools. The detector treats every confirmed swing as a pool
  with no age weighting — on 1m bars there are far more pools, so
  expect far more sweeps (and near-miss PARTIAL lines) than the 15m
  bot produces.

## Files

| File | What it is |
|---|---|
| `strategy_mss.py` | Sweep / displacement / FVG / order-block / MSS detectors on 1m bars, HTF bias (1H), entry evaluation, target logic, `MssParams` |
| `models.py` | `Bar`, `MssSetup` dataclasses |
| `risk.py` | Pure guards: RTH, 16:00 flatten, 09:30–15:50 entry window, -$500 halt, 1 position, no daily trade cap (unchanged from the original) |
| `paper_exec.py` | Virtual limit entries, stop/target exits on 1m bars, 16:00 flatten. No order code |
| `bot.py` | Poll loop (60s), 1H/1m bar fetch, bias + scan + arm + manage, `--smoke` |
| `config.yaml` | Mode `paper`, ES market, all `mss:` parameters |
| `run_paper.sh` | Paper launcher (forces `MSS1M_FORCE_PAPER=1`) |
| `requirements.txt` | `project-x-py`, `pyyaml`, `polars`, `pytest` |
| `test_strategy_mss.py`, `test_risk.py`, `test_paper_exec.py` | pytest unit tests, synthetic bars only |

## How to run (paper)

```bash
export TOPSTEPX_USERNAME=... TOPSTEPX_API_KEY=... TOPSTEPX_ACCOUNT_ID...
./run_paper.sh            # detached, paper mode, ZERO orders
```

Offline check first (no auth, no orders):

```bash
~/workspace/s4-bot/.venv/bin/python bot.py --smoke
```

State lives in `state.json` (armed setup, pending limit, closed trades,
daily P&L); the daily log is `paper-YYYY-MM-DD.log` — both in this
directory, separate from the 15m bot's.

Near-miss sweeps are logged too, once each, as `PARTIAL MSS-1M ...`
lines (`no_displacement` / `no_fvg` / `no_mss`, with the biggest leg
found vs the 3.5-pt minimum) — a quiet day used to hide whether
anything came close to the displacement threshold. They are also
kept in `state.json` under `partials_today`, and the 16:00 flatten
logs a one-line partials summary for the wrap. Expect many more of
these on 1m bars than the 15m bot logs.

## Guardrails

- 1 contract, ES only, $50/pt. RTH 09:30–16:00 ET, flat by 16:00,
  no overnight. Entry window 09:30–15:50 ET. Max 1 open position,
  no daily paper-trade cap, -$500 paper daily loss halt.
- A setup is decided once, at first detection (take it or skip it);
  it is never carried to a later poll. A pending limit voids on: gap
  through the swept level, HTF bias flip, **10 unfilled 1m bars**,
  or 15:50 ET.
- Detection is a full-session replay over the 1m bars (same pattern as
  the MultiScan scanner), so a restart reproduces the same setup set.

## Test results (Nov 19, 2026)

- `pytest test_strategy_mss.py test_risk.py test_paper_exec.py`:
  **58 passed** — the 15m original's 57 tests adapted to the 1m frame
  (the same synthetic sweep → displacement/FVG → MSS sequence, read
  as 1-minute bars: full bullish + bearish setups arm with entry at
  the FVG midpoint; the no-FVG near-miss reports as a `no_fvg`
  PARTIAL), plus 1 new variant-parameter test pinning the two
  deliberate differences (1m swing param, 10-bar pending lifetime).
- `bot.py --smoke`: **PASSED** — bullish 1H bias → sweep 7640 →
  displacement leaving FVG [7651, 7655] → MSS through 7660 → limit
  fill LONG @ 7653.00 → 2R target 7685.50, **+$1,625.00 paper**,
  zero real orders.
- Live-mode lockout verified: `mode: "live"` → error + exit code 2
  before any authentication. Config restored to `paper`.

## What Steve must approve before live

Same bar as the MultiScan / Push350 bots and the 15m MSS bot: this
bot is paper-only by construction and has never been run against a
live account. Before any live consideration Steve must approve (a)
the strategy itself after seeing paper results, (b) mode `live` plus
a real account ID, and (c) the mechanical choices above — especially
the 3.5-point displacement threshold on 1m bars, which is unvalidated.
The bot refuses to start in live mode today; there is no live code
path to enable by accident. Do NOT push to GitHub (not pushed).
