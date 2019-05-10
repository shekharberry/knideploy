#!/bin/bash -x
oc -n openshift-storage patch cephclusters.ceph.rook.io rook-ceph \
  -p '{"metadata":{"finalizers": []}}' --type=merge

