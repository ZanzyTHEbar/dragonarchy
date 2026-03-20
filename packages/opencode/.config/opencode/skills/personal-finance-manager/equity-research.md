# Equity Research Framework

When analyzing a stock, follow all five sections in order. Search the web for current data before writing each section.

## 1. Fundamental Analysis

### Financial Health

| Metric | What to Find | Red Flag |
|---|---|---|
| Revenue growth (3yr CAGR) | Consistent uptrend | Decelerating for 2+ quarters |
| Gross margin | Stable or expanding | Contracting without explanation |
| Net margin | Positive and stable | Negative and worsening |
| Free cash flow (FCF) | Positive, growing | Negative with high capex |
| FCF yield | FCF / market cap | Below 2% for mature company |
| Debt-to-equity | Sector-appropriate | Above 2x for non-financials |
| Interest coverage | EBIT / interest expense | Below 3x |
| Current ratio | Current assets / liabilities | Below 1.0 |

### Valuation Comparison

Compare against sector median and 5-year own history:

| Metric | Formula | Context |
|---|---|---|
| P/E (trailing) | Price / EPS | Compare to sector median |
| P/E (forward) | Price / estimated EPS | More useful for growth |
| EV/EBITDA | Enterprise value / EBITDA | Capital-structure neutral |
| P/S | Price / revenue per share | For unprofitable growth cos |
| PEG | P/E / EPS growth rate | Below 1.0 = potentially undervalued |
| P/FCF | Price / FCF per share | Harder to manipulate than P/E |

State whether the stock is trading at a premium or discount to peers and its own history, and whether the premium is justified.

### Insider Activity

- Net insider buys/sells over the last 6 months
- Cluster buying (multiple insiders buying within 30 days) is a strong signal
- CEO/CFO transactions carry more weight than board members
- 10b5-1 plan sales are less meaningful than discretionary sales

### Earnings Quality

- Revenue recognition changes or aggressive accounting flags
- Difference between GAAP and non-GAAP earnings (> 30% gap is a flag)
- Accounts receivable growing faster than revenue (channel stuffing risk)
- Cash flow from operations vs net income divergence

## 2. Thesis Validation

### Structure

Present exactly:
- **3 Bull Arguments**: specific, evidence-backed reasons the stock should go up
- **2 Bear Arguments / Key Risks**: the strongest counterpoints or risks that could break the thesis
- **Verdict**: Bullish / Bearish / Neutral with a 1-2 sentence justification

### Quality Standard

Each argument must include:
- A specific data point or event (not "the company is well-managed")
- A quantified impact where possible ("represents $X in incremental revenue")
- A timeline ("expected to materialize in Q3 2026")

### Thesis Killers

If any of these are true, the verdict should be Bearish regardless of other factors:
- Negative FCF with no clear path to profitability within 2 years
- SEC investigation or material accounting restatement
- Insider selling exceeding 10% of holdings in 90 days across multiple executives
- Revenue declining for 3+ consecutive quarters without restructuring plan

## 3. Sector & Macro View

### Sector Overview
- Current sector performance (YTD, relative to S&P 500)
- Sector rotation signals (is capital flowing in or out?)
- Regulatory tailwinds or headwinds
- Key sector ETF performance (XLK, XLF, XLE, XLV, etc.)

### Macro Positioning
- Interest rate environment and Fed stance (hawkish/dovish/neutral)
- Inflation trajectory (CPI trend)
- GDP growth outlook
- Consumer confidence and spending trends
- How these macro factors specifically affect THIS company (not generic macro commentary)

### Competitive Moat Assessment

Rate the moat (None / Narrow / Wide) using these dimensions:

| Moat Type | Signal | Example |
|---|---|---|
| Network effects | Value increases with users | Payment networks, social platforms |
| Switching costs | Painful to leave | Enterprise SaaS, banking |
| Cost advantage | Structural cost leadership | Scale manufacturing, logistics |
| Intangible assets | Brands, patents, licenses | Pharma, luxury goods |
| Efficient scale | Natural monopoly/oligopoly | Utilities, railroads |

## 4. Catalyst Watch

### Short-term (0-3 months)
- Next earnings date and consensus estimates
- Product launches or announcements
- Regulatory decisions pending
- Insider lock-up expirations
- Index inclusion/exclusion

### Long-term (3-12+ months)
- TAM expansion opportunities
- M&A potential (acquirer or target)
- Margin expansion drivers
- International expansion
- Technology shifts benefiting the company

For each catalyst, state: **event**, **expected date**, **potential impact** (quantified if possible), and **probability** (High/Medium/Low).

## 5. Investment Summary

### Final Output Format

```
TICKER: [XXX]
COMPANY: [Full Name]
SECTOR: [GICS Sector]
MARKET CAP: $[X]B

THESIS (5 bullets):
1. [bullet 1]
2. [bullet 2]
3. [bullet 3]
4. [bullet 4]
5. [bullet 5]

VERDICT: [Bullish / Bearish / Neutral]
RECOMMENDATION: [Buy / Hold / Sell]
CONFIDENCE: [High / Medium / Low] ([0-100]%)
TIMEFRAME: [e.g., 6-12 months]
ENTRY ZONE: $[X] - $[Y]
TARGET: $[X] ([+X]% upside)
STOP-LOSS: $[X] ([-X]% downside)
RISK/REWARD: [X:1]
KEY RISK: [single sentence]
```

### Recommendation Criteria

| Recommendation | Criteria |
|---|---|
| **Buy** | Confidence >= 70%, R/R >= 2:1, thesis supported by data, no thesis killers |
| **Hold** | Confidence 50-70%, thesis intact but catalysts unclear, fairly valued |
| **Sell** | Confidence < 50%, thesis broken, or better risk-adjusted alternatives exist |

### Confidence Calibration

- **High (75-100%)**: strong fundamental support, clear catalysts, sector tailwinds, insider buying
- **Medium (50-74%)**: mixed signals, some thesis uncertainty, neutral macro
- **Low (25-49%)**: significant unknowns, conflicting data, sector headwinds -- recommend smaller position or wait
- **Below 25%**: do not recommend the trade; state why and suggest alternatives
