# 母亲膳食管家 — “我的日常”功能设计文档

**日期**：2026-06-29  
**范围**：`add.html`、`src/data-service.js`、`src/common.js`、`tests/test.html`  
**状态**：待实现

---

## 1. 背景与目标

用户在每天记录饮食时，大部分食物是重复出现的（如鸡蛋、牛奶、菠菜）。当前添加流程必须每次都“分类 → 食材 → 数量”，步骤较多。

**目标**：

- 自动把用户最近选择过的食物聚合为“我的日常”。
- 在添加页（`add.html`）选择餐次后，优先展示“我的日常”列表。
- 从“我的日常”选择食物时，自动预填**上次使用的数量和单位**。
- 提供入口切换到原有“按分类查找”模式。
- 不引入新的 IndexedDB 表，不增加 schema 迁移成本。

---

## 2. 数据模型

“我的日常”不新建存储表，而是**从 `daily_intakes` 实时计算**。

### 2.1 计算规则

- **时间窗口**：最近 30 天（含今天）。
- **去重**：同一 `food_id` 只保留一条。
- **保留策略**：保留该食物**最近一次**摄入记录的数量、单位、单位克重、使用时间。
- **排序**：按最近使用时间倒序（越近越靠前）。
- **自动过期**：超过 30 天的记录不再参与计算，食物自然从列表消失。

### 2.2 返回结构

`DataService.getRecentFoods()` 返回：

```js
[
  {
    food: { id, name, emoji, protein_g, ... }, // 完整食物对象
    lastQuantity: 1,
    lastUnit: '个',
    lastUnitWeightG: 50,
    lastUsedAt: '2026-06-29T08:00:00.000Z',
    lastUsedDate: '2026-06-29'
  }
]
```

---

## 3. API 设计

### 3.1 新增 DataService 方法

```js
DataService.getRecentFoods({
  userId,      // 可选，默认 App.getCurrentUserId()
  days = 30,   // 可选，默认 30
  limit = null // 可选，当前实现不限制数量
})
```

**实现步骤**：

1. 计算起止日期：`startDate = formatLocalDate(today - 30天)`，`endDate = formatLocalDate(today)`。
2. 调用 `db.getIntakesByDateRange(uid, startDate, endDate)` 获取记录。
3. 使用 `Map<food_id, intake>` 去重，保留最新一条。
4. 按 `created_at` 降序排列。
5. 对每条记录调用 `db.getFoodById(food_id)` 补全食物信息；若食物不存在则跳过。
6. 返回结果数组。

### 3.2 不新增 IndexedDB store

- 不需要升级 `DB_VERSION`。
- 不需要修改 `onupgradeneeded`。
- 不需要修改导入/导出逻辑。

---

## 4. 页面交互设计

### 4.1 添加页步骤调整

原流程：餐次 → 分类 → 食材 → 数量（4 步）  
新流程：**餐次 → 食材 → 数量（3 步）**

### 4.2 step2：食材选择

进入 step2 后默认显示“我的日常”：

- 顶部两个切换按钮：
  - **我的日常**（默认选中）
  - **按分类查找**
- “我的日常”区域：
  - 列表展示最近 30 天去重后的食物。
  - 每项显示：emoji、食物名、上次数量/单位/克重、相对时间（如“昨天”、“3天前”）。
  - 点击某项后直接进入 step3 数量调整，并预填上次数量/单位。
- 空状态：
  - 文案：“最近 30 天还没有选过食物”。
  - 按钮：“去分类查找”。

### 4.3 切换到“按分类查找”

点击切换按钮后：

- 显示分类网格（谷物、蔬菜、肉蛋等）。
- 点击分类进入该分类下的食物列表。
- 点击食物后进入 step3 数量调整，数量默认 1，单位默认食物第一个可用单位。

### 4.4 step3：数量调整

- 从“我的日常”进入时，数量/单位沿用上次记录。
- 从分类进入时，使用默认值。
- 调整完成后点击“确认保存”。

### 4.5 保存后行为

- 调用 `DataService.addIntake()` 写入 `daily_intakes`。
- 由于“我的日常”实时计算，刚保存的食物会立即出现在列表中。
- 清空当前食材选择，保留餐次，方便继续添加同餐次其他食物。

