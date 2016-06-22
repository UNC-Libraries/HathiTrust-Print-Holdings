#!/bin/sh
#
WORKINGDIR=/scripts/hathi/holdings
DIRLIST=$WORKINGDIR/dir.list
FINALDIR=holdings_final

rm -f *.list
rm -rf $FINALDIR

cd $WORKINGDIR
printf '%s\n' hout_*/ > $DIRLIST

mkdir $FINALDIR


while IFS='' read -r line || [[ -n $line ]]; do
    cats=(exclude mvmonos serials svmonos warning stat)
    odir=$line
    for fn in ${cats[@]}; do
	cat $line$fn.txt >> $FINALDIR/$fn.txt
    done
done < $DIRLIST

cd $FINALDIR

today=$(date +"%Y%m%d")

mv serials.txt unc_serials_$today.tsv
mv mvmonos.txt unc_multi-part_$today.tsv
mv svmonos.txt unc_single-part_$today.tsv
mv exclude.txt excluded_records.txt
mv stat.txt batch_statistics.txt

echo "" >> batch_statistics.txt
echo "Records per file for Title Count Comparison spreadsheet" >> batch_statistics.txt
echo "" >> batch_statistics.txt
wc -l unc_serials_$today.tsv >> batch_statistics.txt
wc -l unc_single-part_$today.tsv >> batch_statistics.txt
wc -l unc_multi-part_$today.tsv >> batch_statistics.txt
wc -l excluded_records.txt >> batch_statistics.txt

exit

