#!/system/bin/sh
# MiMo 一键续期：从 Edge 内存提取 serviceToken，写入 root 凭据
# ⚠️ 警告：读取浏览器进程内存可能被安全软件误报；只提取你自己的登录凭据，勿用于他人账号（见 README/SECURITY.md）。
# 用法：sh /data/adb/mimo_balance/renew_from_edge.sh
# 前提：已在 Edge 打开过 MiMo 余额页（触发登录签发 serviceToken）
BB=/data/adb/ksu/bin/busybox
DIR=/data/adb/mimo_balance
# 读取真实 userId（config.sh，不入库）；scan_edge.py 通过环境变量继承
[ -f "$DIR/config.sh" ] && . "$DIR/config.sh"
export MIMO_USER_ID

PID=$(nsenter -t 1 -m -- $BB ps -A 2>/dev/null | $BB grep -i emmx | $BB grep -v grep | $BB awk '{print $1}' | $BB head -1)
if [ -z "$PID" ]; then
  echo "❌ Edge 没运行，请先打开 Edge 进入 MiMo 余额页"
  exit 1
fi
echo "Edge PID=$PID，扫描内存..."

nsenter -t 1 -m -- cat /proc/$PID/maps > /data/local/tmp/eta/edge_maps.txt 2>/dev/null
cp "$DIR/auth/scan_edge.py" /data/local/tmp/eta/scan_edge.py 2>/dev/null
rm -f /data/local/tmp/eta/FOUND_token.txt
cd /data/local/tmp/eta && python3 scan_edge.py "$PID" 2>/dev/null

TOK=$(cat /data/local/tmp/eta/FOUND_token.txt 2>/dev/null)
if [ -z "$TOK" ]; then
  echo "❌ 未提取到 serviceToken"
  echo "请确认：已在 Edge 打开 MiMo 余额页并停留 10 秒"
  exit 1
fi

EXP=$(( $(date +%s) + 2592000 ))
{
  echo "# Netscape HTTP Cookie File"
  echo -e ".xiaomimimo.com\tTRUE\t/\tTRUE\t$EXP\tapi-platform_serviceToken\t$TOK"
  echo -e ".xiaomimimo.com\tTRUE\t/\tTRUE\t$EXP\tuserId\t${MIMO_USER_ID:-YOUR_USER_ID}"
  echo -e ".account.xiaomi.com\tTRUE\t/\tTRUE\t$EXP\tuserId\t${MIMO_USER_ID:-YOUR_USER_ID}"
} > "$DIR/cookies.txt"
chmod 600 "$DIR/cookies.txt"
echo "✅ serviceToken 已写入凭据（长度 ${#TOK}）"

$BB sh "$DIR/mimo_balance.sh" once >/dev/null 2>&1
echo "✅ 余额已刷新，悬浮窗/通知已更新"
