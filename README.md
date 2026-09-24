# PassWall

OpenWrt PassWall 代理工具的源码、安装包和配置指南，适配多种路由器型号。

## 支持设备

| 型号 | 架构 | 系统 | 包管理器 | 说明 |
|------|------|------|----------|------|
| Cudy TR3000 | aarch64_cortex-a53 | OpenWrt 25.12.4 | apk | 256MB 内存，PassWall 26.9.16 源码部署 |
| Tenda BE12 Pro | aarch64_cortex-a53 | OpenWrt SNAPSHOT r34613（内核 6.18.31） | apk | 512MB 内存 / overlay 仅 65MB，精简安装 |
| GL.iNet GL-SFT1200 | mipsel (mips32r2) | OpenWrt 18.06 | opkg | 116MB 内存，已安装 PassWall 26.9.16 + Xray v1.8.7 |
| GL.iNet GL-XE300 | mips_24kc (大端) | OpenWrt 22.03.4 | opkg | 121MB 内存 / overlay 98MB，**完全离线**安装 PassWall 26.9.16 + Xray 26.9.9 |

> **换行符**：仓库根已加 `.gitattributes`（`* text=auto eol=lf`），在 Windows 上克隆/检出也强制 LF——OpenWrt busybox ash 无法解析 CRLF 脚本。详见各设备 README。

## 目录结构

```
passwall/
├── README.md                           # 本文件
├── .gitignore
├── .gitattributes                      # 强制 LF（Windows checkout 也不转 CRLF）
├── rudy-TR3000/                        # Cudy TR3000 (aarch64)
│   ├── README.md                       # 安装说明 + 踩坑记录
│   ├── scripts/
│   │   └── install-passwall.sh         # 一键安装脚本
│   ├── src/                            # 设备根文件系统的镜像（见下方映射说明）
│   │   ├── etc/
│   │   │   ├── config/
│   │   │   │   └── passwall_server     # 服务端默认配置
│   │   │   ├── hotplug.d/
│   │   │   │   ├── iface/98-passwall   # 接口上线时重载
│   │   │   │   └── ntp/30-passwall-resync  # NTP 校时后重同步
│   │   │   ├── init.d/
│   │   │   │   ├── passwall            # 主服务 init 脚本
│   │   │   │   └── passwall_server     # 服务器端 init 脚本
│   │   │   └── uci-defaults/           # 首次启动初始化脚本
│   │   ├── usr/
│   │   │   ├── lib/lua/luci/           # LuCI 前端
│   │   │   │   ├── controller/passwall.lua
│   │   │   │   ├── model/cbi/passwall/ # 配置页面模型
│   │   │   │   ├── view/passwall/      # 视图模板
│   │   │   │   ├── passwall/           # 核心 Lua 模块（api/com/util_*）
│   │   │   │   └── i18n/passwall.zh-cn.lmo
│   │   │   └── share/
│   │   │       ├── passwall/           # 核心 shell/lua 脚本与规则库
│   │   │       ├── rpcd/acl.d/         # 权限声明
│   │   │       └── ucitrack/           # 配置变更跟踪
│   │   └── www/                        # → 设备 /www（LuCI 静态资源）
│   │       └── luci-static/resources/view/passwall/  # cbi.js / func.js 等前端 JS
│   └── packages/                       # .apk 安装包
│       ├── xray-core-26.3.27-r1.apk    # Xray 代理核心
│       ├── sing-box-1.13.21-r1.apk     # sing-box 代理核心
│       ├── v2ray-geoip-*.apk           # GeoIP 数据库
│       └── v2ray-geosite-*.apk         # GeoSite 域名数据库
│
├── BE12_Pro/                           # Tenda BE12 Pro (aarch64, SNAPSHOT)
│   ├── README.md                       # 安装说明 + 精简安装/CRLF 踩坑
│   └── scripts/
│       └── install-passwall.sh         # 复用 rudy-TR3000/src，核心从 passwall2 仓库拉
│
├── GL-SFT1200/                        # GL.iNet GL-SFT1200 (mipsel)
│   ├── README.md                      # 安装说明（含已知问题和解决方案）
│   └── src/                           # 兼容性脚本和配置模板
│       ├── xray_wrapper.sh             # Xray 配置包装器（修复 tunnel→dokodemo-door）
│       ├── start_xray.sh               # 手动启动 Xray 脚本
│       ├── xray_config_template.json   # Xray 配置模板（占位符，需填入节点信息）
│       └── tyo_xray.init              # OpenWrt init 启动脚本
│
└── XE300/                             # GL.iNet GL-XE300 (mips_24kc, 22.03)
    ├── README.md                      # 完全离线安装说明 + SourceForge/断点续传踩坑
    ├── packages/                      # 18 个离线 ipk（约 23MB）
    │   ├── luci-app-passwall_26.9.16_all.ipk
    │   ├── xray-core_26.9.9-1_mips_24kc.ipk
    │   └── ...                        # chinadns-ng/geoview/coreutils/luci-compat 等
    └── scripts/
        └── install-passwall.sh        # opkg 本地离线一键安装
```

