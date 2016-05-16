#!/bin/sh
#
WORKINGDIR=/scripts/hathi/holdings
DIRLIST=$WORKINGDIR/dir.list
cd $WORKINGDIR

echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
echo "OUTPUT PROGRESS"
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

ls -d hout_* > $DIRLIST
IFS=$'\n' read -r -d '' -a dirs < $DIRLIST

for thedir in ${dirs[@]}
do
    filenum=$(echo $thedir | sed -r 's/hout_([0-9]+)/\1/')
    bnums="hbnumin_${filenum}.txt"
    bnumct=`cat $bnums | wc -l`
    donefile="${thedir}/done.txt"
    donect=`cat $donefile | wc -l`
    progpart=$(bc <<<"scale=2;$donect/$bnumct")
    progpercent=$(bc <<<"scale=2;$progpart*100")
    echo "${filenum}: ${progpercent} percent complete. ${donect} of $bnumct processed."
done



exit
