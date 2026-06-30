#!/usr/bin/env python3
"""Generate complete foods_data.js: 1040 CFCT + oxalate/purine from our DB"""
import json, re
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

# ── Load data ──
with open(PROJECT/'data'/'cfct_foods.json') as f:
    cfct = json.load(f)

with open(PROJECT/'src'/'foods_data.js') as f:
    content = f.read()

our_foods = []
our_units = []
for m in re.finditer(r'\{(?:[^{}]|\{[^{}]*\})*\}', content, re.DOTALL):
    try:
        obj = json.loads(m.group())
        if 'food_id' in obj: our_units.append(obj)
        elif 'id' in obj and 'name' in obj: our_foods.append(obj)
    except: pass

print(f'CFCT: {len(cfct)} | Our: {len(our_foods)} foods, {len(our_units)} units')

# ── Category & emoji from food code prefix ──
CAT_MAP = {
    '01':'grain','02':'vegetable','03':'beans','04':'vegetable','05':'vegetable',
    '06':'fruit','07':'nuts','08':'meat','09':'meat','10':'dairy',
    '11':'nuts','12':'nuts','13':'nuts','14':'other','15':'other','19':'other'
}
CAT_EMOJI = {'grain':'🌾','vegetable':'🥬','beans':'🫘','fruit':'🍎','meat':'🥩','dairy':'🥛','nuts':'🥜','other':'🍽️'}
CAT_CN = {'grain':'谷物','vegetable':'蔬菜','beans':'豆类','fruit':'水果','meat':'肉蛋','dairy':'奶类','nuts':'坚果','other':'其他'}

# ── Build ID mapping: our food → CFCT code ──
def normalize(s):
    return s.replace('（','(').replace('）',')').replace('　',' ').strip()

# Manual overrides for unreliable auto-matches
MANUAL = {
    '大米':'012001x','小麦面粉':'011201x','玉米':'013101','玉米（鲜）':'013101',
    '牛奶':'101101','鸡蛋':'091101','鸡蛋黄':'091201','鹌鹑蛋':'092101',
    '猪肉':'081101','猪里脊':'081101','猪瘦肉':'081202','猪肝':'081701',
    '牛肉':'081301','羊肉':'081401','鸡胸肉':'081801','鸡腿肉':'081802',
    '鸭肉':'082001','鲫鱼':'082401','三文鱼':'082403','虾仁':'083101',
    '带鱼':'082301','酸奶':'010111','奶酪':'010912','紫薯':'021201',
    '葵花籽':'071006','南瓜籽':'071010','豆腐（北）':'031301','老豆腐':'031305',
    '嫩豆腐':'031304','豆腐乳':'031306','青椒':'043101','橙子':'064201',
    '桃子':'063801','柚子':'064301','豆芽':'042202','菜花':'045202',
}

id_map = {}
for of in our_foods:
    name = of['name']
    our_id = of['id']
    
    # Check manual map
    if name in MANUAL:
        cfct_code = MANUAL[name]
        if cfct_code in cfct:
            id_map[of['id']] = (cfct_code, cfct[cfct_code]['name'])
            continue
    
    # Auto-match: normalize and check substring
    nn = normalize(name)
    for code, cf in cfct.items():
        cn = normalize(cf.get('name',''))
        if nn in cn or cn.replace('(','').split('(')[0].strip() == nn:
            id_map[our_id] = (code, cf['name'])
            break

print(f'ID mappings: {len(id_map)}/{len(our_foods)}')

# ── Build lookup: CFCT code → our food data ──
our_by_cfct = {}  # CFCT code → our food entry
for our_id, (cfct_code, _) in id_map.items():
    for of in our_foods:
        if of['id'] == our_id:
            our_by_cfct[cfct_code] = of
            break

# ── Generate foods ──
new_foods = []
new_units = []
used_cfct_codes = set()

for code, cf in sorted(cfct.items()):
    prefix = code[:2]
    cat_id = CAT_MAP.get(prefix, 'other')
    name = re.sub(r'\s+[\d.]+$', '', cf.get('name',''))
    
    # Assign ID
    if code in our_by_cfct:
        fid = our_by_cfct[code]['id']  # preserve old ID
    else:
        fid = f'cfct_{code}'
    
    entry = {
        'id': fid, 'name': name, 'emoji': CAT_EMOJI[cat_id],
        'category_id': cat_id, 'category': CAT_CN[cat_id],
        'kcal': cf.get('kcal'), 'protein_g': cf.get('protein_g'),
        'fat_g': cf.get('fat_g'), 'carbs_g': cf.get('carbs_g'),
        'fiber_g': cf.get('fiber_g'),
        'calcium_mg': cf.get('calcium_mg'), 'phosphorus_mg': cf.get('phosphorus_mg'),
        'potassium_mg': cf.get('potassium_mg'), 'sodium_mg': cf.get('sodium_mg'),
        'iron_mg': cf.get('iron_mg'),
        'source': 'CFCT',
    }
    
    # Add oxalate/purine if our DB has it
    if code in our_by_cfct:
        of = our_by_cfct[code]
        entry['oxalate_mg'] = of.get('oxalate_mg')
        entry['purine_mg'] = of.get('purine_mg')
        if of.get('emoji'): entry['emoji'] = of['emoji']
    
    new_foods.append(entry)
    used_cfct_codes.add(code)
    
    # Units: 100g base + our units if matched
    new_units.append({'food_id': fid, 'name': 'g', 'weight_g': 100, 'description': '100g'})
    if code in our_by_cfct:
        for u in our_units:
            if u['food_id'] == our_by_cfct[code]['id']:
                u = dict(u)
                u['food_id'] = fid
                new_units.append(u)

# ── Add our foods NOT matched to any CFCT ──
for of in our_foods:
    if of['id'] not in {f['id'] for f in new_foods}:
        entry = dict(of)
        entry['category_id'] = entry.get('category_id', 'other')
        new_foods.append(entry)
        for u in our_units:
            if u['food_id'] == of['id']:
                new_units.append(u)

print(f'Final: {len(new_foods)} foods, {len(new_units)} units')

# ── Generate files ──
def js_dumps(obj):
    return json.dumps(obj, ensure_ascii=False)

output = 'const EXTENDED_FOODS=[\n'
for i, f in enumerate(new_foods):
    output += '  ' + js_dumps(f)
    output += ',\n' if i < len(new_foods) - 1 else '\n'
output += '];\n\nconst EXTENDED_UNITS=[\n'
for i, u in enumerate(new_units):
    output += '  ' + js_dumps(u)
    output += ',\n' if i < len(new_units) - 1 else '\n'
output += '];\nif(typeof window!==\'undefined\')window.AppData={EXTENDED_FOODS,EXTENDED_UNITS};\n'

with open(PROJECT/'src'/'foods_data.js','w') as f:
    f.write(output)

# Stats
from collections import Counter
cats = Counter(f['category_id'] for f in new_foods)
with_ox = sum(1 for f in new_foods if f.get('oxalate_mg'))
with_pur = sum(1 for f in new_foods if f.get('purine_mg'))
with_k = sum(1 for f in new_foods if f.get('potassium_mg'))
with_pro = sum(1 for f in new_foods if f.get('protein_g'))
print(f'\nCategories:')
for c, n in sorted(cats.items(), key=lambda x:-x[1]):
    print(f'  {CAT_EMOJI.get(c,"?")} {c}: {n}')
print(f'Data: protein={with_pro} K={with_k} oxalate={with_ox} purine={with_pur}')
print(f'File: {len(output)//1024}KB')
