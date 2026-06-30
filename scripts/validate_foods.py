#!/usr/bin/env python3
"""
食物营养数据验证脚本
用法：
  python3 scripts/validate_foods.py --template   # 生成对比模板
  python3 scripts/validate_foods.py               # 对照验证（需先填好参考值）
"""

import json, re, sys, urllib.request, ssl
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
FOODS_FILE = PROJECT / 'src' / 'foods_data.js'
REF_FILE = PROJECT / 'data' / 'cfct_reference.json'


def load_env():
    """从 .env 读取 API key"""
    env_path = PROJECT / '.env'
    if not env_path.exists():
        print('Error: .env file not found')
        return None
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line.startswith('DASHSCOPE_API_KEY='):
                return line.split('=', 1)[1].strip()
    return None

def query_cfct_ai(food_name, api_key):
    """调用 DashScope API 查询 CFCT 数据"""
    ctx = ssl._create_unverified_context()
    prompt = f'请查询中国食物成分表中"{food_name}"每100克的营养成分，返回纯JSON：{{"protein_g":数字,"potassium_mg":数字,"phosphorus_mg":数字,"calcium_mg":数字}} 只返回JSON，不要其他文字。'
    req = urllib.request.Request(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        data=json.dumps({
            'model': 'qwen-plus',
            'messages': [{'role': 'user', 'content': prompt}],
            'temperature': 0.1, 'max_tokens': 500
        }).encode(),
        headers={'Authorization': f'Bearer {api_key}', 'Content-Type': 'application/json'}
    )
    resp = urllib.request.urlopen(req, timeout=30, context=ctx)
    data = json.loads(resp.read())
    answer = data['choices'][0]['message']['content']
    answer = answer.replace('```json', '').replace('```', '').strip()
    return json.loads(answer)

def ai_fill_references():
    """使用 AI 自动填充 cfct_reference.json 中的 null 值"""
    api_key = load_env()
    if not api_key:
        print('Error: DASHSCOPE_API_KEY not found in .env')
        return

    ref_data = load_reference()
    if not ref_data:
        ref_data = {f['id']: {} for f in load_db_foods()}

    filled = 0
    for fid, data in ref_data.items():
        name = data.pop('_name', fid)
        nulls = [k for k, v in data.items() if v is None and not k.startswith('_')]
        if not nulls:
            continue
        print(f'Querying AI for: {name} ({len(nulls)} nutrients)...')
        try:
            result = query_cfct_ai(name, api_key)
            for key in nulls:
                if key in result:
                    data[key] = result[key]
                    filled += 1
            # Restore _name
            data['_name'] = name
            ref_data[fid] = data
        except Exception as e:
            print(f'  Failed for {name}: {e}')
            data['_name'] = name
            continue

    with open(REF_FILE, 'w') as f:
        json.dump(ref_data, f, ensure_ascii=False, indent=2)
    print(f'\nAI filled {filled} values. Run without --ai-fill to validate.')

def generate_reference_js():
    """Generate cfct_reference.js for frontend use"""
    ref_data = load_reference()
    if not ref_data:
        return
    filled = sum(1 for d in ref_data.values() for k, v in d.items() if v is not None and not k.startswith('_'))
    total = sum(1 for d in ref_data.values() for k, v in d.items() if not k.startswith('_'))
    out = PROJECT / 'src' / 'cfct_reference.js'
    with open(out, 'w') as f:
        f.write('// CFCT Reference Data\n')
        f.write(f'// {filled}/{total} values filled\n')
        f.write('window.CFCT_REFERENCE = ')
        json.dump(ref_data, f, ensure_ascii=False, indent=2)
        f.write(';\n')
    print(f'Generated {out}: {filled}/{total} values')


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
    if '--ai-fill' in sys.argv:
        ai_fill_references()
        generate_reference_js()
        sys.exit(0)
    if '--template' in sys.argv or not ref:
        gen_template(db)
        generate_reference_js()
    else:
        compare(db, ref)
    export_csv(db)
