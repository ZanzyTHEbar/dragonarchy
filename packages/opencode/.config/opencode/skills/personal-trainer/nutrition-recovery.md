# Nutrition & Recovery Protocols

## TDEE Calculation

Use the Mifflin-St Jeor equation (most accurate for non-obese adults):

```
BMR (men) = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
```

For the user (update weight when known):
```
BMR = (10 * weight_kg) + (6.25 * 177) - (5 * 27) + 5
    = (10 * weight_kg) + 1106.25 - 135 + 5
    = (10 * weight_kg) + 976.25
```

Multiply BMR by activity factor:

| Activity Level | Factor | Description |
|---|---|---|
| Sedentary (desk job, no exercise) | 1.2 | Not applicable -- user trains |
| Light (1-3 days/week) | 1.375 | Unlikely for the user |
| Moderate (3-5 days/week) | 1.55 | **Most likely for the user** |
| Active (6-7 days/week) | 1.725 | If training 5-6x with active lifestyle |
| Very active (2x/day or physical job) | 1.9 | Only if adding significant cardio |

`TDEE = BMR * activity_factor`

**Always verify with real-world data**: if the user's weight is stable over 2+ weeks at a given caloric intake, that intake IS their maintenance regardless of what the formula says.

## Macronutrient Targets by Phase

### Hypertrophy (Lean Bulk)

| Macro | Target | Rationale |
|---|---|---|
| Calories | TDEE + 200-300 kcal | Small surplus minimizes fat gain while supporting growth |
| Protein | 1.6-2.2 g/kg bodyweight | Meta-analysis consensus for maximizing MPS (Schoenfeld 2018, Morton 2018) |
| Fat | 0.7-1.0 g/kg bodyweight | Hormone production floor, essential fatty acids |
| Carbs | Remainder of calories | Primary fuel for high-intensity training, glycogen replenishment |

### Maintenance / Recomposition

| Macro | Target | Rationale |
|---|---|---|
| Calories | TDEE (matched) | Body recomposition possible at maintenance for intermediates |
| Protein | 1.8-2.2 g/kg | Higher end to support growth at maintenance calories |
| Fat | 0.8-1.0 g/kg | Same floor |
| Carbs | Remainder | Slightly lower than bulk phase |

### Cut (Fat Loss)

| Macro | Target | Rationale |
|---|---|---|
| Calories | TDEE - 300-500 kcal | Moderate deficit preserves muscle; aggressive deficits lose muscle |
| Protein | 2.0-2.4 g/kg | Higher protein during deficit preserves lean mass (Helms 2014) |
| Fat | 0.7-1.0 g/kg | Don't drop below 0.7 -- hormonal consequences |
| Carbs | Remainder (reduced) | Accept lower carbs; prioritize around training |

### Carb Timing (Practical)

- **Pre-workout (1-2hr before)**: 30-50g carbs + 20-30g protein (meal or shake)
- **Post-workout (within 2hr)**: 40-60g carbs + 30-40g protein (the "anabolic window" is wider than broscience suggests, but post-workout nutrition still matters for glycogen and MPS)
- **Rest of day**: distribute remaining carbs evenly

## Turning Macros Into Meals (Mealie)

The user's Mealie instance is the bridge between abstract macro targets and actual food on the plate. Use it for every meal planning interaction.

### Macro-to-Mealie Search Strategy

Once daily macro targets are set, translate them into Mealie recipe searches:

| Daily Target | Per-Meal Budget (4 meals) | Mealie Search Terms |
|---|---|---|
| 2,800 kcal / 160g P / 70g F / 370g C | ~700 kcal / 40g P per meal | `"chicken"`, `"salmon"`, `"beef"`, `"high-protein"` |
| 2,200 kcal / 170g P / 60g F / 220g C (cut) | ~550 kcal / 42g P per meal | `"low-fat"`, `"cutting"`, `"high-protein"` |

Use `mealie_call` with `tool_id: "recipes_list"` and `params: {"search": "<term>"}` to find candidates. Evaluate each recipe's nutrition data against the meal budget.

### Weekly Meal Prep Workflow

1. **Sunday planning**: calculate the week's macro targets based on training phase
2. **Search Mealie** for 5-7 dinner recipes and 3-4 lunch recipes that hit the targets
3. **Build the meal plan** in Mealie (`households_mealplans_post` for each day)
4. **Generate the shopping list** by adding all recipe ingredients (`lists_recipe_post_2`)
5. **Add staples** not in recipes: protein powder, creatine, eggs, oats, fruit
6. Present the plan to the user with a macro breakdown per day

### Recipe Gap Handling

When Mealie doesn't have a recipe for a specific macro target:
- Search the web for a recipe that fits, then import it via `create_url_post`
- Tag it in Mealie with the appropriate phase tag (`bulking`, `cutting`, `maintenance`)
- Add the `high-protein` tag if protein > 30g/serving

Over time, the Mealie library builds into a personalized macro-optimized recipe database.

For the full Mealie API reference and tagging strategy, see [mealie-integration.md](mealie-integration.md).

## Protein Distribution

Distribute protein across 3-5 meals, each containing 25-40g, to maximize muscle protein synthesis per meal. A 4-meal distribution:

| Meal | Timing | Protein Target |
|---|---|---|
| Breakfast | Morning | 30-40g |
| Lunch | Midday | 30-40g |
| Pre/post-workout | Around training | 30-40g |
| Dinner | Evening | 30-40g |
| Before bed (optional) | 30-60 min before sleep | 20-30g (casein or Greek yogurt preferred) |

## Evidence-Based Supplements

Tiered by strength of evidence:

### Tier 1 -- Strong Evidence (Recommended)

