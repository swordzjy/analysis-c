/**
 * 母亲膳食管家 - 公共工具函数
 * 所有页面通过经典脚本加载，函数挂载到 window.App
 */

(function (global) {
  'use strict';

  const App = {};

  // ========== HTML 安全 ==========
  App.escapeHtml = function escapeHtml(str) {
    if (str == null) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  };

  // ========== 用户与导航 ==========
  App.getCurrentUserId = function getCurrentUserId() {
    return localStorage.getItem('currentUserId') || 'user_1';
  };

  App.goPage = function goPage(url) {
    window.location.href = url;
  };

  // ========== 日期与时间 ==========
  App.formatLocalDate = function formatLocalDate(date) {
    const d = date instanceof Date ? date : new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  App.parseLocalDate = function parseLocalDate(dateStr) {
    const [year, month, day] = dateStr.split('-').map(Number);
    return new Date(year, month - 1, day);
  };

  App.getWeekday = function getWeekday(date) {
    const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    const d = date instanceof Date ? date : new Date(date);
    return weekdays[d.getDay()];
  };

  App.formatDisplayDate = function formatDisplayDate(date) {
    const d = date instanceof Date ? date : new Date(date);
    const m = d.getMonth() + 1;
    const day = d.getDate();
    return `${m}月${day}日 <span class="weekday">${App.getWeekday(d)}</span>`;
  };

  // ========== 餐次 ==========
  App.getMealName = function getMealName(key) {
    const names = { breakfast: '早餐', lunch: '午餐', dinner: '晚餐', snack: '加餐' };
    return names[key] || key;
  };

  App.getMealTime = function getMealTime(meal) {
    const times = { breakfast: '07:30', lunch: '12:00', dinner: '18:00', snack: '15:00' };
    return times[meal] || '12:00';
  };

  // ========== 分类映射 ==========
  App.CATEGORY_MAP = {
    '谷物': 'grain',
    '豆类': 'beans',
    '蔬菜': 'vegetable',
    '水果': 'fruit',
    '肉蛋': 'meat',
    '奶类': 'dairy',
    '油脂坚果': 'nuts'
  };

  App.CATEGORY_NAME_MAP = {
    grain: '谷物',
    beans: '豆类',
    vegetable: '蔬菜',
    fruit: '水果',
    meat: '肉蛋',
    dairy: '奶类',
    nuts: '油脂坚果'
  };

  App.CATEGORY_ICONS = {
    grain: '🌾',
    beans: '🫘',
    vegetable: '🥬',
    fruit: '🍎',
    meat: '🥩',
    dairy: '🥛',
    nuts: '🥜'
  };

  App.getCategoryName = function getCategoryName(id) {
    return App.CATEGORY_NAME_MAP[id] || id;
  };

  // ========== 营养素配置 ==========
  App.getNutrientConfig = function getNutrientConfig(limits) {
    // limits 来自 data-service，键为 UI 键：protein/potassium/phosphorus/calcium/oxalate/purine
    return {
      protein: { name: '蛋白质', unit: 'g', limit: limits.protein || 50, icon: '💪', color: 'safe' },
      potassium: { name: '钾', unit: 'mg', limit: limits.potassium || 2500, icon: '⚡', color: 'warning' },
      phosphorus: { name: '磷', unit: 'mg', limit: limits.phosphorus || 1000, icon: '🦴', color: 'safe' },
      calcium: { name: '钙', unit: 'mg', limit: limits.calcium || 800, icon: '🥛', color: 'safe' },
      oxalate: { name: '草酸', unit: 'mg', limit: limits.oxalate || 200, icon: '⚠️', color: 'danger' },
      purine: { name: '嘌呤', unit: 'mg', limit: limits.purine || 300, icon: '🧬', color: 'warning' }
    };
  };

  // 由 DB 限值对象（protein_g_max...）转换到 UI 限值对象
  App.mapDbLimitsToUiLimits = function mapDbLimitsToUiLimits(dbLimits) {
    return {
      protein: dbLimits.protein_g_max,
      phosphorus: dbLimits.phosphorus_mg_max,
      potassium: dbLimits.potassium_mg_max,
      sodium: dbLimits.sodium_mg_max,
      calcium: dbLimits.calcium_mg_max,
      vc: dbLimits.vc_mg_max,
      oxalate: dbLimits.oxalate_mg_max,
      purine: dbLimits.purine_mg_max
    };
  };

  App.mapUiLimitsToDbLimits = function mapUiLimitsToDbLimits(uiLimits) {
    const mapped = {};
    if (uiLimits.protein != null) mapped.protein_g_max = Number(uiLimits.protein);
    if (uiLimits.phosphorus != null) mapped.phosphorus_mg_max = Number(uiLimits.phosphorus);
    if (uiLimits.potassium != null) mapped.potassium_mg_max = Number(uiLimits.potassium);
    if (uiLimits.sodium != null) mapped.sodium_mg_max = Number(uiLimits.sodium);
    if (uiLimits.calcium != null) mapped.calcium_mg_max = Number(uiLimits.calcium);
    if (uiLimits.vc != null) mapped.vc_mg_max = Number(uiLimits.vc);
    if (uiLimits.oxalate != null) mapped.oxalate_mg_max = Number(uiLimits.oxalate);
    if (uiLimits.purine != null) mapped.purine_mg_max = Number(uiLimits.purine);
    return mapped;
  };

  // ========== 营养计算 ==========
  App.calcNutrients = function calcNutrients(food, grams) {
    const ratio = grams / 100;
    return {
      protein: (food.protein_g || 0) * ratio,
      fat: (food.fat_g || 0) * ratio,
      carbs: (food.carbs_g || 0) * ratio,
      kcal: (food.kcal || 0) * ratio,
      phosphorus: (food.phosphorus_mg || 0) * ratio,
      potassium: (food.potassium_mg || 0) * ratio,
      sodium: (food.sodium_mg || 0) * ratio,
      calcium: (food.calcium_mg || 0) * ratio,
      iron: (food.iron_mg || 0) * ratio,
      vc: (food.vc_mg || 0) * ratio,
      oxalate: (food.oxalate_mg || 0) * ratio,
      purine: (food.purine_mg || 0) * ratio
    };
  };

  // ========== 状态判断 ==========
  App.getStatusClass = function getStatusClass(value, limit) {
    if (!limit || limit <= 0) return 'safe';
    const pct = value / limit;
    if (pct > 1) return 'danger';
    if (pct > 0.8) return 'warning';
    return 'safe';
  };

  App.getStatusText = function getStatusText(value, limit) {
    const cls = App.getStatusClass(value, limit);
    if (cls === 'danger') return '超标';
    if (cls === 'warning') return '接近';
    return '正常';
  };

  // ========== 格式化 ==========
  App.round1 = function round1(value) {
    return Math.round(value * 10) / 10;
  };

  App.formatNumber = function formatNumber(value, decimals = 0) {
    const n = Number(value);
    if (Number.isNaN(n)) return '0';
    return n.toFixed(decimals);
  };

  App.formatRelativeDate = function formatRelativeDate(isoString) {
    if (!isoString) return '';
    const date = new Date(isoString);
    if (Number.isNaN(date.getTime())) return '';

    const today = new Date();
    const dateStr = App.formatLocalDate(date);
    const todayStr = App.formatLocalDate(today);
    if (dateStr === todayStr) return '今天';

    const yesterday = new Date(today);
    yesterday.setDate(today.getDate() - 1);
    if (dateStr === App.formatLocalDate(yesterday)) return '昨天';

    const startOfToday = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime();
    const startOfDate = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
    const diffDays = Math.floor((startOfToday - startOfDate) / 86400000);
    if (diffDays > 1) return `${diffDays}天前`;
    return '';
  };

  // ========== 应用初始化 ==========
  App.initApp = async function initApp() {
    // 初始化数据层（种子 + 迁移）
    if (global.DataService && typeof global.DataService.init === 'function') {
      try {
        await global.DataService.init();
      } catch (err) {
        console.error('DataService init failed:', err);
      }
    }

    // 注册 Service Worker（仅在安全上下文）
    if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost' || location.hostname === '127.0.0.1')) {
      navigator.serviceWorker.register('./sw.js').catch(err => {
        console.error('Service Worker registration failed:', err);
      });
    }
  };

  // ========== 挂载到全局 ==========
  global.App = App;

  // 兼容直接访问常用函数
  global.escapeHtml = App.escapeHtml;
  global.formatLocalDate = App.formatLocalDate;
  global.goPage = App.goPage;
})(typeof window !== 'undefined' ? window : this);
