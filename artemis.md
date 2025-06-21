### Setup
0. Set vars
```
ROOTDISK=/dev/disk/by-id/nvme-WD_BLACK_SN770_1TB_xxxxxxxxxxxx
DATADISK0=/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_xxxxxxxxxxxx
DATADISK1=/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_xxxxxxxxxxxx
NEWUSER=arluke
HOSTNAME=artemis
```

### Disks
1. Partitions
```
sgdisk -t1:ef00 -n1:4096:+1GiB    ${ROOTDISK}
sgdisk -t1:8309 -n1:   0:+920GiB  ${ROOTDISK}
sgdisk -t1:fd00 -n1:4096:+3725GiB ${DATADISK_0}
sgdisk -t1:fd00 -n1:4096:+3725GiB ${DATADISK_1}
```
2. md RAID
```
mdadm --create /dev/md/data --level=mirror --raid-devices=2 ${DATADISK_0}-part1 ${DATADISK_1}-part1
```
3. Encrypt
```
cryptsetup luksFormat -v ${ROOTDISK}-part2
cryptsetup luksFormat -v /dev/md/data

cryptsetup luksOpen ${ROOTDISK}-part2 root
cryptsetup luksOpen /dev/md/data data
```
4. Format
```
mkfs.fat -F 32 ${ROOTDISK}-part1
mkfs.btrfs /dev/mapper/root
mkfs.btrfs /dev/mapper/data
```
5. Filesystem & Mounts
```
mount -o defaults,discard /dev/mapper/root /mnt && \
btrfs subvol create /mnt/@ && \
umount /mnt && \
mount -o defaults,discard,subvol=/@ /dev/mapper/root /mnt && \
mkdir -p /mnt/var/cache/pacman && \
btrfs subvol create /mnt/var/log /mnt/var/cache/pacman/pkg;

mount --mkdir -o defaults,discard /dev/mapper/data /mnt/home && \
btrfs subvol create /mnt/home/@home && \
umount /mnt/home && \
mount -o defaults,discard,subvol=/@home /dev/mapper/data /mnt/home;

mount --mkdir -o uid=0,gid=0,fmask=0077,dmask=0077,discard /dev/${ROOTDISK} /mnt/efi;
```
6. Swap
```
btrfs filesystem mkswapfile --size 32G /mnt/.swapfile && \
swapon /mnt/.swapfile;
```
### Pacstrap & Initial Config
+ Unpack base system and tools
+ Create fstab in new environment
+ set nvim as the default editor
+ set hostname
+ chroot
```
pacstrap -K /mnt base base-devel btrfs-progs efibootmgr efitools gdisk intel-ucode linux linux-firmware \
    linux-headers mdadm neovim networkmanager openssh sbctl sbsigntools sudo systemd-ukify;
genfstab -U /mnt >> /mnt/etc/fstab;
printf '\nEDITOR=nvim' >> /mnt/etc/bash.bashrc;
printf '${HOSTNAME}' > /mnt/etc/hostname;
arch-chroot /mnt;
```

Create Encryption Key for /dev/md/home
```
openssl genpkey -algorithm RSA -out /etc/cryptsetup-keys.d/data.pem;
cryptsetup luksAddKey /dev/mapper/data -S 30 /etc/cryptsetup-keys.d/data.pem;
echo "data     UUID=$(blkid -s UUID -o value /dev/mapper/data)     /etc/cryptsetup-keys.d/data.pem     luks,discard,tries=3" > /etc/crypttab";
echo "UUID=${uuid}     /home     btrfs     rw,relatime,ssd,discard,space_cache=v2,subvol=/@home     0 0 >> /etc/fstab"
```
