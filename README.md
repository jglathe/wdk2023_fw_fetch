# Firmware for the Windows Dev Kit 2023

This script is used to find and copy firmware files for the Windows Dev Kit 2023 to the ```/lib/firmware/qcom/sc8280xp/MICROSOFT/DEVKIT23/``` path for use with the linux kernel. Most of the required firmware already is in the linux-firmare package, these are not. They are also signed in a way that they only run on the Windows Dev Kit 2023.

## Usage

The intended use is in a bootable Ubuntu 23.04 desktop image that can be found [here](https://drive.google.com/drive/folders/1sc_CpqOMTJNljfvRyLG-xdwB0yduje_O?usp=sharing) It boots from USB, searches the local nvme ssd, copies the files and reboots. After reboot the Ubuntu Ubiquity installer comes up and you can proceed with the setup.

## Prerequisites

To boot from USB with the Windows Dev Kit 2023, you need to enter the UEFI setup from Windows (no, there is no other way), disable secure boot, and add USB as boot source. To actually fetch the files from the ntfs partition from USB boot, you also need to decrypt it by disabling bitlocker. If you don't want to do this, I would suggest to copy the files directly in Windows, and add them after booting the Linux stick. It will come up without them, but certain subsystems of the SC8280XP SoC will not work. 

## Acknowledgements

I can't do bash, nor can I do systemd. I have used ChatGPT via phind.com, it was quite fun. Thanks to @qzed for giving me the idea. 
