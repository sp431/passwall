# PassWall - rudy-TR3000 (Cudy TR3000)

## 设备信息

| 项目 | 值 |
|------|-----|
| 型号 | Cudy TR3000 256MB v1 |
| 架构 | aarch64_cortex-a53 |
| 系统 | OpenWrt 25.12.4 (r32933-4ccb782af7)，定制固件 FanchmWrt |
| 目标 | mediatek/filogic |
| 内核 | 6.12.87 |
| 内存 | 496MB |
| 包管理器 | **apk**（apk-tools 3.x，不是 opkg） |

## 已安装版本（2026-09-22 实测）

| 组件 | 版本 | 来源 |
|------|------|------|
| PassWall | 26.9.16 | 本仓库 `src/` 源码部署 |
| xray-core | 26.3.27 | 本仓库 `packages/` |
| sing-box | 1.13.21 | 本仓库 `packages/` |
| v2ray-geoip | 202607171233 | 本仓库 `packages/` |
| v2ray-geosite | 20260726062913 | 本仓库 `packages/` |
| hysteria | 2.12.3 | 在线源 |
| geoview | 0.2.6 | 在线源 |
| chinadns-ng | 2025.08.09 | 在线源 |
| naiveproxy | 150.0.7871.63 | 在线源 |
| shadowsocks-rust-sslocal / ssserver | 1.25.0 | 在线源 |
| shadowsocksr-libev-ssr-local / redir / server | 2.5.6-r12 | 在线源 |
| simple-obfs-client | 0.0.5-r3 | 在线源 |
| tcping | 0.3-r1 | 在线源 |
| v2ray-plugin | 5.49.0-r1 | 在线源 |

> `packages/` 只收录体积较大、且源站访问不稳定的 4 个核心包；其余体积小的依赖直接从
> OpenWrt 官方源安装即可。

## src/ 目录与设备路径的映射约定

**这是本仓库最重要的约定：`src/` 是路由器根文件系统的镜像。**

| 仓库路径 | 设备路径 | 内容 |
|----------|----------|------|
| `src/etc/` | `/etc/` | init 脚本、hotplug、uci-defaults、默认配置 |
| `src/usr/` | `/usr/` | LuCI 前端（controller/model/view/i18n）、核心 shell/lua 脚本、ACL、ucitrack |
| `src/www/` | `/www/` | LuCI 静态资源（前端 JS） |

因此部署时可以用一条 tar 管道整目录还原，无需逐文件 cp：

```sh
cd src && tar -cf - etc usr www | (cd / && tar -xf -)
```

## 安装方法

### 方法 1：一键脚本（推荐）

把整个 `rudy-TR3000/` 目录传到设备后：

```sh
cd /tmp/rudy-TR3000
sh scripts/install-passwall.sh
```

脚本依次完成：安装依赖包 → 按映射部署 `src/` → 修正权限 → 清理 LuCI 缓存并启用服务。

### 方法 2：手动部署

```sh
# 1) 安装共享依赖（PassWall 与 PassWall2 共用同一批核心）
apk update
apk add xray-core sing-box chinadns-ng geoview hysteria naiveproxy \
  shadowsocks-rust-sslocal shadowsocks-rust-ssserver \
  shadowsocksr-libev-ssr-local shadowsocksr-libev-ssr-redir shadowsocksr-libev-ssr-server \
  simple-obfs-client tcping v2ray-geoip v2ray-geosite v2ray-plugin

# 2) 安装本仓库自带的核心包（本地文件未签名，需 --allow-untrusted）
for f in packages/*.apk; do apk add --allow-untrusted "$f"; done

# 3) 按映射部署源码
cd src && tar -cf - etc usr www | (cd / && tar -xf -)

# 4) 权限
chmod +x /etc/init.d/passwall /etc/init.d/passwall_server
chmod +x /usr/share/passwall/*.sh
chmod +x /etc/hotplug.d/iface/98-passwall /etc/hotplug.d/ntp/30-passwall-resync
chmod 755 /etc/uci-defaults/luci-app-passwall /etc/uci-defaults/luci-app-passwall_server

# 5) 清理 LuCI 缓存并启用服务
rm -f /tmp/luci-indexcache* ; rm -rf /tmp/luci-modulecache
/etc/init.d/passwall enable
/etc/init.d/rpcd restart
```

## 验证安装

```sh
# 核心二进制可用
xray version | head -1
sing-box version | head -1

# 服务已注册
ls -l /etc/init.d/passwall
ls -l /usr/lib/lua/luci/passwall/api.lua /usr/lib/lua/luci/passwall/com.lua
ls -l /www/luci-static/resources/view/passwall/

# LuCI 页面可访问（路径是 services/passwall）
# http://<设备IP>/cgi-bin/luci/admin/services/passwall
```

## 踩坑记录（实测）

### 1. 缺 `luci/passwall/` 模块会让**整个 LuCI** 报 500

PassWall 一代的 LuCI controller 会 `require("luci.passwall.api")`。若
`/usr/lib/lua/luci/passwall/` 缺失，controller 加载失败，**不是单独一个页面报错，
而是整个 LuCI 后台 500**（菜单构建阶段就崩了）。

排查时要先移走 `/usr/lib/lua/luci/controller/passwall.lua` 恢复 LuCI，
补齐模块后再放回。本仓库已包含这 8 个模块（`api/com/server_app/util_*`），不会再踩。

### 2. PassWall 一代没有可用的官方 apk 源

OpenWrt 官方源和 SourceForge 的 `openwrt-passwall-build` 源里只有 **passwall2**，
没有 PassWall 一代的 `luci-app-passwall`。所以本机的 PassWall 一代是**源码部署**，
不在 apk 数据库里：

- `apk del` 卸不掉它，卸载需按 `src/` 的文件清单手工删除
- 升级需要重新覆盖 `src/`

### 3. 前端 JS 在 `www/` 下，不在 `usr/` 下

PassWall 的 `cbi.js` / `func.js` 等走的是 `/www/luci-static/resources/view/passwall/`。
只复制 `usr/` 会得到一个"能打开但交互失效"的页面。这是 `src/www/` 映射存在的原因。

### 4. SourceForge 在部分网络下不可用

实测：索引文件（`packages.adb`，几百字节）能下，但包体（几十 KB 以上）
直接连接中断；本机到 SourceForge 各镜像 SSL 全部 EOF。
**结论：优先走 GitHub 或 OpenWrt 官方源。**

### 5. 部署后必须清 LuCI 缓存

否则页面仍渲染旧菜单/旧模板：

```sh
rm -f /tmp/luci-indexcache* ; rm -rf /tmp/luci-modulecache
/etc/init.d/rpcd restart
```

## 注意事项

- 此设备使用 apk 包管理器，`opkg` 不存在；busybox 也**没有 `stat`**，查文件大小用 `wc -c`
- PassWall 与 PassWall2 共享依赖包（xray-core / sing-box 等），可共存但建议只启用一个
- iptables 模块 `socket` 可能不可用，PassWall 会自动降级为 REDIRECT 模式
- 全局开关默认关闭，装完需在页面里手动启用
