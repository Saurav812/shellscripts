#!/bin/bash

echo "This is the script for if else command"

function script_usage
{
        echo " Usage   : $0 OS "
        echo " Example : $0 HPCA7_90_7_AGENT_PATCH 7_90 7 macosx_x86 "
                echo " Example : $0 HPCA7_80_10_AGENT_PATCH 7_80 10 macosx_x86 "
}

if [ $# -lt 1 ]
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

if [ $1 = LNX ]
	then
		echo "I am Linux machine"

elif [ $1 = MAC]
	then 
		echo "I am a MAC machine"

else [ $1 = WIN]
	then
		echo "I am a Win machine"

fi
