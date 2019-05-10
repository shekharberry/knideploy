#!/bin/bash -x
# Elko's magic incantation
# fix provisioner to use rook-ceph namespace for secret??
# this assumes that we are above the git repo "external-storage"
# see Elko's description of what steps are needed here:
#  https://mojo.redhat.com/docs/DOC-1189365

NOTOK=1
OK=0

# must be run from wherever the rook YAMLs are
if [ ! -f common-modified.yaml ] ; then exit 1 ; fi

ocrc="oc -n $ROOK_CEPH_NAMESPACE"
toolpod=$($ocrc get pods | awk '/tools/{print $1}')
$ocrc delete secret/ceph-secret-admin
$ocrc rsh $toolpod bash -c 'ceph auth get-key client.admin' > /tmp/cephfs.key && \
$ocrc create secret generic ceph-secret-admin --from-file=/tmp/cephfs.key
if [ $? != $OK ] ; then 
  echo "ERROR: failed to create secret"
  exit $NOTOK
fi
if [ ! -d external-storage ] ; then
	git clone https://github.com/openshift/external-storage
else
	(cd external-storage ; git pull)
fi
cd external-storage/ceph/cephfs/deploy || exit $NOTOK
sed -r -i "s/namespace: [^ ]+/namespace: $ROOK_CEPH_NAMESPACE/g" rbac/*.yaml
# this step may fail if things already exist, check error message
oc delete -f ./rbac
oc create -f ./rbac
oc adm policy add-scc-to-user anyuid -z cephfs-provisioner

mon_ips=( $( $ocrc get pods -o wide | awk '/ceph-mon/{print $6}' ) )
mon_ip_port_list=$(echo ${mon_ips[0]}:6789,${mon_ips[1]}:6789,${mon_ips[2]}:6789)
classfn=~/cephfs-storageclass.yaml
cat > $classfn <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: cephfs
  namespace: $ROOK_CEPH_NAMESPACE
provisioner: ceph.com/cephfs
parameters:
    monitors: $mon_ip_port_list
    adminId: admin
    adminSecretName: ceph-secret-admin
    adminSecretNamespace: "$ROOK_CEPH_NAMESPACE"
    claimRoot: /pvc-volumes
EOF
cat $classfn
$ocrc delete sc/cephfs
oc create -f $classfn

