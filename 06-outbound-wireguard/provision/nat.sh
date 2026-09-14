#!/bin/bash
# The customer's router. It NATs the site's LAN outward and forwards nothing
# in. Nobody in this lab configures this machine from the fleet side; it
# exists so the tunnel has to be won from the site's side, the way it is in
# production. Rules are not persisted, so the script re-applies on every
# boot and is idempotent.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends iptables >/dev/null

WAN_IF="$(ip -o -4 addr show | awk '$4 == "192.168.77.1/24" {print $2}')"
LAN_IF="$(ip -o -4 addr show | awk '$4 == "192.168.78.1/24" {print $2}')"
if [ -z "${WAN_IF}" ] || [ -z "${LAN_IF}" ]; then
    echo "nat: could not find WAN/LAN interfaces by address" >&2
    exit 1
fi

echo 1 > /proc/sys/net/ipv4/ip_forward

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -F INPUT
iptables -F FORWARD
iptables -t nat -F POSTROUTING
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i "${WAN_IF}" -o "${LAN_IF}" -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i "${LAN_IF}" -o "${WAN_IF}" -j ACCEPT
iptables -t nat -A POSTROUTING -o "${WAN_IF}" -s 192.168.78.0/24 -j MASQUERADE
