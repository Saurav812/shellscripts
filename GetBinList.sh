#!/bin/bash
# The result of this script will give you the list of Binary files changed.
# Ensure that the following files are  
# Located on ftcbuild-mac-x86.cnd.hp.com in /Users/capatch/GetBinList/ folder
# Following files need to be present at the above location
# GetBinList.sh GetTheListOfBin.tcl pcp.tcl MapFile.txt Exclude.txt nvdkit scripts/svnenv.sh scripts/svnco.sh


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
TEMP=TEMP/$TAG/RADMAINT

if [ -d $TEMP ]
   then
     echo Cleaning the temporary $TEMP folder...
fi
echo " Creating the temporary TEMP/$TAG/RADMAINT folder... "

mkdir -p $TEMP

echo " Created TEMP/$TAG/RADMAINT "
#ls -ltr TEMP/$TAG/

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

if [ -d agentpatches ] 
then
     echo " Removing old agentpatches directory "
     rm  -Rf agentpatches
fi

if [ -d common ]
then
     echo " Removing old common directory "
     rm  -Rf common
fi

if [ -d agent ]
then
     echo " Removing old agent directory "
     rm  -Rf agent
fi

if [ -d RSM ]
then
     echo " Removing old RSM directory "
     rm  -Rf RSM
fi

if [ -d ConnectDefer ]
then
     echo " Removing old ConnectDefer directory "
     rm  -Rf ConnectDefer
fi

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
echo " Checking out common directory "
#-----------------------------------------------------------#
# Setting SVNMIGMODEL to 2. Since Share/common is on Model 2

SVNMIGMODEL=2
export SVNMIGMODEL=2
echo " SVNMIGMODEL is $SVNMIGMODEL "
$SCRIPTHOME/svnco.sh $TAG shared common common $SVNMIGMODEL
SVNRC=$?
if [ $SVNRC -ne 0 ]
then 
    echo "Error in SVN source load " >> $PHERE/Fullpatch.log
    exit 16
fi
echo " Checkout for common completed "
#-----------------------------------------------------------#
echo " Checking out agentpatches directory "
#-----------------------------------------------------------#
# Setting SVNMIGMODEL to 1. Since agentpatches is on Model 1
SVNMIGMODEL=1
$SCRIPTHOME/svnco.sh $TAG Agent agentpatches/external/mac agentpatches $SVNMIGMODEL
SVNRC=$?
if [ $SVNRC -ne 0 ]
then
	echo "SVN checkout Error during checkout of $PTAG, Agent, agentpatches/external/mac" >> $PHERE/Fullpatch.log
	exit 16
fi
echo " Checkout for agentpatches completed "
#-----------------------------------------------------------#
echo " Checking out agent directory "
#-----------------------------------------------------------#
# Re-Setting SVNMIGMODEL to 1. Since Agent use Model 1

SVNMIGMODEL=1
cd $SANDBOX
echo " Checking out agent directory "
# cvs -Q co -r $PTAG -d agent   nvd/agent
$SCRIPTHOME/svnco.sh $TAG Agent agent agent $SVNMIGMODEL
SVNRC=$?
if [ $SVNRC -ne 0 ]
then 
    echo "Error in SVN source load "  >> $PHERE/Fullpatch.log
    exit 16
fi
echo " Checkout for agent completed "
#-----------------------------------------------------------#
echo " Checking out RSM directory "
#-----------------------------------------------------------#
# Re-Setting SVNMIGMODEL to 1. Since RSM use Model 1

SVNMIGMODEL=1
cd $SANDBOX
echo " Checking out RSM directory "
$SCRIPTHOME/svnco.sh $TAG Agent RSM RSM $SVNMIGMODEL
SVNRC=$?
if [ $SVNRC -ne 0 ]
then 
    echo "Error in SVN source load " >> $PHERE/Fullpatch.log
    exit 16
