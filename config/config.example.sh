# 复制到 /data/adb/mimo_balance/config.sh 并填入真实值（chmod 600）
# 此文件是模板，真实 config.sh 已被 .gitignore 排除

# 小米账号 userId（登录 platform.xiaomimimo.com 后从 cookies 里看）
export MIMO_USER_ID="YOUR_USER_ID"

# SSO 兑换 callback（URL 编码后的完整地址，含平台签名 sign，缺签名会 401）
# 从浏览器开发者工具 Network 里复制 serviceLogin 请求的 callback 参数即可
export MIMO_CB="https%3A%2F%2Fplatform.xiaomimimo.com%2Fsts%3Fsign%3DYOUR_SIGN%253D%26followup%3Dhttp%3A%2F%2Fplatform.xiaomimimo.com%2Fapi%2Fv1%2FtokenPlan%2Fdetail"
