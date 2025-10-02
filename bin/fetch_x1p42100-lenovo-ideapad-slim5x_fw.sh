#!/bin/bash

# The target firmware path
target_fw_path="/usr/lib/firmware/updates/qcom/x1p42100/LENOVO/83HL/"
# Flag to do a reboot (via systemd) and disable its own service, needed only once
do_disable_reboot=0

# Find the unlocked Windows NTFS device by label
windows_dev=$(lsblk -p -o PATH,FSTYPE,LABEL | grep -w "ntfs" | grep "Windows" | awk '{print $1}')
if [ -z "$windows_dev" ]; then
    echo "Windows partition not found or not unlocked. Please unlock the BitLocker partition first."
    exit 1
fi
# Find if it's already mounted, get the mount point
mount_point=$(lsblk -o MOUNTPOINTS,PATH | grep "${windows_dev}" | awk '{print $1}')
unmount_at_end=false
if [ -z "$mount_point" ]; then
# Not mounted, mount it to /mnt
    mkdir -p /mnt
    mount -t ntfs-3g "$windows_dev" /mnt/
    if [ $? -ne 0 ]; then
        echo "Failed to mount $windows_dev to /mnt."
        exit 1
        fi
    base_mount="/mnt"
    unmount_at_end=true
else
# Already mounted, use existing mount point
    base_mount="$mount_point"
fi
# Set source_path based on the base mount
source_path="$base_mount/Windows/System32/DriverStore/FileRepository"
# Verify if it's a Windows installation
if ! ls "$source_path" > /dev/null 2>&1; then
    echo "Source path not found on $windows_dev. This may not be the correct Windows partition."
    if [ "$unmount_at_end" = true ]; then
        umount /mnt/
    fi
    exit 1
fi
echo "Found the Windows installation on $windows_dev, using mount point $base_mount."

# Step 3: Locate directories where *8380.mbn files exist and iterate over each unique file
mbn_files=$(find $source_path -name '*8380.mbn' -exec readlink -f {} \; | sort -u)
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

# Step 4: Copy the newest *8380.mbn file including *.jsn and *.elf files to the target library path
mkdir -p "$target_fw_path"
for dir in "${unique_dirs[@]}"; do
    cp "$dir"/*.mbn "$target_fw_path"
    # Check if *.jsn files exist in the directory before copying them
    if ls "$dir"/*.jsn > /dev/null 2>&1; then
        cp "$dir"/*.jsn "$target_fw_path"
    fi
    # Check if *.elf files exist in the directory before copying them
    if ls "$dir"/*.elf > /dev/null 2>&1; then
        cp "$dir"/*.elf "$target_fw_path"
    fi
done

# Unmount the partition if mounted by us
if [ "$unmount_at_end" = true ]; then
    umount /mnt/
fi

# List the contents of $target_fw_path
echo "Contents of $target_fw_path:"
ls -l "$target_fw_path"

# disable adsp for the odd fuckery it does when not loaded from initramfs
# mv "$target_fw_path"qcadsp8380.mbn "$target_fw_path"qcadsp8380.mbn.disabled

# update initramfs
# echo "Updating initramfs"
/usr/sbin/update-initramfs -u -k all

# disable the fetcher in systemd
if [ $do_disable_reboot -eq 1 ]; then
    /usr/bin/systemctl disable copy_firmware.service
fi

