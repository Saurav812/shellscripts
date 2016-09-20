#!/bin/bash
# version : 1.0.1
# Author  : Azher 
# Description : This script will be used to build and package the mac agent patch
# Dependencies : setmacenv.sh, loadsrc2.sh, FinalSpeclist, verifysrclist.sh, 
#		 makeexport.tcl, macx86-modules.xml, nvdkit, pkgs.dat, promote.tkd, 
#		 sample.cfg, SetStamp.tcl, stamp.tkd, stampit.sh, tar.sh
#		 VerifyBinListCopy.sh, MACBinList (These 2 files have been introduced which will replace FinalSpeclist verifysrclist.sh)
# Syntax : ./HPCAbuildmacagentpatch.sh <SVN Tag> <Release_Major_Minor> <Patch_SP_number> <OS>
# Example: ./HPCAbuildmacagentpatch.sh HPCA7_90_7_AGENT_PATCH 7_90 7 macosx_x86
# Example: ./HPCAbuildmacagentpatch.sh HPCA7_80_10_AGENT_PATCH 7_80 10 macosx_x86


function script_usage
{
        echo " Usage   : $0 <SVN Tag> <Release_Major_Minor> <Patch_SP_number> <OS> "
        echo " Example : $0 HPCA7_90_7_AGENT_PATCH 7_90 7 macosx_x86 "
		echo " Example : $0 HPCA7_80_10_AGENT_PATCH 7_80 10 macosx_x86 "
}

