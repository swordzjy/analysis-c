#!/usr/bin/env python3
"""
食物营养数据验证脚本
用法：
  python3 scripts/validate_foods.py --template   # 生成对比模板
  python3 scripts/validate_foods.py               # 对照验证（需先填好参考值）
"""

import json, re, sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
FOODS_FILE = PROJECT / 'src' / 'foods_data.js'
REF_FILE = PROJECT / 'data' / 'cfct_reference.json'

KEY_NUTRIENTS = [
    ('protein_g', '蛋白质', 'g'),
    ('potassium_mg', '钾', 'mg'),
    ('phosphorus_mg', '磷', 'mg'),
    ('calcium_mg', '钙', 'mg'),
    ('oxalate_mg', '草酸', 'mg'),
    ('purine_mg', '嘌呤', 'mg'),
    ('kcal', '热量', 'kcal'),
]

def load_db_foods():
    with open(FOODS_FILE) as f:
        content = f.read()
    foods = []
    for m in re.finditer(r'\{(?:[^{}]|\{[^{}]*\})*\}', content, re.DOTALL):
        try:
            obj = json.loads(m.group())
            if 'id' in obj and 'name' in obj and 'protein_g' in obj:
                foods.append(obj)
        except json.JSONDecodeError:
            pass
    return foods

def load_reference():
    if REF_FILE.exists():
        with open(REF_FILE) as f:
            return json.load(f)
    return {}

def compare(db_foods, ref_data):
    issues = []
    print(f'\n{"="*70}')
    print(f'{"食物":<10} {"营养素":<6} {"数据库":>8} {"CFCT参考":>8} {"差异":>6}')
    print(f'{"-"*70}')
    for food in db_foods:
        ref = ref_data.get(food['id'], {})
        for key, label, unit in KEY_NUTRIENTS:
            db_val = food.get(key, 0) or 0
            ref_val = ref.get(key)
            if ref_val is None or ref_val == 0:
                continue
            if db_val == 0 and ref_val == 0:
                continue
            diff = abs(db_val - ref_val) / max(ref_val, 0.1) * 100
            s = '✅' if diff < 10 else '⚠️' if diff < 30 else '🔴'
            if diff >= 10:
                issues.append((food['name'], label, db_val, ref_val, diff))
            print(f'{food["name"]:<10} {label:<6} {db_val:>6.0f}{unit} {ref_val:>6.0f}{unit} {diff:>5.0f}% {s}')
    if issues:
        print(f'\n⚠️  {len(issues)} 处差异 >10%:')
        for n, l, d, r, p in issues:
            print(f'  {n} {l}: DB={d} vs CFCT={r} ({p:.0f}%)')
    else:
        print('\n✅ 全部一致')

def gen_template(db_foods):
    t = {}
    for food in db_foods:
        entry = {}
        for key, label, unit in KEY_NUTRIENTS:
            if food.get(key):
                entry[key] = None
        if entry:
            t[food['id']] = {'_name': food['name'], '_cat': food.get('category',''), **entry}
    with open(REF_FILE, 'w') as f:
        json.dump(t, f, ensure_ascii=False, indent=2)
    print(f'模板: {REF_FILE} (将 null 替换为 CFCT 数值后重新运行)')

def export_csv(db_foods):
    p = PROJECT / 'data' / 'foods_export.csv'
    with open(p, 'w') as f:
        h = ['id','name','category'] + [k for k,_,_ in KEY_NUTRIENTS]
        f.write(','.join(h) + '\n')
        for food in db_foods:
            f.write(','.join(str(food.get(k,'')) for k in h) + '\n')
    print(f'CSV: {p}')

if __name__ == '__main__':
    db = load_db_foods()
    print(f'{len(db)} foods in DB')
    ref = load_reference()
    if '--template' in sys.argv or not ref:
        gen_template(db)
    else:
        compare(db, ref)
    export_csv(db)
