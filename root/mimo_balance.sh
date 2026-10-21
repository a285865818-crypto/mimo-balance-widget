#!/system/bin/sh
# MiMo 余额小组件：通知栏卡片，每2分钟刷新
# ⚠️ 警告：仅供学习研究。凭据为使用者自有账号，勿用于他人账号；使用风险自负（见 README）。
# 凭据：$DIR/cookies.txt（含 passToken / serviceToken，勿泄露）
BB=/data/adb/ksu/bin/busybox
DIR=/data/adb/mimo_balance
UA='Mozilla/5.0 (Linux; Android 14; Mi) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36'
# SSO 兑换 callback 必须带平台签名 sign（防 401），真实值放 config.sh，不入库
[ -f "$DIR/config.sh" ] && . "$DIR/config.sh"
CB="${MIMO_CB:-https%3A%2F%2Fplatform.xiaomimimo.com%2Fsts%3Fsign%3DYOUR_SIGN%253D%26followup%3Dhttp%3A%2F%2Fplatform.xiaomimimo.com%2Fapi%2Fv1%2FtokenPlan%2Fdetail}"
SSO_URL="https://account.xiaomi.com/pass/serviceLogin?sid=api-platform&callback=$CB"
BAL_URL="https://platform.xiaomimimo.com/api/v1/balance"
ICON_SRC="$DIR/mimo_icon.png"
ICON="file:///data/local/tmp/mimo_icon.png"

post() { # $1=title $2=text $3=bal $4=cash $5=gift $6=frz $7=hm $8=history
  # 安全消毒：title/text 源自 API 响应，剥掉全部 shell 元字符（八进制转义避开引号地狱）
  # 后才允许拼进 su -c 命令串，杜绝命令注入
  T=$(printf '%s' "$1" | $BB awk '{gsub(/[\047\140\044\073\046\174\074\076\134]/,"");print}')
  B=$(printf '%s' "$2" | $BB awk '{gsub(/[\047\140\044\073\046\174\074\076\134]/,"");print}')
  # 用 nsenter 写 app 私有目录（KSU shell 直写会进隔离视图，app 读不到）
  nsenter -t 1 -m -- mkdir -p /data/data/com.mimo.balance/files 2>/dev/null
  nsenter -t 1 -m -- sh -c "$BB awk 'NF>=7 && \$1 !~ /^#/ {printf \"%s=%s; \", \$6, \$7}' '$DIR/cookies.txt' > /data/data/com.mimo.balance/files/cookies.txt" 2>/dev/null
  # root 侧已抓到数据，全部喂给 app 渲染（避免 app 自抓的网络/权限问题）
  if ! am startservice -n com.mimo.balance/.UpdateService \
      --es title "$1" --es text "$2" \
      --es bal "$3" --es cash "$4" --es gift "$5" --es frz "$6" --es time "$7" --es hist "$8" --es days "$9" >/dev/null 2>&1; then
    printf '%s\n%s\n' "$1" "$2" > /data/data/com.mimo.balance/files/state.txt 2>/dev/null
    su 2000 -c "cmd notification post -t '$T' -i '$ICON' -I '$ICON' -S bigtext eta_mimo_balance '$B'"
  fi
}

fetch_balance() {
  curl -s -b "$DIR/cookies.txt" -A "$UA" --max-time 15 "$BAL_URL" 2>/dev/null
}

refresh() {
  [ -f "$ICON_SRC" ] && cp "$ICON_SRC" /data/local/tmp/mimo_icon.png 2>/dev/null
  hm=$($BB date '+%H:%M')
  body=$(fetch_balance)
  case "$body" in
    *'"balance"'*) ;;
    *)
      curl -s -L -b "$DIR/cookies.txt" -c "$DIR/cookies.txt" -A "$UA" --max-time 30 "$SSO_URL" >/dev/null 2>&1
      body=$(fetch_balance)
      ;;
  esac
  [ -n "$body" ] && echo "$body" > "$DIR/last.json"
  case "$body" in
    *'"balance"'*)
      num() { echo "$body" | grep -oE "\"$1\":\"[0-9.]+\"" | head -1 | grep -oE '[0-9.]+'; }
      bal=$(num balance); cash=$(num cashBalance); gift=$(num giftBalance); frz=$(num frozenBalance)
      title="💰 MiMo 余额 ¥$bal"
      if [ "$gift" != "0.00" ] || [ "$frz" != "0.00" ]; then
        text="现金 ¥$cash · 赠送 ¥$gift · 冻结 ¥$frz