---

## 5. 状态变量

`add.html` 新增/调整：

```js
let foodSource = 'recent'; // 'recent' | 'category'
```

其他状态复用现有变量：

- `selectedMeal`
- `selectedCategory`
- `selectedFood`
- `currentQty`
- `currentUnit`
- `sessionFoods`

---

## 6. 核心函数

### 6.1 渲染“我的日常”

```js
async function renderRecentFoods() {
  const list = await DataService.getRecentFoods({ days: 30 });
  // 渲染列表或空状态
}
```

### 6.2 选择常用食物

```js
async function selectRecentFood(foodId, lastQty, lastUnit, lastUnitWeightG) {
  selectedFood = await DataService.getFoodById(foodId);
  currentQty = lastQty || 1;

  // 验证 lastUnit 是否仍存在于该食物的单位表中
  const units = await DataService.getFoodUnits(foodId);
  const matched = units.find(u => u.name === lastUnit);
  if (matched) {
    currentUnit = { name: matched.name, weight: matched.weight_g };
  } else if (units.length) {
    currentUnit = { name: units[0].name, weight: units[0].weight_g };
  } else {
    currentUnit = { name: 'g', weight: 1 };
  }

  showStep(3);
  updateQtyDisplay();
  updateQtyPreview();
}
```

### 6.3 切换数据源

```js
function switchFoodSource(source) {
  foodSource = source;
  // 高亮按钮
  if (source === 'recent') renderRecentFoods();
  else renderCategoryGrid();
}
```

---

## 7. 错误处理与边界情况

| 场景 | 处理 |
|---|---|
| 30 天内无记录 | 显示空状态 + “去分类查找”按钮 |
| 历史记录中的食物已被删除 | `getRecentFoods` 内部跳过，不报错 |
| 历史单位已不存在 | `selectRecentFood` 回退到该食物当前第一个可用单位，若都没有则回退到 `g` |
| `getRecentFoods` 查询失败 | 捕获异常，返回空数组，页面降级显示分类入口 |
| 保存失败 | 保持现有逻辑：提示用户，不进入下一步 |

---

## 8. 测试计划

在 `tests/test.html` 中新增以下用例：

1. `getRecentFoods` 返回最近 30 天记录中去重后的食物。
2. 同一食物多次添加，结果中只保留最新一次的数量/单位/时间。
3. 结果按最近使用时间倒序排列。
4. 超过 30 天的记录不参与计算。
5. 食物不存在时静默跳过，不破坏列表。
6. 从“我的日常”选择食物后，step3 正确预填上次数量/单位。
7. 单位回退逻辑：当历史单位不存在时，回退到默认单位。

---

## 9. 非目标

以下功能本次不做，避免 scope 膨胀：

- 手动管理/删除“我的日常”条目（用户已确认完全自动）。
- 在 `foods.html` 或 `settings.html` 中展示“我的日常”。
- 按使用频率排序（当前仅按最近时间）。
- 多用户隔离之外的特殊处理（沿用现有 `user_id` 机制）。

---

## 10. 影响文件

- `src/data-service.js`：新增 `getRecentFoods`。
- `src/common.js`：可选新增相对时间格式化辅助函数（如“昨天”、“3天前”）。
- `add.html`：调整步骤、新增“我的日常”UI 和切换逻辑。
- `tests/test.html`：新增测试用例。

---

## 11. 验收标准

- [ ] 进入 `add.html` 选择餐次后，默认展示“我的日常”列表。
- [ ] 列表中的食物均为最近 30 天内选择过的，去重，按最近时间倒序。
- [ ] 点击“我的日常”食物进入数量页，默认数量/单位为上次使用值。
- [ ] 点击“按分类查找”可切换到原有分类选择流程。
- [ ] 30 天内无记录时显示空状态和分类查找入口。
- [ ] 保存新记录后，该食物立即出现在“我的日常”顶部。
- [ ] `tests/test.html` 新增用例全部通过。

---

*设计批准后将进入 `writing-plans` 阶段生成实现计划。*
