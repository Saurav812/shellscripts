#!/bin/bash
# This script performs a build
#PHERE=`pwd`
#echo " loading the build.properties "
. ./build.properties
GETHERE=/Users/capatch/test-mac-patch
echo " loading $GETHERE/build.properties "
$GETHERE/build.properties
cd /Users/caagent/$PDIR
echo " We are currently in `pwd` location "
echo " setting the mac environment "
/mnt/ftcshare/nfs_src/client/mac_svn_co_scripts/svnenv.sh
#Ensure to save the SSH Session for the build log
#echo " cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR >> $TAG.blog "
echo " cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR 1> $TAG.blog 2> $TAG.blog "
cc_build.sh $TAG $PRT /mnt/ftcshare/nfs_src/client/$RDIR 1> $TAG.blog 2> $TAG.blog
ls -ltr $PRT/$TAG/CA-Build/content/agents/macx86/ram >> buildlist.blog
grep Error $TAG.blog >> error.blog
grep FAILED $TAG.blog >> fatalerror.blog
grep -v "Error 1" error.blog >> fatalerror.blog
if [ -s fatalerror.blog ]
 then 
	echo " Please verify the error.msg log located in `pwd` location "
	echo " You can Ignore " "Error 1" "or" "Error 1 (Ignored)"
	echo " Also verify the  buildlist.blog to check if the binaries have been built correctly "
	echo " *.blog copy to $GETHERE "
	mv *.blog $GETHERE
	exit 16
 #else
#	echo " The build completed successfully "
fi
if [ -s buildlist.blog ]
	then 
		echo " The build completed successfully "
		echo " *.blog copy to $GETHERE "
		mv *.blog $GETHERE
else
	echo " Build Failed "
	echo " Please verify the $TAG.log "
	echo " *.blog copy to $GETHERE "
                mv *.blog $GETHERE
	exit 16
fi

