#!/bin/sh

### first check some things

if [ "$1" = "" ] || [ "$2" = "" ]
then
  echo 'Usage: wufik.sh windows_install.iso /dev/usb_drive'
  exit 1
fi

iso="$1"
usb="$2"

if [ ! -e "$iso" ]
then
  echo "Error: file $iso does not exist."
  exit 1
fi

if [ ! -e "$usb" ]
then
  echo "Error: drive $usb does not exist."
  exit 1
fi

if [ "$(mount | grep $usb)" ]
then
  echo "Error: drive $usb is mounted."
  exit 1
fi

if [ "$(id -u)" != "0" ]
then
  echo 'You must have root privileges to use this.'
  exit 1
fi

isosize=$(ls -l "$iso" | cut -d' ' -f5)
usbsize=$(fdisk -l "$usb" | head -1 | cut -d' ' -f5)
if [ $usbsize -lt $(($isosize+100*1024*1024)) ]
then
  echo "Error: file in size $isosize will not fit on this drive in size $usbsize."
  exit 1
fi

if [ ! $(which grub-install) ]
then
  if [ $(which grub2-install) ]
  then
    alias grub-install=grub2-install
  else
    echo 'Error: can not find grub-install or grub2-install'
    exit 1
  fi
fi

### part a drive

(echo o; echo n; echo ""; echo ""; echo ""; echo "+100M"; echo a;
 echo n; echo ""; echo ""; echo ""; echo ""; echo t; echo 2; echo 7;
 echo p; echo w) | fdisk $usb > /dev/null

### format partitions

echo 'Formatting target device...'
yes | mkfs.ext3 -q "$usb"1
mkfs.ntfs -f -q "$usb"2

mkdir -p /mnt/usb /mnt/iso

### install grub2 bootloader

mount "$usb"1 /mnt/usb

echo 'Installing GRUB2...'
grub-install --target=i386-pc --boot-directory=/mnt/usb $usb

echo 'menuentry "Windows installation" {
  set root=(hd0,msdos2)
  ntldr /bootmgr
  boot
}' > /mnt/usb/$(ls /mnt/usb/ | grep grub)/grub.cfg

umount /mnt/usb

### finally copy installation files with percentage showing

mount "$usb"2 /mnt/usb
mount -o ro "$iso"  /mnt/iso
echo -n 'Copying Windows installation files '
(while [ "$(ps | grep cp)" ] 
do 
  pr=$(($(df /mnt/usb | tail -1 | tr -s $' ' | cut -d' ' -f 3)*1008*100/$isosize))
  tput sc
  if [ $pr -lt 99 ]
  then
    echo -n "$pr% "
  else
    echo -n '99% '
  fi
  sleep 2
  tput rc
done) &
cp -r /mnt/iso/* /mnt/usb
sync
echo '100%'

umount /mnt/usb /mnt/iso
rmdir  /mnt/usb /mnt/iso

echo 'Drive is ready to be used.'
