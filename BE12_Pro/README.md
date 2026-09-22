# Tenda BE12 Pro — PassWall 安装说明

本目录为 **Tenda BE12 Pro** 的 PassWall 安装支持。脚本与源码复用仓库内跨内核通用的文件，本目录只放设备专用安装脚本与说明。

## 设备信息（实测 2026-09-22）

| 项目 | 值 |
|---|---|
| 型号 | Tenda BE12 Pro（`tenda,be12-pro`） |
| 系统 | OpenWrt SNAPSHOT r34613（FanchmWrt） |
| 内核 | 6.18.31 aarch64 |
| 架构 | mediatek/filogic / aarch64_cortex-a53 |
| 包管理器 | apk（无 opkg） |
| 内存 | 512 MB |
| **overlay** | **仅 65 MB**（装完剩约 38 MB） |
| 网络 | br-lan 192.168.1.1 / phy0.1-sta0 192.168.254.60（中继） |

## 安装

把**整个仓库**放到设备（脚本依赖 `rudy-TR3000/src` 与 sp431/passwall2 仓库的核心 apk）：

```sh
cd /tmp/passwall
sh BE12_Pro/scripts/install-passwall.sh
```

脚本流程：备份 → 装小包依赖 → 从 GitHub raw 串行下载核心 apk 并逐字节校验 → 安装核心 → 部署源码 → 权限自检 → 启用开机自启。

安装后页面：`http://<设备IP>/cgi-bin/luci/admin/services/passwall`（实测 200）。

## 精简安装说明

overlay 仅 65 MB，脚本默认只装：

| 组件 | 版本 | 来源 |
|---|---|---|
| Xray | 26.3.27 | sp431/passwall2 apk |
| chinadns-ng | 2025.08.09 | sp431/passwall2 apk |
| geoview | 0.2.6 | sp431/passwall2 apk |
| v2ray-geoip / geosite | 2026-07 | sp431/passwall2 apk |
| tcping | 0.3 | sp431/passwall2 apk |
| microsocks / luci-compat | 官方源小包 | downloads.openwrt.org |

需要 sing-box（约 15 MB）/ hysteria（约 8 MB）等时再单独补，空间基本够但别一次装齐。

## 踩坑记录（实测）

1. **换行符 CRLF（最隐蔽）**
   仓库 blob 本是 LF，但在 Windows 上克隆时，用户全局 `core.autocrlf=true` 会在**工作区**把脚本转成 CRLF。若直接把工作区文件部署到设备，busybox `ash` 解析全部失败：

   ```
   /etc/rc.common: line N: : not found
   can't open '\r/usr/share/passwall/utils.sh'
   ```

   表现为 init enable 返回 2、服务静默不起。
   **根治（已在仓库根加 `.gitattributes`，`* text=auto eol=lf`）**：此后在 Windows 克隆/检出也强制保持 LF。设备侧已部署后可 `sed -i 's/\r$//'` 应急。

2. **官方源大核心下载超时**：设备上 `apk update` / 下载 Xray 等常 wget error 8、APKINDEX unexpected EOF。可靠做法是设备从 **GitHub raw 串行下载 + `wc -c` 校验**（Go 核心静态编译，不挑内核）。不要并行后台下载，会截断。

3. **PassWall 一代无官方 apk**：OpenWrt 官方 snapshot 源只有 PassWall2，本设备走**源码部署**，不在 apk 数据库，卸载需手工。

4. **world 残留约束**：安装失败后 `/etc/apk/world` 可能留未满足约束，导致 apk 全面报错。须手工删掉残留行后一次性装齐（详见仓库根 skill 说明）。

## 卸载（源码部署，无 apk）

手工删除：`/etc/init.d/passwall*`、`/usr/lib/lua/luci/{controller,model,view,passwall}/*passwall*`、`/usr/share/passwall`、`/www/luci-static/resources/view/passwall`、`/etc/config/passwall*`，再删自启软链 `/etc/rc.d/{S99,K15}passwall`。
