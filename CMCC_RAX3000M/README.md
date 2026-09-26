# CMCC RAX3000M — PassWall（一代）离线安装说明

本目录为 **中国移动 CMCC RAX3000M** 提供 **纯离线** 的 PassWall 安装支持。设备刷 FanchmWrt 后无 WAN、无 apk 源，全部依赖与前端随本目录携带。

## 设备信息（实测 2026-09-26）

| 项目 | 值 |
|---|---|
| 型号 | 中国移动 CMCC RAX3000M（`cmcc,rax3000m`） |
| SoC | MediaTek MT7981B（Filogic 820），双核 A53，aarch64 |
| 系统 | FanchmWrt = **OpenWrt 25.12.4** r32933-4ccb782af7 |
| 内核 | **6.12.87** |
| 架构标识 | mediatek/filogic / `aarch64_cortex-a53` |
| 包管理器 | **apk-tools 3.0.5**（非 opkg） |
| 存储 | 128MB SPI-NAND；rootfs_data(UBI) 88.5MiB |
| 内存 | 512MB DDR4 |
| 网络 | br-lan **192.168.1.1**，root / password |
| 源状态 | `/etc/apk/repositories` **为空**，无 WAN/互联网 |
| 防火墙 | **仅 nft**（nftables-json 1.1.6），无 iptables |

## 目录内容

```
CMCC_RAX3000M/
├── README.md                    # 本文件
├── packages/                    # 39 个离线 apk（61MB）+ SHA256SUMS.txt
├── scripts/
│   └── install-passwall.sh      # 一键离线安装
└── src/                         # ⚠️ PassWall 一代前端（etc usr www，无 apk）
    ├── etc/init.d/{passwall,passwall_server}
    ├── usr/lib/lua/luci/controller/passwall.lua
    ├── usr/lib/lua/luci/passwall/        # api/com/util_xray...
    ├── usr/share/passwall/
    └── www/luci-static/resources/view/passwall/
```

## 安装

把本 `CMCC_RAX3000M` 目录上传到设备（dropbear 无 SFTP，用 `cat >` / U盘 / HTTP）：

```sh
cd /tmp/CMCC_RAX3000M
sh scripts/install-passwall.sh
```

安装后页面：

```
http://192.168.1.1/cgi-bin/luci/admin/services/passwall
```

## 安装结果（实测）

| 组件 | 版本 / 状态 |
|---|---|
| PassWall 前端 | src 部署，`controller/passwall.lua` 存在 |
| xray-core | 26.3.27（`/usr/bin/xray`） |
| sing-box | 1.13.21 |
| chinadns-ng | 2025.08.09 |
| 其它核心 | hysteria 2.12.3、naiveproxy、shadowsocks-rust、shadowsocksr-libev、v2ray geoip/geosite、geoview |
| Lua 依赖 | lyaml 6.2.7 / libyaml 0.2.5 |
| 开机自启 | `S99passwall` 已建立 |
| LuCI 页面 | HTTP **200** |

## 关键经验 / 调试方法

1. **⚠️ PassWall 一代前端没有 apk**：它的 LuCI（controller、view、lua 库、init、share）只存在于 `src/` 根文件系统映射。**必须用 tar 展开到根**，直接装 apk 装不出页面：
   ```sh
   cd src && tar -cf - etc usr www | (cd / && tar -xf -)
   chmod 755 /etc/init.d/passwall /etc/init.d/passwall_server
   ```
   （PassWall2 与 OpenVPN 的前端则由 apk 提供，不需要 src。）
2. **一次性装齐（最重要）**：apk 半途失败会在 `/etc/apk/world` 残留坏约束使 apk 瘫痪。先干跑：
   ```sh
   apk add --allow-untrusted --simulate /tmp/apkpool/*.apk
   ```
   反复「补包 → 上传 → 干跑」直到没有 `missing`，再真正 `apk add`。本次迭代三轮补齐。
3. **干跑缺依赖的典型补齐**：coreutils / coreutils-base64 / nohup / timeout、curl、unzip、lyaml（+libyaml）、libev、libpcre2、libsodium、libudns、libatomic1（在 **target feed**）。
4. **DCO 占位**：
   ```sh
   apk add --virtual kmod-ovpn-backports
   ```
5. **部署后必须刷新**：删 `/tmp/luci-indexcache*` 与 `/tmp/luci-modulecache/*`，再 `/etc/init.d/rpcd restart`，否则菜单/页面不更新。
6. **nft-only**：设备没有 iptables 命令，透明代理走 nftables；所需 `kmod-nft-tproxy`、`kmod-nf-socket`、`kmod-nft-fullcone` 均已内置。
7. **完整性校验**：
   ```sh
   cd packages && sha256sum -c SHA256SUMS.txt
   ```

## 依赖来源

- PassWall 前端 src 与核心 apk：本仓库 `rudy-TR3000/`（TR3000 与本机同为 filogic / aarch64_cortex-a53 / 25.12.4 / 内核 6.12.87，apk 可直接复用）。
- 通用依赖：OpenWrt 25.12.4 官方 base/packages/luci/target feed 离线下载补齐（离线无网时在另一台联网机抓 feed 索引后下载）。
