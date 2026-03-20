# Mealie Integration Guide

The user self-hosts a Mealie instance for recipes, meal plans, and grocery shopping. Access it via the `user-mealie` MCP server using two tools: `mealie_registry` (discover operations) and `mealie_call` (execute operations).

## Workflow Pattern

Always follow: **Discover -> Reason -> Act**

1. **Discover**: call `mealie_registry` with a focused `query` (e.g., "recipe", "mealplan", "shopping") to find the exact `short_id` for the operation you need
2. **Reason**: state what you're about to do and why in nutritionist terms ("I'll search for high-protein recipes to hit your 160g protein target for tomorrow's meal plan")
3. **Act**: call `mealie_call` with the correct `tool_id` and `params`, then interpret the result in training/nutrition context

## Key Operations

### Recipes

| Operation | tool_id | Params | Use Case |
|---|---|---|---|
| List all recipes | `recipes_list` | `search`, `perPage` | Find existing recipes matching macro targets |
| Get one recipe | `recip_get` | `slug` | Pull full recipe with nutrition data and ingredients |
| Create recipe (JSON) | `recipes_post` | `requestBody` (recipe object) | Add new macro-friendly recipes to the library |
| Scrape recipe from URL | `create_url_post` | `requestBody: { url: "..." }` | Import recipes the user finds online |
| Suggest recipes | `recipes_suggestions_list` | (query params) | Get AI-powered suggestions from the existing library |
| Get recipe by category | `organizers_categori_get` | category slug | Find recipes by type (e.g., "high-protein", "post-workout") |

### Meal Plans

| Operation | tool_id | Params | Use Case |
|---|---|---|---|
| List meal plans | `households_mealplans_list` | `start_date`, `end_date` | Review planned meals for the week |
| Get today's meals | `mealplans_today_list` | (none) | Check what's on today's plan |
| Create meal plan entry | `households_mealplans_post` | `requestBody: { date, entryType, title, recipeId }` | Add a meal to a specific day |
| Update meal plan | `households_mealplan_put` | `item_id`, `requestBody` | Swap a meal |
| Delete meal plan entry | `households_mealplan_delete` | `item_id` | Remove a meal |
| Random meal suggestion | `mealplans_random_post` | (none) | Get a random recipe following household rules |

Entry types for meal plans: `breakfast`, `lunch`, `dinner`, `snack`, `side`

### Shopping Lists

| Operation | tool_id | Params | Use Case |
|---|---|---|---|
| List all shopping lists | `shopping_lists_list` | (none) | Find existing lists |
| Get one shopping list | `shopping_list_get` | `item_id` | View items on a list |
| Create shopping list | `shopping_lists_post` | `requestBody: { name }` | Start a new grocery list |
| Add recipe ingredients to list | `lists_recipe_post_2` | list id, recipe id | Auto-populate groceries from a meal plan |
| Add single item | `shopping_items_post` | `requestBody: { shoppingListId, note, quantity, unit }` | Add individual items (supplements, snacks) |
| Check off item | `shopping_item_put` | `item_id`, `requestBody: { checked: true }` | Mark items as purchased |

### Foods & Ingredients

| Operation | tool_id | Params | Use Case |
|---|---|---|---|
| List all foods | `foods_list` | `search`, `perPage` | Search the food database |
| Get one food | `food_get` | `item_id` | Get food details |
| Create food | `foods_post` | `requestBody` | Add a custom food (e.g., a specific protein powder) |
| Parse ingredient string | `parser_ingredient_post` | `requestBody: { ingredient: "200g chicken breast" }` | Parse natural language ingredients |

### Organization

| Operation | tool_id | Params | Use Case |
|---|---|---|---|
| List categories | `organizers_categories_list` | (none) | See recipe categories |
| Create category | `organizers_categories_post` | `requestBody: { name }` | Add categories like "bulking", "cutting", "post-workout" |
| List tags | `organizers_tags_list` | (none) | See recipe tags |
| Create tag | `organizers_tags_post` | `requestBody: { name }` | Add tags like "high-protein", "meal-prep", "quick" |

## Nutrition-Aware Meal Planning Pipeline

This is the end-to-end workflow for building a macro-aligned meal plan.

