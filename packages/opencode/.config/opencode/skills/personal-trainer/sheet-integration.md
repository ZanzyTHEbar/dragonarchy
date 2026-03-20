# Google Sheet Integration Guide

## Sheet URL

```
https://docs.google.com/spreadsheets/d/1JV5DkfODiL0CnZto4GKQZskcKSIMHTkKM-t88XPYyzI/edit
```

## Tab Structure

The sheet has 7 tabs. Tab names are in Portuguese.

| Tab Name | English | Purpose | Read/Write |
|---|---|---|---|
| Introducao | Introduction | User profile, training instructions, glossary | Read only |
| Treino | Training | Current workout program (exercises, sets, reps, rest, PSE) | Read + Write (program modifications) |
| Registo de Cargas | Load Registry | Session-by-session weight and rep tracking per exercise | Read + Write (logging workouts) |
| Performance | Performance | Performance metrics, calculated from load registry | Read + Write (update analysis) |
| Evolucao | Evolution | Progress tracking over time (body measurements, strength milestones) | Read + Write |
| Periodizacao | Periodization | Mesocycle/macrocycle planning, training phases | Read + Write (program changes) |
| Base | Base | Reference data, formulas, calculations | Read only (don't modify formulas) |

## Browser Workflow for Sheet Access

Use the Cursor IDE browser MCP tools to interact with the sheet. The workflow follows this sequence:

### Reading Data

1. Use `browser_navigate` to open the sheet URL
2. Wait for the sheet to fully load (check for the tab bar at the bottom)
3. Use `browser_snapshot` to get the current page state
4. Click the appropriate tab name at the bottom of the sheet to switch tabs
5. Use `browser_snapshot` again to read the tab contents
6. Parse the data from the accessibility tree or visible text

### Writing Data

1. Navigate to the correct tab
2. Use `browser_snapshot` to locate the target cell
3. Click the target cell using `browser_click`
4. Use `browser_type` to enter the value (append to existing) or `browser_fill` to clear and replace
5. Press Enter or Tab to confirm the entry
6. Use `browser_snapshot` to verify the value was entered correctly
7. Wait briefly for Google Sheets to auto-save (the sheet auto-saves to Drive)

### Important Notes

- **Decimal separator**: the sheet uses comma (`,`) not period (`.`) for decimals (European convention). When entering weights like 62.5kg, type `62,5`
- **Auto-calculation**: the sheet has formulas that auto-calculate progression. After entering data in Registo de Cargas, the Performance and Base tabs will auto-update
- **Don't modify Base tab formulas**: the Base tab contains the calculation engine. Read from it, never write to it
- **Tab switching**: click the tab name at the bottom of the sheet. The tabs appear as: `Introducao | Treino | Registo de Cargas | Performance | Evolucao | Periodizacao | Base`

## Tab-Specific Data Formats

### Introducao Tab

**Layout (from web scrape):**

| Row | Column A | Column B |
|---|---|---|
| 3 | Data de Inicio: | 05/01/2026 |
| 4 | Data de Renovacao: | (renewal date) |
| 6 | ALUNO | Zacariah Heim |
| 8 | Objectivo Atual: | Hipertrofia |
| 9 | Idade: | 27 |
| 10 | Altura: | 1,77m |

Also contains:
- Warmup instructions (row 23)
- Load progression instructions (row 25)
- Load logging instructions (row 27)
- Rest time guidelines (row 40)
- Bracing technique (rows 42-43)
- PSE scale (row 45)
- Heart rate measurement guide (row 47)
- Glossary (rows 53+)

### Treino Tab

Expected structure (standard PT sheet format):

| Column | Content |
|---|---|
| A | Exercise group / session label (e.g., "Treino A", "Treino B") |
| B | Exercise name (Portuguese) |
| C | Sets |
| D | Reps (range, e.g., "10-12") |
| E | Rest period (seconds or minutes) |
| F | PSE target |
| G | Notes / technique cues |

**When reading**: capture all exercises for the target session, including sets, reps, rest, and PSE.
**When writing**: only modify this tab if the user approves a program change. When swapping exercises, update the exercise name and adjust sets/reps/rest if needed.

### Registo de Cargas Tab

This is the primary logging tab. Expected structure:

| Column | Content |
|---|---|
| A | Date |
| B | Exercise name |
| C-onwards | Set 1 weight, Set 1 reps, Set 2 weight, Set 2 reps, ... |

Or alternatively organized by session with exercises in rows and sets in columns.

**Data entry format**:
- Weights in kg with comma decimal: `62,5`
- Reps as integers: `10`
- If bodyweight exercise, enter the user's body weight
- If unilateral exercise, enter the weight per arm/leg (not total)

**When logging**: find the correct date row, locate the exercise column, and enter weight and reps for each set performed.

### Performance Tab

Auto-calculated from Registo de Cargas. Likely contains:
- Volume load per session (sets * reps * weight)
- Estimated 1RM progression
- Weekly volume per muscle group
- Performance trends

**Read from this tab** to generate weekly reports and progress assessments. Do not manually edit calculated cells.

### Evolucao Tab

Progress tracking over time. May contain:
- Body weight entries
- Body measurements (chest, waist, arms, legs)
- Progress photos notes
- Strength milestones

**Write to this tab** when the user reports new measurements or body weight.

### Periodizacao Tab

Mesocycle/macrocycle planning. Expected structure:
- Weeks mapped to training phases
- Volume targets per phase
- Deload weeks marked
- Phase transitions

**Read to understand** the current phase context before making programming recommendations.
**Write only** when making approved program-level changes.

## Handling Sheet Errors

| Issue | Solution |
|---|---|
| Sheet won't load | Retry navigation; check if the user is logged into Google |
| Tab not found | The tab names may have accented characters; try clicking by position |
| Cell is formula-protected | Don't write to it; find the input cell that feeds the formula |
| Data didn't save | Google Sheets auto-saves, but verify by re-reading the cell after entry |
| Wrong decimal separator | Always use comma (`,`) not period (`.`) |

## Quick Reference: Common Actions

### Log a workout session
1. Navigate to sheet -> Registo de Cargas tab
2. Find today's date (or add a new row with today's date)
3. For each exercise: enter weight and reps per set
4. Verify entries by reading back the row

### Check last session's performance
1. Navigate to sheet -> Registo de Cargas tab
2. Find the most recent entry for the target exercise
3. Read weight and reps for all sets
4. Report to user with progression recommendation

### Update training program
1. Navigate to sheet -> Treino tab
2. Locate the exercise to modify
3. Update the cell (exercise name, sets, reps, rest, or PSE)
4. If adding an exercise, find the next empty row in the session block
5. Verify the change was saved

### Record body weight
1. Navigate to sheet -> Evolucao tab
2. Find the date column or next empty row
3. Enter the weight in kg (comma decimal)
4. Verify entry
