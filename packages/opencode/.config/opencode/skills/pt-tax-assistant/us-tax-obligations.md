# US Tax Obligations for Citizens Abroad

The US taxes its citizens on **worldwide income** regardless of where they live. The user is a US citizen residing in Portugal, creating dual filing obligations every year.

## Annual Filing Requirements

### Form 1040 (US Individual Income Tax Return)

- Report all income worldwide, including Portuguese employment income
- Convert EUR to USD using the **IRS annual average exchange rate** for the tax year (published by the IRS; verify each year at `https://www.irs.gov/individuals/international-taxpayers/yearly-average-currency-exchange-rates`)
- Even if no US tax is owed (after credits/exclusions), the return must be filed

### Filing Deadlines

| Deadline | Condition |
|---|---|
| **April 15** | Standard deadline (most US filers) |
| **June 15** | Automatic 2-month extension for US citizens/residents abroad -- no form needed, just attach statement |
| **October 15** | Extended deadline if Form 4868 filed by April 15 |

The June 15 auto-extension applies to the user. Interest (but not penalties) accrues on any balance due from April 15.

## Reducing Double Taxation

### Option 1: Foreign Tax Credit (Form 1116)

Credits Portuguese taxes paid against US tax liability, dollar for dollar (subject to limitations).

**How it works for the user:**
1. Calculate US tax on worldwide income (as if no foreign tax existed)
2. Calculate the FTC limitation: `(foreign source income / worldwide income) * US tax`
3. Credit = lesser of (PT tax actually paid) or (FTC limitation)
4. Excess credits carry back 1 year or forward 10 years

**Mapping PT taxes to Form 1116:**
- IRS withholding from payslips (T001 code) -> Line 8 (taxes paid or accrued)
- Social Security (T003 code) -> generally NOT creditable on Form 1116 (SS is covered by totalization agreements, not income tax credit)
- Use the **paid** basis (taxes actually withheld during the year) or **accrued** basis (taxes assessed on the nota de liquidacao) -- must be consistent year to year

**Category of income**: Portuguese employment income = "General category income" on Form 1116.

### Option 2: Foreign Earned Income Exclusion (Form 2555)

Excludes foreign earned income up to an annual threshold from US taxation entirely.

**Thresholds** (indexed for inflation -- verify each year):
- 2024: USD 126,500
- 2025: ~USD 130,000 (projected)
- 2026: verify at filing time

**Qualification tests** (must meet one):
1. **Bona fide residence test**: established bona fide residence in Portugal for a full calendar year. The user qualifies (resident since 2023, NHR registered).
2. **Physical presence test**: physically present in a foreign country for 330 full days in a 12-month period.

**Key trade-off**: you **cannot** claim FTC on income excluded via FEIE. Choosing FEIE on some income means forfeiting the credit on that portion.

### FTC vs FEIE Decision Framework

For the user's current situation (~EUR 57,700 annual gross = ~USD 62,000-65,000):

```
User's PT effective rate (NHR): 20%
User's approximate US effective rate at this income level: ~15-18% (single, standard deduction)

PT rate > US rate -> FTC fully offsets US liability -> FTC is better
  - No US tax owed after FTC
  - Excess credit generated (carryforward)
  - Retains flexibility for future years

FEIE would also eliminate US tax at this income level (under threshold),
but: once elected, revoking FEIE requires waiting 5 years to re-elect.
FTC has no such lock-in.
```

**Recommendation**: FTC (Form 1116) is generally superior at this income level because:
- PT taxes exceed US liability, generating excess credits
- No 5-year lock-in period
- More flexible if income increases or tax situations change
- Preserves ability to use FEIE later if advantageous

**Re-evaluate annually** if income changes significantly or US tax law changes.

## FBAR (FinCEN 114 -- Report of Foreign Bank and Financial Accounts)

### Who must file

Any US person with a financial interest in or signature authority over foreign financial accounts if the **aggregate value of all foreign accounts exceeded USD 10,000 at any time during the calendar year**.

### What counts as a foreign account
- Portuguese bank accounts (checking, savings)
- Investment accounts held at Portuguese/European institutions
- Retirement accounts (if any, outside US)
- Any account outside the US where the user is an owner or signatory

### Filing details

| Field | Value |
|---|---|
| Form | FinCEN 114 (filed electronically via BSA E-Filing) |
| URL | `https://bsaefiling.fincen.treas.gov/` |
| Deadline | April 15, auto-extended to **October 15** (no form needed) |
| Penalty for non-filing | Up to USD 10,000 per violation (non-willful); criminal penalties for willful violations |

### What to report
- Maximum account value during the year (in USD, converted at the year's peak rate)
- Account number
- Bank name, address, and country
- Type of account

## FATCA (Form 8938 -- Statement of Specified Foreign Financial Assets)

### Who must file

US citizens living abroad with specified foreign financial assets exceeding:

| Filing status | End-of-year threshold | Any-time-during-year threshold |
|---|---|---|
| Single | USD 200,000 | USD 300,000 |
| Married filing jointly | USD 400,000 | USD 600,000 |

### What counts
- Foreign bank accounts (same as FBAR, plus...)
- Foreign securities, financial instruments
- Interest in foreign entities
- Foreign pension plans
- Foreign life insurance with cash value

### Filing details
- Filed with the annual tax return (Form 1040)
- Separate from FBAR -- both may be required

## Schedule B Part III

If the user has any foreign financial accounts at any time during the year:
- Answer "Yes" to question 7a ("Did you have a financial interest in or signature authority over a financial account in a foreign country?")
- Enter the country: **Portugal**
- If FBAR was filed, check the FBAR box

## Social Security Totalization Agreement (PT-US)

The US and Portugal have a totalization agreement that prevents dual Social Security taxation:
- If working for a **Portuguese employer** in Portugal (the user's situation): Portuguese Social Security applies exclusively
- US Social Security (FICA) is NOT owed
- Portuguese SS contributions are NOT creditable on Form 1116 (they are not income taxes)
- The totalization agreement ensures years of Portuguese SS contribution count toward US Social Security benefit eligibility (and vice versa)

## State Tax Considerations

If the user previously resided in a US state with income tax:
- Some states (CA, NY, VA, NM, SC) are known to be aggressive about maintaining tax nexus for former residents
- Most states release nexus once domicile is clearly established abroad
- If any US state filing was done previously, verify that state nexus has been properly severed
- **Escalate to a human CPA** if state tax nexus is unclear

## Document Retention

Keep for **at least 7 years** (3 years standard + potential 6-year extended statute for 25%+ income omission):
- All Portuguese payslips (monthly)
- Portuguese IRS nota de liquidacao (annual)
- NHR comprovativo
- Form 1040 + all schedules/forms
- Form 1116 or 2555
- FBAR confirmation
- Form 8938
- Foreign bank statements (year-end + any showing peak balance for FBAR)
- EUR/USD exchange rate documentation
