#!/bin/bash
# The edge server at the site. The only machine in the lab that initiates a
# connection. It dials the hub from behind the customer's NAT, holds the
# resulting mapping open with a 25-second keepalive, and accepts nothing
# inbound anywhere. The hub is defined before this machine in the
# Vagrantfile, so hub.pub already exists by the time this runs.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

KEYS_DIR=/vagrant/keys
mkdir -p "${KEYS_DIR}"
chmod 700 "${KEYS_DIR}"

apt-get update -qq
apt-get install -y -qq --no-install-recommends wireguard-tools iputils-ping >/dev/null

for _ in $(seq 1 150); do
    [ -s "${KEYS_DIR}/hub.pub" ] && break
    sleep 2
done
if [ ! -s "${KEYS_DIR}/hub.pub" ]; then
    echo "edge: hub.pub never appeared in ${KEYS_DIR}" >&2
    exit 1
fi

if [ ! -s "${KEYS_DIR}/edge.key" ]; then
    umask 077
    wg genkey > "${KEYS_DIR}/edge.key"
fi
chmod 600 "${KEYS_DIR}/edge.key"
wg pubkey < "${KEYS_DIR}/edge.key" > "${KEYS_DIR}/edge.pub"

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.77.0.2/24
PrivateKey = $(cat "${KEYS_DIR}/edge.key")

[Peer]
PublicKey = $(cat "${KEYS_DIR}/hub.pub")
Endpoint = 192.168.77.10:51820
AllowedIPs = 10.77.0.0/24
PersistentKeepalive = 25
EOF

wg-quick down wg0 2>/dev/null || true
wg-quick up wg0
