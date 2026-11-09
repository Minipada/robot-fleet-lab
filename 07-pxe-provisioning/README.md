# 07 PXE provisioning

Companion lab for "Provisioning Edge Servers with PXE". A robot with a blank
disk powers on, boots a small installer from the edge server over the network,
writes a Yocto image to its disk, and restarts from that disk.

## Status

Ran end to end on one Linux host (libvirt, QEMU/KVM, OVMF) on 2026-11-09.
See "Results" at the bottom for exactly what was observed.

## Pieces

- `kas.yml`: the Yocto workspace (poky scarthgap, `qemux86-64`). One build
  makes both images.
- `meta-fleet-lab/`: the layer.
  - `fleet-robot-image`: kernel, busybox and nothing else. UEFI, systemd-boot,
    shipped as `wic.gz` plus a `wic.bmap`.
  - `fleet-installer-image`: an initramfs with `bmaptool`, `efibootmgr` and the
    install script `fleetinstall`. It is the program the blank robot runs.
- `Vagrantfile`: `edge` (dnsmasq, iPXE, nginx) and `robot` (no box, blank disk,
  boots from the network then the disk).
- `provision/`: how `edge` turns into the install server.

## Run it

Needs Linux with KVM, libvirt, Vagrant with `vagrant-libvirt`, `rsync`, and
Docker or Podman for `kas-container`.

```bash
# 1. Build both images. A cold build took about 5 hours on 8 cores (the
#    kernel, the toolchain and qemu-system-native dominate); a rebuild after
#    a change to the installer script takes a few minutes. Keep the cache
#    directories between builds; do not delete them.
mkdir -p ~/.cache/robot-fleet-lab/{work,downloads,sstate} build
export KAS_CONTAINER_ENGINE=docker            # or podman
export KAS_WORK_DIR=$HOME/.cache/robot-fleet-lab/work
export KAS_BUILD_DIR=$PWD/build
export DL_DIR=$HOME/.cache/robot-fleet-lab/downloads
export SSTATE_DIR=$HOME/.cache/robot-fleet-lab/sstate
kas-container build kas.yml

# 2. Give the robot its own copy of the UEFI variable store (once).
size=$(stat -c %s /usr/share/OVMF/OVMF_VARS_4M.fd)
virsh -c qemu:///system vol-create-as default fleet-robot_VARS.fd "$size" --format raw
virsh -c qemu:///system vol-upload --pool default fleet-robot_VARS.fd /usr/share/OVMF/OVMF_VARS_4M.fd

# 3. Start the edge server, then the blank robot.
vagrant up edge
vagrant up robot
virsh -c qemu:///system console 07-pxe-provisioning_robot
```

The robot needs no internet. Its only network is the install network the edge
server sits on.

Notes from the first run:

- With rootless Docker, `kas-container` needs an exclusive `KAS_WORK_DIR`
  (it takes ownership of the directory), which is why it is not the checkout.
- The edge server gets its files by rsync, not 9p. A private home directory
  (mode 700) stops the libvirt QEMU user from reading a 9p share.
- To run the install again, `vagrant destroy -f robot`, upload a fresh
  `OVMF_VARS_4M.fd` over `fleet-robot_VARS.fd`, and `vagrant up robot`.
  After a rebuild, `vagrant rsync edge && vagrant provision edge` publishes it.

## What the run should show

1. The robot's firmware asks for DHCP; the edge server answers with iPXE.
2. iPXE asks again, receives `boot.ipxe`, and loads the installer over HTTP.
3. The installer writes the image with `bmaptool`, removes the network boot
   entries from the firmware, adds one for the disk, and reboots.
4. The second start goes to the disk and does not touch the network.

The robot VM is set up the way a real robot would be: disk first, network
second. A blank disk makes the firmware fall through to the network. Putting
the network first would not work in libvirt, because libvirt regenerates the
boot order from its own settings at every start and `efibootmgr` could not
change it.

## What this does not prove

- Real firmware. QEMU's OVMF behaves like many UEFI implementations, but a
  vendor board may re-add network boot entries or ignore the boot order.
- Secure Boot. The boot chain here is unsigned. Signing it is a later step.
- Authenticated images. The installer checks the block checksums in the bmap
  file, which catches corruption. It does not yet check who produced the image.

## Results

Observed on 2026-11-09 with the images built from this directory:

- The blank robot got an address and iPXE from the edge server, fetched
  `boot.ipxe` over HTTP, and loaded the installer kernel and initramfs over
  HTTP.
- The installer got a DHCP lease, wrote the 31 MB `wic.gz` to `/dev/vda` with
  `bmaptool` (about 30 MiB/s, block checksums checked), removed the network
  entries from the firmware, added a `fleet-robot` disk entry, and rebooted.
- The second start loaded `fleet-robot` from the disk, reached the login
  prompt of the Yocto image, and did not touch the network. A further reset
  behaved the same.

Not tested: real hardware, Secure Boot, a corrupted or substituted image
(the bmap checksums cover corruption in transit only), and a robot that has
the wrong disk layout.
