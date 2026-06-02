/// 应用常量定义
class AppConstants {
  // 应用信息
  static const String appName = '维生素分析仪';
  static const String appVersion = '1.0.0';
  static const String appSlogan = '拍一拍，知营养';

  // 数据库
  static const String dbName = 'vitamin_analyzer.db';
  static const int dbVersion = 1;

  // 表名
  static const String tableFoods = 'foods';
  static const String tableVitamins = 'vitamins';
  static const String tableMinerals = 'minerals';
  static const String tableHistory = 'history';
  static const String tableAnalysisCache = 'analysis_cache';

  // 维生素类型
  static const List<Map<String, dynamic>> vitaminTypes = [
    {'code': 'vitamin_a', 'name': '维生素A', 'unit': 'μg', 'daily': 900},
    {'code': 'vitamin_b1', 'name': '维生素B1', 'unit': 'mg', 'daily': 1.2},
    {'code': 'vitamin_b2', 'name': '维生素B2', 'unit': 'mg', 'daily': 1.3},
    {'code': 'vitamin_b6', 'name': '维生素B6', 'unit': 'mg', 'daily': 1.3},
    {'code': 'vitamin_b12', 'name': '维生素B12', 'unit': 'μg', 'daily': 2.4},
    {'code': 'vitamin_c', 'name': '维生素C', 'unit': 'mg', 'daily': 90},
    {'code': 'vitamin_d', 'name': '维生素D', 'unit': 'μg', 'daily': 15},
    {'code': 'vitamin_e', 'name': '维生素E', 'unit': 'mg', 'daily': 15},
    {'code': 'vitamin_k', 'name': '维生素K', 'unit': 'μg', 'daily': 120},
    {'code': 'folate', 'name': '叶酸', 'unit': 'μg', 'daily': 400},
    {'code': 'niacin', 'name': '烟酸', 'unit': 'mg', 'daily': 16},
    {'code': 'pantothenic', 'name': '泛酸', 'unit': 'mg', 'daily': 5},
  ];

  // 微量元素类型定义
  static const List<Map<String, dynamic>> mineralTypes = [
    {'code': 'calcium', 'name': '钙', 'unit': 'mg', 'daily': 1000},
    {'code': 'iron', 'name': '铁', 'unit': 'mg', 'daily': 8},
    {'code': 'zinc', 'name': '锌', 'unit': 'mg', 'daily': 8},
    {'code': 'magnesium', 'name': '镁', 'unit': 'mg', 'daily': 310},
    {'code': 'potassium', 'name': '钾', 'unit': 'mg', 'daily': 2000},
    {'code': 'sodium', 'name': '钠', 'unit': 'mg', 'daily': 1500},
    {'code': 'selenium', 'name': '硒', 'unit': 'μg', 'daily': 55},
    {'code': 'copper', 'name': '铜', 'unit': 'mg', 'daily': 0.9},
    {'code': 'manganese', 'name': '锰', 'unit': 'mg', 'daily': 1.8},
    {'code': 'phosphorus', 'name': '磷', 'unit': 'mg', 'daily': 700},
  ];

