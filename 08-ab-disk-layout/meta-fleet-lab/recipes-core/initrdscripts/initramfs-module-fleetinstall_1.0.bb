SUMMARY = "initramfs-framework module: install the robot image from the edge server"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = "file://fleetinstall"
S = "${WORKDIR}"

do_install() {
    install -d ${D}/init.d
    install -m 0755 ${WORKDIR}/fleetinstall ${D}/init.d/90-fleetinstall
}

FILES:${PN} = "/init.d/90-fleetinstall"
RDEPENDS:${PN} = "initramfs-framework-base busybox-udhcpc bmaptool python3-netclient efibootmgr util-linux-blockdev"
