#!/bin/bash

concurrent=5000
num_objects=1000
# client_time=180
# client_ops=500000
kill_time=60
restart_time=120
prep=0

for i in "$@" ;do
    case $i in
	--time=*)
	    client_time="${i#*=}"
	    shift
	    ;;
	--ops=*)
	    client_ops="${i#*=}"
	    shift
	    ;;
	-c=*|--concurrent=*)
	    concurrent="${i#*=}"
	    shift
	    ;;
	--objs=*|--objects=*)
	    num_objects="${i#*=}"
	    shift
	    ;;
	--kill)
	    mode=kill
	    shift # past argument=value
	    ;;
	--keep)
	    mode=keep
	    shift # past argument=value
	    ;;
	--restart)
	    mode=restart
	    shift # past argument=value
	    ;;
	--prep)
	    mode=prep
	    shift # past argument=value
	    ;;
	--help)
	    echo $0 [mode] [limit] [options]
	    echo "    mode is one of --prep, --keep, --kill, or --restart"
	    echo "    limit is one of:"
	    echo "        --time=<seconds>"
	    echo "        --ops=<number-operations>"
	    echo "    options are:"
	    echo "        --concurrent=<concurrent-operations>"
	    echo "        --objs=<number-objects>"
	    exit 0
	    ;;
	*)
	    echo "Unknown argument $i"
	    error=1
	    ;;
    esac
done

if [ "$error" = "1" ] ;then
    echo Error: command-line options.
    exit 1
fi

if [ "$mode" = "" ] ;then
    echo Error: must specify --prep, --mode, --keep or --restart.
    exit 1
fi

cd /home/ivancich/ceph-work/build
pool=smalliopool
prefix=smallio

if [ "$mode" = "prep" ] ; then
# start ceph
    ../src/stop.sh

    echo "FIX vstart.sh params"
    exit 9
    ../src/vstart.sh --osd_num 5 -k -l --short 2>/dev/null

    # delete pool
    bin/ceph osd pool delete $pool $pool --yes-i-really-really-mean-it

    # create pool named data
    bin/ceph osd pool create $pool 150

    # create
    set -x
    bin/ceph_smalliobench --num-objects $num_objects --init-only on \
			  --use-prefix $prefix --pool-name $pool
    set +x

    exit 0
fi

if [ -z "$client_time" -a -z "$client_ops" ] ;then
    echo Error: must specify either --time or --ops.
    exit 1
elif [ -n "$client_time" ] ;then
    timing1="--duration"
    timing2="$client_time"
else
    timing1="--max-ops"
    timing2="$client_ops"
fi

# find unique suffix based on date/time
stamp=$(date "+%m%d%H%M")
set -o noclobber
for s in a b c d e f g h i j k l m n o p q r s t u v w x y z ;do
    id="${stamp}${s}"
    info=smalliobench-info-${id}.txt
    { > $info ; } &> /dev/null
    if [ $? -eq 0 ] ;then break ;fi
done
set +o noclobber

out_summary=smalliobench-summary-${id}.json
out_ops=smalliobench-ops-${id}.json
info=smalliobench-info-${id}.txt

if [ "$mode" = "kill" -o "$mode" = "restart" ] ;then
    echo Killing osd 3 after $kill_time seconds
    # ( sleep $kill_time ; kill -9 $(cat out/osd.3.pid) ; echo "killed osd 3" ) &
    ( sleep $kill_time ; bin/ceph osd out 3 ; echo "killed osd 3" ) &
fi

if [ "$mode" = "restart" ] ;then
    echo Restarting osd 3 after $restart_time seconds
    # ( sleep $restart_time ; /home/ivancich/ceph-work/build/bin/ceph-osd -i 3 -c /home/ivancich/ceph-work/build/ceph.conf ; echo "restarted osd 3" ) &
    ( sleep $restart_time ; bin/ceph osd in 3 ; echo "restarted osd 3" ) &
fi

start=`date`

# test
set -x
bin/ceph_smalliobench $timing1 $timing2 --do-not-init on \
		      --use-prefix $prefix --pool-name $pool \
		      --num-concurrent-ops $concurrent \
		      --num-objects $num_objects \
		      >$out_summary 2>$out_ops
set +x
stop=`date`

# record some information in a .txt file

echo "concurrent = ${concurrent}" >>$info
echo "num_objects = ${num_objects}" >>$info
echo "mode = ${mode}" >>$info
echo "timing = ${timing1} ${timing2}" >>$info

# run-time
echo "$start" >>$info
echo "$stop" >>$info

# git branch/commit
git branch --no-color 2>/dev/null |
    sed -e '/^[^*]/d' -e 's/* \(.*\)/branch: \1/' >>$info
echo "commit: $(git rev-parse HEAD)" >>$info

# config
echo "==== ceph.conf start ====" >>$info
cat ceph.conf >>$info
echo "==== ceph.conf end ====" >>$info

# memory
free >>$info
