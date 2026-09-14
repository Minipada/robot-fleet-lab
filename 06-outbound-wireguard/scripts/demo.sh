#!/bin/bash
# The demonstration for this increment, one part per machine. Run it three
# times, once inside each VM:
#
#   vagrant ssh hub  -c /vagrant/scripts/demo.sh
#   vagrant ssh nat  -c /vagrant/scripts/demo.sh
#   vagrant ssh edge -c /vagrant/scripts/demo.sh
#
# Failures are the point in the first two sections, so this script never
# sets -e: an unreachable dial must print and continue, not abort.
set -uo pipefail

case "$(hostname -s)" in
hub)
    echo "== 1. The hub has no route into the customer's network"
    echo '$ ip route get 192.168.78.10'
    ip route get 192.168.78.10
    echo "    (exit $?: the site's LAN is not an address the hub can name)"
    echo
    echo "== 2. Dialing the site fails: nothing accepts new inbound sessions"
    echo '$ nc -z -w 2 192.168.78.10 22'
    nc -z -w 2 192.168.78.10 22
    echo "    (exit $?: no listener, no port forward, no path in)"
    echo
    echo "== 3. The tunnel exists because the site dialed out"
    echo '$ wg show wg0'
    wg show wg0
    echo
    echo "    endpoint above = the customer router's WAN address and a port"
    echo "    the router chose by itself. Nobody opened it for us."
    echo
    echo "== 4. The hub reaches the site through the tunnel the site created"
    echo '$ ping -c 3 10.77.0.2'
    ping -c 3 10.77.0.2
    ;;

nat)
    echo "== The customer's router, in full: NAT out, forward nothing in"
    echo '$ iptables -t nat -S POSTROUTING'
    iptables -t nat -S POSTROUTING
    echo
    echo '$ iptables -t nat -S | grep -c DNAT || true'
    echo "    DNAT rules: $(iptables -t nat -S | grep -c DNAT || true)"
    echo
    echo '$ iptables -S FORWARD'
    iptables -S FORWARD
    echo
    echo "    The only way back in is on a session the site itself started."
    ;;

edge)
    echo "== The site dialed out and keeps the mapping alive"
    echo '$ wg show wg0'
    wg show wg0
    echo
    echo "    persistent keepalive: every 25 seconds, or the NAT mapping"
    echo "    times out and the hub loses its only way back in."
    echo
    echo "== The hub through the tunnel"
    echo '$ ping -c 3 10.77.0.1'
    ping -c 3 10.77.0.1
    ;;

*)
    echo "run this inside one of the lab VMs: hub, nat or edge" >&2
    exit 1
    ;;
esac
