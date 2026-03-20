# Financial Tracking Reference

## MCP Server

Server: `user-actualbudget`

Important: Call `actual_budgets_getMonth` before any query or summary tool to open the budget file. Avoid parallel query calls — run them sequentially.

## Account Reference

| Account | ID | Type |
|---------|----|------|
| LDA (main) | `cc37eada-f6ff-469d-9b31-883615be4505` | On-budget, checking |
| Personal | `940a94d8-bec8-4389-b2db-24aacecdb9b6` | On-budget |

## Budget Regime (March 2026+)

| Category | Monthly EUR | Category ID |
|----------|-------------|-------------|
| Developer Tooling (Cursor + X) | 250 | `9794def7-b195-4afb-9163-a4b91d9cff60` |
| General | 750 | `af375fd4-d759-46b3-bffe-74a856151d57` |
| Food & Dining (group) | 600 | group `e2fe89e9-b60a-4dc4-8ee9-b514a40a1d71` |
| Taxes & Government | 190 | `316c3163-9b79-4ccc-b49c-709653d7b401` |
| Professional Services | 150 | `7d9fc2b5-ee0f-4978-a992-fa61c318c606` |
| Travel | 130 | `5d1c1b1b-6c8e-4ddb-b917-27ef204158c5` |
| Software & SaaS | 100 | `7ba9465c-51e5-4ea9-a668-debdf1e5b2bb` |
| Bills (Flexible) | 100 | `29ec2c58-8cd3-42fe-9187-7b5dfe0f70a6` |
| Payment Processing | 80 | `8eaeeffd-8779-4320-a223-b820f7e1acfa` |
| Transportation | 50 | `3a0a843e-3f0a-4e34-9b47-ca385dc85980` |
| Bank Fees | 25 | `6044da93-4cb7-4c31-8402-00657bb7ddf1` |
| Owner Draws | 0 (stopped) | `214e3380-c364-4c49-a7f8-8002a059f253` |
| Venture Investment | 0 (gated) | `30286bf8-47a8-48f1-8109-b21ce26b195f` |
| **Total** | **2,425** | |

## Key Financial Parameters

| Parameter | Value |
|-----------|-------|
| Monthly burn | EUR 2,425 |
| Personal injection | +EUR 1,000/month |
| Net monthly burn | EUR 1,425 |
| Breakeven MRR target | EUR 1,425 |
| Post-withdrawal starting capital | EUR 20,946 |
| Worst-case runway (no revenue) | ~14.7 months |
| Runway with PetFilter POC+prototype | ~10 months |

## Common Queries

### Get LDA balance

```json
{
  "toolName": "actual_accounts_get_balance",
  "arguments": { "id": "cc37eada-f6ff-469d-9b31-883615be4505" }
}
```

Result is in **cents**. Divide by 100 for EUR.

### Get monthly budget

```json
{
  "toolName": "actual_budgets_getMonth",
  "arguments": { "month": "2026-03" }
}
```

### Run a SQL query

```json
{
  "toolName": "actual_query_run",
  "arguments": {
    "query": "SELECT date, amount, payee.name, category.name FROM transactions WHERE date >= '2026-03-01' ORDER BY date DESC LIMIT 20"
  }
}
```

Amounts in SQL results are in **cents**. Negative = expense, positive = income.

### Set a budget amount

```json
{
  "toolName": "actual_budgets_setAmount",
  "arguments": {
    "month": "2026-03",
    "categoryId": "316c3163-9b79-4ccc-b49c-709653d7b401",
    "amount": 19000
  }
}
```

Amount is in **cents**.
