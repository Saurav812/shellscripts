#!/bin/bash
# Evaluate which build needs to be triggered

function script_usage
{
       # echo " Usage   : $0 <$TAG> <"$MAJ_MIN"_"$SP"PatchScript> <Radia_"$MAJ_MIN"_"$SP"> "
        	echo " Usage   : $0 <TAG> <"MAJ_MIN"_"SP"PatchScript> <"Radia_MAJ_MIN"_"SP"> "
		echo " Example : $0 HPCA7_90_7_AGENT_PATCH 7_90_9PatchScript Radia_7_90_9"
		echo " To test: $0 HPCA7_90_7_AGENT_PATCH 7.9.7PatchScript Radia_797 "
}

if [ ! $# -eq 3 ]
then
                echo " Please read the below usage. "
                script_usage
     exit 16
else
    TAG=$1
    PDIR=$2
    RDIR=$3
    echo  " Entered the following attributes $TAG $PDIR $RDIR "
fi

PHERE=`pwd`
PRT=$PHERE/private
echo " Begin the build "
echo " Performing build for $TAG output will be in $PRT/$TAG "
     if [ -d $PRT/$TAG ]
       then
	DIRNAME=`date +%F_%T`
	echo "moving $PRT/$TAG to $PRT/$TAG-$DIRNAME "
          mv $PRT/$TAG $PRT/$TAG-$DIRNAME
     fi

     if [ ! -d /mnt/ftcshare/nfs_src/client/$RDIR ]
       then
        echo " Creating /mnt/ftcshare/nfs_src/client/$RDIR since its not present "
	sudo mkdir -p /mnt/ftcshare/nfs_src/client/$RDIR
     else
	echo " /mnt/ftcshare/nfs_src/client/$RDIR is available "
	fi

     if [ ! -d /Users/caagent/$PDIR ]
       then
	echo " /Users/caagent/$PDIR does not exist "
	echo " Error /Users/caagent/$PDIR does not exist " >> $PHERE/Fullpatch.log
	exit 16
	else 
		cd /Users/caagent/$PDIR
		echo " We are currently in `pwd` location "
	fi
echo " setting the mac environment "
/mnt/ftcshare/nfs_src/client/mac_svn_co_scripts/svnenv.sh
#echo " cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR 1> $TAG.log 2> $TAG.log "
echo " cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR  | tee $PRT/$TAG/$TAG.log "
#cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR 1> $TAG.log 2> $TAG.log

cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR 2>&1 | tee -a $PRT/$TAG.log

sudo mv $PRT/$TAG.log $PRT/$TAG/$TAG.log 
echo " cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR 2>&1 | tee -a $PRT/$TAG/$TAG.log "
echo " ls -ltr $PRT/$TAG/CA-Build/content/agents/macx86/ram >> $PRT/$TAG/buildlist.log "
ls -ltr $PRT/$TAG/CA-Build/content/agents/macx86/ram >> $PRT/$TAG/buildlist.log
echo "grep Error $PRT/$TAG/$TAG.log >> $PRT/$TAG/error.log"
grep Error $PRT/$TAG/$TAG.log >> $PRT/$TAG/error.log
echo " grep FAILED $PRT/$TAG/$TAG.log >> $PRT/$TAG/fatalerror.log "
grep FAILED $PRT/$TAG/$TAG.log >> $PRT/$TAG/fatalerror.log
echo " grep -v "Error 1" error.log >> $PRT/$TAG/fatalerror.log "
grep -v "Error 1" $PRT/$TAG/error.log >> $PRT/$TAG/fatalerror.log
if [ -s $PRT/$TAG/fatalerror.log ]
 then 
        echo " Please verify the Error in error.msg log located in `pwd` location "  >> $PHERE/Fullpatch.log
        echo " You can Ignore " "Error 1" "or" "Error 1 (Ignored)"  >> $PHERE/Fullpatch.log
        echo " Also verify the  buildlist.log to check if the binaries have been built correctly "  >> $PHERE/Fullpatch.log
        exit 16
# else
 #      echo " The build completed successfully "
fi
if [ -s $PRT/$TAG/buildlist.log ]
        then 
                echo " The build completed successfully "
else
        echo " Error in build, hence Build Failed " >> $PHERE/Fullpatch.log
        echo " Please verify the log at $PRT/$TAG/$TAG.log " >> $PHERE/Fullpatch.log
        exit 16
fi
cd $PHERE
	if [ -s $PRT/$TAG/fatalerror.log ]
		then
		Echo " The build has failed " >> $PHERE/Fullpatch.log
		Echo " Verify the build logs for Error and fix the issue " >> $PHERE/Fullpatch.log
		exit 16
#		else
#		echo " Build has completed " >> $PHERE/Fullpatch.log
	fi
echo " We are now at $PHERE location "
