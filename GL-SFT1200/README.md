# PassWall - GL-SFT1200 (GL.iNet)

## 设备信息
- 型号: GL.iNet GL-SFT1200
- 架构: mipsel (MIPS interAptiv mips32r2 小端)
- 系统: OpenWrt 18.06
- SoC: Siflower sf19a28
- 内存: 116MB

## 已安装包

| 包名 | 版本 | 备注 |
|------|------|------|
| luci-app-passwall | 26.9.16 | PassWall 主包 |
| xray-core | v1.8.7 | 手动安装（mips32le） |
| chinadns-ng | - | DNS 分流 |
| sing-box | - | 代理核心 |

## 安装方法

### 步骤1: 安装 PassWall

PassWall 26.9.16 不在 OpenWrt 18.06 默认源中，需手动安装。

```bash
# 下载 PassWall ipk 包（需从 PassWall Releases 下载对应 mipsel 架构版本）
# https://github.com/xiaorouji/openwrt-passwall/releases

# 安装依赖
opkg update
opkg install iptables-mod-nat-extra iptables-mod-tproxy libopenssl

# 安装 PassWall
opkg install luci-app-passwall_*.ipk
```

### 步骤2: 安装 Xray v1.8.7

Xray 新版本（v26.x）与此设备的 Linux 4.14 内核不兼容（futexwakeup 错误），
需安装 v1.8.7 版本。

```bash
# 下载 mips32le (小端) 版本的 Xray v1.8.7
wget https://github.com/XTLS/Xray-core/releases/download/v1.8.7/Xray-linux-mips32le-v1.8.7.zip
unzip Xray-linux-mips32le-v1.8.7.zip -d /tmp/xray_install

# 安装
cp /tmp/xray_install/xray /usr/bin/xray
chmod +x /usr/bin/xray

# 验证
/usr/bin/xray version
```

### 步骤3: 配置 Xray 兼容性

PassWall 26.9.16 为新版 Xray 生成 `tunnel` 协议配置，Xray v1.8.7 不支持。
需要使用 xray_wrapper.sh 包装器自动修复配置。

```bash
# 安装包装器
cp src/xray_wrapper.sh /usr/bin/xray_wrapper.sh
chmod +x /usr/bin/xray_wrapper.sh

# 备份原始 xray 并安装包装器
cp /usr/bin/xray /usr/bin/xray.real
cp /usr/bin/xray_wrapper.sh /usr/bin/xray
chmod +x /usr/bin/xray
```

### 步骤4: 手动配置代理节点

由于 PassWall 生成的配置与 Xray v1.8.7 不兼容，可使用手动配置脚本：

```bash
# 编辑配置模板
cp src/xray_config_template.json /etc/tyo_config.json
vi /etc/tyo_config.json  # 修改为你的节点信息

# 安装启动脚本
cp src/tyo_xray.init /etc/init.d/tyo_xray
chmod +x /etc/init.d/tyo_xray
/etc/init.d/tyo_xray enable

# 启动
/etc/init.d/tyo_xray start

# 验证 SOCKS 代理
curl -s --socks5-hostname 127.0.0.1:1070 http://ip.sb
```

## 目录结构

```
src/
  xray_wrapper.sh          # Xray 配置兼容包装器
  start_xray.sh            # 手动启动 Xray 脚本
  tyo_xray.init            # OpenWrt init 启动脚本
  xray_config_template.json # Xray 配置模板
packages/
  installed_packages.txt   # 完整已安装包列表（待补充）
```

## 已知问题与解决方案

### 1. Xray "unknown config id: tunnel" 错误
- 原因: PassWall 26.9.16 使用新版 Xray 的 `tunnel` 协议
- 解决: 使用 `xray_wrapper.sh` 自动将 `tunnel` 替换为 `dokodemo-door`

### 2. Xray v26.x "Illegal instruction" 错误
- 原因: 新版 Xray 不兼容 MIPS mips32r2 架构
- 解决: 使用 Xray v1.8.7 (mips32le)

### 3. 动态链接器缺失
- 原因: 部分 mipsel 包需要 `ld-musl-mipsel-sf.so.1`
- 解决: `ln -sf /lib/ld-musl-mipsel.so.1 /lib/ld-musl-mipsel-sf.so.1`

### 4. iptables-mod-socket 不可用
- 原因: OpenWrt 18.06 缺少该模块
- 解决: PassWall 自动降级使用 REDIRECT 模式

## 注意事项

- 此设备使用 opkg 包管理器
- 内存仅 116MB，大型代理工具（如 sing-box）可能占用较多资源
- Xray v1.8.7 不支持 `tunnel` 协议，需使用包装器或手动配置
- 配置文件中不要包含真实的节点 IP、密码等敏感信息
