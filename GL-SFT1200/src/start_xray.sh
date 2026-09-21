#!/bin/sh
# Manually generate Xray v1.8.7 compatible config and start xray
# Usage: Edit NODE_ADDR, NODE_PORT, NODE_USER, NODE_PASS before running
NODE_ADDR="YOUR_NODE_ADDRESS"
NODE_PORT="YOUR_NODE_PORT"
NODE_USER="YOUR_USERNAME"
NODE_PASS="YOUR_PASSWORD"
SOCKS_PORT="1070"
REDIR_PORT="1041"

CONFIG_DIR="/tmp/etc/passwall/acl/default"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/global.json" << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": ${SOCKS_PORT},
      "protocol": "socks",
      "settings": {"udp": true, "auth": "noauth"},
      "listen": "127.0.0.1",
      "tag": "socks-in"
    },
    {
      "port": ${REDIR_PORT},
      "protocol": "dokodemo-door",
      "streamSettings": {"sockopt": {"tproxy": "redirect"}},
      "settings": {"network": "tcp,udp", "followRedirect": true},
      "tag": "tcp_redir"
    }
  ],
  "outbounds": [
    {
      "protocol": "socks",
      "settings": {
        "servers": [{
          "address": "${NODE_ADDR}",
          "port": ${NODE_PORT},
          "users": [{"user": "${NODE_USER}", "pass": "${NODE_PASS}"}]
        }]
      },
      "streamSettings": {"sockopt": {"mark": 255}},
      "tag": "proxy"
    },
    {"protocol": "freedom", "tag": "direct"},
    {"protocol": "blackhole", "tag": "blackhole"}
  ],
  "routing": {
    "rules": [
      {"type": "field", "outboundTag": "proxy", "network": "tcp,udp"}
    ]
  }
}
EOF

# Restore original xray binary if wrapper exists
if [ -f /usr/bin/xray.real ]; then
    rm -f /usr/bin/xray
    mv /usr/bin/xray.real /usr/bin/xray
    chmod +x /usr/bin/xray
fi

killall xray 2>/dev/null
sleep 1

/usr/bin/xray run -c "$CONFIG_DIR/global.json" &
echo "xray started, PID: $!"
sleep 2

ps | grep xray | grep -v grep
netstat -tlnp 2>/dev/null | grep -E "${SOCKS_PORT}|${REDIR_PORT}"
