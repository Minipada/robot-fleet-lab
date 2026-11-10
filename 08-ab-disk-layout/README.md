# 08 A/B disk layout

Companion lab for "Two Root Filesystems and a Data Partition". The robot
image carries two equal root filesystems (slot A, slot B) and a data
partition instead of the single root of [07-pxe-provisioning](../07-pxe-provisioning/).
The installer writes the whole partition table on day zero; nothing uses
slot B or the data partition until the update articles land.

Everything else is the 07 flow: two VMs, `edge` (the install server) and
`robot` (a machine with an empty disk and no internet). The robot network
boots, writes the image, and restarts from it.

## Quick start

You need a Linux machine with KVM, libvirt, Vagrant and the `vagrant-libvirt`
plugin. About 10 minutes if you download the images.

```bash
cd 08-ab-disk-layout

scripts/prereqs.sh          # lists anything missing on this machine
scripts/fetch-images.sh     # downloads the prebuilt images
scripts/inspect-image.sh    # prints the partition table, no VM needed

scripts/robot-reset.sh      # blank robot disk and firmware settings
vagrant up edge             # the install server
vagrant up robot            # the blank robot; it starts installing at once
virsh -c qemu:///system console 08-ab-disk-layout_robot
```

`fetch-images.sh` downloads from the lab's GitHub releases
(`RELEASE_TAG=08-images-v1` by default). Until that release is published,
build the images yourself instead:

```bash
scripts/build.sh            # kas-container build kas.yml; a cold build takes hours
```

After the install, the robot boots slot A and looks exactly like the 07
one: same greeting, same SSH. The proof of this article is on the disk, so
look at either of these:

- `scripts/inspect-image.sh`, which reads the image file the edge server
  serves and prints the table below; or
- from inside the running robot (`ssh root@192.168.79.10`),
  `ls /dev/disk/by-partlabel/`, which shows boot, roota, rootb and data.

Expected partition table (from `scripts/inspect-image.sh`; ids are
per-build, the names and sizes are the contract):

```text
label: gpt
label-id: 9E1A8C4E-0000-4C1B-9F30-1A2B3C4D5E6F
device: image.wic
unit: sectors
first-lba: 2048
last-lba: 1843166
sector-size: 512

image.wic1 : start=        2048, size=      131072, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, uuid=3B7A1C2D-0000-4E5F-8A9B-0C1D2E3F4A5B, name="boot"
image.wic2 : start=      133120, size=      524288, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=5D6E7F80-0000-4A1B-9C2D-3E4F5A6B7C8D, name="roota"
image.wic3 : start=      657408, size=      524288, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=7E8F90A1-0000-4B2C-8D3E-4F5A6B7C8D9E, name="rootb"
image.wic4 : start=     1181696, size=      524288, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, uuid=9F0A1B2C-0000-4C3D-8E4F-5A6B7C8D9E0F, name="data"
```

The slots are symmetric: same size (256M), same filesystem, same content at
install. The boot entry systemd-boot writes names slot A's PARTUUID, so the
installed robot boots slot A; slot B holds the same build and waits.

## The layout contract

The update client the series installs later reads a RAUC `system.conf` that
names its slots by device. On this image that file maps the partition
labels:

```ini
[slot.rootfs.0]
device=/dev/disk/by-partlabel/roota
type=raw

[slot.rootfs.1]
device=/dev/disk/by-partlabel/rootb
type=raw
```

RAUC's own documentation puts the first install of bootloader and rootfs
outside its scope; the installer writing this image is that first install.
The whole image change from 07 is the wic file,
[meta-fleet-lab/wic/fleet-robot.wks](meta-fleet-lab/wic/fleet-robot.wks).

## Differences from 07

- `meta-fleet-lab/wic/fleet-robot.wks`: two rootfs slots and the data
  partition replace the single root.
- `scripts/lib.sh`: a different libvirt volume and domain name, so this
  increment can coexist with a 07 checkout on the same machine.
- `scripts/inspect-image.sh`: new; prints the partition table.
- `Vagrantfile`: install network renamed `fleet-install-ab` for the same
  coexistence reason.

## Build the images yourself

The release images come from this directory. To build them instead of
downloading them, you need Docker or Podman and
[`kas-container`](https://kas.readthedocs.io/). A cold build took about 5
hours on 8 cores and about 50 GB of disk; a rebuild after a small change
takes minutes because of the caches.

```bash
scripts/build.sh            # kas-container build kas.yml
```

`scripts/build.sh` keeps its caches in `~/.cache/robot-fleet-lab` (override
with `FLEET_LAB_CACHE`). Keep them: deleting the `sstate` or `downloads`
directories turns the next build into a cold one. With rootless Docker, the
`work` directory there is owned by kas on purpose, so do not point it at your
checkout.

After a rebuild, publish the new files to the running edge server:

```bash
vagrant rsync edge && vagrant provision edge
```

## Looking at the VMs

- Robot, over SSH: `ssh root@192.168.79.10`. The edge server always gives
  the robot that address.
- Robot, over the serial console: `virsh -c qemu:///system console
  08-ab-disk-layout_robot`. This is the only view while it installs.
- Edge server: `vagrant ssh edge`, then `ls /srv/images`.

Root has an empty password. That is only acceptable because the install
network is isolated; a real robot gets SSH keys.

Run it again from a blank robot with `scripts/robot-reset.sh` followed by
`vagrant up robot`. Remove everything with `scripts/clean.sh`.
