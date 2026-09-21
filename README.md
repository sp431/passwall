<img width="950" height="520" alt="image" src="https://github.com/user-attachments/assets/8f939009-d20c-477d-b938-8c34500b562b" />

以上是 PassWall 与 PassWall2 的核心差异对比。以下是详细的补充说明：

## 核心定位差异

PassWall 是经典稳定版本，适合日常代理和轻量路由场景；PassWall2 是进阶演进版本，强调节点分流和 DNS 策略控制。

## 协议支持

PassWall2 支持更多新协议，包括 Hysteria2、TUIC、Reality、Shadow-TLS、XHTTP 等 passwall2.org 。PassWall 原版对新协议的支持较少。

## 分流能力

PassWall2 预置了精细的分流规则——包括游戏直连（Steam 等）、AI 服务代理、流媒体分流（Netflix/Disney）、Telegram 代理等，开箱即用 github.com 。PassWall 原版分流规则相对基础，需要手动配置。

## 负载均衡与故障转移

PassWall2 支持自动故障转移（Failover），当主节点不可用时自动切换备用节点；PassWall 原版依赖 HAProxy 手动配置负载均衡。

