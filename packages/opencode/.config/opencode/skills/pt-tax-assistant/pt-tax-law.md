# Portuguese Tax Law Reference

## NHR Regime (Residente Nao Habitual)

### Legal Basis

- **Registration**: Art. 16(8) CIRS -- individuals who become Portuguese tax residents and were not resident in PT in any of the preceding 5 years may register as NHR.
- **Flat rate**: Art. 72(10) CIRS -- NHR beneficiaries earning Category A (employment) or Category B (self-employment) income from "high value-added activities" pay a **flat 20% IRS rate** instead of progressive tables.
- **Eligible activities**: Portaria 12/2010, of January 7 -- lists professions qualifying as high-value-added. Software engineering, platform engineering, and ICT roles are included.
- **Duration**: 10 consecutive years from the year of registration. Non-renewable.
- **Foreign income**: depending on category, NHR may provide exemption (with progression) or flat 10% rate on foreign pensions. Method depends on income category and whether a double taxation treaty exists.

### User's NHR Status

| Field | Value |
|---|---|
| Document | IRNH000107004 |
| Status | Deferido (Approved) |
| Start | 2023 |
| End | 2032 |
| Country of origin | Belgium |

### NHR vs Standard Progressive Tables (2025/2026 reference)

Under NHR, the user pays flat 20% on qualifying Category A income. Without NHR, the standard brackets apply:

| Taxable Income (EUR) | Marginal Rate |
|---|---|
| 0 -- 7,703 | 13.25% |
| 7,703 -- 11,623 | 18.00% |
| 11,623 -- 16,472 | 23.00% |
| 16,472 -- 21,321 | 26.00% |
| 21,321 -- 27,146 | 32.75% |
| 27,146 -- 39,791 | 37.00% |
| 39,791 -- 51,997 | 43.50% |
| 51,997 -- 81,199 | 45.00% |
| 81,199+ | 48.00% |

**Always verify current-year brackets** -- they change annually via Portaria.

### IFICI Regime (EBF Art. 58-A)

The newer "Tax Incentive for Scientific Research and Innovation" regime replaced NHR for new registrations from 2024 onward. The user **does not qualify** because category c) (highly qualified professions) requires a minimum of a bachelor's or master's degree. The user is self-taught with no formal degree.

Other IFICI categories (b, d, e) may theoretically apply but depend on the employer's specific tax incentive registrations, which Gapstars PT does not appear to hold.

**This is irrelevant for the user** -- active NHR through 2032 is superior.

## IRS (Imposto sobre o Rendimento das Pessoas Singulares)

### Income Categories

| Category | Type | Relevant? |
|---|---|---|
| A | Employment income (trabalho dependente) | **Yes -- primary income** |
| B | Self-employment / business (trabalho independente) | Only if freelancing |
| E | Investment income (capitais) | If applicable (interest, dividends) |
| F | Rental income (prediais) | If applicable |
| G | Capital gains (mais-valias) | If applicable |
| H | Pensions | Not applicable |

### Annual IRS Return (Modelo 3)

**Filing period**: April 1 -- June 30 (for the previous tax year).

Required annexes for the user:

| Anexo | Purpose | When needed |
|---|---|---|
| **Rosto** | Cover page -- personal data, NHR flag, marital status | Always |
| **Anexo A** | Category A employment income, withholding, employer NIF | Always |
| **Anexo L** | NHR regime -- declares income under Art. 72(10) | Always (NHR active) |
| Anexo J | Foreign-source income | Only if foreign income exists |
| Anexo G | Capital gains | Only if gains realized |
| Anexo E | Investment income | Only if not withheld at source |

### Portal das Financas Navigation

**Base URL**: `https://portaldasfinancas.gov.pt`

