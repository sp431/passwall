#!/bin/sh
# ============================================================
# PassWall 一键安装脚本（GL.iNet GL-XE300 专用）
# 目标设备: GL.iNet GL-XE300(NOR/NAND) / OpenWrt 22.03.4
#           ath79, mips_24kc (big-endian), opkg, 内核 5.10.176
#           RAM 128MB / overlay 98MB（ubi0_1）
# 用法: 把本目录放设备后  cd XE300 && sh scripts/install-passwall.sh
#
# 特点（2026-09-24 实测）：
#   * 完全离线：全部 18 个 ipk 已随本仓放在 XE300/packages/，
#     opkg 本地安装，不依赖任何网络源。
#   * 设备仅配 GL.iNet 源（fw.gl-inet.com），实测该域名当前不可达；
#     透明代理所需 kmod（TPROXY/conntrack-extra/nat/ifb…）GL 固件已自带。
#   * 安装版本：luci-app-passwall 26.9.16 / xray-core 26.9.9 /
#     chinadns-ng 2025.08.09 / geoview 0.2.6 + 中文包。
# ============================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
PKGDIR="$HERE/../packages"

log()  { echo "[passwall] $*"; }
warn() { echo "[passwall][WARN] $*" >&2; }

[ -x /bin/opkg ] || { echo "错误: 未检测到 opkg（本设备应为 22.03/opkg）"; exit 1; }
[ -d "$PKGDIR" ]  || { echo "错误: 找不到离线包目录 $PKGDIR（请把整个 XE300 目录放设备）"; exit 1; }

# ---------- 0. 备份 ----------
BAK="/root/_pw_backup_xe300_$(date +%Y%m%d%H%M%S)"
log "备份 opkg 状态到 $BAK"
mkdir -p "$BAK"
cp -a /usr/lib/opkg/status "$BAK/status.bak" 2>/dev/null
[ -f /etc/config/passwall ] && cp -a /etc/config/passwall "$BAK/config.bak"

# ---------- 1. 透明代理内核模块自检（GL 固件应已自带） ----------
log "检查透明代理内核模块"
for m in xt_TPROXY nf_tproxy_ipv4 xt_REDIRECT ifb; do
    if [ -f "/lib/modules/$(uname -r)/$m.ko" ]; then
        log "    模块文件存在 $m"
    else
        warn "未找到 $m.ko（若 TPROXY 异常需另装匹配 kmod）"
    fi
done

# ---------- 2. 离线安装全部 ipk ----------
log "本地离线安装 packages/ 下全部 ipk（约 23MB，NAND 写入较慢请耐心等待）"
opkg install "$PKGDIR"/*.ipk
RC=$?
[ $RC -ne 0 ] && { warn "opkg 返回非 0（$RC），见上方信息"; }

# ---------- 3. 权限 + 开机自启 ----------
log "权限与开机自启"
chmod 755 /etc/init.d/passwall /etc/init.d/passwall_server 2>/dev/null
/etc/init.d/passwall enable
/etc/init.d/passwall_server enable 2>/dev/null
rm -f /tmp/luci-indexcache* 2>/dev/null
rm -rf /tmp/luci-modulecache 2>/dev/null

log "完成。核心版本：$(xray version 2>/dev/null | head -1)"
log "页面: http://192.168.8.1/cgi-bin/luci/admin/services/passwall"
log "全局开关默认关闭，添加节点后在页面手动启用。"
