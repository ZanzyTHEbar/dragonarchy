# Data Sources & Indicators Reference

This file catalogs every data category the agent should consider when performing financial analysis. For each category, the key metrics and where to find them are listed.

When performing analysis, search the web for the most current values. Never use stale or training-data prices.

## Fundamental Data

| Metric | What It Tells You | Free Source |
|---|---|---|
| EPS (trailing + forward) | Profitability per share | Yahoo Finance, Macrotrends |
| Revenue (quarterly + annual) | Top-line growth | SEC EDGAR (10-Q/10-K), Yahoo Finance |
| Net income | Bottom-line profitability | SEC EDGAR, Macrotrends |
| EBITDA | Operating cash generation proxy | Yahoo Finance, Finviz |
| P/E ratio (trailing + forward) | Relative valuation | Yahoo Finance, Finviz |
| P/S ratio | Revenue-based valuation | Yahoo Finance, Finviz |
| EV/EBITDA | Capital-structure-neutral valuation | Yahoo Finance, GuruFocus |
| Gross margin | Pricing power | Macrotrends, SEC filings |
| Operating margin | Operational efficiency | Macrotrends, SEC filings |
| FCF yield | Cash return on market cap | Yahoo Finance (calculate from statements) |
| PEG ratio | Growth-adjusted P/E | Yahoo Finance, Finviz |
| Insider transactions | Management conviction | OpenInsider, SEC Form 4 filings |
| Institutional ownership | Smart money positioning | Finviz, WhaleWisdom (13F filings) |
| Short interest | Bearish sentiment gauge | Finviz, Ortex (paid) |

## Options Chain Data

| Metric | What It Tells You | Source |
|---|---|---|
| Implied volatility (IV) | Market's expected move | CBOE, Yahoo Finance options chain, Barchart |
| IV Rank / IV Percentile | Context for current IV level | TastyTrade, MarketChameleon |
| Delta, Gamma, Theta, Vega | Sensitivity metrics | Any options chain (Yahoo, CBOE, broker) |
| Open interest (by strike) | Where positions are concentrated | Yahoo Finance, Barchart |
| Volume (by strike) | Intraday flow | Yahoo Finance, Barchart |
| Put/call ratio | Sentiment gauge | CBOE (equity + index), Barchart |
| IV skew | Demand imbalance puts vs calls | MarketChameleon, VolatilitySurf |
| IV term structure | Event pricing across expirations | MarketChameleon, TastyTrade |
| Max pain | Price at which most options expire worthless | Swaggystocks, OptionStrat |
| Unusual options activity | Smart money signals | Unusual Whales, Barchart unusual activity |

## Price & Technical Data

| Metric | What It Tells You | Source |
|---|---|---|
| OHLCV (daily) | Price action | Yahoo Finance, Google Finance, TradingView |
| Historical volatility (20/60/252 day) | Realized vs implied comparison | TradingView, Barchart |
| Moving averages (50/100/200 SMA/EMA) | Trend direction and support/resistance | TradingView, Finviz |
| RSI (14-day) | Overbought (>70) / oversold (<30) | TradingView, Finviz |
| MACD | Momentum and trend crossovers | TradingView |
| Bollinger Bands (20,2) | Volatility envelope | TradingView |
| VWAP | Institutional fair value intraday | TradingView (intraday chart) |
| ATR (14-day) | Average daily range in dollars | TradingView, Barchart |
| Pivot points | Support/resistance levels | TradingView |
| Volume profile | Price levels with highest trading activity | TradingView (visible range) |
| 52-week high/low | Range context | Yahoo Finance, Finviz |
| Relative strength vs S&P 500 | Outperformance/underperformance | Finviz, StockCharts |

## Macro Indicators

| Indicator | Frequency | What It Tells You | Source |
|---|---|---|---|
| CPI (US) | Monthly | Inflation rate | BLS, FRED |
| HICP (EU) | Monthly | Eurozone inflation | Eurostat, ECB |
| GDP growth (US) | Quarterly | Economic expansion/contraction | BEA, FRED |
| Unemployment rate (US) | Monthly | Labor market health | BLS, FRED |
| Nonfarm payrolls | Monthly | Job creation | BLS, FRED |
| 10-year Treasury yield | Daily | Risk-free rate, market expectations | FRED, TradingView |
| 2s/10s spread | Daily | Yield curve (inversion = recession signal) | FRED |
| Fed funds rate | 8x/year (FOMC) | Monetary policy stance | Federal Reserve |
| VIX | Daily | Market fear gauge | CBOE, Yahoo Finance |
| ISM Manufacturing PMI | Monthly | Manufacturing expansion/contraction | ISM, FRED |
| Consumer confidence | Monthly | Spending outlook | Conference Board, FRED |
| Retail sales | Monthly | Consumer spending | Census Bureau, FRED |
| EUR/USD exchange rate | Daily | Currency risk for the user | Yahoo Finance, ECB, XE.com |
| ECB deposit rate | ~6x/year | Eurozone monetary policy | ECB |
| SOFR rate | Daily | Short-term USD funding | FRED, NY Fed |

