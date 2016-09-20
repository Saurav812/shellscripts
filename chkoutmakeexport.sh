#!/bin/bash
# The result of this script will give you the MakeExport folder checked out from SVN.
# Following files need to be present at the above location
# nvdkit scripts/svnenv.sh scripts/svnco.sh


function script_usage
{
        echo " Usage   : $0 <SVN Tag> <Release_Major_Minor> <Patch_SP_number> <svnuser> <svnpassword> <MRTAG> "
		echo " $0 %TAG% %MAJ_MIN% %SP% %SVNUSERNAME% %SVNPASSWORD% %MRTAG%"
        echo " Example : $0 HPCA7_80_10_AGENT_PATCH 7_80 10 tsg-bsaca-dev-build caSVNbu1ldID HPCA7_8_MR "
}

if [ $# -lt 6 ]
	then
		echo " Please read the below usage. "
		script_usage
		echo " Error: GetBinList.sh arguments incorrect " >> $PHERE/Fullpatch.log
		exit 16
else
    TAG=$1
    MAJ_MIN=$2
	SP=$3
    SVNUSERNAME=$4
    SVNPASSWORD=$5
    MRTAG=$6
fi
# Set the variables which are needed for the execution of this script

PHERE=`pwd`
SANDBOX=$PHERE/sandbox/$TAG
LOG_FILE=$SANDBOX/sandbox_update_$PTAG.log

echo " The Tag is set to $TAG "
echo " The Major_Minor version is set to $MAJ_MIN "
echo " The Patch Version is set to $SP "
echo " The username $SVNUSERNAME "
echo " The MRTAG is set to $MRTAG "
echo " The current path is $PHERE "
echo " The Home sys is set to $HOSTNAME "
echo " The sandbox is located at $SANDBOX "
echo " View following log for more info $LOG_FILE "

PATCH_TAG=CPATCH_$MAJ_MIN_$SP
LOGS=CPATCH_$MAJ_MIN_$SP-WIN32_BuildResults
SCRIPTHOME=$PHERE/scripts

#Check if scripts exist
if [ ! -d $SCRIPTHOME  ]
then
	echo " $SCRIPTHOME does not exist"
	echo " Create script home and place svnco.sh and svnenv.sh in it "
	echo " Error $SCRIPTHOME does not exist. Create script home and place svnco.sh and svnenv.sh in it " >> $PHERE/Fullpatch.log
     exit 16
else
   echo " "
   echo " $SCRIPTHOME already exists "  >> $PHERE/Fullpatch.log
   echo " "
fi 
# Check if the Sanbox exists

if [ ! -d $SANDBOX  ]
then
echo " $SANDBOX does not exist"
echo " Creating $SANDBOX structure "
     mkdir -p $SANDBOX
else
   echo " "
   echo " $SANDBOX already exists "
   echo " "
fi     
cd $SANDBOX
echo "Now accessing sandbox at $PWD "

if [ -d MakeExport ]
then
     echo " Removing old MakeExport directory "
     rm  -Rf MakeExport
fi

date > $LOG_FILE
echo "Updating sandbox for $radia_version " >> $PHERE/Fullpatch.log
echo "" >> $PHERE/Fullpatch.log

cd $SANDBOX
echo " setting the svn environment"
$SCRIPTHOME/svnenv.sh
#-----------------------------------------------------------#
echo " Checking out MakeExport directory "
#-----------------------------------------------------------#
# Re-Setting SVNMIGMODEL to 1. Since MakeExport use Model 1

SVNMIGMODEL=1
cd $SANDBOX
echo " Checking out MakeExport directory "
$SCRIPTHOME/svnco.sh $TAG Agent MakeExport MakeExport $SVNMIGMODEL
SVNRC=$?
if [ $SVNRC -ne 0 ]
then 
    echo "Error in SVN source load " >> $PHERE/Fullpatch.log
    exit 16
fi
echo " Checkout for MakeExport completed "

