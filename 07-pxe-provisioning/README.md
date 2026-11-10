# 07 PXE provisioning

Companion lab for "Provisioning Edge Servers with PXE". A robot with a blank
disk powers on, boots a small installer from the edge server over the network,
writes a Yocto image to its disk, and restarts from that disk.

Everything runs in two local VMs: `edge` (the install server) and `robot` (a
machine with an empty disk and no internet).

## Quick start

You need a Linux machine with KVM, libvirt, Vagrant and the `vagrant-libvirt`
plugin. About 10 minutes if you download the images.

```bash
cd 07-pxe-provisioning

scripts/prereqs.sh          # lists anything missing on this machine
scripts/fetch-images.sh     # downloads the prebuilt images (about 55 MB)
scripts/robot-reset.sh      # blank robot disk and firmware settings

vagrant up edge             # the install server
vagrant up robot            # the blank robot; it starts installing at once
virsh -c qemu:///system console 07-pxe-provisioning_robot
```

Watch the console. After about 30 seconds you see the installer write the
disk, then the robot restarts and shows:

```text
Welcome to the Robot!
This image was loaded through iPXE from the edge server.

Robot Fleet Lab 0.1 robot /dev/ttyS0
robot login:
```

Log in as `root` (no password), or leave the console with `Ctrl+]`.

## Looking at the VMs

- Edge server: `vagrant ssh edge`. Try `journalctl -u dnsmasq -f` for the DHCP
  log and `ls /srv/images` for what it serves.
- Robot, over SSH: `ssh root@192.168.79.10`. The edge server always gives the
  robot that address. Your host reaches it because libvirt puts your machine
  on the install network (`192.168.79.1`). `vagrant ssh robot` does not work:
  the robot has no Vagrant management network.
- Robot, over the serial console: `virsh -c qemu:///system console
  07-pxe-provisioning_robot`. This is the only view while it installs, because
  there is no SSH server in the installer.

Root has an empty password. That is only acceptable because the install
network is isolated; a real robot gets SSH keys.

Run it again from a blank robot with `scripts/robot-reset.sh` followed by
`vagrant up robot`. Remove everything with `scripts/clean.sh`.

## Build the images yourself

The release images come from this directory. To build them instead of
downloading them, you need Docker or Podman and
[`kas-container`](https://kas.readthedocs.io/). A cold build took about 5
hours on 8 cores and about 50 GB of disk; a rebuild after a small change takes
minutes because of the caches.

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

## What is in here

- `kas.yml`: the Yocto workspace (poky scarthgap, machine `qemux86-64`). One
  build makes both images.
- `meta-fleet-lab/`: the layer.
  - `conf/distro/fleet-lab.conf`: the distribution, poky renamed "Robot Fleet
    Lab".
  - `fleet-robot-image`: kernel, busybox, a DHCP client and the dropbear SSH
    server. UEFI, systemd-boot, shipped as `wic.gz` plus a `wic.bmap`. The
    greeting is in `base-files/files/{issue,motd}`.
  - `fleet-installer-image`: an initramfs with `bmaptool`, `efibootmgr` and the
    install script `fleetinstall`. It is the program the blank robot runs.
- `Vagrantfile`: `edge` (dnsmasq, iPXE, nginx) and `robot` (no box, blank disk,
  disk first and network second in its boot order).
- `provision/`: how `edge` becomes the install server.
- `scripts/`: the helpers used above.

## What happens when the robot starts

1. The robot's firmware finds no bootable disk and falls through to the
   network. It asks for DHCP; the edge server answers with iPXE.
2. iPXE asks again, receives `boot.ipxe` over HTTP, and loads the installer
   kernel and initramfs over HTTP.
3. The installer writes the image with `bmaptool`, removes the network boot
   entries from the firmware, adds one for the disk, and reboots.
4. The second start goes to the disk. The installed robot asks DHCP for an
   address (always `192.168.79.10`) and starts SSH; it does not need the edge
   server to boot.

The robot VM is set up the way a real robot would be: disk first, network
second. Putting the network first would not work in libvirt, because libvirt
regenerates the boot order from its own settings at every start and
`efibootmgr` could not change it.

## Troubleshooting

`vagrant up edge` fails with "Permission denied" opening the lab directory.
A 9p share cannot read a private home directory. This lab uses rsync folders
for that reason; if you changed them to 9p, change them back.

`vagrant up robot` fails with "cannot load AppArmor profile". The robot needs
its own copy of the firmware variable store. Run `scripts/robot-reset.sh`.

The robot shows the iPXE shell, or "Install boot failed". The edge server has
no images. Check `ls build/tmp/deploy/images/qemux86-64`, then
`vagrant rsync edge && vagrant provision edge`.

The robot installs again at every start. Its firmware settings were reset, or
the install did not finish. Read the console for lines starting with
`fleet-install:`; every failure prints its reason there and stops.

`kas-container` says "Permission denied" creating `layers/poky`. With rootless
Docker, kas needs a work directory of its own. Use `scripts/build.sh`.

## Results

Observed on 2026-11-09 and 2026-11-10 with the images built from this
directory, on one Linux host with libvirt, QEMU/KVM and OVMF:

- The blank robot got an address and iPXE from the edge server, fetched
  `boot.ipxe` over HTTP, and loaded the installer kernel and initramfs over
  HTTP.
- The installer got a DHCP lease, wrote the 31 MB `wic.gz` to `/dev/vda` with
  `bmaptool` (about 30 MiB/s, block checksums checked), removed the stale
  entries from the firmware, added a `fleet-robot` disk entry, and rebooted.
- The second start loaded `fleet-robot` from the disk, reached the login
  prompt of the Yocto image. With the edge server stopped it still booted. A
  further reset behaved the same.
- After the robot restarted, `ssh root@192.168.79.10` from the host showed the
  greeting and a shell.

## What this does not prove

- Real firmware. QEMU's OVMF behaves like many UEFI implementations, but a
  vendor board may re-add network boot entries or ignore the boot order.
- Secure Boot. The boot chain here is unsigned. Signing it is a later step.
- Authenticated images. The installer checks the block checksums in the bmap
  file, which catches corruption. It does not check who produced the image.
- A corrupted or substituted image, and a robot with the wrong disk layout.
