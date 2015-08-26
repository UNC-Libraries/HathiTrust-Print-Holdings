#!/bin/sh
#
WORKINGDIR=/scripts/hathi
cd $WORKINGDIR

LOGFILE=$WORKINGDIR/log.txt
rm -f $LOGFILE
touch $LOGFILE


BNUMSCRIPT=$WORKINGDIR/get_bib_num_lists.pl
PROCESSSCRIPT=$WORKINGDIR/extract_holdings_data_from_bibs.pl
BLIST=$WORKINGDIR/bnums.list
FINISHEDLIST=$WORKINGDIR/finished.list
# Maximum number of files running at a time
concurrentFiles=3



echo "$(timestamp): Deleting old bnum input files" >> $LOGFILE
rm -f hbnumin_*

echo "$(timestamp): Deleting old processed data direcories" >> $LOGFILE
rm -rf hout_*

echo "$(timestamp): Deleting old final output directory" >> $LOGFILE
rm -rf holdings_final

echo "$(timestamp): Deleting old file lists and output" >> $LOGFILE
echo "" >> $LOGFILE
rm -f *.list
rm -f *.out
rm -f *.err

#create new blank file
touch $FINISHEDLIST

# run script to create new bnum input files
echo "$(timestamp): Starting to build new bnum input files..." >> $LOGFILE
/usr/bin/perl $BNUMSCRIPT  >> $LOGFILE & 
PID=$!
wait $PID
echo "$(timestamp): Done building new bnum input files" >> $LOGFILE
echo "" >> $LOGFILE

ls hbnumin_*.txt > $BLIST

IFS=$'\n' read -r -d '' -a bnumfiles < $BLIST
BNUMFILECOUNT=${#bnumfiles[@]}
lastProcessedIdx=0
lastFinishedCount=`cat $FINISHEDLIST | wc -l`

echo "$(timestamp): There are $BNUMFILECOUNT bnum files to process." >> $LOGFILE
echo "$(timestamp): Starting to run holdings processes on bnum files..." >> $LOGFILE

processesCt=0

timestamp() {
    date +"%T"
}

process_bnums() {
    (( processesCt++ ))
    thisfile=$1
    filenum=$(echo $thisfile | sed -r 's/hbnumin_([0-9]+)\.txt/\1/')
    thisdir=hout_$filenum
    mkdir $thisdir

    /usr/bin/perl $PROCESSSCRIPT $thisfile $thisdir &
    PID=$!
    wait $PID
    echo "$thisfile completed" >> $FINISHEDLIST
    processesCt=$((processesCt - 1))
}

filesStartedCount=0
while (( $filesStartedCount < $concurrentFiles ))
do
    echo "$(timestamp): Kicking off ${bnumfiles[$lastProcessedIdx]}" >> $LOGFILE
    process_bnums ${bnumfiles[$lastProcessedIdx]} &
    lastProcessedIdx=$((lastProcessedIdx + 1))
    (( filesStartedCount++ ))
done

until (( $filesStartedCount == $BNUMFILECOUNT ))
do
    if (( $processesCt < $concurrentFiles ))
    then
	nowFinishedCount=`cat $FINISHEDLIST | wc -l`
	if (( $nowFinishedCount > $lastFinishedCount ))
	then
	    (( lastFinishedCount++ ))
	    echo "$(timestamp): Kicking off ${bnumfiles[$lastProcessedIdx]}" >> $LOGFILE
	    process_bnums ${bnumfiles[$lastProcessedIdx]} &
	    lastProcessedIdx=$((lastProcessedIdx + 1))
	    (( filesStartedCount++ ))	    
	else
	    echo "$(timestamp): No open processing slots. Waiting for another file to finish processing..." >> $LOGFILE
	    sleep 5m
	fi
    else
	echo "$(timestamp): Already $processesCt processes running. Waiting to check again..." >> $LOGFILE
	sleep 5m
    fi
done
exit
