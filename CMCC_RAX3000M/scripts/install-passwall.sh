#!/bin/sh
# ============================================================
# PassWall（一代）离线一键安装（CMCC RAX3000M 专用）
# 目标: 中国移动 CMCC RAX3000M, MediaTek MT7981B (filogic), aarch64
#       FanchmWrt = OpenWrt 25.12.4 r32933, 内核 6.12.87, apk-tools
# 场景: 设备 /etc/apk/repositories 为空且无 WAN/互联网 -> 纯离线
#
# 用法（把本 CMCC_RAX3000M 目录放到设备后）:
#   cd /tmp/CMCC_RAX3000M && sh scripts/install-passwall.sh
#
# 实测（2026-09-26）:
#   * ⚠️ PassWall 一代 LuCI 前端【没有 apk】，只存在于 src/ 根文件系统
#     映射（etc/usr/www），必须用 tar 展开到 / 部署
#   * 核心/依赖（xray-core、sing-box、chinadns-ng、lyaml、coreutils…）
#     由 39 个 apk 一次性装齐
#   * DCO 占位：openvpn 相关依赖里的 kmod-ovpn-backports 用空虚拟包
#   * 设备仅 nft（nftables-json），无 iptables；透明代理内核模块已内置
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
PKGDIR="$HERE/../packages"
SRCDIR="$HERE/../src"
STAGE="/tmp/apkpool"

log()  { echo "[passwall] $*"; }
warn() { echo "[passwall][WARN] $*" >&2; }

[ -x /sbin/apk ] || { echo "错误: 未检测到 apk"; exit 1; }
ls "$PKGDIR"/*.apk >/dev/null 2>&1 || { echo "错误: $PKGDIR 内无 apk"; exit 1; }
[ -d "$SRCDIR/etc" ] || { echo "错误: 未找到 $SRCDIR（PassWall 前端源码）"; exit 1; }

# ---------- 0. 备份 ----------
BAK="/root/_pw_backup_$(date +%Y%m%d%H%M%S)"
log "0/6 备份到 $BAK"; mkdir -p "$BAK"
for p in /etc/init.d/passwall /etc/init.d/passwall_server \
         /etc/config/passwall /usr/share/passwall /etc/apk/world; do
    [ -e "$p" ] && cp -r "$p" "$BAK"/ 2>/dev/null
done

# ---------- 1. 内核模块 / TUN ----------
log "1/6 检查 TUN / 透明代理内核模块"
[ -c /dev/net/tun ] && log "    /dev/net/tun 存在" || warn "无 /dev/net/tun"

# ---------- 2. DCO 空虚拟包占位 ----------
log "2/6 占位 kmod-ovpn-backports"
if apk info -e kmod-ovpn-backports >/dev/null 2>&1; then
    log "    已存在"
else
    apk add --virtual kmod-ovpn-backports || warn "空虚拟包创建失败"
fi

# ---------- 3. 一次性离线安装全部 apk ----------
log "3/6 离线安装（39 个 apk，一次性装齐）"
mkdir -p "$STAGE"; rm -f "$STAGE"/*.apk
cp "$PKGDIR"/*.apk "$STAGE"/
N=$(ls "$STAGE"/*.apk | wc -l); log "    待装 $N 个包"
apk add --allow-untrusted "$STAGE"/*.apk || {
    warn "批量安装失败。请执行: apk add --allow-untrusted --simulate $STAGE/*.apk"
    warn "按 missing 输出补齐依赖后重跑，勿半途残留。"
    exit 1
}

# ---------- 4. 部署 PassWall 一代前端 src（关键，无 apk） ----------
log "4/6 部署 src/（etc usr www）到根文件系统"
( cd "$SRCDIR" && tar -cf - etc usr www | (cd / && tar -xf -) ) || {
    warn "src 部署失败"; exit 1
}
chmod 755 /etc/init.d/passwall 2>/dev/null
chmod 755 /etc/init.d/passwall_server 2>/dev/null

# ---------- 5. 清缓存 / 重启 rpcd ----------
log "5/6 刷新 LuCI 缓存并重启 rpcd"
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null

# ---------- 6. 启用自启 + 验证 ----------
log "6/6 启用开机自启并验证"
/etc/init.d/passwall enable
echo "    ---- 控制器/前端 ----"
[ -f /usr/lib/lua/luci/controller/passwall.lua ] \
    && echo "    controller/passwall.lua 存在" || warn "缺 controller"
[ -d /usr/share/passwall ] && echo "    /usr/share/passwall 存在" || warn "缺 share"
echo "    ---- 核心二进制 ----"
for b in xray sing-box chinadns-ng; do
    printf '    %-10s ' "$b"; (which "$b" 2>/dev/null || echo MISSING)
done
rm -rf "$STAGE"

log "完成。页面 http://<设备IP>/cgi-bin/luci/admin/services/passwall"
