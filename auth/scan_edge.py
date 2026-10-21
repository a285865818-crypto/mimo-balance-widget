
# 扫 Edge 内存提取 serviceToken，逐个试调余额验证（结果反推）
# ⚠️ 警告：仅用于提取使用者自有账号的凭据；读取 /proc/<pid>/mem 可能被杀软误报，风险自负（见 SECURITY.md）。
import re, urllib.request, sys, os

pid = sys.argv[1] if len(sys.argv) > 1 else ''
if not pid:
    print('usage: scan_edge.py <edge_pid>')
    sys.exit(2)
mem = open(f'/proc/{pid}/mem', 'rb')
maps = open(os.environ.get('MIMO_EDGE_MAPS', '/data/local/tmp/eta/edge_maps.txt')).read().strip().split('\n')

pat = re.compile(rb'[A-Za-z0-9+/]{280,420}={1,2}')
seen = {}
for line in maps:
    p = line.split()
    rng, perm = p[0], p[1]
    if 'r' not in perm:
        continue
    s, e = rng.split('-')
    si, ei = int(s, 16), int(e, 16)
    sz = ei - si
    if sz > 20_000_000:
        continue
    try:
        mem.seek(si)
        data = mem.read(sz)
        for m in pat.finditer(data):
            t = m.group(0).decode()
            if ('+' in t or '/' in t) and not re.fullmatch(r'[0-9a-fA-F]+', t) and 'AAAA' not in t:
                seen[t] = 1
    except Exception:
        continue
mem.close()

cands = list(seen.keys())
UA = 'Mozilla/5.0'
for i, tok in enumerate(cands):
    ck = f'api-platform_serviceToken={tok}; userId={os.environ.get("MIMO_USER_ID", "YOUR_USER_ID")}'
    try:
        req = urllib.request.Request('https://platform.xiaomimimo.com/api/v1/balance',
                                     headers={'User-Agent': UA, 'Cookie': ck})
        b = urllib.request.urlopen(req, timeout=8).read().decode()
    except Exception as e:
        try:
            b = e.read().decode()
        except Exception:
            b = ''
    if '"balance"' in b:
        open('FOUND_token.txt', 'w').write(tok)
        print(f'FOUND len={len(tok)}')
        sys.exit(0)
print('NOT_FOUND')
sys.exit(1)