### Economic Calendar

Key data release schedule sources:
- **US**: `https://www.bls.gov/schedule/` and `https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm`
- **EU**: `https://www.ecb.europa.eu/press/govcdec/mopo/html/index.en.html`
- **Aggregated**: Investing.com economic calendar, ForexFactory calendar

## ETF & Fund Flow Data

| Metric | What It Tells You | Source |
|---|---|---|
| SPY/QQQ daily flows | Broad market sentiment | ETF.com, Bloomberg (free terminal data) |
| Sector ETF flows (XLK, XLF, XLE, XLV) | Sector rotation | ETF.com, ETFdb.com |
| 13F filings (quarterly) | Hedge fund positioning | WhaleWisdom, SEC EDGAR |
| ETF short interest | Bearish sentiment on sectors | Finviz, Ortex |
| Leveraged ETF rebalance estimates | End-of-day flow impact | Calculate from daily returns + AUM |

Key sector ETFs to track:

| Sector | ETF | Alternate |
|---|---|---|
| Technology | XLK | VGT, QQQ |
| Financials | XLF | VFH |
| Energy | XLE | VDE |
| Healthcare | XLV | VHT |
| Consumer Discretionary | XLY | VCR |
| Industrials | XLI | VIS |
| Real Estate | XLRE | VNQ |
| Utilities | XLU | VPU |

## Analyst & Sentiment Data

| Metric | What It Tells You | Source |
|---|---|---|
| Consensus price target | Sell-side average expectation | Yahoo Finance, TipRanks |
| Upgrades/downgrades | Sentiment shifts | MarketBeat, Benzinga |
| Earnings estimate revisions | Fundamental momentum | Yahoo Finance, Seeking Alpha |
| Short interest (% of float) | Bearish positioning | Finviz, Ortex |
| Social sentiment (Reddit, X) | Retail momentum | Quiver Quantitative (free), Sentiment Investor |
| Google Trends | Search interest as proxy for attention | trends.google.com |
| Congress trading | Insider political sentiment | QuiverQuant, Capitol Trades |

## Alternative Data

| Data Type | What It Tells You | Source |
|---|---|---|
| App download trends | Product adoption | Sensor Tower (limited free), SimilarWeb |
| Web traffic estimates | Business momentum | SimilarWeb |
| Job postings | Growth or contraction signals | Indeed, LinkedIn (manual search) |
| Patent filings | Innovation pipeline | Google Patents, USPTO |
| Satellite/foot traffic | Physical retail activity | Placer.ai (limited free) |
| Credit card spending | Revenue leading indicator | Mostly paid (Second Measure); use earnings transcripts for mentions |

## Crypto & DeFi Data

| Metric | What It Tells You | Source |
|---|---|---|
| Price (BTC, ETH, alts) | Market value | CoinGecko, CoinMarketCap |
| Market cap + dominance | BTC vs alt rotation | CoinGecko |
| Total Value Locked (TVL) | DeFi protocol health | DefiLlama |
| Protocol revenue | Sustainable yield assessment | Token Terminal, DefiLlama |
| Gas fees (Ethereum) | Network demand | Etherscan, ultrasound.money |
| Stablecoin flows | Risk-on/risk-off gauge | DefiLlama stablecoins dashboard |
| Fear & Greed Index (crypto) | Sentiment extremes | Alternative.me |
| Exchange inflows/outflows | Selling vs accumulation | CryptoQuant, Glassnode (limited free) |
| Smart contract audits | Security assessment | DeFiSafety, Certik, audit reports |
| Token unlocks | Supply inflation events | Token Unlocks (token.unlocks.app) |

## Free Research Aggregators

For quick multi-source research:

| Platform | Best For | URL |
|---|---|---|
| Finviz | Screener, fundamentals, technicals | finviz.com |
| TradingView | Charts, technicals, community ideas | tradingview.com |
| Macrotrends | Long-term fundamental history | macrotrends.net |
| FRED | All US macro data | fred.stlouisfed.org |
| SEC EDGAR | Official US filings | sec.gov/cgi-bin/browse-edgar |
| OpenInsider | Insider transactions | openinsider.com |
| WhaleWisdom | 13F institutional holdings | whalewisdom.com |
| DefiLlama | DeFi TVL, yields, protocol data | defillama.com |
| CoinGecko | Crypto prices, market data | coingecko.com |
| ETFdb | ETF comparisons, flows | etfdb.com |
