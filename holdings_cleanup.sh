#!/bin/sh
#
WORKINGDIR=/scripts/hathi/holdings

cd $WORKINGDIR

echo "Deleting old bnum input files"
rm -f hbnumin_*

echo "Deleting old processed data direcories"
rm -rf hout_*

echo "Deleting old final output directory"
rm -rf holdings_final

echo "Deleting old file lists and output"
rm -f *.list
rm -f *.out
rm -f *.err