fi
echo " Checkout for RSM completed "
#-----------------------------------------------------------#
echo " Checking out ConnectDefer directory "
#-----------------------------------------------------------#
# Re-Setting SVNMIGMODEL to 1. Since ConnectDefer use Model 1

SVNMIGMODEL=1
cd $SANDBOX
echo " Checking out ConnectDefer directory "
$SCRIPTHOME/svnco.sh $TAG Agent ConnectDefer ConnectDefer $SVNMIGMODEL
SVNRC=$?
if [ $SVNRC -ne 0 ]
then 
    echo "Error in SVN source load " >> $PHERE/Fullpatch.log
    exit 16
fi
echo " Checkout for ConnectDefer completed "
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
#-----------------------------------------------------------#
echo " All Checkouts are completed "
#-----------------------------------------------------------#
echo " Getting list of modified files "
echo "sudo ./nvdkit GetTheListOfBin.tcl -tag1 $MRTAG -branch2 $TAG -debug 0 -scm svn -raddir $TEMP -exclude Exclude.txt -phere $PHERE -sandbox $SANDBOX"
chmod 777 *
cd $PHERE
#echo "$PHERE/nvdkit $PHERE/GetTheListOfBin.tcl -tag1 $MRTAG -branch2 $TAG -debug 0 -scm svn -raddir $TEMP -exclude $PHERE/Exclude.txt"
#sudo $PHERE/nvdkit $PHERE/GetTheListOfBin.tcl -tag1 $MRTAG -branch2 $TAG -debug 0 -scm svn -raddir $TEMP -exclude $PHERE/Exclude.txt
echo " Current Directory is `pwd` "
sudo ./nvdkit GetTheListOfBin.tcl -tag1 $MRTAG -branch2 $TAG -debug 0 -scm svn -raddir $TEMP -exclude Exclude.txt -phere $PHERE -sandbox $SANDBOX
SVNRC=$?
if [ $SVNRC -ne 0 ]
then 
	echo " Error: The GetTheListOfBin.tcl Failed " >> $PHERE/Fullpatch.log
    exit 16
fi
echo " The GetTheListOfBin.tcl completed successfully " >> $PHERE/Fullpatch.log

# grep vcproj *.log >> vcprojList
# remove the first column of this
# for i in `cat vcprojList`;do grep $i MapFile.txtORG | cut -d " " -f2;done

echo " Consolidating the Binary List for $TAG "

cat agentbinlist.log CDFbinlist.log RSMbinlist.log >> ACRbinlist.log
sort ACRbinlist.log >> SrtACRbinlist.log
FinalBinList=$TAG-BinList.log
uniq SrtACRbinlist.log >> $FinalBinList
LogDir=$TAG-`date +%F_%T`
mkdir -p archive/$LogDir
#mv agentbinlist.log CDFbinlist.log RSMbinlist.log $TAG_BinList archive/$TAG-`date +%F_%T`
#mv *.log archive/$LogDir
cp $FinalBinList ./archive/$LogDir/
cp *.log ./archive/$LogDir/
echo " Please find the ouput $FinalBinList at the following location $PHERE/archive/$LogDir" >> $PHERE/Fullpatch.log
echo "_______________________________________________________________________________________"
echo " Executing the Mapping Script to generate MACBinList and LinuxBinList "
./GetBinOSList.sh $FinalBinList
     cd $PHERE
     grep Error $PHERE/Fullpatch.log > $SHRLOC/$PDIR/GetBinList-out
     RETVAL=$?
     echo "grep exit status was $RETVAL"
     if [ $RETVAL = 1 ]
       then
        echo " The source GetBinList.sh has finished successfully, process continuing " >> $PHERE/Fullpatch.log
     else
       echo " Error was encountered during OS match in GetBinList.sh "
	   echo " Error was encountered during OS match in GetBinList.sh " >> $PHERE/Fullpatch.log
       RC=16
	exit 16
     fi
echo " Please verify the MACBinList with the binaries listed in the CRs "
echo " *********************COMPLETED******************** "