  // 默认食物数据（用于离线演示）- 包含维生素和微量元素
  static const List<Map<String, dynamic>> defaultFoods = [
    {
      'id': 'apple',
      'name': '苹果',
      'category': '水果',
      'vitamins': {
        'vitamin_c': 4.6,
        'vitamin_a': 3.0,
        'vitamin_e': 0.18,
        'vitamin_k': 2.2,
        'vitamin_b6': 0.041,
      },
      'minerals': {
        'potassium': 107.0,
        'calcium': 6.0,
        'magnesium': 5.0,
        'iron': 0.12,
        'phosphorus': 11.0,
      }
    },
    {
      'id': 'broccoli',
      'name': '西兰花',
      'category': '蔬菜',
      'vitamins': {
        'vitamin_c': 89.2,
        'vitamin_a': 31.0,
        'vitamin_k': 101.6,
        'vitamin_b6': 0.175,
        'folate': 63.0,
      },
      'minerals': {
        'calcium': 47.0,
        'iron': 0.73,
        'magnesium': 21.0,
        'potassium': 316.0,
        'phosphorus': 66.0,
        'zinc': 0.41,
        'manganese': 0.21,
      }
    },
    {
      'id': 'orange',
      'name': '橙子',
      'category': '水果',
      'vitamins': {
        'vitamin_c': 53.2,
        'vitamin_a': 11.0,
        'vitamin_b1': 0.087,
        'folate': 40.0,
      },
      'minerals': {
        'calcium': 40.0,
        'potassium': 181.0,
        'magnesium': 10.0,
        'phosphorus': 14.0,
      }
    },
    {
      'id': 'carrot',
      'name': '胡萝卜',
      'category': '蔬菜',
      'vitamins': {
        'vitamin_a': 835.0,
        'vitamin_k': 13.2,
        'vitamin_c': 5.9,
        'vitamin_b6': 0.138,
      },
      'minerals': {
        'potassium': 320.0,
        'calcium': 33.0,
        'magnesium': 12.0,
        'phosphorus': 35.0,
        'iron': 0.3,
      }
    },
    {
      'id': 'egg',
      'name': '鸡蛋',
      'category': '蛋奶',
      'vitamins': {
        'vitamin_a': 160.0,
        'vitamin_d': 2.0,
        'vitamin_e': 1.03,
        'vitamin_b12': 0.89,
        'vitamin_b2': 0.457,
        'folate': 47.0,
      },
      'minerals': {
        'iron': 1.75,
        'phosphorus': 198.0,
        'calcium': 50.0,
        'potassium': 126.0,
        'zinc': 1.29,
        'selenium': 15.4,
      }
    },
    {
      'id': 'salmon',
      'name': '三文鱼',
      'category': '海鲜',
      'vitamins': {
        'vitamin_d': 11.0,
        'vitamin_b12': 2.8,
        'vitamin_b6': 0.636,
        'vitamin_e': 3.55,
        'niacin': 8.04,
      },
      'minerals': {
        'selenium': 36.5,
        'phosphorus': 200.0,
        'potassium': 360.0,
        'magnesium': 29.0,
        'calcium': 12.0,
        'iron': 0.34,
        'zinc': 0.36,
      }
    },
    {
      'id': 'spinach',
      'name': '菠菜',
      'category': '蔬菜',
      'vitamins': {
        'vitamin_a': 469.0,
        'vitamin_k': 483.0,
        'vitamin_c': 28.1,
        'folate': 194.0,
        'vitamin_e': 2.03,
      },
      'minerals': {
        'iron': 2.71,
        'calcium': 99.0,
        'magnesium': 79.0,
        'potassium': 558.0,
        'manganese': 0.897,
        'phosphorus': 49.0,
      }
    },
    {
      'id': 'banana',
      'name': '香蕉',
      'category': '水果',
      'vitamins': {
        'vitamin_b6': 0.367,
        'vitamin_c': 8.7,
        'folate': 20.0,
        'vitamin_b2': 0.073,
      },
      'minerals': {
        'potassium': 358.0,
        'magnesium': 27.0,
        'phosphorus': 22.0,
        'calcium': 5.0,
        'manganese': 0.27,
      }
    },
    {
      'id': 'almond',
      'name': '杏仁',
      'category': '坚果',
      'vitamins': {
        'vitamin_e': 25.63,
        'vitamin_b2': 1.014,
        'folate': 44.0,
        'vitamin_b1': 0.211,
      },
      'minerals': {
        'calcium': 269.0,
        'magnesium': 270.0,
        'phosphorus': 481.0,
        'potassium': 733.0,
        'iron': 3.71,
        'zinc': 3.12,
        'manganese': 2.179,
        'copper': 1.031,
      }
    },
    {
      'id': 'milk',
      'name': '牛奶',
      'category': '蛋奶',
      'vitamins': {
        'vitamin_b12': 0.44,
        'vitamin_d': 1.2,
        'vitamin_b2': 0.185,
        'vitamin_a': 46.0,
      },
      'minerals': {
        'calcium': 125.0,
        'phosphorus': 95.0,
        'potassium': 150.0,
        'magnesium': 11.0,
        'zinc': 0.42,
        'selenium': 3.3,
      }
    },
  ];

  // 路由名称
  static const String routeHome = '/';
  static const String routeTextInput = '/text-input';
  static const String routeCamera = '/camera';
  static const String routeResult = '/result';
  static const String routeHistory = '/history';
  static const String routeSettings = '/settings';

  // 动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 2);
}
