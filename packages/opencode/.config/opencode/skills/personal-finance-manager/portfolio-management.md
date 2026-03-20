# Portfolio Management Framework

## Asset Allocation Models

### By Risk Profile

Determine the user's risk profile first. If unknown, ask these three questions:
1. What is your investment time horizon? (< 3yr / 3-10yr / 10yr+)
2. How would you react to a 30% portfolio drawdown? (Sell everything / Hold nervously / Buy more)
3. What percentage of your net worth is this portfolio? (< 25% / 25-75% / > 75%)

| Profile | Equities | Fixed Income | Alternatives | Cash |
|---|---|---|---|---|
| **Conservative** (short horizon, low risk tolerance) | 30-40% | 40-50% | 5-10% | 10-15% |
| **Moderate** (medium horizon, moderate tolerance) | 50-60% | 25-35% | 10-15% | 5-10% |
| **Aggressive** (long horizon, high tolerance, small % of NW) | 70-80% | 5-15% | 10-20% | 2-5% |
| **Ultra-aggressive** (long horizon, user explicitly opts in) | 80-90% | 0-5% | 10-20% | 0-5% |

### Sub-Allocation Within Equities

| Category | Conservative | Moderate | Aggressive |
|---|---|---|---|
| US Large Cap (S&P 500) | 60% | 45% | 35% |
| US Mid/Small Cap | 10% | 15% | 20% |
| International Developed | 20% | 20% | 15% |
| Emerging Markets | 5% | 10% | 15% |
| Individual Stocks | 5% | 10% | 15% |

### Alternatives Breakdown

| Asset | Allocation Range | Vehicle |
|---|---|---|
| Crypto (BTC + ETH core) | 0-10% | Direct or ETF (IBIT, ETHA) |
| REITs | 0-5% | VNQ, SCHH, or international equivalents |
| Commodities | 0-5% | GLD, SLV, DBC |
| DeFi yield | 0-3% | Only audited protocols, blue-chip only |

### Fixed Income Options

| Type | When to Use | Vehicle |
|---|---|---|
| US Treasuries | Safety, rate-sensitive | TLT (long), IEF (intermediate), SHV (short) |
| TIPS | Inflation hedge | TIP, SCHP |
| Corporate bonds (IG) | Yield pickup | LQD, VCIT |
| I-Bonds | Up to $10k/yr, inflation-protected | TreasuryDirect.gov |
| Portuguese savings bonds (CTPC) | PT residents, competitive EUR rates | IGCP (certificados.igcp.pt) |

## Core-Satellite Strategy

The recommended approach splits the portfolio into:

**Core (70-80% of portfolio)**:
- Passive, low-cost index funds/ETFs
- Buy-and-hold, rebalanced quarterly
- Tax-efficient (low turnover)

**Satellite (20-30% of portfolio)**:
- Active positions: individual stocks, options, crypto, DeFi
- Higher turnover, actively managed
- Where alpha is generated (or attempted)

This structure ensures the portfolio performs reasonably even if the satellite positions underperform, while giving room for conviction trades.

## Risk Management Rules

### Position Sizing

| Asset Type | Max Single Position | Rationale |
|---|---|---|
| Index ETF | 25% of portfolio | Diversified by nature |
| Individual equity | 5% at cost | Concentration risk |
| Options (single trade) | 0.5% max loss | Leverage risk |
| Single crypto asset | 5% of portfolio | Volatility risk |
| Single DeFi protocol | 2% of portfolio | Smart contract risk |

### Drawdown Limits

| Level | Drawdown | Action |
|---|---|---|
| **Yellow** | -10% from peak | Review positions, confirm theses still valid |
| **Orange** | -20% from peak | Reduce satellite positions by 50%, increase cash |
| **Red** | -30% from peak | Move to core-only (close all satellite), reassess allocation |

These are guidelines. In a broad market correction (everything down), holding through may be appropriate if theses are intact. In an idiosyncratic drawdown (one position cratering), the stop-loss should have already triggered.

### Correlation Management