Key paths:
- Login: NIF tab > enter NIF + password (or Chave Movel Digital)
- IRS filing: Servicos > IRS > Entregar Declaracao > Modelo 3
- NHR consultation: Servicos > IRS > Residente Nao Habitual > Consultar Pedido
- Tax situation: Situacao Fiscal Integrada > Dados Gerais de Identificacao
- E-fatura (invoice validation): `https://faturas.portaldasfinancas.gov.pt`
- NHR certificate download: `https://sitfiscal.portaldasfinancas.gov.pt/dados/residentenaohabitual/consultar/comprovativo?numeroDocumento=IRNH000107004`

### Withholding at Source (Retencao na Fonte)

For NHR beneficiaries with Category A income in high-value activities:
- Employer applies **flat 20%** on the taxable base (Art. 99-A CIRS)
- No deductible parcel (*parcela a abater*) -- the flat rate replaces progressive withholding entirely
- The employee must provide proof of NHR registration to the employer
- If employer does not apply the correct rate, overpayment is refunded via the annual return

### Automatic IRS (IRS Automatico)

NHR beneficiaries generally **cannot** use the simplified automatic IRS return. They must file manually (Modelo 3) to include Anexo L.

## Social Security (Seguranca Social)

| Component | Rate |
|---|---|
| Employee contribution | 11.00% |
| Employer contribution | 23.75% |
| **Total** | **34.75%** |

- Applies to base salary + holiday allowance + Christmas allowance
- Does NOT apply to meal allowance (below threshold) or telework expense
- NHR does not affect Social Security rates
- User's NISS: 12171501825

## Meal Allowance (Subsidio de Refeicao)

Tax-exempt thresholds (verify annually):
- **Cash payment**: EUR 6.00/day
- **Meal card (cartao refeicao)**: EUR 10.20/day

Amount above threshold is taxed as income. The user receives EUR 10.20/day (card), which is exactly at the exempt threshold.

## Holiday and Christmas Allowances

Portuguese law mandates two extra monthly payments per year:
- **Subsidio de Ferias** (holiday allowance): equivalent to one month's base salary
- **Subsidio de Natal** (Christmas allowance): equivalent to one month's base salary

These can be paid in two ways:
- **Lump sum**: full amount paid in June (holiday) and November/December (Christmas)
- **Duodecimos**: 1/12th of each allowance paid monthly throughout the year

The user's payslip shows duodecimos (monthly twelfths).

## Telework Expenses

Portaria 292-A/2023 established rules for telework expense compensation:
- Employer can pay a fixed amount to cover telework costs (electricity, internet, etc.)
- The user receives EUR 4.50/month
- Generally exempt from IRS and Social Security if within reasonable limits

## Double Taxation Treaty: Portugal -- United States

Signed: September 6, 1994. In force since 1996.

Key articles:
- **Art. 15 (Dependent Personal Services)**: employment income taxable in the state where work is performed (Portugal, for the user)
- **Art. 23 (Elimination of Double Taxation)**: US shall allow FTC for PT taxes paid on PT-source income
- **Art. 24 (Non-discrimination)**: nationals of one state shall not be taxed more burdensomely in the other

The treaty allows the US to tax worldwide income of its citizens (saving clause, Art. 1(4)), but must credit PT taxes paid.

## Key Tax Calendar

| Date | Event |
|---|---|
| Jan 31 | Employer issues Declaracao de Rendimentos for previous year |
| Feb 15 | E-fatura validation deadline (confirm/dispute invoices for deductions) |
| Mar 31 | IRS automatic declarations available for review |
| Apr 1 | IRS Modelo 3 filing opens |
| Apr 15 | US tax filing deadline (auto-extends to Jun 15 for expats) |
| Jun 15 | US expat auto-extension deadline |
| Jun 30 | PT IRS Modelo 3 filing deadline |
| Jul--Aug | PT nota de liquidacao (tax assessment/refund) typically issued |
| Oct 15 | US extension deadline (if Form 4868 filed); FBAR extended deadline |
| Dec 31 | Tax year end |