## src/ 与设备路径的映射约定

`rudy-TR3000/src/` 是**设备根文件系统的镜像**：

| 仓库路径 | 设备路径 |
|----------|----------|
| `src/etc/` | `/etc/` |
| `src/usr/` | `/usr/` |
| `src/www/` | `/www/` |

因此可以整目录还原：

```sh
cd rudy-TR3000/src && tar -cf - etc usr www | (cd / && tar -xf -)
```

## 文件用途

### rudy-TR3000/src/ — PassWall 源码

与 OpenWrt 官方 `luci-app-passwall` 包（tag 26.9.16-1）对齐的完整源码。

| 路径 | 用途 |
|------|------|
| `etc/init.d/passwall` | PassWall 主服务启动/停止脚本 |
| `etc/init.d/passwall_server` | PassWall 服务器端启动脚本 |
| `etc/hotplug.d/iface/98-passwall` | 网络接口上线时自动重载代理 |
| `etc/hotplug.d/ntp/30-passwall-resync` | NTP 校时后重新同步 |
| `etc/uci-defaults/luci-app-passwall*` | 首次启动的默认配置初始化 |
| `etc/config/passwall_server` | 服务端默认 UCI 配置 |
| `usr/lib/lua/luci/controller/passwall.lua` | LuCI 菜单控制器 |
| `usr/lib/lua/luci/passwall/api.lua` | 核心 API 模块（**缺失会导致整个 LuCI 500**） |
| `usr/lib/lua/luci/passwall/com.lua` | 通用功能模块 |
| `usr/lib/lua/luci/passwall/util_*.lua` | 各协议后端（xray / sing-box / hysteria2 / naiveproxy / shadowsocks） |
| `usr/lib/lua/luci/model/cbi/passwall/` | LuCI 配置页面模型 |
| `usr/lib/lua/luci/view/passwall/` | LuCI 视图模板 |
| `www/luci-static/resources/view/passwall/` | 前端 JS（cbi.js / func.js / Sortable.min.js / qrcode.min.js） |
| `usr/share/rpcd/acl.d/luci-app-passwall.json` | LuCI 权限声明 |
| `usr/share/ucitrack/luci-app-passwall*.json` | 配置变更跟踪声明 |
| `usr/share/passwall/app.sh` | 主应用逻辑（生成配置、启动/停止代理） |
| `usr/share/passwall/utils.sh` | 通用工具函数 |
| `usr/share/passwall/iptables.sh` | iptables 防火墙规则管理 |
| `usr/share/passwall/nftables.sh` | nftables 防火墙规则管理 |
| `usr/share/passwall/monitor.sh` | 代理进程监控和自动恢复 |
| `usr/share/passwall/subscribe.lua` | 节点订阅解析和更新 |
| `usr/share/passwall/rule_update.lua` | GeoIP/GeoSite 规则更新 |
| `usr/share/passwall/helper_dnsmasq.lua` | DNS 分流配置（dnsmasq + ChinaDNS-NG） |
| `usr/share/passwall/haproxy.lua` | 节点负载均衡 |
| `usr/share/passwall/tasks.sh` | 定时任务（订阅更新、规则更新等） |
| `usr/share/passwall/test.sh` | 节点连通性测试 |
| `usr/share/passwall/0_default_config` | UCI 默认配置 |

### rudy-TR3000/scripts/ — 安装脚本

| 文件 | 用途 |
|------|------|
| `install-passwall.sh` | 一键完成：备份 → 装依赖 → 装核心包 → 部署 src → 权限 → 清缓存启用 |

### rudy-TR3000/packages/ — .apk 安装包

| 文件 | 版本 | 说明 |
|------|------|------|
| `xray-core-26.3.27-r1.apk` | 26.3.27 | Xray 代理核心 |
| `sing-box-1.13.21-r1.apk` | 1.13.21 | sing-box 代理核心 |
| `v2ray-geoip-*.apk` | 2026-07-17 | GeoIP 数据库 |
| `v2ray-geosite-*.apk` | 2026-08-26 | GeoSite 域名数据库 |

其余体积较小的依赖（hysteria / geoview / chinadns-ng / naiveproxy / shadowsocks-rust 等）
从 OpenWrt 官方源安装即可，无需离线打包。

### GL-SFT1200/src/ — 兼容性脚本

GL.iNet GL-SFT1200 使用 OpenWrt 18.06 + Xray v1.8.7，与 PassWall 26.9.16 存在兼容性问题，以下脚本用于修复。

| 文件 | 用途 |
|------|------|
| `xray_wrapper.sh` | 包装器：自动将 PassWall 生成的 `tunnel` 协议替换为 `dokodemo-door`，兼容 Xray v1.8.7 |
| `start_xray.sh` | 手动生成兼容配置并启动 Xray（含变量占位符，需填入节点信息） |
| `xray_config_template.json` | Xray 配置模板（SOCKS 代理 + 透明代理），占位符格式 |
| `tyo_xray.init` | OpenWrt init 脚本，开机自动启动 Xray |

