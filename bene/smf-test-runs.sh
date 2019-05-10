#!/bin/bash -x

oplist="create read append ls-l chmod delete"
#oplist="create delete"
fpdlist="10 100 1000 10000"
#fpdlist="10 100"
fszlist="4 64 1024 4096"
#fszlist="4 64"
files_per_thread=1000
#files_per_thread=100

RUN_SMF=~/bene/run-smf-pods.sh

# clean up whatever was left over from before
oc delete namespace smallfile
rm -fv pod.list

# must create namespace before creating PVC + pods
oc create namespace smallfile

# dont do anything unless you can get a Cephfs PVC into Bound state

oc create -f ~/openshift_scalability/content/smallfile/claim.yaml
sleep 1
ocsmf="oc -n smallfile "
$ocsmf get pvc | grep Bound
if [ $? != 0 ] ; then
  echo 'cephfs pvc not bound, exiting'
  exit 1
fi

(cd ~/openshift_scalability; ./cluster-loader.py -f content/smallfile/smallfile-parameters.yaml || exit 1)
pods_created=$( $ocsmf get pod | grep smallfile-pod | wc -l )
if [ "$pods_created" = 0 ] ; then
  exit 1
fi
# wait for pods to be in Running state
while [ 1 ] ; do
  sleep 2
  non_running_pods=$( $ocsmf get pod | grep smallfile-pod | grep -v Running | wc -l )
  if [ $non_running_pods = 0 ] ; then
	break
  fi
done

# construct list of pod ids to hand to smallfile

worker_file=$HOME/smf.pod.id.list
rm -fv $worker_file
for p in `$ocsmf get pod | awk '/smallfile-pod/{print $1}'` ; do
  $ocsmf logs $p | awk '/as-host/&&/python/{print $NF}'
done | sort -u > $worker_file

pbench-kill-tools

# this script is intended to clear out the Cephfs kernel client cache on all hosts

drop_cache() {
  sleep 1
  ansible all -i ~/ben.inv -m shell -a 'sync ; echo 3 > /proc/sys/vm/drop_caches'
  sleep 3
}

# effect of file size

for fsz in $fszlist ; do
  for op in $oplist ; do 
   drop_cache
   $RUN_SMF "--files $files_per_thread --file-size $fsz --threads 1 --operation $op" fsz.$fsz.op.$op
  done
  NO_PBENCH=1 $RUN_SMF "--files $files_per_thread --threads 1 --operation cleanup" 
done

# effect of files per directory

for fpd in $fpdlist ; do
  for op in $oplist ; do 
    drop_cache
    $RUN_SMF "--files $files_per_thread --file-size 4 --files-per-dir $fpd --threads 1 --operation $op" fpd.$fpd.op.$op
  done
  NO_PBENCH=1 $RUN_SMF "--files $files_per_thread --threads 1 --operation cleanup" 
done

# effect of sharing directories between pods

for op in $oplist ; do 
  drop_cache
  $RUN_SMF "--files $files_per_thread --same-dir Y --file-size 4 --threads 1 --operation $op" same-dir
done
NO_PBENCH=1 $RUN_SMF "--files $files_per_thread --same-dir Y --threads 1 --operation cleanup" 
# compare to same file size with parameters below and default of --same-dir N

# effect of hashing into dirs (random access to directories)

for op in $oplist ; do 
  drop_cache
  $RUN_SMF "--files $files_per_thread --hash-into-dirs Y --file-size 4 --threads 1 --operation $op" hash-into-dirs
done
NO_PBENCH=1 $RUN_SMF "--files $files_per_thread --hash-into-dirs Y --threads 1 --operation cleanup" 
# compare to same file size with parameters below and default of --hash-into-dirs N

