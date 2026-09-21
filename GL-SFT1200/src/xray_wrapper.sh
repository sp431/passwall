#!/bin/sh
# Xray wrapper for PassWall compatibility on Xray v1.8.7
# This script patches PassWall-generated configs to use dokodemo-door
# instead of the "tunnel" protocol (which is only available in newer Xray)
REAL=/usr/bin/xray.real

for a in "$@"; do
case "$a" in
*.json)
if [ -f "$a" ]; then
ADDR=$(grep -o '"address": *"[^"]*"' "$a" | grep -v '127.0.0.1' | head -1 | sed 's/.*"address": *"//;s/".*//')
PORT=$(grep -o '"port": *[0-9]*' "$a" | grep -v '1070\|1041' | head -1 | sed 's/.*"port": *//')
PASS=$(grep -o '"pass": *"[^"]*"' "$a" | head -1 | sed 's/.*"pass": *"//;s/".*//')

if [ -z "$PORT" ]; then
PORT=$(grep -o '"port": *[0-9]*' "$a" | sed -n 3p | sed 's/.*"port": *//')
fi

if [ -z "$ADDR" ]; then
ADDR=$(grep -o '"address": *"[^"]*"' "$a" | tail -1 | sed 's/.*"address": *"//;s/".*//')
fi

if [ -n "$ADDR" ] && [ -n "$PORT" ]; then
cat > "$a" << EOF
{
  "log": {"loglevel": "warning"},
  "inbounds": [
    {
      "port": 1070,
      "protocol": "socks",
      "settings": {"udp": true, "auth": "noauth"},
      "listen": "127.0.0.1",
      "tag": "socks-in"
    },
    {
      "port": 1041,
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
          "address": "${ADDR}",
          "port": ${PORT},
          "users": [{"user": "", "pass": "${PASS}"}]
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
fi
fi
;;
esac
done

exec "$REAL" "$@"