## 安装方法

### Cudy TR3000 (rudy-TR3000)

推荐用一键脚本：

```bash
cd /tmp/rudy-TR3000 && sh scripts/install-passwall.sh
```

手动安装（等价步骤）：

```bash
# 1) 装共享依赖
apk update
apk add xray-core sing-box chinadns-ng geoview hysteria naiveproxy \
  shadowsocks-rust-sslocal shadowsocks-rust-ssserver \
  shadowsocksr-libev-ssr-local shadowsocksr-libev-ssr-redir shadowsocksr-libev-ssr-server \
  simple-obfs-client tcping v2ray-geoip v2ray-geosite v2ray-plugin

# 2) 装本仓库核心包
for f in packages/*.apk; do apk add --allow-untrusted "$f"; done

# 3) 按映射部署源码
cd src && tar -cf - etc usr www | (cd / && tar -xf -)

# 4) 权限 + 启用
chmod +x /etc/init.d/passwall /etc/init.d/passwall_server /usr/share/passwall/*.sh
rm -f /tmp/luci-indexcache* ; rm -rf /tmp/luci-modulecache
/etc/init.d/passwall enable
```

> **PassWall 一代没有可用的官方 apk 源**（OpenWrt 官方源与 SourceForge 的
> `openwrt-passwall-build` 只提供 PassWall2），所以本设备采用源码部署，
> 不在 apk 数据库中，`apk del` 无法卸载。

### GL.iNet GL-SFT1200 (GL-SFT1200)

详见 [GL-SFT1200/README.md](GL-SFT1200/README.md)，主要步骤：

1. 安装 PassWall 26.9.16 ipk 包（需手动下载 mipsel 版本）
2. 安装 Xray v1.8.7（mips32le 版本，新版不兼容此设备）
3. 部署 `xray_wrapper.sh` 包装器修复配置兼容性
4. 使用 `xray_config_template.json` 模板配置代理节点
5. 部署 `tyo_xray.init` 实现开机自启

### GL.iNet GL-XE300 (XE300)

**完全离线**，18 个 ipk 已随仓放在 `XE300/packages/`（设备 GL 源不可达，无法在线装）：

```sh
cd /tmp/XE300 && sh scripts/install-passwall.sh
```

透明代理所需 kmod（TPROXY/conntrack-extra/nat/ifb）GL 固件已自带。详见 [XE300/README.md](XE300/README.md)。

## 已知问题

### Cudy TR3000

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 整个 LuCI 后台 500 | 缺 `usr/lib/lua/luci/passwall/` 核心模块，controller 加载失败会在菜单构建阶段拖垮全部页面 | 补齐该目录；应急时先移走 `controller/passwall.lua` |
| 页面能打开但交互失效 | 缺 `www/luci-static/resources/view/passwall/` 前端 JS | 补 `src/www/` 目录 |
| `apk` 报 unresolved dependencies | 批量安装失败在 `/etc/apk/world` 留下未满足的约束 | 手工编辑 world 删掉残留行，再一次性装齐 |
| 下载的 apk 提取失败 | 并行下载被截断（包尺寸不符） | 串行下载 + 用 `wc -c` 校验字节数 |
| SourceForge 无法下载 | 部分网络下大文件连接中断 | 改用 GitHub 或 OpenWrt 官方源 |

详细排查过程见 [rudy-TR3000/README.md](rudy-TR3000/README.md#踩坑记录实测)。

### GL-SFT1200

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Xray "unknown config id: tunnel" | PassWall 26.9.16 使用新版 Xray 的 tunnel 协议 | 使用 xray_wrapper.sh 替换为 dokodemo-door |
| Xray v26.x "Illegal instruction" | 新版 Xray 不兼容 MIPS mips32r2 | 使用 Xray v1.8.7 (mips32le) |
| 动态链接器缺失 | 部分 mipsel 包需要 ld-musl-mipsel-sf.so.1 | `ln -sf /lib/ld-musl-mipsel.so.1 /lib/ld-musl-mipsel-sf.so.1` |
| iptables-mod-socket 不可用 | OpenWrt 18.06 缺少该模块 | PassWall 自动降级使用 REDIRECT 模式 |

## 注意事项

- 配置模板中使用 `YOUR_NODE_ADDRESS` 等占位符，请勿提交真实节点信息
- PassWall 和 PassWall2 共享部分依赖包（xray-core, sing-box 等），建议只启用其中一个
- Xray 版本需与设备架构匹配，详见各设备 README
- OpenWrt 25.x 使用 apk 包管理器，OpenWrt 18.06 使用 opkg
- OpenWrt 25.x 的 busybox 无 `stat` 命令，查看文件大小用 `wc -c`
