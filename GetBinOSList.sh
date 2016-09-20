#!/bin/bash
# This script takes input as the windows binary list file
# and provides its equivalent MacOS and Linux Binary files
# The pre-requisite for this script is to have the Mapping file 
# "binlist" already placed in its current directory which has the
# file mapping with "|" seperator for Windows|MAC|Linux
# File Syntax:
#    Winmodule1[,submodule11,...]|Macmodule1[,submodule11,...]|Linmodule1[,submodule11,...]

BinList=$1
MasterBinList=binlist

grep -i .dll $BinList >> Flist

if [ -s Flist ]
then 
	echo " The file $BinList is Windows Binary List "
else
	echo " Error: The file $BinList is NOT Windows Binary List " >> $PHERE/Fullpatch.log
	echo " Please ensure to provide the Windows Binary List " 
	rm -rf Flist
	exit 16
fi

echo " Preparing the equivalent Linux Binary List and MacOS Binary List "
# Need to copy the nvdkit externally since this does not get modified every time
# This section will be dedicated to such files (manual Files)
# Appending nvdkit to $Bin List
echo " Appending nvdkit to $Bin List "
echo nvdkit >> $BinList
for i in `cat $BinList`
do
grep -i $i $MasterBinList >> FoundBinList
done
cut -d "|" -f2 FoundBinList >> MACBinListNS
more MACBinListNS | tr "," "\n" >> MACBinListT
echo " Ignoring libcrypto.dylib and libssl.dylib MacOS Binary List MACBinList "
cat MACBinListT | grep -v libcrypto.dylib | grep -v libssl.dylib >> MACBinList
echo " Created the MacOS Binary List MACBinList "
cut -d "|" -f3 FoundBinList >> LnxBinListNS
more LnxBinListNS | tr "," "\n" >> LnxBinList
echo " Created the Linux Binary List LnxBinList "
echo " Script Completed successfully "
rm -rf Flist FoundBinList MACBinListT MACBinListNS LnxBinListNS

