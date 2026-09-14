#!/bin/bash
# Admits the edge site as the only peer. The edge publishes its public key
# into the shared folder while this runs; the hub admits exactly that key,
# as 10.77.0.2, and nothing else. Installed by provision/hub.sh and run as
# a systemd oneshot on every boot, so admission survives restarts without
# re-provisioning. Re-runs are safe.
set -euo pipefail

KEYS_DIR=/vagrant/keys
CONF=/etc/wireguard/wg0.conf

for _ in $(seq 1 300); do
    [ -s "${KEYS_DIR}/edge.pub" ] && break
    sleep 2
done
if [ ! -s "${KEYS_DIR}/edge.pub" ]; then
    echo "admit-edge: edge.pub never appeared in ${KEYS_DIR}" >&2
    exit 1
fi

EDGE_PUB="$(cat "${KEYS_DIR}/edge.pub")"
if ! grep -qF "${EDGE_PUB}" "${CONF}"; then
    cat >> "${CONF}" <<EOF

[Peer]
PublicKey = ${EDGE_PUB}
AllowedIPs = 10.77.0.2/32
EOF
fi

# Apply the config without bouncing the tunnel: a new peer joining must not
# reset the sessions of peers already on the hub.
wg syncconf wg0 <(wg-quick strip "${CONF}")
