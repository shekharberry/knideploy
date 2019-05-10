#!/bin/bash -x 
p=$( oc -n $ROOK_CEPH_NAMESPACE get pods | grep tool | awk '{ print $1 }' )
oc -n $ROOK_CEPH_NAMESPACE rsh $p $*
