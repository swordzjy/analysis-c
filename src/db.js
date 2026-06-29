/**
 * 母亲膳食管家 - IndexedDB 数据库层
 * 完全离线，浏览器本地存储
 */

const DB_NAME = 'MomDietCareDB';
const DB_VERSION = 1;

// ========== 工具函数：把 IDBRequest / IDBTransaction 包装成 Promise ==========
function promisifyRequest(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

function promisifyTransaction(transaction) {
  return new Promise((resolve, reject) => {
    transaction.oncomplete = () => resolve();
    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () => reject(transaction.error || new Error('Transaction aborted'));
  });
}

class MomDietDB {
  constructor() {
    this.db = null;
  }

  async init() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onerror = () => reject(request.error);
      request.onsuccess = () => {
        this.db = request.result;
        resolve(this.db);
      };

      request.onupgradeneeded = (event) => {
        const db = event.target.result;

        // 1. 食物主表
        const foodStore = db.createObjectStore('foods', { keyPath: 'id' });
        foodStore.createIndex('category', 'category', { unique: false });
        foodStore.createIndex('name', 'name', { unique: false });
        foodStore.createIndex('category_id', 'category_id', { unique: false });
        foodStore.createIndex('oxalate_high', 'oxalate_mg', { unique: false });

        // 2. 计量单位表
        const unitStore = db.createObjectStore('food_units', { keyPath: 'id', autoIncrement: true });
        unitStore.createIndex('food_id', 'food_id', { unique: false });

        // 3. 每日摄入记录
        const intakeStore = db.createObjectStore('daily_intakes', { keyPath: 'id', autoIncrement: true });
        intakeStore.createIndex('user_date', ['user_id', 'date'], { unique: false });
        intakeStore.createIndex('date', 'date', { unique: false });
        intakeStore.createIndex('user_id', 'user_id', { unique: false });

        // 4. 用户限值设定
        db.createObjectStore('user_limits', { keyPath: 'user_id' });

        // 5. 每日汇总缓存（加速查询）
        db.createObjectStore('daily_totals', { keyPath: ['user_id', 'date'] });
      };
    });
  }

  // ========== 食物操作 ==========

  async seedFoods(foodsData) {
    const tx = this.db.transaction('foods', 'readwrite');
    const store = tx.objectStore('foods');
    const requests = foodsData.map(food => store.put(food));
    await Promise.all(requests.map(promisifyRequest));
    await promisifyTransaction(tx);
  }

  async seedUnits(unitsData) {
    const tx = this.db.transaction('food_units', 'readwrite');
    const store = tx.objectStore('food_units');
    const requests = unitsData.map(unit => store.put(unit));
    await Promise.all(requests.map(promisifyRequest));
    await promisifyTransaction(tx);
  }

  async getFoodById(id) {
    const tx = this.db.transaction('foods');
    const store = tx.objectStore('foods');
    return promisifyRequest(store.get(id));
  }

  async searchFoods(keyword, categoryId = null) {
    const tx = this.db.transaction('foods');
    const store = tx.objectStore('foods');
    const request = store.openCursor();
    const results = [];
    const lowerKeyword = keyword ? String(keyword).toLowerCase() : '';

    return new Promise((resolve, reject) => {
      request.onsuccess = (event) => {
        const cursor = event.target.result;
        if (cursor) {
          const food = cursor.value;
          const matchName = !lowerKeyword || food.name.toLowerCase().includes(lowerKeyword);
          const matchCategory = !categoryId || food.category_id === categoryId;
          if (matchName && matchCategory) {
            results.push(food);
          }
          cursor.continue();
        } else {
          resolve(results);
        }
      };
      request.onerror = () => reject(request.error);
    });
  }

  async getFoodsByCategory(categoryId) {
    const tx = this.db.transaction('foods');
    const index = tx.objectStore('foods').index('category_id');
    return promisifyRequest(index.getAll(categoryId));
  }

  async getAllUnits() {
    const tx = this.db.transaction('food_units');
    const store = tx.objectStore('food_units');
    return promisifyRequest(store.getAll());
  }

  async clearFoods() {
    const tx = this.db.transaction('foods', 'readwrite');
    const store = tx.objectStore('foods');
    await promisifyRequest(store.clear());
    await promisifyTransaction(tx);
  }

  async clearUnits() {
    const tx = this.db.transaction('food_units', 'readwrite');
    const store = tx.objectStore('food_units');
    await promisifyRequest(store.clear());
    await promisifyTransaction(tx);
  }

  async getAllFoods() {
    const tx = this.db.transaction('foods');
    const store = tx.objectStore('foods');
    return promisifyRequest(store.getAll());
  }

  async getHighOxalateFoods(threshold = 100) {
    const tx = this.db.transaction('foods');
    const store = tx.objectStore('foods');
    const request = store.openCursor();
    const results = [];

    return new Promise((resolve, reject) => {
      request.onsuccess = (event) => {
        const cursor = event.target.result;
        if (cursor) {
          const food = cursor.value;
          if (food.oxalate_mg >= threshold) {
            results.push(food);
          }
          cursor.continue();
        } else {
          resolve(results.sort((a, b) => b.oxalate_mg - a.oxalate_mg));
        }
      };
      request.onerror = () => reject(request.error);
    });
  }

  // ========== 摄入记录操作 ==========

  async addIntake(record) {
    const tx = this.db.transaction('daily_intakes', 'readwrite');
    const store = tx.objectStore('daily_intakes');
    const id = await promisifyRequest(store.add(record));
    await promisifyTransaction(tx);

    // 更新每日汇总
    await this.updateDailyTotals(record.user_id, record.date);
    return id;
  }

  async getDailyIntakes(userId, date) {
    const tx = this.db.transaction('daily_intakes');
    const index = tx.objectStore('daily_intakes').index('user_date');
    return promisifyRequest(index.getAll([userId, date]));
  }

  async getIntakeById(id) {
    const tx = this.db.transaction('daily_intakes');
    const store = tx.objectStore('daily_intakes');
    return promisifyRequest(store.get(id));
  }

  async getIntakesByDateRange(userId, startDate, endDate) {
    const tx = this.db.transaction('daily_intakes');
    const store = tx.objectStore('daily_intakes');
    const request = store.openCursor();
    const results = [];

    return new Promise((resolve, reject) => {
      request.onsuccess = (event) => {
        const cursor = event.target.result;
        if (cursor) {
          const record = cursor.value;
          if (record.user_id === userId && record.date >= startDate && record.date <= endDate) {
            results.push(record);
          }
          cursor.continue();
        } else {
          resolve(results);
        }
      };
      request.onerror = () => reject(request.error);
    });
  }

  async deleteIntake(id) {
    const tx = this.db.transaction(['daily_intakes', 'daily_totals'], 'readwrite');
    const store = tx.objectStore('daily_intakes');
    const record = await promisifyRequest(store.get(id));
    if (!record) {
      await promisifyTransaction(tx);
      return false;
    }
    await promisifyRequest(store.delete(id));
    await promisifyTransaction(tx);

    // 重新计算当日汇总
    await this.updateDailyTotals(record.user_id, record.date);
    return true;
  }

  async updateIntake(id, updates) {
    const tx = this.db.transaction(['daily_intakes', 'daily_totals'], 'readwrite');
    const store = tx.objectStore('daily_intakes');
    const record = await promisifyRequest(store.get(id));
    if (!record) {
      await promisifyTransaction(tx);
      throw new Error(`Intake not found: ${id}`);
    }

    const updated = { ...record, ...updates };
    await promisifyRequest(store.put(updated));
    await promisifyTransaction(tx);

    await this.updateDailyTotals(record.user_id, record.date);
    return updated;
  }

  // ========== 营养计算 ==========

  async updateDailyTotals(userId, date) {
    const intakes = await this.getDailyIntakes(userId, date);
    const limits = await this.getUserLimits(userId);

    const totals = {
      user_id: userId,
      date: date,
      protein_g: 0,
      fat_g: 0,
      carbs_g: 0,
      kcal: 0,
      phosphorus_mg: 0,
      potassium_mg: 0,
      sodium_mg: 0,
      calcium_mg: 0,
      iron_mg: 0,
      vc_mg: 0,
      oxalate_mg: 0,
      purine_mg: 0,
      meal_counts: { breakfast: 0, lunch: 0, dinner: 0, snack: 0 }
    };

    for (const intake of intakes) {
      const food = await this.getFoodById(intake.food_id);
      if (!food) continue;

      const ratio = intake.actual_grams / 100;

      totals.protein_g += (food.protein_g || 0) * ratio;
      totals.fat_g += (food.fat_g || 0) * ratio;
      totals.carbs_g += (food.carbs_g || 0) * ratio;
      totals.kcal += (food.kcal || 0) * ratio;
      totals.phosphorus_mg += (food.phosphorus_mg || 0) * ratio;
      totals.potassium_mg += (food.potassium_mg || 0) * ratio;
      totals.sodium_mg += (food.sodium_mg || 0) * ratio;
      totals.calcium_mg += (food.calcium_mg || 0) * ratio;
      totals.iron_mg += (food.iron_mg || 0) * ratio;
      totals.vc_mg += (food.vc_mg || 0) * ratio;
      totals.oxalate_mg += (food.oxalate_mg || 0) * ratio;
      totals.purine_mg += (food.purine_mg || 0) * ratio;

      if (intake.meal) {
        totals.meal_counts[intake.meal] = (totals.meal_counts[intake.meal] || 0) + 1;
      }
    }

    // 计算限值状态
    totals.limit_status = {
      protein: { value: totals.protein_g, limit: limits.protein_g_max || 50, pct: (totals.protein_g / (limits.protein_g_max || 50)) * 100 },
      phosphorus: { value: totals.phosphorus_mg, limit: limits.phosphorus_mg_max || 1000, pct: (totals.phosphorus_mg / (limits.phosphorus_mg_max || 1000)) * 100 },
      potassium: { value: totals.potassium_mg, limit: limits.potassium_mg_max || 2500, pct: (totals.potassium_mg / (limits.potassium_mg_max || 2500)) * 100 },
      sodium: { value: totals.sodium_mg, limit: limits.sodium_mg_max || 2000, pct: (totals.sodium_mg / (limits.sodium_mg_max || 2000)) * 100 },
      calcium: { value: totals.calcium_mg, limit: limits.calcium_mg_max || 800, pct: (totals.calcium_mg / (limits.calcium_mg_max || 800)) * 100 },
      vc: { value: totals.vc_mg, limit: limits.vc_mg_max || 100, pct: (totals.vc_mg / (limits.vc_mg_max || 100)) * 100 },
      oxalate: { value: totals.oxalate_mg, limit: limits.oxalate_mg_max || 200, pct: (totals.oxalate_mg / (limits.oxalate_mg_max || 200)) * 100 },
      purine: { value: totals.purine_mg, limit: limits.purine_mg_max || 300, pct: (totals.purine_mg / (limits.purine_mg_max || 300)) * 100 }
    };

    // 保存汇总
    const tx = this.db.transaction('daily_totals', 'readwrite');
    const store = tx.objectStore('daily_totals');
    store.put(totals);
    await promisifyTransaction(tx);

    return totals;
  }

  async getDailyTotals(userId, date) {
    const tx = this.db.transaction('daily_totals');
    const store = tx.objectStore('daily_totals');
    return promisifyRequest(store.get([userId, date]));
  }

  // ========== 用户限值 ==========

  async setUserLimits(userId, limits) {
    const tx = this.db.transaction('user_limits', 'readwrite');
    const store = tx.objectStore('user_limits');

    const defaultLimits = {
      protein_g_max: 50,
      phosphorus_mg_max: 1000,
      potassium_mg_max: 2500,
      sodium_mg_max: 2000,
      calcium_mg_max: 800,
      vc_mg_max: 100,
      oxalate_mg_max: 200,
      purine_mg_max: 300,
      weight_kg: null,
      condition: ''
    };

    await promisifyRequest(store.put({
      user_id: userId,
      ...defaultLimits,
      ...limits,
      updated_at: new Date().toISOString()
    }));
    await promisifyTransaction(tx);
  }

  async getUserLimits(userId = 'user_1') {
    const tx = this.db.transaction('user_limits');
    const store = tx.objectStore('user_limits');
    const result = await promisifyRequest(store.get(userId));

    if (!result) {
      await this.setUserLimits(userId, {});
      return this.getUserLimits(userId);
    }

    return result;
  }

  // ========== 计量单位 ==========

  async getUnitWeight(foodId, unitName) {
    const tx = this.db.transaction('food_units');
    const index = tx.objectStore('food_units').index('food_id');
    const units = await promisifyRequest(index.getAll(foodId));

    const unit = units.find(u => u.name === unitName);
    return unit ? unit.weight_g : 1; // 默认按克
  }

  async getUnitsForFood(foodId) {
    const tx = this.db.transaction('food_units');
    const index = tx.objectStore('food_units').index('food_id');
    return promisifyRequest(index.getAll(foodId));
  }

  // ========== 数据导出/导入 ==========

  async exportData(userId = 'user_1') {
    const data = {
      foods: [],
      units: [],
      intakes: [],
      limits: null,
      exported_at: new Date().toISOString()
    };

    data.foods = await promisifyRequest(this.db.transaction('foods').objectStore('foods').getAll());
    data.units = await promisifyRequest(this.db.transaction('food_units').objectStore('food_units').getAll());
    data.intakes = await promisifyRequest(this.db.transaction('daily_intakes').objectStore('daily_intakes').getAll());
    data.limits = await this.getUserLimits(userId);

    return data;
  }

  async importData(jsonData) {
    if (jsonData.foods && jsonData.foods.length) {
      await this.seedFoods(jsonData.foods);
    }
    if (jsonData.units && jsonData.units.length) {
      await this.seedUnits(jsonData.units);
    }
    if (jsonData.intakes && jsonData.intakes.length) {
      const tx = this.db.transaction('daily_intakes', 'readwrite');
      const store = tx.objectStore('daily_intakes');
      const requests = jsonData.intakes.map(intake => store.put(intake));
      await Promise.all(requests.map(promisifyRequest));
      await promisifyTransaction(tx);
    }
    if (jsonData.limits) {
      const userId = jsonData.limits.user_id || 'user_1';
      await this.setUserLimits(userId, jsonData.limits);
    }
  }
}

