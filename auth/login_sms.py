import urllib.request, urllib.parse, http.cookiejar, json, re, hashlib, os, sys
# ⚠️ 警告：全自动 2FA 登录会触发小米风控（限流/验证/封号），请留冷却时间；只用你自己的账号，风险自负（见 README/SECURITY.md）。

# 凭据不入库：从环境变量读取，参考 config/secrets.example.json
USER = os.environ.get('MIMO_USER', '')
PW = os.environ.get('MIMO_PW', '')
SID = 'api-platform'
UA = 'Mozilla/5.0 (Linux; Android 14; Mi) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36'
SESS = os.environ.get('MIMO_SESSION_FILE', 'session.json')

cj = http.cookiejar.CookieJar()
op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

def parse(b):
    m = re.search(r'\{.*\}', b, re.S)
    return json.loads(m.group(0)) if m else {}

def get(url, redir=True):
    o = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    if not redir:
        o = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj), NoRedir)
    try:
        r = o.open(urllib.request.Request(url, headers={'User-Agent': UA}))
        return r.status, r.read().decode('utf-8', 'replace'), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', 'replace'), dict(e.headers)

class NoRedir(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None

def post(url, form):
    try:
        r = op.open(urllib.request.Request(url, data=urllib.parse.urlencode(form).encode(),
                     headers={'User-Agent': UA, 'Content-Type': 'application/x-www-form-urlencoded', 'Referer': url}))
        return r.read().decode('utf-8', 'replace')
    except urllib.error.HTTPError as e:
        return e.read().decode('utf-8', 'replace')

def save_session(extra):
    data = {'cookies': {c.name: {'value': c.value, 'domain': c.domain, 'path': c.path} for c in cj}, **extra}
    json.dump(data, open(SESS, 'w'))
    os.chmod(SESS, 0o600)

def load_session():
    data = json.load(open(SESS))
    for name, c in data['cookies'].items():
        ck = http.cookiejar.Cookie(0, name, c['value'], None, False, c['domain'], True, False, c['path'], True, False, None, False, None, None, {})
        cj.set_cookie(ck)
    return data

mode = sys.argv[1] if len(sys.argv) > 1 else 'prep'

if mode == 'prep':
    j1 = parse(get(f'https://account.xiaomi.com/pass/serviceLogin?sid={SID}&_json=true', True)[1])
    form2 = {'sid': SID, 'callback': j1.get('callback', ''), 'qs': j1.get('qs', ''), '_json': 'true',
             'user': USER, 'hash': hashlib.md5(PW.encode()).hexdigest().upper()}
    j2 = parse(post('https://account.xiaomi.com/pass/serviceLoginAuth2', form2))
    ctx = urllib.parse.parse_qs(urllib.parse.urlparse(j2.get('notificationUrl', '')).query).get('context', [''])[0]
    jl = parse(get('https://account.xiaomi.com/identity/list?context=' + urllib.parse.quote(ctx) + f'&sid={SID}&_json=true', True)[1])
    tok = jl.get('applyToken', '')
    j5 = parse(post('https://account.xiaomi.com/identity/auth/sendPhoneTicket',
                    {'_flag': '4', '_json': 'true', 'applyToken': tok, 'sid': SID}))
    print('sendPhoneTicket:', j5.get('code'), j5.get('desc', ''))
    save_session({'context': ctx, 'applyToken': tok, 'form2': form2})
    print('READY')
else:
    code = sys.argv[2]
    d = load_session()
    tok = d['applyToken']
    form2 = d['form2']
    jv = parse(post('https://account.xiaomi.com/identity/auth/verifyPhone',
                    {'_flag': '4', '_json': 'true', 'applyToken': tok, 'sid': SID, 'ticket': code}))
    print('verifyPhone -> code:', jv.get('code'), 'loc:', bool(jv.get('location')))
    print('cookies after verify:', {c.name: len(c.value) for c in cj})
    loc = jv.get('location', '')
    if not loc:
        j4 = parse(post('https://account.xiaomi.com/pass/serviceLoginAuth2', form2))
        loc = j4.get('location', '')
        print('relogin loc:', bool(loc), 'passToken:', bool(j4.get('passToken')))
    # 手动跟随兑换链，打印每一跳
    url = loc
    for hop in range(6):
        if not url:
            break
        st, body, hdrs = get(url, redir=False)
        setc = hdrs.get('Set-Cookie', '')
        print(f'hop{hop}: {st} -> {url[:80]}... set-cookie: {setc[:120]}')
        if st in (301, 302, 303, 307, 308):
            url = hdrs.get('Location', '')
            if url.startswith('/'):
                p = urllib.parse.urlparse(loc)
                url = p.scheme + '://' + p.netloc + url
        else:
            break
    print('final cookies:', {c.name: len(c.value) for c in cj})
    # 试查余额
    st, body, _ = get('https://platform.xiaomimimo.com/api/v1/tokenPlan/detail', True)
    print('balance api:', st, body[:700])
    save_session({'context': d.get('context', ''), 'applyToken': tok, 'form2': form2})
    pt = next((c.value for c in cj if c.name == 'passToken'), '')
    if pt:
        json.dump({'userId': USER, 'passToken': pt}, open('secrets.json', 'w'))
        os.chmod('secrets.json', 0o600)
        print('passToken SAVED len', len(pt))
