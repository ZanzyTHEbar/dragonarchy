# Gate System Reference

## Overview

PetFilter commercialization is funded through a stage-gate process. Each gate has specific financial and technical conditions. No gate condition may be waived — if any condition fails, the defined fail-path action applies.

## Gate Definitions

### Gate 1 — POC Greenlight

| Field | Value |
|-------|-------|
| Target date | May 2026 (Month 3) |
| Investment unlocked | EUR 1,500 (PetFilter POC) |
| Linear issue | NOR-23 |
| Linear milestone | Gate 1: POC Greenlight |

**Conditions:**

| # | Condition | Threshold | How to verify |
|---|-----------|-----------|---------------|
| 1 | Software MRR | >= EUR 300/month | Gumroad + Stripe dashboards |
| 2 | LDA balance | > EUR 14,000 | `actual_accounts_get_balance` id `cc37eada...` |

**Pass action:** Fund PetFilter POC. Components: 3D-printed venturi, off-the-shelf peristaltic pump, ESP32-S3 dev board, UVC LED module, sealed test chamber, ammonia measurement equipment.

**Fail action:** Delay PetFilter to Month 5. Double down on software revenue (MCP Memory Cloud and cursor-rules premium marketing). Re-evaluate in 2 months.

---

### Gate 2 — Prototype Greenlight

| Field | Value |
|-------|-------|
| Target date | August 2026 (Month 6) |
| Investment unlocked | EUR 6,000 (engineering prototype) |
| Linear issue | NOR-24 |
| Linear milestone | Gate 2: Prototype Greenlight |

**Conditions:**

| # | Condition | Threshold | How to verify |
|---|-----------|-----------|---------------|
| 1 | POC ammonia reduction | > 80% in sealed chamber | PetFilter POC test results |
| 2 | Software MRR | >= EUR 1,000/month | Gumroad + Stripe dashboards |
| 3 | LDA balance | > EUR 10,000 | `actual_accounts_get_balance` |

**All-pass action:** Fund engineering prototype. Components: custom PCB (JLCPCB), iterated venturi, 3D-printed housing, 5-10 units.

**Physics fail (condition 1):** Kill PetFilter entirely. Reallocate all effort to AI Infrastructure Stack (MCP Memory Cloud, picoclaw, knowledgebase).

**Revenue fail (condition 2 or 3):** Activate consulting bridge — minimum 2-3 days/month at EUR 500/day. Delay prototype funding until revenue catches up.

---

### Gate 3 — Pre-Production Greenlight

| Field | Value |
|-------|-------|
| Target date | December 2026 (Month 10) |
| Investment unlocked | EUR 25,000 (pre-production) |
| Linear issue | To be created |
| Linear milestone | To be created |

**Conditions:**

| # | Condition | Threshold | How to verify |
|---|-----------|-----------|---------------|
| 1 | Prototype validation | Repeatable >80% across 5+ units, noise <50 dB, no UVC leaks | Engineering test reports |
| 2 | Software MRR | >= EUR 2,000/month | Gumroad + Stripe dashboards |
| 3 | Kickstarter pre-launch | Campaign page ready, email list > 5,000 | Kickstarter dashboard |

**All-pass action:** Seek external funding for EUR 25,000 pre-production. Options: Kickstarter pre-orders, angel investment, accumulated software revenue, Portugal 2020/PRR innovation grant.

**Any-fail action:** Focus purely on software portfolio. PetFilter enters indefinite hold until conditions are met.

---

## Evaluation Procedure

When evaluating any gate:

1. Open Actual Budget: `actual_budgets_getMonth` for current month
2. Query LDA balance: `actual_accounts_get_balance`
3. Gather MRR data from revenue sources
4. Check each condition independently
5. Format results using the gate evaluation template from SKILL.md
6. Write evaluation to Memory Bank: `memory_bank_write` with project `way-of-working`
7. Update the gate issue in Linear with a comment containing the evaluation
8. If all pass: create the next set of issues for the funded phase
9. If any fail: create issues for the fail-path actions

## Evaluation History

Record each evaluation below as it occurs:

(No evaluations performed yet — first evaluation due May 2026)
