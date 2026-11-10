#!/usr/bin/env bash
# Turn the edge VM into the robots' install server: DHCP + TFTP hand the
# firmware iPXE, iPXE asks for a script over HTTP, the script loads the
# installer kernel and initramfs over HTTP. Idempotent, runs on every boot.
set -euo pipefail

EDGE_IP="${1:?usage: edge.sh <edge ip>}"
IMAGES=/srv/images
WWW=/srv/fleet-www
TFTP=/srv/tftp

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq dnsmasq nginx-light ipxe >/dev/null

# The install interface is the one that holds the lab address.
iface="$(ip -o -4 addr show | awk -v ip="$EDGE_IP" '$4 ~ "^"ip"/" {print $2}')"
[ -n "$iface" ] || {
	echo "no interface carries $EDGE_IP" >&2
	exit 1
}

install -d "$TFTP" "$WWW"
install -m 0644 /usr/lib/ipxe/snponly.efi "$TFTP/snponly.efi"
sed "s/@EDGE_IP@/$EDGE_IP/g" /srv/provision/boot.ipxe.in >"$WWW/boot.ipxe"

sed -e "s/@IFACE@/$iface/g" -e "s/@EDGE_IP@/$EDGE_IP/g" \
	/srv/provision/dnsmasq-fleet.conf.in >/etc/dnsmasq.d/fleet.conf
install -m 0644 /srv/provision/nginx-fleet.conf /etc/nginx/conf.d/fleet.conf
rm -f /etc/nginx/sites-enabled/default

[ -d "$IMAGES" ] || {
	echo "no build output at $IMAGES; run the kas build first, then vagrant rsync" >&2
	exit 1
}

systemctl enable dnsmasq nginx
systemctl restart dnsmasq nginx
echo "edge ready: DHCP/TFTP on $iface, images on http://$EDGE_IP:8080"