| Supplement | Dose | Timing | Effect |
|---|---|---|---|
| **Creatine monohydrate** | 3-5g/day | Any time, daily | +5-10% strength, increased cell hydration, well-studied safety profile |
| **Protein powder (whey/casein)** | As needed to hit protein target | Post-workout or between meals | Convenience; no advantage over whole food protein |
| **Caffeine** | 3-6 mg/kg bodyweight | 30-60 min pre-workout | Improved performance, reduced RPE; cycle off periodically |
| **Vitamin D** | 2000-4000 IU/day | With a fat-containing meal | Most people in Portugal are still deficient (indoor work, sunscreen); affects testosterone, immunity |

### Tier 2 -- Moderate Evidence (Consider)

| Supplement | Dose | Timing | Effect |
|---|---|---|---|
| **Omega-3 (EPA/DHA)** | 2-3g combined EPA+DHA/day | With food | Anti-inflammatory, joint health, potentially improved MPS |
| **Magnesium** | 200-400mg/day (glycinate or citrate) | Before bed | Sleep quality, muscle relaxation, many people are deficient |
| **Ashwagandha (KSM-66)** | 600mg/day | Morning or split | Cortisol reduction, modest testosterone support, improved recovery (Wankhede 2015) |

### Tier 3 -- Weak/Mixed Evidence (Optional)

| Supplement | Dose | Notes |
|---|---|---|
| Beta-alanine | 3-6g/day | Tingling is harmless; benefits mainly for 1-4 min sustained efforts |
| Citrulline malate | 6-8g pre-workout | Modest pump and endurance benefit |
| HMB | 3g/day | May help during aggressive cuts to preserve muscle; less useful in surplus |

### Do NOT Waste Money On

- BCAAs (you're eating enough protein -- BCAAs are redundant)
- Testosterone boosters (tribulus, D-aspartic acid -- don't work)
- Fat burners (stimulant-based, marginal effect, health risks)
- "Mass gainers" (just expensive sugar -- eat real food)

## Sleep Optimization

Sleep is where growth happens. 7-9 hours is non-negotiable for hypertrophy.

### Sleep Hygiene Protocol

| Factor | Target | Why |
|---|---|---|
| Duration | 7-9 hours | Growth hormone peaks during deep sleep |
| Consistency | Same bed/wake time +/- 30 min, including weekends | Circadian rhythm drives hormone timing |
| Room temperature | 18-20°C (64-68°F) | Core temperature drop triggers melatonin |
| Screen cutoff | 60 min before bed (or use blue light filter) | Blue light suppresses melatonin |
| Caffeine cutoff | 8-10 hours before bed | Caffeine half-life is ~5-6 hours |
| Last meal | 2-3 hours before bed | Large meals disrupt sleep; casein protein is fine |
| Alcohol | Minimize or eliminate | Destroys sleep architecture, reduces MPS by ~20-30%, inhibits recovery |

### If Sleep is Consistently < 7 Hours

This is a training emergency. Poor sleep:
- Reduces testosterone by 10-15% (Leproult 2011)
- Increases cortisol (catabolic)
- Impairs glucose metabolism (nutrient partitioning suffers)
- Reduces training performance and motivation

Fix sleep before adding volume or supplements. It's the highest-ROI intervention possible.

## Mobility & Active Recovery

### Daily Mobility (10 min minimum)

| Focus Area | Exercise | Duration |
|---|---|---|
| Thoracic spine | Foam roll upper back + cat-cow | 2 min |
| Hips | 90/90 stretch + hip flexor lunge | 2 min |
| Shoulders | Band pull-aparts + wall slides | 2 min |
| Ankles | Banded ankle dorsiflexion | 2 min |
| General | Deep squat hold (goblet position) | 2 min |

### Active Recovery Days

On rest days, 20-30 min of low-intensity activity:
- Walking (zone 2, conversational pace)
- Light cycling
- Swimming
- Yoga/stretching

Target heart rate: 100-130 BPM (50-60% max HR). This promotes blood flow for recovery without generating training fatigue.

## Deload Protocols

### When to Deload

- Every 4-6 weeks during a mesocycle (programmed, not reactive)
- When 2+ overreaching signals appear (see SKILL.md workflow 7)
- After a training max attempt / strength test
- When returning from illness or > 1 week off

### How to Deload

| Method | Volume Change | Intensity Change | Best For |
|---|---|---|---|
| **Volume deload** (preferred) | Reduce sets by 40-50% | Keep load the same | Most lifters, most situations |
| **Intensity deload** | Keep sets the same | Reduce load by 40-50% | When joints are beat up |
| **Full rest** | No training for 5-7 days | N/A | Only after extended overreaching (rare) |

**During deload week:**
- Maintain protein intake (don't cut calories)
- Prioritize sleep (aim for 8-9 hours)
- Increase mobility work
- Reduce stimulants (caffeine)
- Assess: which lifts need programming changes? Which muscle groups are lagging?

### Post-Deload

After a deload, you should feel:
- Restored motivation to train
- Reduced joint aches
- Improved sleep quality
- Ready to push hard again

If you don't feel recovered after a deload, the issue is likely outside the gym (sleep, stress, nutrition). Address those first before increasing training load.

## Hydration

| Guideline | Target |
|---|---|
| Baseline | 35-40 ml per kg bodyweight (e.g., 80kg = 2.8-3.2L/day) |
| Training days | Add 500-750 ml per hour of training |
| Hot weather / sweat | Add 500-1000 ml extra |
| Indicator | Urine should be pale yellow (not clear, not dark) |

Dehydration of just 2% bodyweight impairs strength and endurance. Drink before you're thirsty.
