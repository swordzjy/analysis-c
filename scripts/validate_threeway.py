#!/usr/bin/env python3
"""三方验证 — 三取二规则 + CFCT查询方法"""
import subprocess, json, re, select, ssl, urllib.request
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

def load_db():
    with open(PROJECT/'src'/'foods_data.js') as f:
        content = f.read()
    foods = []
    for m in re.finditer(r'\{(?:[^{}]|\{[^{}]*\})*\}', content, re.DOTALL):
        try:
            obj = json.loads(m.group())
            if 'id' in obj and 'name' in obj and 'protein_g' in obj:
                foods.append(obj)
        except: pass
    return foods

def load_ai_key():
    env = PROJECT / '.env'
    if env.exists():
        for line in open(env):
            if line.startswith('DASHSCOPE_API_KEY='):
                return line.split('=',1)[1].strip()
    return None

def query_ai(food_name, nutrient):
    """Query CFCT via DashScope AI"""
    key = load_ai_key()
    if not key: return None
    prompt = f'请查询中国食物成分表中"{food_name}"每100克可食部的{nutrient}含量。只返回数字，不要单位。'
    ctx = ssl._create_unverified_context()
    req = urllib.request.Request(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        data=json.dumps({'model':'qwen-plus','messages':[{'role':'user','content':prompt}],'temperature':0,'max_tokens':50}).encode(),
        headers={'Authorization':f'Bearer {key}','Content-Type':'application/json'}
    )
    try:
        resp = urllib.request.urlopen(req, timeout=20, context=ctx)
        data = json.loads(resp.read())
        ans = data['choices'][0]['message']['content'].strip()
        return float(ans.replace('mg','').replace('g','').replace('约','').strip())
    except:
        return None

def best_of_three(db_v, mc_v, ai_v, tolerance=0.3):
    """
    三取二规则：DB、MCP、AI 中任意两个值接近（差异<tolerance），取它们的平均值。
    返回: (consensus_value, confidence, sources_used)
    """
    vals = [('DB', db_v), ('MCP', mc_v), ('AI', ai_v)]
    available = [(s, v) for s, v in vals if v is not None and v > 0]

    if len(available) < 2:
        return None, 'insufficient', []

    # Check all pairs for agreement
    for i in range(len(available)):
        for j in range(i+1, len(available)):
            v1, v2 = available[i][1], available[j][1]
            diff = abs(v1 - v2) / max(v2, 0.1)
            if diff < tolerance:
                avg = (v1 + v2) / 2
                return avg, 'high', [available[i][0], available[j][0]]

    # No pair agrees → low confidence, use median
    sorted_vals = sorted(available, key=lambda x: x[1])
    median = sorted_vals[len(sorted_vals)//2][1] if sorted_vals else None
    return median, 'low', [s for s,_ in available]

def main():
    foods = load_db()
    key = load_ai_key()
    print(f'DB: {len(foods)} | AI: {"on" if key else "off"} | Rule: 三取二(tolerance=30%)')

    proc = subprocess.Popen(
        ['npx', '-y', '@iflow-mcp/ruffood-cn-food-mcp'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
    )
    rid=[0]
    def send(m,p):
        rid[0]+=1
        req=json.dumps({"jsonrpc":"2.0","id":rid[0],"method":m,"params":p})+'\n'
        proc.stdin.write(req);proc.stdin.flush()
        ready,_,_=select.select([proc.stdout],[],[],10)
        if ready:
            line=proc.stdout.readline().strip()
            return json.loads(line) if line else None
        return None
    send("initialize",{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"v","version":"1"}})

    def mcp_query(name):
        """Query CFCT via MCP — 两步: search_food → get_nutrition"""
        r = send("tools/call",{"name":"search_food","arguments":{"query":name,"limit":1}})
        if not r: return None, None
        result = r.get('result',{})
        if result.get('isError'): return None, None
        try:
            data = json.loads(result['content'][0]['text'])
            f_list = data.get('foods',[])
            if not f_list: return None, None
            f = f_list[0]
        except: return None, None
        mcp_name = f['name']
        if name not in mcp_name and mcp_name not in name: return None, None
        r2 = send("tools/call",{"name":"get_nutrition","arguments":{"food_id":f['id']}})
        if not r2 or r2.get('result',{}).get('isError'): return None, None
        nutr = json.loads(r2['result']['content'][0]['text'])
        if not nutr.get('protein'): return None, None
        return mcp_name, nutr

    KEYS = [('protein','蛋白质','g'),('potassium','钾','mg'),('phosphorus','磷','mg'),('calcium','钙','mg')]
    fixes = []      # suggested DB corrections
    disputes = []   # needs manual review
    consistent = 0
    total = 0

    for food in foods:
        mcp_name, mcp_data = mcp_query(food['name'])
        if not mcp_data: continue
        for key, label, unit in KEYS:
            db_v = food.get(key+'_g', food.get(key+'_mg', 0)) or 0
            mc_v = mcp_data.get(key, 0) or 0
            if mc_v == 0: continue
            total += 1

            diff_mp = abs(db_v - mc_v) / max(mc_v, 0.1)
            if diff_mp < 0.1:
                consistent += 1
                continue
            if mc_v < 1 and db_v > mc_v * 10:
                continue  # MCP损坏

            # AI arbitration
            ai_v = query_ai(food['name'], key) if key else None
            consensus, confidence, sources = best_of_three(db_v, mc_v, ai_v)

            if confidence == 'high':
                # Two sources agree → fix DB to consensus
                fixes.append((food['name'], label, unit, db_v, consensus, sources))
            else:
                disputes.append((food['name'], label, unit, db_v, mc_v, ai_v))

    proc.terminate()

    print(f'\n对比 {total} 项 | ✅一致: {consistent} | 📗建议修正: {len(fixes)} | ⚠️需人工: {len(disputes)}')

    if fixes:
        print(f'\n{"="*70}')
        print(f'📗 三取二建议修正 ({len(fixes)} 项)')
        print(f'{"="*70}')
        print(f'{"食物":<10} {"营养素":<6} {"当前DB":>6} {"→修正为":>6} {"依据"}')
        print(f'{"-"*70}')
        for name, label, unit, db_v, consensus, sources in fixes:
            print(f'{name:<10} {label:<6} {db_v:>4}{unit} → {consensus:>4.0f}{unit}  ({"/".join(sources)})')

    if disputes:
        print(f'\n{"="*80}')
        print(f'⚠️  需人工核查 ({len(disputes)} 项)')
        print(f'{"="*80}')
        print(f'{"食物":<10} {"营养素":<6} {"DB":>5} {"MCP":>5} {"AI":>5}')
        print(f'{"-"*80}')
        for name, label, unit, db_v, mc_v, ai_v in disputes[:20]:
            ai_str = f'{ai_v:.0f}{unit}' if ai_v else 'N/A'
            print(f'{name:<10} {label:<6} {db_v:>4}{unit} {mc_v:>4}{unit} {ai_str:>5}')

    # Show CFCT query method
    print(f'\n{"="*60}')
    print(f'CFCT 查询方法')
    print(f'{"="*60}')
    print(f'  MCP: search_food({name}) → get_nutrition(id)  — 覆盖 1750 种食物')
    print(f'  AI:  DashScope qwen-plus 查询中国食物成分表')
    print(f'  三取二: DB/MCP/AI 中任意两个差异<30%即取均值')

if __name__ == '__main__':
    main()
