#!/bin/bash
# The hub. It listens on UDP 51820 and answers. It never dials a site: the
# return path into the site exists only because the site dialed out first.
# Provisioning publishes the hub's public key, brings the interface up, and
# hands peer admission to a systemd oneshot that waits for the edge site to
# publish its key (see hub-admit-edge.sh), so `vagrant up` cannot deadlock
# on the order the machines boot in.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

KEYS_DIR=/vagrant/keys
mkdir -p "${KEYS_DIR}"
chmod 700 "${KEYS_DIR}"

apt-get update -qq
apt-get install -y -qq --no-install-recommends wireguard-tools netcat-openbsd iputils-ping >/dev/null

if [ ! -s "${KEYS_DIR}/hub.key" ]; then
    umask 077
    wg genkey > "${KEYS_DIR}/hub.key"
fi
chmod 600 "${KEYS_DIR}/hub.key"
wg pubkey < "${KEYS_DIR}/hub.key" > "${KEYS_DIR}/hub.pub"

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.77.0.1/24
ListenPort = 51820
PrivateKey = $(cat "${KEYS_DIR}/hub.key")
EOF

if [ -s "${KEYS_DIR}/edge.pub" ]; then
    cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
PublicKey = $(cat "${KEYS_DIR}/edge.pub")
AllowedIPs = 10.77.0.2/32
EOF
fi

systemctl enable wg-quick@wg0 >/dev/null
systemctl restart wg-quick@wg0

install -m 0755 /vagrant/provision/hub-admit-edge.sh /usr/local/bin/hub-admit-edge
install -m 0644 /vagrant/provision/admit-edge.service /etc/systemd/system/admit-edge.service
systemctl daemon-reload
systemctl enable --now admit-edge.service
