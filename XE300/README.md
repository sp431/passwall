# GL.iNet GL-XE300 — PassWall 离线安装说明

本目录为 **GL.iNet GL-XE300(NOR/NAND)** 的 PassWall 安装支持。与其他设备不同，本机 **完全离线安装**：全部 23 个 ipk 已随本仓放在 `XE300/packages/`，opkg 本地安装，不依赖任何网络源。

## 设备信息（实测 2026-09-24）

| 项目 | 值 |
|---|---|
| 型号 | GL.iNet GL-XE300(NOR/NAND) |
| 系统 | OpenWrt 22.03.4 r20123（GL.iNet 官方固件） |
| 内核 | 5.10.176 |
| 架构 | ath79/nand / **mips_24kc（big-endian 大端）** |
| 包管理器 | **opkg**（非 apk） |
| 内存 | 约 121 MB |
| overlay | 98 MB（ubi0_1，装完用约 39 MB、剩约 54 MB） |
| 外接存储 | /mnt/sda1 约 29.7 GB |
| 网络 | br-lan 192.168.8.1 / WAN eth1（出口北京移动） |
| SSH | `root` / 见设备登记 |

## 安装

把**整个 XE300 目录**放到设备（脚本依赖同级 `packages/`）：

```sh
cd /tmp/XE300
sh scripts/install-passwall.sh
```

脚本流程：备份 opkg status 与旧配置 → 透明代理 kmod 自检 → `opkg install packages/*.ipk` 离线安装 → 权限与开机自启 → 清 LuCI 缓存。

安装后页面：`http://192.168.8.1/cgi-bin/luci/admin/services/passwall`（实测 HTTP 200）。
全局开关默认关闭，**添加节点后在页面手动启用**。

## 版本清单（packages/，共 23 个 ipk）

| 组件 | 版本 |
|---|---|
| luci-app-passwall | 26.9.16 |
| luci-i18n-passwall-zh-cn | 26.9.16（中文） |
| xray-core | **26.9.9** |
| chinadns-ng | 2025.08.09 |
| geoview | 0.2.6 |
| v2ray-geoip / v2ray-geosite | 2026-09-04 / 2026-09-07 |
| ipt2socks / dns2socks / microsocks | 1.1.4 / 2.1 / 1.0.5 |
| tcping | 0.3 |
| coreutils / -base64 / -nohup / -timeout | 9.0-2 |
| luci-compat | git-23.093.42303 |
| libyaml / lyaml | 0.2.5 / 6.2.7 |
| iptables-mod-socket / -iprange | 1.8.7（透明代理 match 扩展） |
| kmod-nf-socket / kmod-ipt-socket / kmod-ipt-iprange | 5.10.176（对应内核模块） |

> `coreutils` 是仅依赖 libc 的空壳 meta 包（967 B，无载荷），属正常。
> ipk 来源为官方预编译 feed **openwrt-passwall-build（SourceForge）** 的 `packages-22.03/mips_24kc/`，ipk 外层为 tar.gz（内含 debian-binary / data.tar.gz / control.tar.gz），opkg 正常支持。

## 踩坑记录（实测）

1. **GL.iNet 源当前不可达**
   `/etc/opkg/distfeeds.conf` 只有 3 个指向 `fw.gl-inet.com` 的源，实测该域名当前连不通；设备也没有标准 OpenWrt 源。因此**不能 `opkg update` 在线装**，必须走离线 ipk。好在透明代理所需 kmod（TPROXY / conntrack-extra / nat / ifb 等）GL 固件已全部自带并加载，无需另装。

2. **SourceForge 浏览器 UA 返回镜像选择 HTML 页**
   用带 `Mozilla/...` 的 UA 下载大文件，拿到的是约 102 KB 的镜像选择 HTML（`<!doctype html>...<title>Download ...`），不是真 ipk。**去掉浏览器 UA、用 curl 默认 UA**（等价 `Accept: application/octet-stream`）才直接 301 到真实文件；镜像子域名（altushost-swe / nchc / jaist 等）在当前网络下全部 `http=000`，只有 `master.dl.sourceforge.net` 可用。

