#!/usr/bin/env python3
"""Final CFCT parser: macro by line, mineral by 200-char backward search + validation"""
import json, re
from pathlib import Path

content = open(Path(__file__).resolve().parent.parent / 'data' / 'chinese-food-nutrition-merged.md', encoding='utf-8').read()

# ── Macro ──
foods = {}
for line in content.split('\n'):
    line = line.strip()
    if not line.startswith('| ') or line.startswith('|--'): continue
    cells = [c.strip() for c in line.split('|')]
    if len(cells) < 10: continue
    code = cells[1]
    if not re.match(r'^\d{5,6}x?$', code): continue
    name = cells[2].replace('\r','').split('\n')[0].strip()
    def v(i):
        try: return float(cells[i]) if cells[i] and cells[i] != '−' else None
        except: return None
    foods[code] = {'name': name, 'kcal': v(5), 'protein_g': v(7), 'fat_g': v(8), 'carbs_g': v(9)}

# ── Mineral: 200-char backward search from Ca-P-K ──
# Track which codes have already been assigned minerals (keep first only)
assigned = set()
for m in re.finditer(r'\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|\s*(\d+)\s*\|\s*([\d.]+)\s*\|', content):
    ca, p, k = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if not (0 < ca < 2000 and 0 < p < 2000 and 0 < k < 3000): continue
    
    # Backward search within 200 chars, find LAST code
    before = content[max(0, m.start()-200):m.start()]
    codes = re.findall(r'(\d{5,6}x?)', before)
    if not codes: continue
    code = codes[-1]
    if code not in foods or code in assigned: continue
    
    foods[code].update({
        'calcium_mg': ca, 'phosphorus_mg': p, 'potassium_mg': k,
        'sodium_mg': float(m.group(4)), 'magnesium_mg': int(m.group(5)), 'iron_mg': float(m.group(6))
    })
    assigned.add(code)

# Stats
keys = ['protein_g','kcal','calcium_mg','phosphorus_mg','potassium_mg','sodium_mg','magnesium_mg','iron_mg']
stats = {k: sum(1 for f in foods.values() if f.get(k)) for k in keys}
print(f'Total: {len(foods)} foods')
for k, c in sorted(stats.items(), key=lambda x:-x[1]):
    print(f'  {k}: {c}')

# Save
out = Path('/Users/jianyu/Workspace/MomsNutrition/data/cfct_foods.json')
with open(out, 'w') as f:
    json.dump(foods, f, ensure_ascii=False, indent=2)
print(f'\nSaved: {out}')

# Verify
for code in ['011101','011202','011205','041101','062001','081101','091101','101101','111101']:
    if code in foods:
        f = foods[code]
        show = {k: f.get(k) for k in keys+['name'] if f.get(k)}
        print(f'\n{code}: {json.dumps(show, ensure_ascii=False)}')
