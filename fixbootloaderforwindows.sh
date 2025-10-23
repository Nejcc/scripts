#!/bin/bash

echo "==============================="
echo " ARCH LINUX GRUB RESTORATION (UEFI) "
echo "==============================="

# List partitions for user clarity
echo "🔍 Available disks/partitions:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

echo ""
read -p "👉 Enter your ROOT partition (e.g. /dev/nvme0n1p2 or /dev/sda2): " ROOTPART
read -p "👉 Enter your EFI partition (FAT32, e.g. /dev/nvme0n1p1 or /dev/sda1): " EFIPART

# Create mount point
echo "📁 Mounting root partition..."
mount $ROOTPART /mnt || { echo "❌ Failed to mount root partition"; exit 1; }

# Mount EFI
if [ -d /mnt/boot ]; then
  EFIDIR="/mnt/boot"
elif [ -d /mnt/boot/efi ]; then
  EFIDIR="/mnt/boot/efi"
else
  mkdir -p /mnt/boot
  EFIDIR="/mnt/boot"
fi

echo "📁 Mounting EFI partition..."
mount $EFIPART $EFIDIR || { echo "❌ Failed to mount EFI partition"; exit 1; }

echo "✅ Partitions mounted."
echo "-------------------------------"
echo "🏁 Entering chroot..."
arch-chroot /mnt /bin/bash <<EOF

echo "🖥 Installing GRUB for UEFI..."
grub-install --target=x86_64-efi --efi-directory=$EFIDIR --bootloader-id=Arch || exit 1

echo "🔄 Generating GRUB config..."
grub-mkconfig -o /boot/grub/grub.cfg

EOF

echo "✅ GRUB restored successfully."
echo "📦 Unmounting and rebooting..."

umount -R /mnt
echo "🔁 Rebooting in 5 seconds..."
sleep 5
reboot