3. **大文件被截断 → 断点续传**
   geoip / geosite 多次在 ~3 MB 处被截断，重下无效。用 `curl -sL -C -` 断点续传循环 + `wc -c` 逐字节校验、`gzip -t` 完整性检查补齐：
   ```sh
   for n in $(seq 1 60); do
     got=$(wc -c < "$name"); [ "$got" = "$exp" ] && break
     curl -sL --max-time 120 -C - -o "$name" "$url"; sleep 1
   done
   ```

4. **coreutils 在 packages feed，不在 base**
   22.03 feed 布局为 `packages/<arch>/{base,packages,luci}/`；coreutils 系位于 **packages** feed，从 base 取会 404。

5. **GL 首启包还原占用 opkg 锁**
   首启时 PPid=1 的 `opkg update; cat /etc/backup/installed_packages.txt | xargs opkg install` 会把出厂包（samba4 等）装回，期间持续占用 opkg 锁。属正常流程，**等待结束**即可，不要强杀。

6. **Xray 版本硬门禁 + prerelease 取包**
   新版 `util_xray.lua` 写死 `xray_min_version = "26.7.11"`，旧核心启动即被 `app/version` 拒绝、socks 入站起不来（前端误报「SOCKS 端口不可用」）。本目录直接随仓携带 **xray-core 26.9.9**。
   ⚠️ XTLS 自 v26.4 起全部标记 **prerelease**，`/releases/latest` 永远停在 26.3.27，需到 [tags 列表](https://github.com/XTLS/Xray-core/tags) 取新版。

7. **NAND 写入慢，安装中途查不到包**
   opkg 先解包落盘（overlay 增长），再逐个 postinst，最后一次性「Configuring…Updating database」。期间可能出现 `D` 态 `balance_dirty_pages`（UBI/NAND 刷盘慢）与卡在 `luci-app-passwall.postinst`（对 init 脚本 enable+start），耐心等待即可，**不要中途强杀**以免损坏数据库。

8. **fw4 环境不完整 → 回退 iptables，且缺 socket/iprange（2026-09-24 实测）**
   GL 固件虽带 firewall4 / nft，但 PassWall 检测 `dnsmasq_nftset:0`（dnsmasq-full 无 nftset 支持），打印「nftables (fw4) 应用环境不完整，切换至 iptables」。而 iptables 路径又**缺少 `socket`、`iprange` 两个基础 match 扩展**（用户态 `/usr/lib/iptables/libxt_*.so` 与内核 `xt_socket`/`xt_iprange` 都没有），PassWall 判定为「非代理模式，仅允许服务启停」，不下发透明代理规则。
   **修复**：补装本目录已随仓的 5 个 ipk（`opkg install packages/*.ipk` 会一并装上）——3 个 kmod（kmod-nf-socket、kmod-ipt-socket、kmod-ipt-iprange）+ 2 个用户态扩展（iptables-mod-socket、iptables-mod-iprange）。装完 `lsmod` 见 `xt_socket`/`xt_iprange`，重启 PassWall 即正常下发规则。
   ⚠️ 这些 kmod 必须与设备内核**精确匹配**（本机内核 5.10.176，官方 22.03.4 target feed 正是 5.10.176，哈希一致可装）。

## 卸载

ipk 已注册进 opkg 数据库，可正常卸载：

```sh
/etc/init.d/passwall stop
opkg remove luci-i18n-passwall-zh-cn luci-app-passwall xray-core \
  chinadns-ng geoview ipt2socks dns2socks microsocks tcping \
  v2ray-geoip v2ray-geosite lyaml libyaml luci-compat coreutils-* coreutils \
  iptables-mod-socket iptables-mod-iprange \
  kmod-ipt-socket kmod-ipt-iprange kmod-nf-socket
```
