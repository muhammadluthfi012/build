#!/bin/bash
# ==========================================
# Build SiYunOS ISO (based on Void Linux XFCE)
# ==========================================

set -e

ISO_NAME="siyunos-xfce.iso"
WORKDIR="$HOME/siyunos-build"
LIVE_DIR="$WORKDIR/live"
ISO_DIR="$WORKDIR/iso"

echo "[*] Install dependencies..."
sudo xbps-install -Sy git make ncurses-devel dialog \
  squashfs-tools xorriso syslinux dracut

echo "[*] Update /etc/os-release branding..."
sudo tee /etc/os-release > /dev/null <<EOF
NAME="SiYunOS"
ID=siyunos
ID_LIKE=void
PRETTY_NAME="SiYunOS (Void based)"
VERSION="1.0"
EOF

echo "[*] Create live user..."
if ! id live &>/dev/null; then
  sudo useradd -m -s /bin/bash live
  echo "live:live" | sudo chpasswd
fi

echo "[*] Configure LightDM autologin..."
sudo tee /etc/lightdm/lightdm.conf > /dev/null <<EOF
[Seat:*]
autologin-user=live
EOF

echo "[*] Prepare build directories..."
rm -rf "$WORKDIR"
mkdir -p "$LIVE_DIR" "$ISO_DIR/boot/isolinux"

echo "[*] Build rootfs.squashfs (excluding boot + old home)..."
sudo mksquashfs / "$LIVE_DIR/rootfs.squashfs" \
  -e boot home/$USER

echo "[*] Copy kernel and initrd..."
KERNEL=$(ls /boot/vmlinuz-* | head -n1)
INITRD=$(ls /boot/initramfs-* | head -n1)
cp "$KERNEL" "$LIVE_DIR/vmlinuz"
cp "$INITRD" "$LIVE_DIR/initrd"

echo "[*] Copy to ISO structure..."
cp "$LIVE_DIR"/* "$ISO_DIR/boot/"

echo "[*] Copy syslinux bootloader..."
cp /usr/share/syslinux/isolinux.bin "$ISO_DIR/boot/isolinux/"
cp /usr/share/syslinux/ldlinux.c32 "$ISO_DIR/boot/isolinux/"
cp /usr/share/syslinux/menu.c32 "$ISO_DIR/boot/isolinux/"

echo "[*] Create isolinux.cfg..."
cat > "$ISO_DIR/boot/isolinux/isolinux.cfg" <<EOF
UI menu.c32
PROMPT 0
TIMEOUT 50
DEFAULT siyunos

LABEL siyunos
    MENU LABEL Boot SiYunOS XFCE (Live)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initrd boot=live
EOF

echo "[*] Build ISO image..."
xorriso -as mkisofs \
  -o "$HOME/$ISO_NAME" \
  -b boot/isolinux/isolinux.bin \
  -c boot/isolinux/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  "$ISO_DIR"

echo "[+] Done!"
echo "ISO created: $HOME/$ISO_NAME"
