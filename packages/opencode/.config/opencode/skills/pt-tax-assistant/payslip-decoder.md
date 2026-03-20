# Portuguese Payslip Decoder

## Payslip Structure

A standard Portuguese payslip (*recibo de vencimento*) is divided into three sections:

1. **Header**: employee identification, employer, category, pay period
2. **Body**: line items for earnings (abonos/additions) and deductions (descontos)
3. **Footer**: totals for gross, deductions, and net pay

## Header Fields

| Portuguese | English | Notes |
|---|---|---|
| Nome | Name | Full legal name |
| NIF / Contribuinte | Taxpayer number | 9-digit NIF |
| N.o Beneficiario | SS beneficiary number | NISS |
| N.o Mecanografico | Employee number | Internal employer ID |
| Categoria / Profissao | Category / Profession | Job title |
| Tipo de Processamento | Processing type | Normalizado = standard monthly |
| Base de Processamento | Processing basis | Mensal = monthly |
| Vencimento Base | Base salary | Monthly gross before additions |
| Valor Hora | Hourly rate | Base salary / (weekly hours * 4.33) |
| Horas Semanais | Weekly hours | Contractual weekly hours |
| Dias do Mes | Working days in month | Varies by month |

## Earnings Codes (Abonos)

Common codes seen on the user's payslips:

| Code | Portuguese | English | Taxable? | SS-eligible? |
|---|---|---|---|---|
| A001 | Vencimento Base | Base Salary | Yes | Yes |
| A002 | Subsidio de Refeicao | Meal Allowance | No (if <= threshold) | No |
| A004 | Subsidio de Ferias (duodecimos) | Holiday Allowance (twelfths) | Yes | Yes |
| A021 | Subsidio de Natal (duodecimos) | Christmas Allowance (twelfths) | Yes | Yes |
| A124 | Compensacao Despesas Teletrabalho | Telework Expense Payment | No (within limits) | No |

### Duodecimos Explained

Instead of receiving holiday and Christmas allowances as lump sums (June and December respectively), the employer distributes them as 1/12th of the annual amount each month.

**Calculation:**
- Holiday allowance monthly portion = base salary / 12
- Christmas allowance monthly portion = base salary / 12

For the user: EUR 4,807.66 / 12 = ~EUR 400.64 each (the slight variation on the payslip is due to rounding or pro-rata adjustments).

The payslip shows "100% incl. duodecimos" meaning the full twelfth is being paid monthly.

## Deduction Codes (Descontos)

| Code | Portuguese | English | Rate/Basis |
|---|---|---|---|
| D020 | Desconto dias antes do inicio | Pre-contract day deduction | Hourly rate * hours not worked (one-time) |
| T001 | IRS (Imposto sobre Rendimento) | Income Tax withholding | See withholding section below |
| T003 | Seguranca Social | Social Security | 11% of SS-eligible base |

### Other Deduction Codes (may appear on future payslips)

| Code | Portuguese | English |
|---|---|---|
| D001 | Faltas | Absences (unpaid) |
| D010 | Penhora | Wage garnishment |
| T002 | Sobretaxa IRS | IRS surcharge (if applicable) |

## IRS Withholding Calculation

### Standard (Progressive) -- INCORRECT for the user

The payslip's T001 line shows three values:
- **Base tributavel** (taxable base): total taxable earnings minus SS contribution
- **Taxa** (rate): the marginal withholding rate from the standard tables
- **Parcela a abater** (deductible parcel): reduces the tax to approximate the effective rate

Formula: `IRS = (taxable_base * marginal_rate) - deductible_parcel`

Example from the user's January 2026 payslip:
```
Taxable base:      EUR 4,229.09
Marginal rate:     39.69%
Deductible parcel: EUR 531.62
IRS withheld:      EUR 4,229.09 * 0.3969 - 531.62 = EUR 1,058.00
```

### NHR 20% Flat Rate -- CORRECT for the user

Under NHR, the calculation is simpler:
```
IRS = taxable_base * 0.20
```

No deductible parcel. No progressive brackets.

Correct calculation for the same payslip:
```
Taxable base:      EUR 4,229.09
NHR flat rate:     20.00%
IRS should be:     EUR 4,229.09 * 0.20 = EUR 845.82
```

**Monthly overpayment**: EUR 1,058.00 - EUR 845.82 = **EUR 212.18**

## Taxable Base Calculation

The taxable base for IRS withholding is:

```
Taxable base = (base salary + holiday allowance + Christmas allowance + other taxable earnings)
             - Social Security contribution (11%)
```

Step by step for the user's January 2026 payslip:
```
Base salary:           EUR 4,807.66
Holiday allowance:     EUR   364.22
Christmas allowance:   EUR   388.56
                       ────────────
SS-eligible gross:     EUR 5,560.44

Minus: D020 deduction: EUR 1,331.35  (one-time pre-contract adjustment)
Adjusted gross:        EUR 4,229.09  (this is the IRS taxable base shown)

Social Security (11%): EUR   465.20  (11% of adjusted gross)
```

Note: meal allowance (EUR 153.00) and telework expense (EUR 4.50) are excluded from both the IRS taxable base and SS base because they are within exempt thresholds.

## Effective Rate Verification

The payslip may show multiple effective rates:
- **Rate on base salary + additions**: IRS / (base salary + other taxable additions)
- **Rate on holiday allowance**: separate effective rate applied to the holiday portion

Under NHR, both should resolve to approximately **20%** on the taxable base.

## Common Payroll Errors to Watch For

1. **Wrong withholding rate** (the user's current issue): progressive tables applied instead of NHR 20% flat. This is the most common error for NHR beneficiaries whose employer hasn't been notified or hasn't updated their payroll system.

2. **Meal allowance over-taxation**: if the daily amount exceeds the exempt threshold, only the excess should be taxed. Verify the per-day amount matches the payslip quantity.

3. **SS on exempt components**: Social Security should NOT be charged on meal allowance (below threshold) or telework expenses. Check that only base salary + allowances are in the SS base.

4. **Duodecimos calculation error**: each twelfth should be exactly base salary / 12. Small rounding differences (< EUR 1) are normal; larger deviations should be questioned.

5. **Missing telework compensation**: if the user works remotely, they are entitled to expense compensation under the telework regime. If it disappears from the payslip, follow up with HR.

## Monthly Payslip Review Checklist

When reviewing any new payslip:

- [ ] Base salary matches contract (EUR 4,807.66)
- [ ] Meal allowance: EUR 10.20/day * working days in month
- [ ] Holiday allowance (duodecimo): ~EUR 400.64 (base / 12)
- [ ] Christmas allowance (duodecimo): ~EUR 400.64 (base / 12)
- [ ] IRS withholding uses 20% flat rate (no parcela a abater)
- [ ] Social Security is exactly 11% of SS-eligible base
- [ ] Telework expense present (EUR 4.50)
- [ ] Net pay = total additions - total deductions
- [ ] No unexpected deduction codes
