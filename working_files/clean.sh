cd ~/dev-scripts
make clean
rm -rf ~/.cache /tmp/* ~/go/src/github.com/* /opt/dev-scripts/* /var/lib/containers/*
yum reinstall -y podman