- No two individual equity positions should have > 0.80 trailing 90-day correlation
- Crypto counts as a single correlated block (BTC, ETH, and alts move together in stress)
- Maintain at least one negatively correlated asset class (Treasuries, gold, or VIX products for hedging)

### Currency Risk

The user earns EUR but may hold USD-denominated investments:
- US equities provide natural USD exposure
- Consider EUR-hedged ETFs for fixed income to avoid double volatility
- Monitor EUR/USD -- a strengthening EUR reduces USD portfolio value in EUR terms
- No need to actively hedge currency if investment horizon > 5 years (PPP tends to equalize)

## Rebalancing Protocol

### When to Rebalance

| Trigger | Action |
|---|---|
| **Calendar** (quarterly) | Review all allocations, rebalance if any are > 5% off target |
| **Threshold** (any time) | If any asset class drifts > 10% from target, rebalance immediately |
| **Cash event** | New deposits or withdrawals -- use to rebalance by directing cash to underweight positions |
| **Tax event** | Year-end tax-loss harvesting (coordinate with `pt-tax-assistant`) |

### Rebalancing Method

1. Calculate current vs target allocation for each asset class
2. Identify overweight and underweight positions
3. Prefer rebalancing by directing new cash to underweight positions (avoids taxable events)
4. If selling is necessary, sell overweight positions with the highest cost basis first (minimize tax impact)
5. For US tax purposes: observe wash sale rules (30 days) when harvesting losses

### Output Format for Rebalancing Recommendations

```
PORTFOLIO REBALANCE - [Date]

| Asset Class       | Current $ | Current % | Target % | Delta % | Action          | Amount    |
|-------------------|-----------|-----------|----------|---------|-----------------|-----------|
| US Large Cap      | $45,000   | 45.0%     | 40.0%    | +5.0%   | Sell / Redirect | -$5,000   |
| Crypto            | $3,000    | 3.0%      | 7.0%     | -4.0%   | Buy             | +$4,000   |
| ...               | ...       | ...       | ...      | ...     | ...             | ...       |

NET CASH NEEDED: $[X]
TAX IMPLICATIONS: [brief note, defer to pt-tax-assistant for details]
```

## Emergency Fund & Liquidity

Before investing, ensure:

| Requirement | Target | Status |
|---|---|---|
| Emergency fund | 3-6 months expenses in liquid savings | ~EUR 8,600-17,200 based on current net pay |
| High-interest debt | Paid off (anything > 6% APR) | Verify with user |
| Insurance | Health, liability adequate | User has Allianz via employer |

If the emergency fund is not fully funded, prioritize that before any satellite/speculative investments.

## US Citizen in Portugal -- Investment Account Considerations

### Account Types

| Account | Access | Tax Treatment | Notes |
|---|---|---|---|
| US brokerage (taxable) | Yes, but some brokers drop non-resident clients | Capital gains taxed by both US and PT | FTC should offset, coordinate with tax skill |
| Roth IRA | If existing, keep. New contributions need US earned income. | US: tax-free growth. PT: NHR may exempt. Complex -- get CPA advice. | Do NOT withdraw without tax analysis |
| Traditional IRA / 401k | Rollover to IRA if leaving US employer | US: taxable on withdrawal. PT: complex NHR treatment. | Defer to human CPA for distributions |
| Portuguese investment account | Available via PT brokers (Degiro, XTB) | PT capital gains tax applies; NHR may provide exemptions for foreign-source gains | Simpler for EUR-denominated investments |

### PFIC Warning

US citizens holding foreign (non-US) mutual funds or ETFs may trigger **Passive Foreign Investment Company (PFIC)** rules, which impose punitive US taxation. Avoid holding:
- EU-domiciled ETFs (UCITS) in a US-reportable account
- Foreign mutual funds

Stick to US-listed ETFs (SPY, QQQ, VTI, etc.) for the equity allocation to avoid PFIC headaches.

### Reporting Obligations

- Capital gains from all accounts must be reported on US Form 1040 Schedule D
- Foreign accounts: FBAR and Form 8938 (see `pt-tax-assistant` for thresholds)
- PT side: capital gains reported on Anexo G/J depending on source
