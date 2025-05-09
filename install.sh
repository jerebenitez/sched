#!/bin/sh

set -e

echo "[*] Copying files..."
cp ./VMKERNEL4BSD /sys/amd64/conf/VMKERNEL4BSD
echo "[✔️] Kernel config for VMs"


