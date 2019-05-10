#!/bin/bash -x
if [ -z "$1" ] ; then
	echo 'usage: run-smf-pods.sh "smf-parameters"'
	exit 1
fi
parameters="$1"
testlabel="$2"

OC="oc -n smallfile "
OCRC="oc -n $ROOK_CEPH_NAMESPACE"
# this will be list of IDs which we use to talk to workers
# someday this will be pod names but don't know how yet
worker_file=${POD_LIST:-$HOME/smf.pod.id.list}
pod_id=$( $OC get pod | awk '/smallfile-pod/{print $1}' | head -n 1 )
#
# drop cache
#
osds=$( $OCRC get pod | awk '/ceph-osd/{print $1}' | awk -F- '{printf "%s\n", $4}' )
mdss=$( $OCRC get pod | awk '/ceph-mds/{print $1}' | awk -F- '{printf "%s-%s\n", $4, $5}' )
toolpod=$( $OCRC get pod | awk '/tool/{print $1}')
for o in $osds ; do
	$OCRC rsh $toolpod ceph tell osd.$o cache drop
done
for m in $mdss ; do
	$OCRC rsh $toolpod ceph tell mds.$m cache drop
done

# initialize test driver pod

$OC rsh $pod_id rm -rf /tmp/result.json /mnt/cephfs/network_shared
$OC cp $worker_file $pod_id:/tmp/
#wc -l $worker_file

# run test , with option to skip pbench if you don't need it

sprm="--top /mnt/cephfs --launch-by-daemon Y --output-json /tmp/result.json --response-times Y"
sprm="$sprm --host-set /tmp/`basename $worker_file` $parameters"
if [ -z "$NO_PBENCH" ] ; then
  pbench-user-benchmark --sysinfo=none -C bensmf_${testlabel} -- $OC rsh $pod_id /smallfile/smallfile_cli.py $sprm
  pbench_dir=`ls -trd /var/lib/pbench-agent/pbench-user-benchmark_bensmf* | tail -1`
  ls $pbench_dir
else
  pbench_dir=/var/tmp/smf.`date +%Y-%m-%d-%H-%M`
  mkdir -pv $pbench_dir
  $OC rsh $pod_id /smallfile/smallfile_cli.py $sprm
fi
cp $worker_file $pbench_dir/
$OC cp  $pod_id:/tmp/result.json $pbench_dir/result.json
$OC rsh $pod_id find /mnt/cephfs/network_shared/ -name '*.tmp' -delete
$OC rsh $pod_id tar zcvf /tmp/network_shared.tgz /mnt/cephfs/network_shared
$OC cp $pod_id:/tmp/network_shared.tgz $pbench_dir/network_shared.tgz
