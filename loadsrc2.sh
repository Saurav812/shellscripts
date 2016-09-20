#!/bin/bash
# The input to this script is the SVN Tag and the SVN Patch Tag
# This Script will download the Agent folders and load 
# them in the radia_version (Ex:HPCA_79)
# also provision is given to call the Mac build script from here

function script_usage
{
        echo " Usage   : $0 <SVN Tag> <PTAG> <OS> "
        echo " Example : $0 HPCA7_90_7_AGENT_PATCH HPCA7_90_7_AGENT_PATCH macosx_x86 $RTAG "
}


echo " $radia_version is exported "
echo " $MAJ_MIN is exported "
echo " $SP is exported "


PHERE=$PWD
PDIR="patchinfo"

#if [ -f  $PHERE/Fullpatch.log ]
#then   
#	rm $PHERE/Fullpatch.log
#echo "custom removing the old log file"
#fi

if [ ! $# -eq 3 ]
then
                echo " Please read the below usage. "
                script_usage
                echo "Error Incorrect Parms Passed " >> $PHERE/Fullpatch.log
     exit 16
else
    TAG=$1
    PTAG=$2
    OS_PLATFORM=$3
    echo "Load source values are good and are $TAG $PTAG $OS_PLATFORM " >> $PHERE/Fullpatch.log
fi

echo " The SHRLOC is $SHRLOC "
echo " The Radia Version is $radia_version "
RadiaVer=Radia_"$MAJ_MIN"_"$SP"
#RadiaVer=Radia_`echo $TAG | cut -b 5-10`
# Radia_7_80_10
PatchScript="$MAJ_MIN"_"$SP"_PatchScript
#PatchScript=`echo $TAG | cut -b 5-10`_PatchScript
# 7_80_10_PatchScript
SOURCE_BASE=$PHERE
BUILD_BASE=$SOURCE_BASE/$radia_version
SANDBOX=$SOURCE_BASE/sandbox/$TAG
LOG_FILE=$PDIR/sandbox_update_$PTAG.log
SCRIPTHOME=$PHERE/scripts

export SANDBOX
echo " The SOURCE_BASE is $SOURCE_BASE "
echo " The BUILD_BASE is $BUILD_BASE "
echo " the SANDBOX is $SANDBOX "
echo " the LOG_FILE is $LOG_FILE"
echo " The RadiaVer folder is $RadiaVer "
echo " The PatchScript folder is $PatchScript "

# Check if the Script folder exists


Echo " ******* Please Input "Y" if Build for this patch is Needed ******"
Echo " **** Please Enter "N" if build was already completed & if ONLY Repackaging is required ******"
read INPUT


if [ $INPUT = "Y" -o $INPUT = "y" ]
    then
		echo " Proceeding to Begin the build for the $TAG Mac Patch " >> $PHERE/Fullpatch.log
		echo " evalbuild.sh $TAG $PatchScript $RadiaVer " >> $PHERE/Fullpatch.log 
		./evalbuild.sh $TAG $PatchScript $RadiaVer
		 cd $PHERE
		     grep Error $PHERE/Fullpatch.log >> $PHERE/loadsrc-out
 		    RETVAL=$?
     			echo "grep exit status was $RETVAL"
     			if [ $RETVAL = 1 ]
      			 then
       			LOADDONE=1
       			 echo " The Build Completed successfully, process continuing " >> $PHERE/Fullpatch.log
    			 else
      			 echo " Error was encountered during MAC Agent Build, process terminating " >> $PHERE/Fullpatch.log
      			 RC=16
        		exit 16
     fi


elif [ $INPUT = "N" -o $INPUT = "n" ]
    then 
        echo " Assuming build has already been done " >> $PHERE/Fullpatch.log
		echo " Assuming this is just to repackage the binaries " >> $PHERE/Fullpatch.log
else
    echo " Error: Invalid input given exiting the patch build/packaging " >> $PHERE/Fullpatch.log
    exit 16
fi

date  >> $PHERE/Fullpatch.log
echo "Finished loadsrc2.sh successfully "  >> $PHERE/Fullpatch.log
echo ""  >> $PHERE/Fullpatch.log
exit 0



