#!/usr/bin/env python3
"""DB vs MCP(CFCT) 验证对比"""
import subprocess, json, re, select
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

def main():
    foods = load_db()
    print(f'DB: {len(foods)} foods')

    proc = subprocess.Popen(
        ['npx', '-y', '@iflow-mcp/ruffood-cn-food-mcp'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True
    )
    rid=[0]
    def send(method, params):
        rid[0]+=1
        req=json.dumps({"jsonrpc":"2.0","id":rid[0],"method":method,"params":params})+'\n'
        proc.stdin.write(req); proc.stdin.flush()
        ready,_,_=select.select([proc.stdout],[],[],15)
        if ready:
            line = proc.stdout.readline().strip()
            return json.loads(line) if line else None
        return None

    def query(name):
        r = send("tools/call",{"name":"search_food","arguments":{"query":name,"limit":1}})
        if not r: return ('TIMEOUT',{})
        result = r.get('result',{})
        if result.get('isError'): return ('ERR',{})
        try:
            data = json.loads(result['content'][0]['text'])
            f_list = data.get('foods', data if isinstance(data,list) else [])
            if not f_list: return ('NO_RESULTS',{})
            f = f_list[0]
        except: return ('PARSE_ERR',{})
        mcp_name = f['name']
        if name not in mcp_name and mcp_name not in name:
            return ('MISMATCH:'+mcp_name,{})
        r2 = send("tools/call",{"name":"get_nutrition","arguments":{"food_id":f['id']}})
        if not r2: return ('NUTR_TIMEOUT',{})
        r2r = r2.get('result',{})
        if r2r.get('isError'):
            err = r2r.get('content',[{}])[0].get('text','')[:60]
            return ('NUTR_ERR:'+err,{})
        try:
            nutr = json.loads(r2r['content'][0]['text'])
            if not nutr.get('protein'): return ('BAD_DATA',{})
            return ('OK', nutr)
        except: return ('NUTR_PARSE',{})

    send("initialize",{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"v","version":"1"}})

    KEYS = [('protein','蛋白质','g'),('potassium','钾','mg'),
            ('phosphorus','磷','mg'),('calcium','钙','mg')]

    ok, mismatch, no_match, printed = 0, 0, 0, 0
    for i, food in enumerate(foods):
        status, mcp_data = query(food['name'])
        if status == 'OK':
            ok += 1
        elif status.startswith('MISMATCH:'):
            mismatch += 1
            if i < 3: print(f"  [{food['name']}] -> {status}")
        else:
            no_match += 1
            if i < 3: print(f"  [{food['name']}] {status}")
        if status != 'OK': continue

        for key, label, unit in KEYS:
            db_v = food.get(key+'_g', food.get(key+'_mg', 0)) or 0
            mc_v = mcp_data.get(key, 0) or 0
            if mc_v == 0: continue
            diff = abs(db_v - mc_v) / max(mc_v, 0.1) * 100
            s = 'OK' if diff < 10 else 'WARN' if diff < 30 else 'BAD'
            if printed == 0:
                print(f'\n{"DB":<10} {"营养素":<6} {"DB值":>6} {"MCP值":>6} {"差异":>5}')
                print('-'*50)
            print(f'{food["name"]:<10} {label:<6} {db_v:>4}{unit} {mc_v:>4}{unit} {diff:>4.0f}% {s}')
            printed += 1

    proc.terminate()
    print(f'\nOK: {ok}  Mismatch: {mismatch}  NoMatch: {no_match}  Comparisons: {printed}')

if __name__ == '__main__':
    main()
