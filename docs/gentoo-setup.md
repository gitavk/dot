# Gentoo minimal install → bspwm desktop (replay HowTo)

Target: minimal Gentoo (OpenRC) → SSH → bspwm + sxhkd + alacritty + zellij +
neovim + firefox, dotfiles via GNU Stow. Written from a real install on a
Pentium Silver N5030 / 8GB RAM box; adjust sizing notes for a beefier machine
(Core i7 / 32GB — you can be more generous with MAKEOPTS and swap, and you
may not need `getbinpkg` as much, but it's still recommended for firefox).

Replace every `sdX` / UUID / hostname / username below with your real values.

---

## 0. Before you start

From a live/minimal ISO, gather:

```bash
lscpu | head -20          # cores, microarch → MAKEOPTS, -march
ls /sys/firmware/efi      # exists = UEFI; also check fw_platform_size (want 64)
lsblk                     # disk name: sda / nvme0n1
ip link                   # NIC name
```

Prefer wired ethernet for the install; Wi-Fi setup comes later, from the
running system, via ssh — much less painful than fighting wpa on the laptop
keyboard.

## 1. SSH into the live environment

```bash
passwd                      # temp password for this live session
rc-service sshd start
grep -i permitrootlogin /etc/ssh/sshd_config   # fix to 'yes' if needed
ip -4 addr show
```

From your main machine: `ssh root@<live-ip>`. Run `tmux` on the remote side
so a flaky connection doesn't kill a long emerge.

## 2. Partitioning

Adjust to your actual layout — reusing an existing ESP and leaving a
`/home` partition untouched (from a previous install) is fine; GPT doesn't
care about a gap in partition numbering.

```bash
parted -a optimal /dev/sdX
  mklabel gpt
  mkpart ESP fat32 1MiB 513MiB
  set 1 esp on
  mkpart swap linux-swap 513MiB 16.5GiB   # or skip: use a swapfile instead
  mkpart root ext4 16.5GiB 100%
  quit

mkfs.vfat -F32 /dev/sdX1        # only if ESP is new — NEVER reformat an
                                 # existing ESP that other bootloaders use
mkfs.ext4 -L gentoo-root /dev/sdX3
```

If reusing an old `/home` partition: **do not format it.** Just mount it.

```bash
mount /dev/sdX3 /mnt/gentoo
mkdir -p /mnt/gentoo/efi /mnt/gentoo/home
mount /dev/sdX1 /mnt/gentoo/efi
mount /dev/sdX4 /mnt/gentoo/home   # only if reusing an old /home
```

### Swap

A real swap partition is simplest if you have the space. Otherwise a
swapfile works identically for our purposes:

```bash
mkdir -p /mnt/gentoo/home/.swap
fallocate -l 12G /mnt/gentoo/home/.swap/swapfile   # bump on low-RAM boxes
chmod 600 /mnt/gentoo/home/.swap/swapfile
mkswap /mnt/gentoo/home/.swap/swapfile
swapon /mnt/gentoo/home/.swap/swapfile
```

On the 32GB machine you can size this much smaller (or skip a swapfile
entirely) — swap here was mainly insurance against OOM during linking on
the 8GB box.

## 3. stage3

No installer — you unpack a base-system tarball by hand. From
https://www.gentoo.org/downloads/ → **amd64** → **Stage archives** → grab
**`Stage openrc`** (NOT systemd, NOT desktop-profile).

```bash
cd /mnt/gentoo
wget <stage3-amd64-openrc-*.tar.xz URL>
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz
```

## 4. make.conf

`/mnt/gentoo/etc/portage/make.conf` — replace entirely:

```bash
COMMON_FLAGS="-O2 -pipe -march=native"     # or an explicit -march name
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

MAKEOPTS="-j$(nproc) -l$(nproc)"           # tune down on low-RAM boxes

USE="X -wayland -systemd -kde -gnome -qt5 -qt6 pulseaudio dbus elogind"
VIDEO_CARDS="intel"                        # or amdgpu / nvidia as appropriate
INPUT_DEVICES="libinput"
ACCEPT_LICENSE="*"
GENTOO_MIRRORS="https://distfiles.gentoo.org"

PORTAGE_TMPDIR="/home/.portage-tmp"        # keep big build dirs off root
FEATURES="getbinpkg"
EMERGE_DEFAULT_OPTS="--binpkg-respect-use=y --keep-going"

LC_MESSAGES=C.utf8
```

**`GENTOO_MIRRORS` gotcha:** not every mirror listed on the Gentoo site
actually carries the `snapshots/` tree — `emerge-webrsync` will 404 loop
through dates otherwise. `https://distfiles.gentoo.org` always works;
`https://ftp.gwdg.de/pub/linux/gentoo/` is a solid EU fallback.

**`getbinpkg` is the single biggest time-saver** on slow hardware — the
official binary host covers most of the stack (rust, llvm, gcc-built
packages, etc). Even on a fast machine, keep it on; it just means faster
installs and less local build time for anything without unusual USE flags.

## 5. Enter chroot

```bash
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys  && mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev  && mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run   && mount --make-slave /mnt/gentoo/run

chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"
ping -c2 gentoo.org   # confirm DNS/network survived the chroot
```

## 6. Portage tree, keys, profile

```bash
emerge-webrsync
getuto                          # binpkg signing keys
eselect profile list
eselect profile set <N>         # plain default/linux/amd64/23.0, NOT desktop
```

## 7. Timezone & locale

```bash
ln -sf ../usr/share/zoneinfo/<Region>/<City> /etc/localtime
nano /etc/locale.gen
# uncomment, WITH explicit encoding:
#   en_US.UTF-8 UTF-8
#   ru_RU.UTF-8 UTF-8
locale-gen
eselect locale list
eselect locale set <N>          # en_US.utf8 recommended for system locale —
                                 # error messages google better in English
env-update && source /etc/profile
```

## 8. Update @world for the new USE flags

```bash
emerge --ask --verbose --update --deep --newuse @world
```

Check the plan: most lines should say `[binary ...]`. If everything shows
`[ebuild]`, something's off with `getbinpkg` / keys — fix before letting a
huge compile run unattended. Use `emerge -p <pkg>` (pretend) any time you
want to preview a plan without `--ask` triggering a real merge.

## 9. Kernel

```bash
mkdir -p /etc/portage/package.use
echo "sys-kernel/installkernel dracut grub" >> /etc/portage/package.use/kernel
emerge sys-kernel/installkernel
emerge sys-kernel/gentoo-kernel-bin sys-kernel/linux-firmware
emerge sys-firmware/intel-microcode      # or amd equivalent
emerge sys-firmware/sof-firmware         # only needed for SOF-based audio
                                          # (common on recent Intel laptops;
                                          # skip on unrelated hardware)
```

`gentoo-kernel-bin` = prebuilt kernel with a sane distro config. Build your
own later, from the running system, where a bad config doesn't mean a trip
to grab the install media again. `installkernel` with `dracut grub` USE
auto-generates initramfs and updates the GRUB config on every kernel merge.

Verify:

```bash
ls -lh /boot        # expect vmlinuz-*, initramfs-*, microcode img(s)
```

## 10. fstab, hostname, root password, user

```bash
blkid                                   # get real UUIDs — don't reuse old
                                         # ones if you reformatted the
                                         # partition, they change!
nano /etc/fstab
```

```
UUID=<root-uuid>   /      ext4  defaults,noatime  0 1
UUID=<esp-uuid>    /efi   vfat  defaults,noatime  0 2
UUID=<home-uuid>   /home  ext4  defaults,noatime  0 2
/home/.swap/swapfile none swap sw                 0 0
```

Order matters if the swapfile lives under `/home`: `/home` must mount
before the swap line is processed (fstab is read top-to-bottom).

```bash
echo "<hostname>" > /etc/hostname
passwd                                  # root password for the INSTALLED
                                         # system (not the live one)

useradd -m -G users,wheel,audio,video,input -s /bin/bash <username>
passwd <username>
id <username>                           # confirm uid/gid match an old
                                         # /home if you're reusing one
```

## 11. Network + SSH in the new system

```bash
emerge net-misc/dhcpcd
rc-update add dhcpcd default
rc-update add sshd default
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
rc-update show default        # sanity-check: dhcpcd + sshd must be listed
```

This is the single most important check before rebooting — miss it and the
system boots fine but silently locks you out.

## 12. Bootloader (UEFI/GRUB)

```bash
emerge sys-boot/grub sys-boot/efibootmgr
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=gentoo
grub-mkconfig -o /boot/grub/grub.cfg
```

Check the `grub-mkconfig` output for a `Found linux image: ...` line before
rebooting. `--bootloader-id=gentoo` matters if the ESP is shared with
another distro's bootloader (see troubleshooting below).

## 13. Exit and reboot

```bash
exit
cd
swapoff -a               # if umount complains the swapfile keeps /home busy
umount -R /mnt/gentoo
reboot
```

Remove install media before it comes back up.

---

## First-boot checklist (X11 / bspwm stack)

```bash
# Xorg + driver + fonts
emerge x11-base/xorg-server x11-apps/xinit x11-apps/xrandr x11-apps/setxkbmap
emerge x11-drivers/xf86-video-intel      # or the right driver for your GPU
emerge media-fonts/dejavu media-fonts/noto media-fonts/terminus-font

# wm stack
emerge x11-wm/bspwm x11-misc/sxhkd x11-terms/alacritty
emerge x11-misc/polybar x11-misc/rofi
```

**elogind/dbus must be enabled**, or Xorg fails with
`parse_vt_settings: Cannot open /dev/tty0 (Permission denied)`:

```bash
rc-update add dbus default
rc-update add elogind boot
rc-service dbus start
rc-service elogind start
```

Then **log out and back in on the local tty** (not ssh) so elogind creates
a session and hands over VT permissions. Verify with `loginctl`.

**Common freetype/USE conflict:** installing things like `rofi` may fail
with `no ebuilds built with USE flags to satisfy ...[harfbuzz]` because a
prebuilt `pango` binpkg expects a specific freetype build:

```bash
echo "media-libs/freetype harfbuzz" >> /etc/portage/package.use/freetype
```

**polybar's `internal/network` module silently missing:** the binary
package ships without the `network` USE flag by default:

```bash
echo "x11-misc/polybar network ipc" >> /etc/portage/package.use/polybar
emerge polybar
```

Then start X:

```bash
startx     # from ~/.xinitrc
```

## Firefox

```bash
emerge www-client/firefox-bin
```

Prefer `-bin` over `www-client/firefox` unless you specifically need a
from-source build — the official Mozilla binary avoids pulling in USE-flag
mismatches (e.g. `ffmpeg[postproc]`) that force long from-source builds for
transitive deps. To get a non-English UI:

```bash
echo "www-client/firefox-bin L10N: ru" >> /etc/portage/package.use/firefox
```

## Wi-Fi (iwd)

```bash
emerge net-wireless/iwd
rc-update add iwd default
rc-service iwd start

iwctl device list
iwctl station wlan0 scan
iwctl station wlan0 get-networks
iwctl station wlan0 connect "<SSID>"
ip -4 addr show wlan0     # dhcpcd (already in `default`) picks it up
```

## neovim + zellij + tooling

```bash
emerge app-editors/neovim
emerge app-shells/fzf sys-apps/ripgrep net-libs/nodejs

# zellij is often keyworded ~amd64 only (testing) — unmask explicitly:
echo "app-misc/zellij ~amd64" >> /etc/portage/package.accept_keywords/zellij
emerge app-misc/zellij     # builds from source (Rust) — 15-30min on slow HW
```

If using a lazy.nvim config from a separate repo:

```bash
git clone <your-nvim-config-repo> ~/.config/nvim
nvim   # let lazy.nvim sync plugins on first run
```

**Plugin API drift is common** with fast-moving plugins on a fresh Neovim.
Two we hit:
- `mason-lspconfig` v2 removed `setup_handlers()` — handlers now go inside
  `.setup({ handlers = {...} })`.
- `nvim-treesitter` `main` branch dropped the `nvim-treesitter.configs`
  module entirely — highlighting/folding are now wired manually via
  `vim.treesitter.start()` and `vim.treesitter.foldexpr()` in a
  `FileType` autocmd, not a single `.setup()` call.

## bash-completion

```bash
emerge app-shells/bash-completion
exec bash
```

(Your `.bashrc` needs to already source
`/usr/share/bash-completion/bash_completion` — check before assuming it's
missing.)

## Dotfiles via GNU Stow

```bash
emerge app-admin/stow
git clone <your-dotfiles-repo> ~/dotfiles
cd ~/dotfiles/stow
stow -t ~ bspwm sxhkd alacritty polybar rofi zellij bash git x11
```

Each folder under `stow/` mirrors its target path relative to `$HOME`
(e.g. `stow/bspwm/.config/bspwm/...`). Add a new config → drop it in the
right package → `stow -t ~ <package>` → commit. No manual `ln -s` ever
again. See the dotfiles repo's own README for the full package list.

---

## Troubleshooting notes worth remembering

- **UEFI boots the wrong OS by default (old bootloader picked up):** check
  `efibootmgr -v`, reorder with `efibootmgr -o <gentoo-id>,<rest>`, and
  optionally delete stale entries with `efibootmgr -b <id> -B`.
- **`grub>` prompt instead of a menu:** firmware launched a leftover
  bootloader from another distro whose config no longer matches your disk.
  Fix the EFI boot order (above) rather than fighting it manually every
  boot.
- **Reformatted a partition → old UUID in fstab is stale:** always
  `blkid` again after `mkfs`, never reuse a UUID from before a format.
- **`umount` says target busy on `/home`:** almost always the swapfile
  living there is still active — `swapoff -a` first.
- **fstab / build-dir sizing on a small root partition:** point
  `PORTAGE_TMPDIR` at a roomier filesystem (e.g. `/home/.portage-tmp`) if
  root is under ~30GB — a single from-source build (browser, big Rust
  project) can easily need 15-20GB of scratch space.
