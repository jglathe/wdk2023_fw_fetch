#!/bin/bash

# The target firmware path
source_path="/mnt/Windows/System32/DriverStore/FileRepository"
target_fw_path="/lib/firmware/qcom/sc8280xp/MICROSOFT/DEVKIT23/"
# Flag to do a reboot (via systemd) and disable its own service, needed only once
do_disable_reboot=1

# Step 1: Find the NTFS partition(s) on /dev/nvme0n1
partitions=$(lsblk -f -o NAME,FSTYPE | grep -w "ntfs" | grep "nvme0n1" | while read -r name fstype; do echo "/dev/"$(echo ${name} | sed 's/^.*─//;q'); done)

# Step 2: Mount each NTFS partition and verify if it is a Windows installation
for partition in $partitions
do
    mount -t ntfs-3g $partition /mnt/
    if ls "$source_path" > /dev/null 2>&1; then
        echo "Found the Windows installation on $partition."
        break
    else
        umount /mnt/
    fi
done

# Step 3: Locate directories where *8280.mbn files exist and iterate over each unique file
mbn_files=$(find $source_path -name '*8280.mbn' -exec readlink -f {} \; | sort -u)
mbn_paths=()
for file in $mbn_files; do
    dir=$(dirname "$file")
    name=$(basename "$file")
    timestamp=$(stat -c %Y "$file")
    mbn_paths+=("$dir,$name,$timestamp")
done

sorted_mbn_paths=($(printf "%s\n" "${mbn_paths[@]}" | sort -t ',' -k3 -rn))

unique_mbn_paths=()
seen_names=()
for path in "${sorted_mbn_paths[@]}"; do
    name=$(echo "$path" | cut -d',' -f2)
    if [[ ! " ${seen_names[@]} " =~ " $name " ]]; then
        unique_mbn_paths+=("$path")
        seen_names+=("$name")
    fi
done

# reduce to directories (by driver)
unique_dirs=()
seen_dirs=()
for path in "${unique_mbn_paths[@]}"; do
    dir=$(echo "$path" | cut -d',' -f1)
    if [[ ! " ${seen_dirs[@]} " =~ " $dir " ]]; then
        unique_dirs+=("$dir")
        seen_dirs+=("$dir")
    fi
done

# Step 4: Copy the newest *8280.mbn file including *.jsn files to the target library path
for dir in "${unique_dirs[@]}"; do
    cp "$dir"/*.mbn "$target_fw_path"
    # Check if *.jsn files exist in the directory before copying them
    if ls "$dir"/*.jsn > /dev/null 2>&1; then
        cp "$dir"/*.jsn "$target_fw_path"
    fi
done

# Unmount the partition
umount /mnt/

# List the contents of $target_fw_path
echo "Contents of $target_fw_path:"
ls -l "$target_fw_path"

# update initramfs
echo "Updating initramfs"
/usr/sbin/update-initramfs -u -k all

# disable the fetcher in systemd
if [ $do_disable_reboot -eq 1 ]; then
    /usr/bin/systemctl disable copy_firmware.service
fi

