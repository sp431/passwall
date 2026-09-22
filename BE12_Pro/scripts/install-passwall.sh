#!/bin/sh
# ============================================================
# PassWall 一键安装脚本（Tenda BE12 Pro 专用）
# 目标设备: Tenda BE12 Pro / OpenWrt SNAPSHOT r34613 (FanchmWrt)
#           内核 6.18.31, aarch64_cortex-a53, apk, 512MB RAM, overlay 65MB
# 用法: cd /tmp/passwall && sh BE12_Pro/scripts/install-passwall.sh
#
# 实测可行的安装路径（2026-09-22）：
#   * PassWall 源码 = 本仓库 rudy-TR3000/src（跨内核通用），部署到根
#   * 核心 apk（Xray/chinadns-ng/geoview/geo）= sp431/passwall2 仓库，
#     设备直接从 GitHub raw 串行下载 + wc -c 逐字节校验（Go 核心静态编译，
#     不挑内核版本）。官方 downloads.openwrt.org 大核心在本设备常超时。
#   * 精简安装：overlay 仅 65MB，只装下列 6 个包，sing-box/hysteria 按需另补。
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SRC="$HERE/../../rudy-TR3000/src"
STAGE="/tmp/pw_pkgs"

PW2="https://raw.githubusercontent.com/sp431/passwall2/master/rudy-TR3000/packages"

# name|expected_bytes（改版本时同步更新 size，可用 GitHub API 查）
PKGS="
chinadns-ng-2025.08.09-r1.apk|270130
geoview-0.2.6-r1.apk|2974684
v2ray-geoip-202607171233-r1.apk|4434302
v2ray-geosite-20260726062913-r1.apk|661857
xray-core-26.3.27-r1.apk|10752795
tcping-0.3-r1.apk|4265
"

log()  { echo "[passwall] $*"; }
warn() { echo "[passwall][WARN] $*" >&2; }

[ -x /sbin/apk ]  || { echo "错误: 未检测到 apk"; exit 1; }
[ -d "$SRC" ]     || { echo "错误: 找不到源码目录 $SRC（请把整个仓库放设备）"; exit 1; }

# ---------- 0. 备份 ----------
BAK="/root/_pw_backup_$(date +%Y%m%d%H%M%S)"
log "0/5 备份到 $BAK"
mkdir -p "$BAK"
for p in /etc/init.d/passwall /usr/lib/lua/luci/passwall /usr/share/passwall \
         /www/luci-static/resources/view/passwall /etc/apk/world; do
    [ -e "$p" ] && cp -r "$p" "$BAK"/ 2>/dev/null
done

# ---------- 1. 小包依赖（官方源） ----------
log "1/5 安装小包依赖（microsocks / luci-compat）"
apk add microsocks luci-compat dnsmasq-full 2>/dev/null \
    || warn "官方源小包未全装上，不影响核心安装"

# ---------- 2. 串行下载核心并校验 ----------
log "2/5 从 GitHub raw 串行下载核心到 $STAGE"
mkdir -p "$STAGE"; rm -f "$STAGE"/*.apk
echo "$PKGS" | sed '/^$/d' | while IFS='|' read -r name expect; do
    dest="$STAGE/$name"; ok=0; n=0
    while [ $n -lt 6 ]; do
        n=$((n+1)); rm -f "$dest"
        wget -q -T 90 -O "$dest" "$PW2/$name"
        got=$(wc -c < "$dest" 2>/dev/null)
        if [ "$got" = "$expect" ]; then ok=1; break; fi
        log "    重试 $name（$got/$expect）"
    done
    if [ $ok -eq 1 ]; then log "    OK   $name ($expect)"; else
        warn "  FAIL $name（6 次未成功）"; echo "$name" > "$STAGE/FAILED"; fi
done
[ -f "$STAGE/FAILED" ] && { warn "有包下载失败，终止。已下载："; ls -l "$STAGE"; exit 1; }

# ---------- 3. 安装核心 + 部署源码 ----------
log "3/5 安装核心 apk"
apk add --allow-untrusted "$STAGE"/*.apk \
    || { warn "核心安装失败"; exit 1; }

log "    部署 src/ -> /"
cd "$SRC" || exit 1
tar -cf - etc usr www | (cd / && tar -xf -) || { warn "src 部署失败"; exit 1; }

# ---------- 4. 权限 + 自检 ----------
log "4/5 权限与自检"
chmod 755 /etc/init.d/passwall /etc/init.d/passwall_server 2>/dev/null
[ -d /usr/share/passwall ] && chmod 755 /usr/share/passwall/*.sh 2>/dev/null
for m in api com util_xray; do
    [ -f "/usr/lib/lua/luci/passwall/$m.lua" ] || warn "缺模块 $m（会导致 LuCI 500）"
done

# ---------- 5. 启用 ----------
log "5/5 清缓存、启用开机自启"
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null
/etc/init.d/passwall enable
/etc/init.d/rpcd restart 2>/dev/null
rm -rf "$STAGE"

log "完成。访问 http://<设备IP>/cgi-bin/luci/admin/services/passwall"
log "全局开关默认关闭，需添加节点后手动启用。"
