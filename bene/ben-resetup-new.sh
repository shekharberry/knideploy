#!/bin/bash -x
# synchronized with pull of rook.io from github on April 20
### MUST BE RUN FROM DIRECTORY CONTAINING YAMLS ###
NS=${ROOK_CEPH_NAMESPACE:-"openshift-storage"}

# clean up any workloads that are running first

oc delete namespace smallfile

fiopods=$(oc -n $NS get pods | awk '/fio-pod/{print $1}')
for f in $fiopods ; do oc -n $NS delete pod/$f ; done

pvcs=$(oc -n $NS get pvc | awk '/^pvc/{print $1}')
for p in $pvcs ; do oc -n $NS delete pvc/$p ; done
oc wait --for condition=delete pod -l app=fio -n $NS --timeout=60s
oc delete -f filesystem-modified.yaml
oc wait --for condition=delete pod -l app=rook-ceph-mds -n $NS --timeout=60s
oc delete -f toolbox-modified.yaml
oc delete -f cluster-modified.yaml
sleep 10
(oc -n $NS | grep ceph-mon) && exit 1
oc delete -f operator-openshift-modified.yaml
oc delete -f common-modified.yaml
sleep 4
oc delete namespace $NS
oc -n $NS get pods 2>&1 | grep -q 'No resources' || exit 1
nodes=$(oc get nodes -o yaml | awk '/address: 192/{ print $NF }')
(echo '[nodes]' ; for n in $nodes ; do echo $n ; done) > ~/ben.inv
a="ansible -i ~/ben.inv "
$a -u core -m script -a ~/bene/rm-var-lib-rook.sh nodes
$a -u core -m script -a ~/bene/zap-drives.sh nodes
if [ -n "$NO_RESTART" ] ; then 
  exit 0
fi
#oc create -f common-modified.yaml
#oc create -f operator-openshift-modified.yaml
#oc wait --for condition=ready  pod -l app=rook-ceph-operator -n openshift-storage --timeout=120s
#oc wait --for condition=ready  pod -l app=rook-ceph-agent -n openshift-storage --timeout=120s
#oc wait --for condition=ready  pod -l app=rook-discover -n openshift-storage --timeout=120s
#oc create -f cluster-modified.yaml
#oc wait --for condition=ready  pod -l app=rook-ceph-mon -n openshift-storage --timeout=120s
#oc create -f toolbox-modified.yaml
#oc create -f filesystem-modified.yaml
