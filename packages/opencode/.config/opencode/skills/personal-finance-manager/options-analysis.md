# Options Analysis Framework

## The Greeks -- What to Track and Why

| Greek | Measures | Key Threshold | Action Signal |
|---|---|---|---|
| **Delta** | Price sensitivity to $1 move in underlying | ATM ~0.50; target 0.30-0.70 for directional | High delta = more stock-like exposure |
| **Gamma** | Rate of delta change | Highest ATM, near expiry | High gamma near expiry = position can flip fast |
| **Theta** | Time decay per day | Accelerates inside 30 DTE | Sellers want high theta; buyers want to minimize |
| **Vega** | Sensitivity to 1% IV change | Higher for longer-dated options | Long vega before events; short vega after |
| **Rho** | Sensitivity to interest rate changes | Minimal for short-dated | Only matters for LEAPS (>1yr) |

## Implied Volatility Analysis

### IV Rank and IV Percentile

- **IV Rank**: where current IV sits relative to 52-week range. `(current IV - 52wk low) / (52wk high - 52wk low)`
- **IV Percentile**: percentage of days in the past year that IV was lower than current IV

| IV Rank | IV Percentile | Interpretation | Strategy Bias |
|---|---|---|---|
| 0-25% | 0-25% | IV is cheap | Buy premium (long straddles, debit spreads) |
| 25-50% | 25-50% | IV is normal-low | Neutral -- either direction works |
| 50-75% | 50-75% | IV is elevated | Lean toward selling premium |
| 75-100% | 75-100% | IV is expensive | Sell premium (short straddles, credit spreads, iron condors) |

### IV Skew

- **Put skew**: OTM puts more expensive than OTM calls -- normal for equities (crash protection demand)
- **Call skew**: OTM calls more expensive -- indicates speculative demand or squeeze potential
- **Flat skew**: unusual -- may signal complacency or low conviction

### Term Structure

- **Contango** (front month IV < back month IV): normal; short-dated options are cheaper
- **Backwardation** (front month IV > back month IV): event-driven (earnings, FDA, etc.); front month is pricing in near-term risk

## Strategy Selection Matrix

### By Market Outlook

| Outlook | IV Environment | Strategy | Risk Profile |
|---|---|---|---|
| **Bullish** | Low IV | Long calls, bull call spreads | Defined risk, unlimited/capped upside |
| **Bullish** | High IV | Bull put spreads, short puts | Defined risk, collects premium |
| **Bearish** | Low IV | Long puts, bear put spreads | Defined risk |
| **Bearish** | High IV | Bear call spreads, short calls | Defined risk, collects premium |
| **Neutral** | Low IV | Long straddle, long strangle | Profits from move in either direction |
| **Neutral** | High IV | Iron condor, iron butterfly, short strangle | Profits from time decay and IV crush |

### By Earnings Play

| Expectation | Strategy | Rationale |
|---|---|---|
| Big move, direction unknown | Long straddle (buy ATM call + put) | Pays if move > combined premium |
| Expecting IV crush, no big move | Short iron condor | Collects premium, profits from IV collapse |
| Directional conviction pre-earnings | Debit spread in conviction direction | Limits IV crush impact vs naked long |

## Trade Selection Criteria

### Hard Filters (mandatory -- reject trades failing any)

| Filter | Threshold | Rationale |
|---|---|---|
| Quote freshness | <= 10 minutes old | Stale quotes = bad fills |
| Probability of profit (POP) | >= 0.65 (65%) | Minimum edge requirement |
| Credit / max loss ratio | >= 0.33 | Risk-reward floor |
| Max loss per trade | <= 0.5% of NAV | Position sizing discipline |
| Bid-ask spread | <= 10% of mid price | Liquidity filter |

### Scoring and Ranking

After hard filters, rank surviving trades by composite score:

```
model_score = 0.35 * POP_normalized
            + 0.25 * credit_ratio_normalized
            + 0.20 * momentum_z
            + 0.15 * flow_z
            + 0.05 * IV_rank_favorability
```

Where:
- `POP_normalized`: POP scaled 0-1
- `credit_ratio_normalized`: credit/max_loss scaled 0-1
- `momentum_z`: price momentum z-score (positive = trend-aligned)
- `flow_z`: unusual options flow z-score (positive = smart money aligned)
- `IV_rank_favorability`: 1 if selling premium in high IV, or buying in low IV; 0 otherwise

### Portfolio-Level Constraints

| Constraint | Limit | Calculation |
|---|---|---|
| **Net delta** | [-0.30, +0.30] * (NAV / 100k) | Sum of all position deltas |
| **Net vega** | >= -0.05 * (NAV / 100k) | Sum of all position vegas |
| **Sector concentration** | Max 2 trades per GICS sector | Diversification |
| **Correlation** | No two trades on >0.80 correlated underlyings | Avoid hidden concentration |

### Tiebreaker Rules

When two trades have equal `model_score`:
1. Prefer higher `momentum_z`
2. If still tied, prefer higher `flow_z`
3. If still tied, prefer higher liquidity (tighter bid-ask)

## Trade Output Format

Always present exactly 5 trades (or state fewer meet criteria):

```
| # | Ticker | Strategy        | Legs                          | Thesis (<=30 words)                    | POP  |
|---|--------|-----------------|-------------------------------|----------------------------------------|------|
| 1 | AAPL   | Bull put spread | Sell 180P / Buy 175P Mar 28   | Strong earnings momentum, IV rank 72%  | 0.71 |
| 2 | ...    | ...             | ...                           | ...                                    | ...  |
```

Rules:
- Thesis must be <= 30 words, plain language
- No exaggerated claims
- If fewer than 5 trades satisfy all criteria: **"Fewer than 5 trades meet criteria, do not execute."**

## Position Management

### Entry Rules
- Use limit orders at or slightly better than mid price
- For credit spreads: enter when underlying is moving in your favor (sell put spreads on green days, call spreads on red)
- Confirm no earnings within the trade's DTE unless the trade IS an earnings play

### Exit Rules

| Condition | Action |
|---|---|
| Profit target reached (50% of max profit for credit spreads) | Close position |
| 21 DTE remaining on short strikes | Roll or close to avoid gamma risk |
| Underlying breaches short strike | Evaluate: close, roll, or hedge |
| Max loss approached (75% of max loss) | Close -- do not let max loss be realized if avoidable |
| IV crush after event | Close if long premium; hold if short premium |

### Rolling Rules
- Roll for a NET CREDIT only (never roll for a debit)
- Roll to at least 30 DTE out
- If can't roll for credit, close the position and reassess

## Risk Warnings

- Options can expire worthless. Never allocate capital you can't afford to lose entirely.
- Selling naked options (uncovered calls, naked puts) has theoretically unlimited risk. This framework uses DEFINED RISK strategies only unless the user explicitly requests otherwise.
- Early assignment risk exists for American-style options, especially near ex-dividend dates for short calls and deep ITM short puts.
- Liquidity risk: wide bid-ask spreads on illiquid options can mean 5-15% of trade value lost on entry/exit.
