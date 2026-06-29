# Foods Library Redesign

**Date:** 2026-06-29
**Goal:** Redesign the 食物库 (Foods Library) page for a 60+ year-old mother who browses to learn about foods rather than to immediately select them for recording.

## User Context

- User is a 60+ year-old mother managing kidney health through diet
- Key nutrients to monitor: oxalate, purine, phosphorus, potassium, protein
- She opens the food library to understand what foods are beneficial or risky
- She does NOT open it to immediately select foods for recording — that happens via the + button on the home page
- She may search for foods not in the database and expects to see their nutritional composition

## Design Principles

1. **Browsing-first, not action-first** — the page is for learning, not selecting
2. **Progressive disclosure** — show categories first, then foods within a category
3. **Health context baked in** — nutritional risk labels visible on every food card
4. **Minimal cognitive load** — one thing at a time, large touch targets, clear labels
5. **Search with fallback** — search local DB first, then API, then manual input

## Architecture

```
┌─────────────────────────────┐
│ Header: 🍽️ 食物库            │
│ Subtitle: 了解食物，选对食物   │
├─────────────────────────────┤
│ 🔍 Search bar (always visible) │
├─────────────────────────────┤
│ Category grid (3 columns)    │
│ 🌾谷物5  🫘豆类4  🥬蔬菜12   │
│ 🍎水果6  🥩肉蛋8  🥛奶类3   │
│ 🥜坚果4                      │
│                              │
│ On category tap ↓            │
├─────────────────────────────┤
│ ← Back  蔬菜 · 12 种          │
│ Filter: [全部] [✅护肾] [⚠️高草酸] [🧬高嘌呤] │
│                              │
│ Food cards with:             │
│ - Name + emoji               │
│ - Health badges              │
│ - Mini nutrient bar chart    │
│ - Dimension-specific scoring │
├─────────────────────────────┤
│ Tab Bar: 今日|食物库|趋势|设置  │
└─────────────────────────────┘
```

## Component Details

### Category Grid
- 3-column grid of category cards: grain, beans, vegetable, fruit, meat, dairy, nuts
- Each card shows emoji + category name + food count
- Tapping a card navigates into that category's food list

### Category Food List
- Header with back button and category name + count
- Filter pills: 全部 (all), ✅护肾, ⚠️高草酸, 🧬高嘌呤
- Filters are cumulative within the category — they narrow the food list
- Foods matching the filter criteria are shown; non-matching are hidden

### Food Card
Every food card displays:
- **Name + Emoji**: Large, readable
- **Health badges**: `[高草酸⚠️]` (oxalate ≥ 100), `[高嘌呤]` (purine ≥ 150), `[高钾]` (potassium ≥ 300), `[高磷]` (phosphorus ≥ 200), `[✅护肾]` (all three low)
- **Mini bar chart**: 6 bars representing protein (green), oxalate (red), potassium (orange), phosphorus (blue), purine (brown), calcium (purple) — normalized to the highest value
- **Tapping** opens the food detail modal showing per-100g nutrition vs daily limits

### Health Filters
- **✅ 护肾**: oxalate < 50 AND purine < 100 AND phosphorus < 150
- **Sort direction**: Tapping an active filter reverses sort (toggle ↑↓). Default: 护肾 ascending (best first), 高草酸/高嘌呤 descending (highest first)
- **⚠️ 高草酸**: oxalate ≥ 100 mg/100g, sorted descending
- **🧬 高嘌呤**: purine ≥ 150 mg/100g, sorted descending
- Filters only show foods matching the criteria within the selected category
- Multiple filters can be active simultaneously (AND logic)
- Tapping "全部" clears all filters and shows all foods unsorted

### Search
- **Local match**: Filter current view by keyword, prioritize foods not eaten in 30 days
- **No local match**: Auto-query Open Food Facts API for nutritional data
- **API data found**: Display nutrition analysis with source attribution
- **API data not found**: Show manual input form (protein, potassium, phosphorus, calcium, oxalate, purine)

### Food Detail Modal
- Per-100g nutrition values compared to daily limits
- Each nutrient shows: icon, name, value, daily limit, status emoji (✅/⚠️/🔴)
- Retained from previous implementation

## Data Flow

1. `init()` → load all foods from IndexedDB via `DataService.getFoods()`
2. `renderCategoryGrid()` → display category cards with counts
3. User taps category → `selectCategory(catId)` → `renderFoodList(catId, activeFilters)`
4. User taps filter → `toggleFilter(filterId)` → re-render food list
5. User searches → `onSearch(keyword)` → filter by keyword within current view → if no results → `fetchFoodNutrition(keyword)` via Open Food Facts API
6. User taps food card → `showFoodDetail(foodId)` → modal with per-100g nutrition analysis

## Error Handling

- API fetch failure → show manual input form as fallback
- Empty category → show "暂无食物" empty state
- Empty filter results → show "该筛选下无食物" empty state
- Search with no results → API auto-fetch; if API also fails → manual form

## Files Modified

- `foods.html` — complete rewrite of HTML, CSS, and JS
