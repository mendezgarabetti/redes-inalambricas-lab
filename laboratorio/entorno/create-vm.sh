#!/bin/bash
VM_NAME=$1
NET1=$2
NET2=$3
MAC1=$4

if [ -z "$VM_NAME" ]; then
    echo "Usage: $0 <vm_name> <network1> [network2] [mac1]"
    exit 1
fi

mkdir -p vm-data/$VM_NAME

cat <<EOF > vm-data/$VM_NAME/user-data
#cloud-config
ssh_authorized_keys:
  - "$(cat lab_key.pub)"
chpasswd:
  list: |
    root:root
    student:student
  expire: False
users:
  - name: student
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    ssh_authorized_keys:
      - "$(cat lab_key.pub)"
runcmd:
  - apt-get update
  - DEBIAN_FRONTEND=noninteractive apt-get install -y dnsmasq tcpdump curl dnsutils iproute2 nftables qemu-guest-agent
  - systemctl enable --now qemu-guest-agent
EOF

cat <<EOF > vm-data/$VM_NAME/meta-data
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF

cat <<EOF > vm-data/$VM_NAME/network-config
version: 2
ethernets:
  enp1s0:
    dhcp4: true
  enp2s0:
    dhcp4: false
EOF

xorriso -as mkisofs -R -V cidata -o vm-data/$VM_NAME/seed.iso vm-data/$VM_NAME/user-data vm-data/$VM_NAME/meta-data vm-data/$VM_NAME/network-config >/dev/null 2>&1

cp debian-12-nocloud-amd64.qcow2 vm-data/$VM_NAME/disk.qcow2
qemu-img resize vm-data/$VM_NAME/disk.qcow2 10G >/dev/null 2>&1

CMD="virt-install --name $VM_NAME --memory 1024 --vcpus 1 \
  --disk vm-data/$VM_NAME/disk.qcow2,device=disk,bus=virtio \
  --disk vm-data/$VM_NAME/seed.iso,device=cdrom \
  --os-variant debian12 \
  --import --noautoconsole"

if [ -n "$NET1" ]; then
    if [ -n "$MAC1" ]; then
        CMD="$CMD --network network=$NET1,mac=$MAC1"
    else
        CMD="$CMD --network network=$NET1"
    fi
fi

if [ -n "$NET2" ]; then
    CMD="$CMD --network network=$NET2"
fi

eval $CMD
