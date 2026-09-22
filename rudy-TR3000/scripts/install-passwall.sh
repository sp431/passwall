#!/bin/sh
# ============================================================
# PassWall 一键安装脚本
# 目标设备: Cudy TR3000 256MB v1 / OpenWrt 25.12.4 (apk)
# 用法: cd /tmp/rudy-TR3000 && sh scripts/install-passwall.sh
#
# 该脚本做四件事:
#   1) 安装共享依赖（xray/sing-box 等，PassWall 与 PassWall2 共用）
#   2) 安装本仓库自带的 4 个核心包
#   3) 按 src/ -> 根文件系统 的映射部署 LuCI 前端与核心脚本
#   4) 修正权限、清理 LuCI 缓存、启用服务
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../src"
PKG="$HERE/../packages"

log() { echo "[passwall] $*"; }
warn() { echo "[passwall][WARN] $*" >&2; }

[ -x /sbin/apk ] || { echo "错误: 未检测到 apk，本脚本仅适用于 OpenWrt 25.x+"; exit 1; }
[ -d "$SRC" ] || { echo "错误: 找不到源码目录 $SRC"; exit 1; }

# ---------- 0. 备份关键路径 ----------
BAK="/root/_pw_backup_$(date +%Y%m%d%H%M%S)"
log "0/5 备份现有文件到 $BAK"
mkdir -p "$BAK"
for p in /etc/init.d/passwall /etc/init.d/passwall_server \
         /usr/lib/lua/luci/controller/passwall.lua \
         /usr/lib/lua/luci/passwall /usr/lib/lua/luci/model/cbi/passwall \
         /usr/lib/lua/luci/view/passwall /usr/share/passwall /www/luci-static/resources/view/passwall; do
    [ -e "$p" ] && cp -r "$p" "$BAK"/ 2>/dev/null
done
log "    备份完成（如需回滚：按 $SRC 清单覆盖回去即可）"

# ---------- 1. 共享依赖 ----------
log "1/5 安装共享依赖（PassWall / PassWall2 共用）"
apk update || warn "apk update 失败，检查 /etc/apk/repositories"
apk add xray-core sing-box chinadns-ng geoview hysteria naiveproxy \
        shadowsocks-rust-sslocal shadowsocks-rust-ssserver \
        shadowsocksr-libev-ssr-local shadowsocksr-libev-ssr-redir shadowsocksr-libev-ssr-server \
        simple-obfs-client tcping v2ray-geoip v2ray-geosite v2ray-plugin \
    || warn "部分依赖安装失败，请检查软件源；已安装的包会被跳过"

# ---------- 2. 本仓库核心包 ----------
if ls "$PKG"/*.apk >/dev/null 2>&1; then
    log "2/5 安装本仓库自带的 apk 包"
    for f in "$PKG"/*.apk; do
        log "    安装 $(basename "$f")"
        # 本地文件无签名，必须 --allow-untrusted；已安装时 apk 会提示并跳过
        apk add --allow-untrusted "$f" || warn "        $(basename "$f") 安装失败"
    done
else
    log "2/5 跳过（packages/ 内无 apk 文件）"
fi

# ---------- 3. 部署源码 ----------
log "3/5 按根文件系统映射部署 src/ -> /"
cd "$SRC" || exit 1
tar -cf - etc usr www | (cd / && tar -xf -)
[ $? -eq 0 ] || { warn "src 部署失败"; exit 1; }

# ---------- 4. 权限 ----------
log "4/5 修正权限"
chmod 755 /etc/init.d/passwall /etc/init.d/passwall_server 2>/dev/null
[ -d /usr/share/passwall ] && chmod 755 /usr/share/passwall/*.sh 2>/dev/null
[ -f /etc/hotplug.d/iface/98-passwall ] && chmod 755 /etc/hotplug.d/iface/98-passwall
[ -f /etc/hotplug.d/ntp/30-passwall-resync ] && chmod 755 /etc/hotplug.d/ntp/30-passwall-resync
for f in /etc/uci-defaults/luci-app-passwall /etc/uci-defaults/luci-app-passwall_server; do
    [ -f "$f" ] && chmod 755 "$f"
done

# 关键模块自检：缺 luci/passwall/ 会导致整个 LuCI 500
for m in api com util_xray util_sing-box; do
    [ -f "/usr/lib/lua/luci/passwall/$m.lua" ] || warn "缺失模块 /usr/lib/lua/luci/passwall/$m.lua（会导致 LuCI 后台 500）"
done
[ -f /www/luci-static/resources/view/passwall/cbi.js ] || warn "缺少前端 JS，页面交互会失效"

# ---------- 5. 生效 ----------
log "5/5 清理 LuCI 缓存并启用服务"
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null
/etc/init.d/passwall enable 2>/dev/null
/etc/init.d/rpcd restart 2>/dev/null

log "安装完成。"
log "访问: http://<设备IP>/cgi-bin/luci/admin/services/passwall"
log "注意: PassWall 全局开关默认关闭，需在页面中手动启用。"