更新 $hm"
      else
        text="全部为现金余额
更新 $hm"
      fi ;;
    *loginUrl*)
      title="⚠️ MiMo 登录已失效"
      text="喊 Eta 说「续期 MiMo 登录」
更新 $hm" ;;
    *)
      title="⏸ MiMo 余额获取失败"
      text="网络/风控中，稍后自动重试
更新 $hm" ;;
  esac
  text=$(echo "$text" | sed "s/[\"']//g")
  # 记录余额历史（去重：余额变化最多每 5 分钟一条，静默每 30 分钟心跳一条，防止刷爆日志挤掉历史）
  if [ -n "$bal" ]; then
    D=$($BB date +%F)
    now=$($BB date +%s)
    lastbal=$($BB tail -1 "$DIR/history.log" 2>/dev/null | $BB awk '{print $3}')
    lastep=$(cat "$DIR/.lastep" 2>/dev/null)
    case "$lastep" in ''|*[!0-9]*) lastep=0;; esac
    if [ $((now - lastep)) -ge 1800 ] || { [ "$bal" != "$lastbal" ] && [ $((now - lastep)) -ge 300 ]; }; then
      echo "$D $hm $bal" >> "$DIR/history.log"
      echo "$now" > "$DIR/.lastep"
    fi
    # 保留最近 30 天（按日期裁剪，兜底 8000 行）
    cutoff=$($BB date -d "@$((now - 2592000))" +%F 2>/dev/null)
    if [ -n "$cutoff" ]; then
      $BB awk -v c="$cutoff" '$1>=c' "$DIR/history.log" > "$DIR/.h.tmp" 2>/dev/null && [ -s "$DIR/.h.tmp" ] && mv "$DIR/.h.tmp" "$DIR/history.log"
    else
      $BB tail -8000 "$DIR/history.log" > "$DIR/.h.tmp" 2>/dev/null && mv "$DIR/.h.tmp" "$DIR/history.log"
    fi
  fi
  # 传今日历史给 app（只传今天的数据，用于今日消耗 + 趋势）
  TODAY=$($BB date +%F)
  HIST=$($BB awk -v d="$TODAY" '$1==d{print $2" "$3}' "$DIR/history.log" 2>/dev/null | $BB tail -1500 | $BB tr '\n' ';')
  DAYS=$($BB awk '{
      d=$1; b=$3+0;
      if (d in last) { drop=last[d]-b; if (drop>0) sum[d]+=drop; }
      last[d]=b;
      if (!(d in seen)) { n++; ord[n]=d; seen[d]=1; }
    } END {
      s=n-6; if (s<1) s=1;
      for (i=n; i>=s; i--) { d=ord[i]; printf "%s:%.2f;", substr(d,6,5), sum[d]+0; }
    }' "$DIR/history.log" 2>/dev/null)
  post "$title" "$text" "$bal" "$cash" "$gift" "$frz" "$hm" "$HIST" "$DAYS"
}

if [ "$1" = "once" ]; then
  refresh
  exit 0
fi

if [ -f "$DIR/run.pid" ] && [ -d "/proc/$(cat "$DIR/run.pid" 2>/dev/null)" ] && grep -q 'mimo_balance' "/proc/$(cat "$DIR/run.pid" 2>/dev/null)/cmdline" 2>/dev/null; then exit 0; fi
echo $$ > "$DIR/run.pid"

while :; do
  refresh
  # 120 秒分片小睡，每 10 秒检查一次点击刷新请求（点悬浮窗后 10 秒内刷新）
  i=0
  while [ $i -lt 12 ]; do
    $BB sleep 10
    if nsenter -t 1 -m -- test -f /data/data/com.mimo.balance/files/refresh.req 2>/dev/null; then
      nsenter -t 1 -m -- rm -f /data/data/com.mimo.balance/files/refresh.req 2>/dev/null
      break
    fi
    i=$((i+1))
  done
done
