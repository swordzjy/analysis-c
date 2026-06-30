#!/usr/bin/env python3
"""Merge: CFCT minerals + our DB macros → new foods_data.js"""
import json, re
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

# Load CFCT
with open(PROJECT/'data'/'cfct_foods.json') as f:
    cfct = json.load(f)

# Load existing DB
with open(PROJECT/'src'/'foods_data.js') as f:
    content = f.read()

foods = []
units = []
for m in re.finditer(r'\{(?:[^{}]|\{[^{}]*\})*\}', content, re.DOTALL):
    try:
        obj = json.loads(m.group())
        if 'food_id' in obj: units.append(obj)
        elif 'id' in obj and 'name' in obj and 'protein_g' in obj: foods.append(obj)
    except: pass

print(f'Existing: {len(foods)} foods, {len(units)} units')

# ── Manual mapping: our food → CFCT code → food name ──
MANUAL = {
    '大米': ('012001x','稻米(代表値)'),
    '小麦面粉': ('011201x','小麦粉(代表値)'),
    '燕麦': ('014101','燕麦仁'),
    '小米': ('015101','小米'),
    '玉米（鲜）': ('013101','玉米(鲜)'),
    '黑米': ('012212','黑米'),
    '荞麦': ('019007','苦荞麦粉'),
    '糙米': ('012216','糙米'),
    '薏米': ('019008','薏米(薏仁米，苡米)'),
    '黄豆': ('031101','黄豆(大豆)'),
    '菠菜': ('045301','菠菜(鮮)(赤根菜)'),
    '大白菜': ('042101','大白菜(代表値)'),
    '西兰花': ('045201','西兰花(绿菜花)'),
    '土豆': ('021101','马铃薯(土豆、洋芋)'),
    '西红柿': ('043106','番茄(整个，罐头)'),
    '胡萝卜': ('041201','胡萝卜(紅)(金笋，丁香萝卜)'),
    '黄瓜': ('043208','黄瓜(鲜)(胡瓜)'),
    '红薯': ('021205','甘薯(红心)(山芋、红薯)'),
    '山药': ('047104','山药(鲜)(薯荡，大薯)'),
    '芋头': ('047203','芋头(芋芳、毛芋)'),
    '莲藕': ('046010','藕(蓮藕)'),
    '冬瓜': ('043221','冬瓜'),
    '芹菜': ('045312','芹菜茎'),
    '韭菜': ('044404','韭菜'),
    '生菜': ('045333','生菜(叶用莴苣)'),
    '油菜': ('045113','油菜(黑)'),
    '豆芽': ('042202','黄豆芽'),
    '洋葱': ('044301','洋葱(鲜)(葱头)'),
    '菜花': ('045202','菜花'),
    '香菇': ('051019','香菇(鲜)(香蕈，冬菇)'),
    '海带': ('052002','海带(鲜)(江白菜)'),
    '秋葵': ('043126','秋葵(黄秋葵、羊角豆)'),
    '苹果': ('061101x','苹果(代表值)'),
    '葡萄': ('063101x','葡萄(代表值)'),
    '西瓜': ('066201x','西瓜(代表值)'),
    '梨': ('061201x','梨(代表値)'),
    '草莓': ('063910','草莓(洋莓，凤阳草莓)'),
    '猕猴桃': ('063909','中华猕猴桃(毛叶猕猴桃)'),
    '芒果': ('065011','芒果(抹猛果，望果)'),
    '杏仁': ('071014','杏仁'),
    '腰果': ('071036','腰果(熟)'),
    '白萝卜': ('041101','白萝卜(鲜)(莱菔)'),
    '茄子': ('043401','茄子(紫皮、长)'),
    '苦瓜': ('043603','苦瓜'),
    '橘子': ('064101','橘柑子(代表値)'),
    '花生': ('071001','花生(代表値)'),
    '核桃': ('071033','核桃(干)'),
    '芝麻': ('071041','芝麻(代表値)'),
    '木耳': ('052005','木耳(干)(黑木耳、云耳)'),
    '紫菜': ('052006','琼脂(紫菜胶洋粉)'),
    # Meat, eggs, dairy - CFCT has specific cuts/varieties
    '鸡蛋': ('091101','鸡蛋(红皮)'),
    '鹌鹑蛋': ('092101','鹌鹑蛋'),
    '牛奶': ('101101','牛乳'),
}

# ── Merge ──
merged = {}
for food in foods:
    fid = food['id']
    name = food['name']
    entry = dict(food)
    
    if name in MANUAL:
        cft_code, cft_name = MANUAL[name]
        cf = cfct.get(cft_code, {})
        if cf:
            # Minerals from CFCT (reliable)
            for k in ['calcium_mg','phosphorus_mg','potassium_mg','sodium_mg','magnesium_mg','iron_mg']:
                if cf.get(k): entry[k] = cf[k]
            # Macros: keep existing (our DB is already CFCT-corrected)
            # Only use CFCT macros if they pass sanity check
            macro_ok = lambda v: v is not None and 0 < v < 1000
            for k in ['kcal','protein_g','fat_g','carbs_g']:
                if cf.get(k) and macro_ok(cf[k]):
                    if abs(cf[k] - food.get(k,0)) / max(food.get(k,0.1),0.1) > 0.5:
                        pass  # CFCT macro differs too much from our DB - keep ours
            entry['_source'] = 'CFCT'
            entry['_cfct_code'] = cft_code
        else:
            entry['_source'] = 'EST'
    else:
        entry['_source'] = 'EST'
    
    # Keep oxalate/purine from our DB
    for k in ['oxalate_mg','purine_mg']:
        if k in entry and entry[k] is None: entry[k] = food.get(k)
    
    merged[fid] = entry

# ── Generate cfct_reference ──
ref = {}
for fid, e in merged.items():
    ref[fid] = {}
    for k in ['protein_g','potassium_mg','phosphorus_mg','calcium_mg']:
        if e.get(k): ref[fid][k] = e[k]

filled = sum(1 for d in ref.values() for k,v in d.items() if v)
with open(PROJECT/'src'/'cfct_reference.js','w') as f:
    f.write(f'// CFCT Reference - {len(ref)} foods\nwindow.CFCT_REFERENCE=')
    json.dump(ref, f, ensure_ascii=False, indent=2)
    f.write(';\n')

# ── Stats ──
verified = sum(1 for e in merged.values() if e.get('_source') == 'CFCT')
print(f'\nMerged: {verified}/{len(merged)} CFCT-verified | {filled} ref values')
for fid in ['rice_white','wheat_flour','sweet_potato','soybean','spinach','egg','milk','apple']:
    if fid in merged:
        e = merged[fid]
        parts = [f"K={e.get('potassium_mg')}", f"P={e.get('phosphorus_mg')}", f"Ca={e.get('calcium_mg')}", f"protein={e.get('protein_g')}", e.get('_source','')]
        print(f'  {e["name"]:<10} {" | ".join(str(p) for p in parts)}')
