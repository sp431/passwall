# PassWall

OpenWrt PassWall 代理工具的源码、安装包和配置指南，适配两种路由器型号。

## 支持设备

| 型号 | 架构 | 系统 | 包管理器 | 说明 |
|------|------|------|----------|------|
| Cudy TR3000 | aarch64_cortex-a53 | OpenWrt 25.12.4 | apk | 256MB 内存，PassWall 共享依赖 |
| GL.iNet GL-SFT1200 | mipsel (mips32r2) | OpenWrt 18.06 | opkg | 116MB 内存，已安装 PassWall 26.9.16 + Xray v1.8.7 |

## 目录结构

```
passwall/
├── README.md                           # 本文件
├── .gitignore
├── rudy-TR3000/                        # Cudy TR3000 (aarch64)
│   ├── README.md                       # 安装说明
│   ├── src/                            # PassWall 源码
│   │   ├── etc/
│   │   │   └── init.d/
│   │   │       ├── passwall            # 主服务 init 脚本
│   │   │       └── passwall_server     # 服务器端 init 脚本
│   │   └── usr/
│   │       ├── lib/lua/luci/           # LuCI 前端 (controller, model, view, i18n)
│   │       └── share/passwall/         # PassWall 核心脚本
│   │           ├── 0_default_config    # 默认配置
│   │           ├── app.sh              # 主应用脚本
│   │           ├── utils.sh            # 工具函数
│   │           ├── iptables.sh         # iptables 防火墙规则
│   │           ├── nftables.sh         # nftables 防火墙规则
│   │           ├── monitor.sh          # 进程监控
│   │           ├── subscribe.lua       # 订阅管理
│   │           ├── rule_update.lua     # 规则更新
│   │           ├── helper_dnsmasq.lua  # DNS 分流辅助
│   │           ├── haproxy.lua         # 负载均衡
│   │           ├── tasks.sh            # 定时任务
│   │           ├── test.sh             # 连通性测试
│   │           └── ...                 # 其他脚本和规则
│   └── packages/                      # .apk 安装包
│       ├── xray-core-26.3.27-r1.apk   # Xray 代理核心
│       ├── sing-box-1.13.21-r1.apk    # sing-box 代理核心
│       ├── v2ray-geoip-*.apk           # GeoIP 数据库
│       └── v2ray-geosite-*.apk         # GeoSite 域名数据库
│
└── GL-SFT1200/                        # GL.iNet GL-SFT1200 (mipsel)
    ├── README.md                      # 安装说明（含已知问题和解决方案）
    └── src/                           # 兼容性脚本和配置模板
        ├── xray_wrapper.sh             # Xray 配置包装器（修复 tunnel→dokodemo-door）
        ├── start_xray.sh               # 手动启动 Xray 脚本
        ├── xray_config_template.json   # Xray 配置模板（占位符，需填入节点信息）
        └── tyo_xray.init              # OpenWrt init 启动脚本
```

## 文件用途

### rudy-TR3000/src/ — PassWall 源码

从 Cudy TR3000 路由器（OpenWrt 25.12.4）上提取的 PassWall 完整源码。

| 路径 | 用途 |
|------|------|
| `etc/init.d/passwall` | PassWall 主服务启动/停止脚本 |
| `etc/init.d/passwall_server` | PassWall 服务器端启动脚本 |
| `usr/lib/lua/luci/controller/passwall.lua` | LuCI 菜单控制器 |
| `usr/lib/lua/luci/model/cbi/passwall/` | LuCI 配置页面模型 |
| `usr/lib/lua/luci/view/passwall/` | LuCI 视图模板 |
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

### rudy-TR3000/packages/ — .apk 安装包

| 文件 | 版本 | 说明 |
|------|------|------|
| `xray-core-26.3.27-r1.apk` | 26.3.27 | Xray 代理核心 |
| `sing-box-1.13.21-r1.apk` | 1.13.21 | sing-box 代理核心 |
| `v2ray-geoip-*.apk` | 2026-07-17 | GeoIP 数据库 |
| `v2ray-geosite-*.apk` | 2026-08-08 | GeoSite 域名数据库 |

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

```bash
# 通过 apk 安装（推荐）
apk update
apk add luci-app-passwall luci-i18n-passwall-zh-cn xray-core sing-box \
  chinadns-ng v2ray-geoip v2ray-geosite

# 或从本仓库安装
cp -r src/usr/share/passwall /usr/share/passwall
cp src/etc/init.d/passwall /etc/init.d/passwall
cp src/etc/init.d/passwall_server /etc/init.d/passwall_server
cp packages/*.apk /tmp/ && apk add /tmp/*.apk
/etc/init.d/passwall enable
```

### GL.iNet GL-SFT1200 (GL-SFT1200)

详见 [GL-SFT1200/README.md](GL-SFT1200/README.md)，主要步骤：

1. 安装 PassWall 26.9.16 ipk 包（需手动下载 mipsel 版本）
2. 安装 Xray v1.8.7（mips32le 版本，新版不兼容此设备）
3. 部署 `xray_wrapper.sh` 包装器修复配置兼容性
4. 使用 `xray_config_template.json` 模板配置代理节点
5. 部署 `tyo_xray.init` 实现开机自启

## 已知问题（GL-SFT1200）

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| Xray "unknown config id: tunnel" | PassWall 26.9.16 使用新版 Xray 的 tunnel 协议 | 使用 xray_wrapper.sh 替换为 dokodemo-door |
| Xray v26.x "Illegal instruction" | 新版 Xray 不兼容 MIPS mips32r2 | 使用 Xray v1.8.7 (mips32le) |
| 动态链接器缺失 | 部分 mipsel 包需要 ld-musl-mipsel-sf.so.1 | `ln -sf /lib/ld-musl-mipsel.so.1 /lib/ld-musl-mipsel-sf.so.1` |
| iptables-mod-socket 不可用 | OpenWrt 18.06 缺少该模块 | PassWall 自动降级使用 REDIRECT 模式 |

## 注意事项

- 配置模板中使用 `YOUR_NODE_ADDRESS` 等占位符，请勿提交真实节点信息
- PassWall 和 PassWall2 共享部分依赖包（xray-core, sing-box 等）
- Xray 版本需与设备架构匹配，详见各设备 README
- OpenWrt 25.x 使用 apk 包管理器，OpenWrt 18.06 使用 opkg