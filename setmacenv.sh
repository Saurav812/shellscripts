#!/bin/bash
# This file will capture the SRC directory, TARGET Directory, BIN location
# This file will also carry a reference to tiles that need to be called externally

echo " Inside the setmacenv.sh file "

#SOURCE_DIR=<sourcedir>
#TARGET_DIR=<targetdir>
#BIN=<macbin>


# Environment variables needed for Agent Build engine.
NOVA_CLNT_DIR=/nfs_src/client/$radia_version
NOVA_CLNT_MAK_DIR=$NOVA_CLNT_DIR/mak
export NOVA_CLNT_DIR NOVA_CLNT_MAK_DIR 
alias setversion='. $NOVA_CLNT_MAK_DIR/select.mak'
alias gbuild='$NOVA_CLNT_MAK_DIR/gbuild.mak'
PATH=$PATH_SPECIAL:$PATH:$NOVA_CLNT_MAK_DIR
export PATH
echo " The MAC Environment is set "
