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

# The first answer (firmware) gets iPXE over TFTP. iPXE identifies itself
# with DHCP option 175; its answer is the HTTP script instead, which is how
# the boot avoids a loop.
cat >/etc/dnsmasq.d/fleet.conf <<CONF
interface=$iface
bind-interfaces
dhcp-range=192.168.79.100,192.168.79.150,12h
dhcp-match=set:ipxe,175
dhcp-boot=tag:!ipxe,snponly.efi
dhcp-boot=tag:ipxe,http://$EDGE_IP:8080/boot.ipxe
enable-tftp
tftp-root=$TFTP
log-dhcp
CONF

cat >/etc/nginx/conf.d/fleet.conf <<CONF
server {
    listen 8080;
    root $WWW;
    # The script is ours; everything else is the Yocto build output.
    location = /boot.ipxe { }
    location / {
        root $IMAGES;
    }
}
CONF
rm -f /etc/nginx/sites-enabled/default

[ -d "$IMAGES" ] || {
	echo "no build output at $IMAGES; run the kas build first, then vagrant rsync" >&2
	exit 1
}

systemctl enable dnsmasq nginx
systemctl restart dnsmasq nginx
echo "edge ready: DHCP/TFTP on $iface, images on http://$EDGE_IP:8080"
