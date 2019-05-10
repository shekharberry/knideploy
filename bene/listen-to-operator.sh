#!/bin/bash
p=$( oc -n rook-ceph-system get pods | grep operator | awk '{ print $1}' )
oc -n rook-ceph-system logs -f $p