### Step 1: Calculate Daily Targets

Use the user's current macro targets from the training phase (see nutrition-recovery.md):

```
Example for hypertrophy bulk (80kg user):
- Calories: ~2,800 kcal
- Protein: 160g (2.0g/kg)
- Fat: 70g (0.88g/kg)
- Carbs: 370g (remainder)
```

### Step 2: Search Existing Recipes

Call `recipes_list` with search terms matching the macro profile:

```
mealie_call(tool_id="recipes_list", params={"search": "chicken", "perPage": 10})
```

For each result, check if the recipe has nutrition data. If it does, evaluate against the meal's macro budget (e.g., dinner should be ~35% of daily calories).

### Step 3: Build the Day

A hypertrophy meal plan day should have 4-5 meals:

| Meal | Timing | Macro Priority | Calorie Share |
|---|---|---|---|
| Breakfast | Morning | Balanced, moderate carbs | 20-25% |
| Lunch | Midday | High protein, moderate carbs | 25-30% |
| Pre-workout snack | 1-2hr before training | High carbs, moderate protein | 10-15% |
| Post-workout / Dinner | After training | High protein, high carbs | 30-35% |
| Evening snack (optional) | Before bed | Protein (casein), low carb | 5-10% |

### Step 4: Create Meal Plan Entries

For each meal, call `households_mealplans_post`:

```
mealie_call(
  tool_id="households_mealplans_post",
  params={
    "requestBody": {
      "date": "2026-02-19",
      "entryType": "dinner",
      "recipeId": "<recipe-id-from-step-2>"
    }
  }
)
```

### Step 5: Generate Shopping List

Once the week's plan is set, auto-populate the grocery list:

```
For each recipe in the week's plan:
  mealie_call(
    tool_id="lists_recipe_post_2",
    params={
      "item_id": "<shopping-list-id>",
      "requestBody": { "recipeId": "<recipe-id>" }
    }
  )
```

Then add any non-recipe items (supplements, protein powder, etc.) individually.

### Step 6: Review and Optimize

- Pull the complete shopping list with `shopping_list_get`
- Check for duplicate ingredients (Mealie may auto-merge)
- Add supplement items manually (creatine, vitamin D, etc.)
- Present the final list to the user

## Recipe Tagging Strategy

Use tags and categories to make future searches faster:

### Recommended Categories

| Category | Purpose |
|---|---|
| Bulking | Calorie-surplus friendly meals |
| Cutting | Low-calorie, high-protein meals |
| Maintenance | Balanced macro meals |
| Meal Prep | Batch-cookable, stores well |
| Post-Workout | High carb + protein, fast to prepare |
| Quick (<20 min) | When time is short |

### Recommended Tags

| Tag | Purpose |
|---|---|
| high-protein | > 30g protein per serving |
| low-fat | < 10g fat per serving |
| high-carb | > 50g carbs per serving |
| vegetarian | No meat |
| budget | Cheap ingredients |
| portuguese | Local Portuguese cuisine |

When creating or importing a recipe, always tag it appropriately so future macro-targeted searches are fast.

## Importing New Recipes

When the user finds a recipe online:

1. Call `create_url_post` with the URL to scrape it
2. Review the imported recipe for accuracy
3. Add nutrition data if missing (estimate from ingredients)
4. Tag and categorize it
5. If it fits the current training phase, add it to the meal plan

When the user describes a recipe verbally or from a photo:

1. Parse ingredients with `parser_ingredients_post`
2. Build the recipe object
3. Call `recipes_post` to create it
4. Tag and categorize

## Integration with Training Phases

The PT skill should automatically adjust meal plan recommendations based on the current training phase:

| Training Phase | Mealie Search Strategy |
|---|---|
| Hypertrophy accumulation | Search "bulking" category, prioritize high-carb + high-protein recipes |
| Strength intensification | Same calories, potentially higher protein, search "high-protein" tag |
| Deload week | Slight calorie reduction, search "maintenance" category |
| Cut phase | Search "cutting" category, prioritize recipes tagged "high-protein" + "low-fat" |

Always state the nutritional reasoning when recommending a recipe: "This meal gives you 45g protein and 60g carbs -- that's exactly what you need post-workout to replenish glycogen and spike MPS."