if [ $# -lt 4 ]
	then
		echo " Please read the below usage. "
		script_usage
		exit 16
else
    TAG=$1
    MAJ_MIN=$2
    SP=$3
    OS=$4
    PTAG=$1
    OSUP=`echo "$OS" | tr a-z A-Z`
    RTAG=`echo $TAG | cut -b 1-7`
#    MAJMIN=`echo $TAG | cut -c5`.`echo $TAG | cut -b 7-8`
fi


if [  $# -eq 5 ]
    then
     PTAG=$5
fi

# Set the variables which are needed for the execution of this script

PHERE=$PWD
PDIR="patchinfo"
SHRLOC=$PWD/nfs_src
HOMESYS=$HOSTNAME
SCRIPTHOME=$PHERE/scripts
MYHOME=$HOME
RC=0
LOADDONE=0
PKG_MACHINE="ftcbuild-mac-x86.usa.hp.com"

if [  -d $PHERE ]
   then
     rm Fullpatch.log GetBinList-out loadsrc-out VerifyBinListCopy-out 
fi
cd $PHERE


if [ ! -d $SHRLOC ]
   then
     echo " NFS Share 'nfs_src' was not found, creating directory "
    mkdir -p $SHRLOC/$PDIR
fi
echo " $SHRLOC is present "

if [ $OS = "macosx_x86" ]
   then
     PATCHTAG="CPATCH_"$MAJ_MIN"_"$SP
     PLATFORMS="$OS"

	echo " selected OS as $OS and the Patch Tag set is $PATCHTAG "
else
    echo "Error: Operating System is not one of the valid choices"
    exit 16
fi

# Calling functions to do set radia_version, parent branch name (brname) and MAJ.MIN

if [ "$RTAG" = "HPCA7_8" ]
     then
        radia_version="HPCA_78"
        brname="HPCA7_8_CPE"
	MRTAG="HPCA7_8_MR"
	MAJMIN=7.80

elif [ "$RTAG" = "HPCA8_1" ]
    then
        radia_version="HPCA_81"
        brname="JALAPENO"
	MRTAG="HPCA_810_MR_JALAPENO2"
	MAJMIN=8.10

elif [ "$RTAG" = "HPCA7_9" ]
    then
        radia_version="HPCA_79"
        brname="MERINO"
	MRTAG="HPCA7_9_L10N_MR"
	MAJMIN=7.90
		
elif [ "$RTAG" = "HPCA9_0" ]
    then
        radia_version="HPCA_90"
        brname="TABASCO"
	MRTAG=NEEDUPDATE
	MAJMIN=NEEDUPDATE
	#If the fix for minor-minor in CSDB is in place (i.e. no issues with 8.11 release of 8.10) then modify MAJMIN in this script

else
    echo "Error: Value given for SVN tag is not a known value"
    exit 16
fi

echo " The Tag is set to $TAG "
echo " The Release Tag is $RTAG "
echo " The Major_Minor version is set to $MAJ_MIN "
echo " The Patch Version is set to $SP "
echo " The OS is set to $OS and OS uppercase is $OSUP "
echo " The PTag is set to $PTAG "
echo " The current path is $PHERE "
echo " The Patch machine is set to $PKG_MACHINE "
echo " The Home sys is set to $HOSTNAME "
echo " The location of MyHome is $MYHOME "
echo " The build platform for tis run is $PLATFORMS "
echo " The script location is $PHERE "
echo " The radia version is $radia_version "
echo " The Branch name is $brname "
echo " The Major.minor is $MAJMIN "

#cd $SHRLOC
#if [  -d $PDIR ]
 #  then
  #   cd $PDIR
   #  rm $OS-location
    # echo " removing old log files from $SHRLOC/$PDIR "
#fi

cd $PHERE

if [ "$OS" = "macosx_x86" ]
  then 
      FTC_MACHINE="ftcbuild-mac-x86.usa.hp.com"
  else
      echo "Error encountered for the OS type, it is not one of the known values"
     # RC=16
	exit 16
  fi

  OUTLOG=$OS"-client.log"

  echo " "
  echo "Using the $FTC_MACHINE to begin the patch building process"
  echo " "

   if [ "$LOADDONE" -eq "0" ]
    then
	echo " ............................."
	echo " Doing source load and Build   "
	echo " ............................."
	cd $PHERE

	export radia_version
	echo " Exported $radia_version "
	export SHRLOC
	echo " Exported $SHRLOC "
#inserted below to ensure the MAJ_MIN SP gets updated for Dir creation in loadsrc2.sh script
	export MAJ_MIN
	echo " Exported  $MAJ_MIN "
	export SP
	echo " Exported $SP "
	cd $SHRLOC
     if [ ! -d $PDIR ]
       then
          mkdir $PDIR
     fi
     cd $PHERE
	 echo " loadsrc2.sh $TAG $PTAG $OS "
     loadsrc2.sh $TAG $PTAG $OS

     cd $PHERE
     grep Error $PHERE/Fullpatch.log > $PHERE/loadsrc-out
     RETVAL=$?
     echo "grep exit status was $RETVAL"
     if [ $RETVAL = 1 ]
       then
        LOADDONE=1
        echo " The source loadsrc2.sh has finished successfully, process continuing "
     else
       echo " Error was encountered during source loadsrc2.sh, process terminating "
       RC=16
	exit 16
     fi

fi

#inserted the below change to accomodate the creation of full patch (Ex: For HPCA_78)

if [ ! "$radia_version" = "HPCA_78" ]
 then 
  echo " ............................."
  echo " Getting the Delta Binary List "
  echo " ............................."
	echo " GetBinList.sh $TAG $MAJ_MIN $SP %SVNUSERNAME% %SVNPASSWORD% $MRTAG "
    ./GetBinList.sh $TAG $MAJ_MIN $SP tsg-bsaca-dev-build caSVNbu1ldID $MRTAG
     cd $PHERE
     grep Error $PHERE/Fullpatch.log > $PHERE/GetBinList-out
     RETVAL=$?
     echo "grep exit status was $RETVAL"
     if [ $RETVAL = 1 ]
       then
        echo " The GetBinList.sh completed successfully, process continuing...... "
     else
       echo " Error while processing GetBinList.sh "
       RC=16
	exit 16
     fi
else
  echo " ............................."
  echo " Creating a Full patch for $TAG "
  echo " ............................." 
  ./GetBinOSList.sh binlist
  sort MACBinList >> MACT1
  rm -rf MACBinList
  uniq MACT1 >> MACBinList
  rm -rf  MACT1
	echo " Checking out MakeExport from SVN "
	echo " ./chkoutmakeexport.sh $TAG $MAJ_MIN $SP tsg-bsaca-dev-build caSVNbu1ldID $MRTAG "
	./chkoutmakeexport.sh $TAG $MAJ_MIN $SP tsg-bsaca-dev-build caSVNbu1ldID $MRTAG
	cd $PHERE
     grep Error $PHERE/Fullpatch.log > $PHERE/VerifyBinListCopy-out
     RETVAL=$?
     echo "grep exit status was $RETVAL"
     if [ $RETVAL = 1 ]
       then
        echo " The chkoutmakeexport.sh completed successfully, process continuing...... "
     else
       echo " Error while processing VerifyBinListCopy.sh "
       RC=16
	exit 16
	fi
fi

cd $PHERE
SANDBOX=$PHERE/sandbox/$TAG
#BUILD_BASE=/Users/capatch/agent-mac-patch/nfs_src/client/$radia_version
brtag=$TAG

export brtag
echo " Exported $brtag"
export brname
echo " Exported $brname"
export SANDBOX
echo " Export $SANDBOX"

echo " ............................................"
echo " Files getting loaded from Source to Target "
echo " ............................................"

VerifyBinListCopy.sh

cd $PHERE
     grep Error $PHERE/Fullpatch.log > $PHERE/VerifyBinListCopy-out
     RETVAL=$?
     echo "grep exit status was $RETVAL"
     if [ $RETVAL = 1 ]
       then
        echo " The VerifyBinListCopy.sh completed successfully, process continuing...... "
     else
       echo " Error while processing VerifyBinListCopy.sh "
       RC=16
	exit 16
     fi


cd $PHERE
echo " Files are loaded and prepared for makeexport.tcl file to execute"
TRG=$PHERE/TRG_Dir/
echo " ...................................."
echo " Doing signing and creating the patch"
echo " ...................................."

echo " nvdkit makeexport.tcl -source $TRG -target /opt/Radmaint -release $MAJMIN -os $OSUP -sp $SP -xml macx86-modules.xml "

#sudo nvdkit $SANDBOX/MakeExport/makeexport.tcl -source $TRG -target /opt/Radmaint -release $MAJMIN -os $OSUP -sp $SP -xml macx86-modules.xml
sudo nvdkit $SANDBOX/MakeExport/makeexport.tcl -source $TRG -target /opt/Radmaint -release $MAJMIN -os $OSUP -sp $SP -xml macx86-modules.xml
RETVAL=$?
     echo "grep exit status for makeexport.tcl was $RETVAL"
     if [ $RETVAL = 0 ]
       then
        echo " The Signing  has finished successfully "
     else
       echo " Error was encountered during Code Signing, process terminating "
       RC=16
	exit 16
     fi

# it shouldbe
# sudo $nvdkit makeexport.tcl -source $TRG -target /opt/Radmaint -release $MAJMIN -os $OSUP -sp $SP -xml $MakeExport/macx86-modules.xml
#echo " Please find the $OS patch at /opt/Radmaint location"
#echo " Patch Creation COMPLETED SUCCESSFULLY "

LogDir=$TAG-`date +%F_%T`
#mkdir -p archive/$TAG
#echo " mv -f *.log ./archive/$LogDir "
#mv -f *.log "./archive/$LogDir"
#echo " Please find the makeexport .logs at the following location $PHERE/archive/$TAG"
	if [ -f /opt/Radmaint/*.gz  ]
	then
		echo " Script Completed Successfully"
		ls -ltr /opt/Radmaint/*.gz
		mv /opt/Radmaint/*.gz $PHERE
		echo " The Patch is available at $PHERE "
	else
		echo " Script Failed to create the PATCH "
		ls -ltr /opt/Radmaint/*.gz
		echo " Please verify all logs starting with $PHERE/Fullpatch.log "
	fi

