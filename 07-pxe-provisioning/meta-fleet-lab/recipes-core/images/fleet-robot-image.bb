SUMMARY = "The smallest bootable robot image: a kernel, busybox and nothing else"
LICENSE = "MIT"
HOMEPAGE = "https://github.com/Minipada/robot-fleet-lab"
AUTHOR = "David Bensoussan"

inherit core-image

# SSH for the lab: dropbear, and root with an empty password. This is only
# acceptable because the install network is isolated; a real robot gets keys.
IMAGE_FEATURES = "ssh-server-dropbear allow-root-login allow-empty-password empty-root-password"
IMAGE_INSTALL = "packagegroup-core-boot init-ifupdown busybox-udhcpc"
IMAGE_LINGUAS = ""

# wic.gz is what travels over the network; wic.bmap lets the installer write
# only the blocks that hold data and verify each one.
IMAGE_FSTYPES = "wic.gz wic.bmap"
WKS_FILE = "fleet-robot.wks"
IMAGE_BOOT_FILES = "${KERNEL_IMAGETYPE}"

# Bring the robot's one network card up with DHCP at boot, so the edge server
# can reach it over SSH. Written into the image, because the stock
# /etc/network/interfaces only holds the loopback.
fleet_network_interfaces() {
    cat > ${IMAGE_ROOTFS}${sysconfdir}/network/interfaces <<'IFACES'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
IFACES
}
ROOTFS_POSTPROCESS_COMMAND += "fleet_network_interfaces;"
