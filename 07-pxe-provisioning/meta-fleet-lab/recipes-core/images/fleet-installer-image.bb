SUMMARY = "Network installer: boots from iPXE and writes the robot image to disk"
LICENSE = "MIT"

# Not core-image: this is an initramfs, with no root filesystem to boot into.
inherit image

PACKAGE_INSTALL = "initramfs-framework-base initramfs-module-fleetinstall busybox"
IMAGE_FEATURES = ""
IMAGE_LINGUAS = ""
NO_RECOMMENDATIONS = "1"
IMAGE_FSTYPES = "cpio.gz"
