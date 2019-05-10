#!/bin/bash -x
make clean
rm -rf ~/.cache /tmp/* ~/go/src/github.com/* /opt/dev-scripts/* /var/lib/containers/*
yum reinstall podman -y
echo 'press RETURN to rebuild' 
read line
make
