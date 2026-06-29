/**
 * 母亲膳食管家 - 统一数据服务层
 * 封装 IndexedDB（src/db.js）与食物种子数据（src/foods_data.js）
 * 所有页面通过 window.DataService 访问
 */

(function (global) {
  'use strict';

  const App = global.App || {};
  const getDB = global.getDB;
  const AppData = global.AppData || {};

  const DataService = {};
  let initPromise = null;

  // ========== 初始化：种子 + 旧数据迁移 ==========
  DataService.init = async function init() {
    if (initPromise) return initPromise;
    initPromise = (async () => {
      const db = await getDB();
      await ensureSeeded(db);
      await migrateLegacyData(db);
    })();
    return initPromise;
  };

 async function ensureSeeded(db) {
   const existing = await db.getAllFoods();
   const foods = (AppData.EXTENDED_FOODS || []).map(food => ({
     ...food,
     category_id: App.CATEGORY_MAP[food.category] || food.category
   }));
   const units = AppData.EXTENDED_UNITS || [];

    if (!existing || existing.length === 0) {
      // 首次：全部种子
     if (foods.length) await db.seedFoods(foods);
     if (units.length) await db.seedUnits(units);
      return;
    }

    // 检查食物数据版本，版本变化则全量重种
    const FOOD_VERSION = '3';
    const storedVersion = localStorage.getItem('food_data_version');
    if (storedVersion !== FOOD_VERSION) {
      // 清除旧数据，重新种子
      await db.clearFoods();
      await db.clearUnits();
      await db.seedFoods(foods);
      await db.seedUnits(units);
      localStorage.setItem('food_data_version', FOOD_VERSION);
      console.log('Food data version updated, re-seeded all foods');
      return;
    }

    // 增量：添加缺失的食物
    const existingIds = new Set(existing.map(f => f.id));
    const newFoods = foods.filter(f => !existingIds.has(f.id));
    if (newFoods.length) {
      await db.seedFoods(newFoods);
      console.log(`Seeded ${newFoods.length} new foods`);
    }

    // 增量：添加缺失的单位
    const allUnits = await db.getAllUnits();
    const existingKeys = new Set(allUnits.map(u => `${u.food_id}|${u.name}`));
    const newUnits = units.filter(u => !existingKeys.has(`${u.food_id}|${u.name}`));
    if (newUnits.length) {
      await db.seedUnits(newUnits);
      console.log(`Seeded ${newUnits.length} new units`);
    }
 }

  async function migrateLegacyData(db) {
    const raw = localStorage.getItem('dietRecords');
    if (!raw) return;

    let legacyRecords = [];
    try {
      legacyRecords = JSON.parse(raw);
      if (!Array.isArray(legacyRecords)) return;
    } catch (e) {
      return;
    }

    const userId = App.getCurrentUserId();

    for (const record of legacyRecords) {
      if (!record || !Array.isArray(record.foods)) continue;
      for (const f of record.foods) {
        if (!f.foodId) continue;
        try {
          const weight = Number(f.weight) || 0;
          await DataService.addIntake({
            userId,
            date: record.date,
            meal: record.meal,
            foodId: f.foodId,
            quantity: Number(f.qty) || 1,
            unit: f.unit || 'g',
            weight: weight > 0 ? weight : undefined,
            nutrients: f.nutrients || undefined
          });
        } catch (err) {
          console.warn('Migrate legacy intake failed:', f, err);
        }
      }
    }

    // 迁移用户限值
    const limitsRaw = localStorage.getItem(`${userId}_limits`);
    if (limitsRaw) {
      try {
        const limits = JSON.parse(limitsRaw);
        if (limits && typeof limits === 'object') {
          await DataService.setUserLimits(userId, limits);
        }
      } catch (e) {
        console.warn('Migrate legacy limits failed:', e);
      }
    }

    // 标记为已迁移，避免重复执行
    localStorage.setItem('dietRecords_migrated', raw);
    localStorage.removeItem('dietRecords');
  }

  // ========== 食物查询 ==========
  DataService.getFoods = async function getFoods(categoryId) {
    const db = await getDB();
    if (categoryId) {
      return db.getFoodsByCategory(categoryId);
    }
    return db.getAllFoods();
  };

  DataService.searchFoods = async function searchFoods(keyword, categoryId) {
    const db = await getDB();
    return db.searchFoods(keyword, categoryId);
  };

  DataService.getFoodById = async function getFoodById(id) {
    const db = await getDB();
    return db.getFoodById(id);
  };

  DataService.getFoodUnits = async function getFoodUnits(foodId) {
    const db = await getDB();
    return db.getUnitsForFood(foodId);
  };

  DataService.getUnitWeight = async function getUnitWeight(foodId, unitName) {
    const db = await getDB();
    return db.getUnitWeight(foodId, unitName);
  };

  // ========== 摄入记录 ==========
  DataService.addIntake = async function addIntake({
    userId,
    date,
    meal,
    foodId,
    quantity,
    unit,
    weight,
    nutrients
  }) {
    const db = await getDB();
    const food = await db.getFoodById(foodId);
    if (!food) {
      throw new Error(`Food not found: ${foodId}`);
    }

    const qty = Number(quantity) || 0;
    if (qty <= 0) {
      throw new Error('Quantity must be greater than 0');
    }

    let unitWeightG;
    let actualGrams;

    if (typeof weight === 'number' && weight > 0) {
      actualGrams = weight;
      unitWeightG = qty > 0 ? weight / qty : weight;
    } else {
      unitWeightG = await db.getUnitWeight(foodId, unit);
      actualGrams = qty * unitWeightG;
    }

    const record = {
      user_id: userId || App.getCurrentUserId(),
      date,
      food_id: foodId,
      food_name: food.name,
      category: food.category_id,
      quantity: qty,
      unit,
      unit_weight_g: unitWeightG,
      actual_grams: actualGrams,
      meal,
      nutrients: nutrients || App.calcNutrients(food, actualGrams),
      created_at: new Date().toISOString()
    };

    return db.addIntake(record);
  };

  DataService.getDailyIntakes = async function getDailyIntakes(date, userId) {
    const db = await getDB();
    return db.getDailyIntakes(userId || App.getCurrentUserId(), date);
  };

  DataService.getDailyTotals = async function getDailyTotals(date, userId) {
    const db = await getDB();
    const totals = await db.getDailyTotals(userId || App.getCurrentUserId(), date);
    if (totals) return totals;

    // 无记录时返回零值汇总
    return {
      user_id: userId || App.getCurrentUserId(),
      date,
      protein_g: 0, fat_g: 0, carbs_g: 0, kcal: 0,
      phosphorus_mg: 0, potassium_mg: 0, sodium_mg: 0,
      calcium_mg: 0, iron_mg: 0, vc_mg: 0,
      oxalate_mg: 0, purine_mg: 0,
      meal_counts: { breakfast: 0, lunch: 0, dinner: 0, snack: 0 },
      limit_status: {}
    };
  };

  DataService.deleteIntake = async function deleteIntake(id) {
    const db = await getDB();
    return db.deleteIntake(id);
  };

  DataService.updateIntake = async function updateIntake(id, {
    quantity,
    unit,
    weight,
    meal,
    nutrients
  }) {
    const db = await getDB();
    const existing = await db.getIntakeById(id);
    if (!existing) {
      throw new Error(`Intake not found: ${id}`);
    }

    const food = await db.getFoodById(existing.food_id);
    if (!food) {
      throw new Error(`Food not found: ${existing.food_id}`);
    }

    const qty = quantity != null ? Number(quantity) : existing.quantity;
    if (qty <= 0) {
      throw new Error('Quantity must be greater than 0');
    }

    let unitWeightG = existing.unit_weight_g;
    let actualGrams = existing.actual_grams;
    let finalUnit = unit || existing.unit;
    let finalNutrients = nutrients || existing.nutrients;

    if (quantity != null || unit != null || weight != null) {
      if (typeof weight === 'number' && weight > 0) {
        actualGrams = weight;
        unitWeightG = qty > 0 ? weight / qty : existing.unit_weight_g;
        finalNutrients = App.calcNutrients(food, actualGrams);
      } else if (unit != null && unit !== existing.unit) {
        unitWeightG = await db.getUnitWeight(existing.food_id, unit);
        actualGrams = qty * unitWeightG;
        finalNutrients = App.calcNutrients(food, actualGrams);
      } else if (quantity != null) {
        actualGrams = qty * unitWeightG;
        finalNutrients = App.calcNutrients(food, actualGrams);
      }
    }

    const updates = {
      quantity: qty,
      unit: finalUnit,
      unit_weight_g: unitWeightG,
      actual_grams: actualGrams,
      nutrients: finalNutrients,
      updated_at: new Date().toISOString()
    };
    if (meal != null) updates.meal = meal;

    return db.updateIntake(id, updates);
  };

  // ========== 我的日常 ==========
  DataService.getRecentFoods = async function getRecentFoods({
    userId,
    days = 30,
    limit = null
  } = {}) {
    const uid = userId || App.getCurrentUserId();
    const end = new Date();
    const start = new Date();
    start.setDate(end.getDate() - days + 1);

    const startStr = App.formatLocalDate(start);
    const endStr = App.formatLocalDate(end);

    const db = await getDB();
    let intakes;
    try {
      intakes = await db.getIntakesByDateRange(uid, startStr, endStr);
    } catch (err) {
      console.error('getRecentFoods query failed:', err);
      return [];
    }

    const latestMap = new Map();
    for (const intake of intakes) {
      const existing = latestMap.get(intake.food_id);
      if (!existing) {
        latestMap.set(intake.food_id, intake);
        continue;
      }
      const timeNew = intake.created_at ? new Date(intake.created_at).getTime() : 0;
      const timeOld = existing.created_at ? new Date(existing.created_at).getTime() : 0;
      if (timeNew > timeOld || (timeNew === timeOld && intake.id > existing.id)) {
        latestMap.set(intake.food_id, intake);
      }
    }

    const sorted = Array.from(latestMap.values()).sort((a, b) => {
      const ta = a.created_at ? new Date(a.created_at).getTime() : 0;
      const tb = b.created_at ? new Date(b.created_at).getTime() : 0;
      if (tb !== ta) return tb - ta;
      return (b.id || 0) - (a.id || 0);
    });

    const results = [];
    for (const intake of sorted) {
      const food = await db.getFoodById(intake.food_id);
      if (!food) continue;
      results.push({
        food,
        lastQuantity: Number(intake.quantity) || 1,
        lastUnit: intake.unit || 'g',
        lastUnitWeightG: Number(intake.unit_weight_g) || 1,
        lastUsedAt: intake.created_at || '',
        lastUsedDate: intake.date || ''
      });
    }

    return limit ? results.slice(0, limit) : results;
  };

  // ========== 用户限值 ==========
  DataService.getUserLimits = async function getUserLimits(userId) {
    const db = await getDB();
    const dbLimits = await db.getUserLimits(userId || App.getCurrentUserId());
    return App.mapDbLimitsToUiLimits(dbLimits);
  };

  DataService.setUserLimits = async function setUserLimits(userId, uiLimits) {
    const db = await getDB();
    const mapped = App.mapUiLimitsToDbLimits(uiLimits);
    await db.setUserLimits(userId || App.getCurrentUserId(), mapped);
  };

  // ========== 统计 ==========
  DataService.getStatsDateRange = async function getStatsDateRange(days, userId) {
    const uid = userId || App.getCurrentUserId();
    const end = new Date();
    const start = new Date();
    start.setDate(end.getDate() - days + 1);

    const startStr = App.formatLocalDate(start);
    const endStr = App.formatLocalDate(end);

    const db = await getDB();
    const intakes = await db.getIntakesByDateRange(uid, startStr, endStr);

    const map = {};
    for (const intake of intakes) {
      if (!map[intake.date]) {
        map[intake.date] = {
          date: intake.date,
          meals: 0,
          foods: {},
          nutrients: {
            protein_g: 0, fat_g: 0, carbs_g: 0, kcal: 0,
            phosphorus_mg: 0, potassium_mg: 0, sodium_mg: 0,
            calcium_mg: 0, iron_mg: 0, vc_mg: 0,
            oxalate_mg: 0, purine_mg: 0
          }
        };
      }
      map[intake.date].meals += 1;
      map[intake.date].foods[intake.food_name] = (map[intake.date].foods[intake.food_name] || 0) + 1;
      const n = intake.nutrients || {};
      map[intake.date].nutrients.protein_g += n.protein || 0;
      map[intake.date].nutrients.fat_g += n.fat || 0;
      map[intake.date].nutrients.carbs_g += n.carbs || 0;
      map[intake.date].nutrients.kcal += n.kcal || 0;
      map[intake.date].nutrients.phosphorus_mg += n.phosphorus || 0;
      map[intake.date].nutrients.potassium_mg += n.potassium || 0;
      map[intake.date].nutrients.sodium_mg += n.sodium || 0;
      map[intake.date].nutrients.calcium_mg += n.calcium || 0;
      map[intake.date].nutrients.iron_mg += n.iron || 0;
      map[intake.date].nutrients.vc_mg += n.vc || 0;
      map[intake.date].nutrients.oxalate_mg += n.oxalate || 0;
      map[intake.date].nutrients.purine_mg += n.purine || 0;
    }

    return Object.values(map).sort((a, b) => a.date.localeCompare(b.date));
  };

  // ========== 导入/导出 ==========
  DataService.exportAllData = async function exportAllData(userId) {
    const db = await getDB();
    const data = await db.exportData(userId || App.getCurrentUserId());
    data.exported_at = new Date().toISOString();
    return data;
  };

  DataService.importAllData = async function importAllData(jsonData) {
    if (!jsonData || typeof jsonData !== 'object') {
      throw new Error('Invalid import data');
    }
    const db = await getDB();
    await db.importData(jsonData);
  };

  // ========== 挂载到全局 ==========
  global.DataService = DataService;
})(typeof window !== 'undefined' ? window : this);
