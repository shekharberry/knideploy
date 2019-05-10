#!/bin/bash
echo removing device mapper block devices for ceph
echo /dev/mapper/ceph-*
sudo ls /dev/mapper/ceph-* | xargs -I% -- sudo dmsetup remove %
sudo rm -rfv /dev/ceph-*
for d in /dev/nvme?n1 /dev/sd[b-z] ; do 
  echo "zapping $d"
  sudo sgdisk --zap-all $d
done