// 单例模式
let dbInstance = null;

async function getDB() {
  if (!dbInstance) {
    dbInstance = new MomDietDB();
    await dbInstance.init();
  }
  return dbInstance;
}

// 食物分类常量
const FOOD_CATEGORIES = [
  { id: 'grain', name: '谷物', icon: '🌾' },
  { id: 'beans', name: '豆类', icon: '🫘' },
  { id: 'vegetable', name: '蔬菜', icon: '🥬' },
  { id: 'fruit', name: '水果', icon: '🍎' },
  { id: 'meat', name: '肉蛋', icon: '🥩' },
  { id: 'dairy', name: '奶类', icon: '🥛' },
  { id: 'nuts', name: '油脂坚果', icon: '🥜' }
];

// 餐次常量
const MEALS = [
  { id: 'breakfast', name: '早餐', icon: '🌅' },
  { id: 'lunch', name: '午餐', icon: '☀️' },
  { id: 'dinner', name: '晚餐', icon: '🌙' },
  { id: 'snack', name: '加餐', icon: '🍪' }
];

// 营养素配置（用于 UI 显示）
const NUTRIENT_CONFIG = {
  protein: { name: '蛋白质', unit: 'g', color: '#FF6B6B', limit_key: 'protein_g_max' },
  phosphorus: { name: '磷', unit: 'mg', color: '#4ECDC4', limit_key: 'phosphorus_mg_max' },
  potassium: { name: '钾', unit: 'mg', color: '#45B7D1', limit_key: 'potassium_mg_max' },
  sodium: { name: '钠', unit: 'mg', color: '#96CEB4', limit_key: 'sodium_mg_max' },
  calcium: { name: '钙', unit: 'mg', color: '#9c27b0', limit_key: 'calcium_mg_max' },
  oxalate: { name: '草酸', unit: 'mg', color: '#FFEAA7', limit_key: 'oxalate_mg_max' },
  purine: { name: '嘌呤', unit: 'mg', color: '#795548', limit_key: 'purine_mg_max' },
  vc: { name: '维生素C', unit: 'mg', color: '#DDA0DD', limit_key: 'vc_mg_max' }
};

// 浏览器全局挂载
if (typeof window !== 'undefined') {
  window.MomDietDB = MomDietDB;
  window.getDB = getDB;
  window.FOOD_CATEGORIES = FOOD_CATEGORIES;
  window.MEALS = MEALS;
  window.NUTRIENT_CONFIG = NUTRIENT_CONFIG;
}

// Node 导出
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { MomDietDB, getDB, FOOD_CATEGORIES, MEALS, NUTRIENT_CONFIG };
}
