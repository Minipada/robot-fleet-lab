SUMMARY = "The smallest bootable robot image: a kernel, busybox and nothing else"
LICENSE = "MIT"

inherit core-image

IMAGE_FEATURES = ""
IMAGE_INSTALL = "packagegroup-core-boot"
IMAGE_LINGUAS = ""

# wic.gz is what travels over the network; wic.bmap lets the installer write
# only the blocks that hold data and verify each one.
IMAGE_FSTYPES = "wic.gz wic.bmap"
WKS_FILE = "fleet-robot.wks"
IMAGE_BOOT_FILES = "${KERNEL_IMAGETYPE}"
