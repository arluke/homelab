### Setup
0. Set vars
```
ROOTDISK=/dev/disk/by-id/nvme-WD_BLACK_SN770_1TB_xxxxxxxxxxxx
DATADISK0=/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_xxxxxxxxxxxx
DATADISK1=/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_xxxxxxxxxxxx
NEWUSER=arluke
HOSTNAME=artemis
DOMAIN=
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
+ set hosts
+ set locale
+ chroot
```
pacstrap -K /mnt base base-devel btrfs-progs efibootmgr efitools gdisk intel-ucode kitty linux linux-firmware \
    linux-headers mdadm mesa neovim networkmanager openssh sbctl sbsigntools sudo systemd-ukify;
genfstab -U /mnt >> /mnt/etc/fstab;
printf '\nEDITOR=nvim' >> /mnt/etc/bash.bashrc;
printf "%h" $HOSTNAME > /mnt/etc/hostname;
printf "127.0.0.1        %h.%d    %h\n" $HOSTNAME $DOMAIN >> /etc/hosts;
printf "127.0.0.1        $HOSTNAME.$DOMAIN    $HOSTNAME\n" >> /etc/hosts;
printf "::1              $HOSTNAME.$DOMAIN    $HOSTNAME\n" >> /etc/hosts;
sed -i 's/#en_US.UTF-8/en_US.UTF-8/g' /mnt/etc/locale.gen;
arch-chroot /mnt;
```

Create Encryption Key for /dev/md/home
```
openssl genpkey -algorithm RSA -out /etc/cryptsetup-keys.d/data.pem;
cryptsetup luksAddKey /dev/mapper/data -S 30 /etc/cryptsetup-keys.d/data.pem;
echo "data     UUID=$(blkid -s UUID -o value /dev/md/data)     /etc/cryptsetup-keys.d/data.pem     luks,discard,tries=3" > /etc/crypttab;
echo "UUID=$(blkid -s UUID -o value /dev/mapper/data)      /home     btrfs     rw,relatime,ssd,discard,space_cache=v2,subvol=/@home     0 0 >> /etc/fstab"
```


```
groupadd --gid 5001 ssh-users;
groupadd --gid 6000 arluke;
useradd --uid 6000 --gid 6000 --groups arluke,ssh-users,wheel --shell /bin/bash --home /home/arluke --create-home arluke;
printf "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00_wheel;
passwd arluke
```




