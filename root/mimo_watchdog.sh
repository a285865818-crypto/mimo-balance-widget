#!/system/bin/sh
# MiMo 看门狗：守护死了自动拉起；处理 app 的自愈请求（app 无 root，用文件信号）
# 每 3 秒检测屏幕方向，变化时把权威方向广播给 app（app 后台时进程内方向查询会过期，
# 显隐同步必须由本脚本以 root 视角检测并广播）。
# 方向判断用 cur=宽x高（dumpsys 里 rotation= 命中的是历史日志行，不是当前状态）。
# 去抖：方向连续 2 轮一致才广播，转屏过渡期的瞬时波动不认（否则 app 端隐藏/恢复闪烁）。
# 另：周期给 MiMo 进程提调度优先级（nice -6），第三方 app 冷启动抢 CPU 时悬浮窗动画少掉帧。
BB=/data/adb/ksu/bin/busybox
DIR=/data/adb/mimo_balance
APPF=/data/data/com.mimo.balance/files
PREV=""
CAND=""
CNT=0
TICK=0
while :; do
  CUR=$(dumpsys window displays 2>/dev/null | head -n 40 | grep -oE 'cur=[0-9]+x[0-9]+' | head -n1)  # head 前置让 dumpsys 提前退出（管道断开），检测约 10ms
  W=${CUR#cur=}; W=${W%x*}
  H=${CUR#*x}
  if [ -n "$W" ] && [ -n "$H" ] && [ "$W" -gt "$H" ] 2>/dev/null; then
    LAND=true
  else
    LAND=false
  fi
  if [ "$LAND" != "$PREV" ]; then
    if [ "$LAND" = "$CAND" ]; then
      CNT=$((CNT+1))
    else
      CAND=$LAND
      CNT=1
    fi
    if [ "$CNT" -ge 2 ]; then
      PREV=$LAND
      CNT=0
      am broadcast -n com.mimo.balance/.RotationSyncReceiver --ez land $LAND >/dev/null 2>&1
    fi
  else
    CAND=$LAND
    CNT=0
  fi
  MPID=$(pidof com.mimo.balance 2>/dev/null | awk '{print $1}')
  if [ -n "$MPID" ]; then
    $BB renice -n -6 -p "$MPID" >/dev/null 2>&1
  fi
  TICK=$((TICK+1))
  if [ "$TICK" -ge 20 ]; then
    TICK=0
    PID=$(cat $DIR/run.pid 2>/dev/null)
    if [ -z "$PID" ] || [ ! -d /proc/$PID ]; then
      rm -f $DIR/run.pid
      setsid sh $DIR/mimo_balance.sh >/dev/null 2>&1 &
    fi
    if [ -f "$APPF/daemon.req" ]; then
      rm -f "$APPF/daemon.req"
    fi
  fi
  $BB sleep 3
done
