# 
#  
# Final list of binaries for patch
# File GetTheListOfBin.tcl
# Version 1.0
# Date: 29-July-2010
# Description : This script get the final list of binaries for cumulative patch
# 
#

source pcp.tcl

proc displayUsage {} {
	puts "USAGE: GetTheListOfBin.tcl \[-tag1 <start_tag> or -branch1 <start_branch>\] \[-tag2 <end_tag> or -branch2 <end_branch>\] -debug <1 or 0> -scm <cvs or svn> -raddir <radmaint_dir> -exclude <file_containing_list_of_filenames> -phere <Present_Directory> -sandbox <SANDBOX_Location>"
	puts "INFO: Distinguishing argument \[-tag1 <start_tag> or -branch1 <start_branch>\] "
	puts "      \[-tag2 <end_tag> or -branch2 <end_branch>\] is applicable only for SVN to "
	puts "      construct the URL. And is not applicable to CVS"
}

#
# 'main' procedure wrapper that takes first source-control tag, second source-control tag,
# directory to be searched to find the list of files to create the patch.
#
proc main {} {

	if {[llength $::argv] == 0} {
		displayUsage
		return 1
	}

	array set ::cfg $::argv
	nvd::init

	# variables to hold either a tag-name / branch-name irrespective of what argument was used in commandline
	set firstTag {}
	set secondTag {}
	if {![info exists ::cfg(-tag1)]} {
		if {![info exists ::cfg(-branch1)]} {
			puts "ERROR: \[-tag1 <tag-name> or -branch1 <branch-name>\] is a required parameter"
			displayUsage
			return 1
		}
	}
	if {[info exists ::cfg(-tag1)] && [info exists ::cfg(-branch1)]} {
		puts "ERROR: \[-tag1 <tag-name> or -branch1 <branch-name>\] are mutually-exclusive"
		displayUsage
		return 1
	}
	
	set isTagFirst 0
	if {[info exists ::cfg(-tag1)]} {
		set isTagFirst 1
		set firstTag $::cfg(-tag1)
	} elseif {[info exists ::cfg(-branch1)]} {
		set isTagFirst 0
		set firstTag $::cfg(-branch1)
	}
	
	if {![info exists ::cfg(-tag2)]} {
		if {![info exists ::cfg(-branch2)]} {
			puts "ERROR: \[-tag2 <tag-name> or -branch2 <branch-name>\] is a required parameter"
			displayUsage
			return 1
		}
	}
	
	if {[info exists ::cfg(-tag2)] && [info exists ::cfg(-branch2)]} {
		puts "ERROR: \[-tag2 <tag-name> or -branch2 <branch-name>\] are mutually-exclusive"
		displayUsage
		return 1
	}

	set isTagSecond 0
	if {[info exists ::cfg(-tag2)]} {
		set isTagSecond 1
		set secondTag $::cfg(-tag2)
	}
	if {[info exists ::cfg(-branch2)]} {
		set isTagSecond 0
		set secondTag $::cfg(-branch2)
	}
	
		set phereloc $::cfg(-phere)
		set sandboxloc $::cfg(-sandbox)
	
	puts "INFO: First Argument isTag : $isTagFirst"
	puts "INFO: First Tag/Branch name: $firstTag"
	puts "INFO: Second Argument isTag : $isTagSecond"
	puts "INFO: Second Tag/Branch name: $secondTag"
	puts "INFO: PHERE name	: $phereloc"
	puts "INFO: SANDBOX name: $sandboxloc"
	
	if {[info exists ::cfg(-debug)]} {
		if {$::cfg(-debug) == 1} {
			puts "INFO: Debug mode turned ON"
			set ::DEBUG 1
		} else {
			puts "INFO: Debug mode turned OFF"
			set ::DEBUG 0
		}
	} else {
		puts "INFO: Debug mode turned OFF"
		set ::DEBUG 0
	}

	if {![info exists ::cfg(-raddir)]} {
		puts "ERROR: Radmaint directory is a required parameter"
		displayUsage
		return 1
	}
	
	if {![info exists ::cfg(-phere)]} {
		puts "ERROR: PHERE directory is a required parameter"
		displayUsage
		return 1
	}
	
	if {![info exists ::cfg(-sandbox)]} {
		puts "ERROR: SANDBOX directory is a required parameter"
		displayUsage
		return 1
	}
	
	if {![info exists ::cfg(-scm)]} {
		puts "INFO: Defaulting SCM to svn"
		set ::isSVN 1
	} else {
		switch -exact $::cfg(-scm) {
			cvs {
				puts "INFO: scm flag set to cvs"
				set ::isSVN 0
			}
			
			svn {
				puts "INFO: scm flag set to svn"
				set ::isSVN 1
			}
			
			default {
				puts "ERROR: unsupported scm value $::cfg(-scm)"
				displayUsage
				return 1
			}
		}
	}

	file mkdir $::cfg(-raddir)
	if {![info exists ::cfg(-exclude)]} {
		puts "ERROR: -exclude <path to file containing list of files to be excluded> is a required parameter"
		displayUsage
		return 1
	}
	
	set excludeListFileName $::cfg(-exclude)
	if {[file readable $excludeListFileName] == 0} {
		puts "ERROR: $excludeListFileName is not readable by current user. Make sure the user running the script has adequate privilege to read from the file"
		return 2
	}
	if {[file size $excludeListFileName] == 0} {
		puts "INFO: Exclude file list is empty. Nothing to exclude"
	}

	# create empty lists
	set listOfCommonFiles [list]
	set listOfFiles [list]
	
	#
	# Looking for changes under agent
	#
	if {$::isSVN == 1} {
		#
		# shared/* is Model-2
		#
		set migrationModel 2
		set listOfCommonFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond shared common $::DEBUG $::isSVN $migrationModel $excludeListFileName]
		#
		# Agent/* is Model-1
		#
		set migrationModel 1
		set listOfFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond Agent agent $::DEBUG $::isSVN $migrationModel $excludeListFileName]
	} else {
		set listOfCommonFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond "" nvd/common $::DEBUG $::isSVN 0 $excludeListFileName]
		set listOfFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond "" nvd/agent $::DEBUG $::isSVN 0 $excludeListFileName]
	}

	set listOfAgentFiles [concat $listOfFiles $listOfCommonFiles]
	set agentCheckoutDir $sandboxloc/agent
	if {$::isSVN == 0} {
		set agentCheckoutDir {nvd/agent}
		set listOfAgentPrjFiles [getListOfProjectFiles $secondTag $agentCheckoutDir *.vcproj $listOfAgentFiles $::DEBUG]
	} else {
		#
		# TODO: set the SVN checkout directory for agent
		#
		set agentCheckoutDir $sandboxloc/agent
		set listOfAgentPrjFiles [getListOfProjectFiles $secondTag $agentCheckoutDir *.vcproj $listOfAgentFiles $::DEBUG]
	}
	
	set listOfAgentBinFiles [getListOfBin $phereloc/MapFile.txt $listOfAgentPrjFiles]
	puts "INFO: Agent files being copied to radmaint..."
	set i 0
			set abl [open agentbinlist.log a]
	while {[llength $listOfAgentBinFiles ] > $i} {
		#file copy -force $agentCheckoutDir/release/[lindex  $listOfAgentBinFiles $i]  $::cfg(-raddir)
			puts $abl "[lindex  $listOfAgentBinFiles $i]"
		set i [expr $i + 1]
	}
	
	#
	# Looking for changes in ConnectDefer
	#
	set listOfFiles [list]
	set listOfCDFFiles [list]
	set listOfCDFPrjFiles [list]
	set listOfCDFBinFiles [list]
	set cdfCheckoutDir $sandboxloc/ConnectDefer
	if {$::isSVN == 0} {
		set listOfFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond "" nvd/ConnectDefer $::DEBUG $::isSVN 0 $excludeListFileName]		
	} else {
		set migrationModel 1
		set listOfFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond Agent ConnectDefer $::DEBUG $::isSVN $migrationModel $excludeListFileName]
	}
	
	set listOfCDFFiles [concat $listOfFiles $listOfCommonFiles]
	
	if {$::isSVN == 0} {
		set cdfCheckoutDir {nvd/ConnectDefer}
		set listOfCDFPrjFiles [getListOfProjectFiles $secondTag $cdfCheckoutDir *.vcproj $listOfCDFFiles $::DEBUG]
	} else {
		set cdfCheckoutDir $sandboxloc/ConnectDefer
		set listOfCDFPrjFiles [getListOfProjectFiles $secondTag $cdfCheckoutDir *.vcproj $listOfCDFFiles $::DEBUG]
	}
	
	set listOfCDFBinFiles [getListOfBin $phereloc/MapFile.txt $listOfCDFPrjFiles ]
	
	puts "INFO: CDF files being copied to radmaint..."
	set i 0
			set cdfbl [open CDFbinlist.log a]
	while {[llength $listOfCDFBinFiles ] > $i} {
		#file copy -force $cdfCheckoutDir/release/[lindex  $listOfCDFBinFiles $i]  $::cfg(-raddir)
			puts $cdfbl "[lindex  $listOfCDFBinFiles $i]"
		set i [expr $i + 1]
	}
	
	#
	# Looking for changes in ConnectDefer
	#
	set listOfRSMFiles [list]
	set listOfRSMPrjFiles [list]
	set listOfRSMBinFiles [list]
	set rsmCheckoutDir $sandboxloc/RSM
	
	if {$::isSVN == 0} {
		set rsmCheckoutDir {nvd/ram/RSM/Win}
		set listOfRSMFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond "" $rsmCheckoutDir $::DEBUG $::isSVN 0 $excludeListFileName]
		set listOfRSMPrjFiles [getListOfProjectFiles $secondTag $rsmCheckoutDir *.csproj $listOfRSMFiles $::DEBUG]
	} else {
		set migrationModel 1
		set rsmCheckoutDir $sandboxloc/RSM/Win
		#set listOfRSMFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond Agent $rsmCheckoutDir $::DEBUG $::isSVN $migrationModel $excludeListFileName]
	set listOfRSMFiles [getModifiedFileList $firstTag $isTagFirst $secondTag $isTagSecond Agent RSM/Win $::DEBUG $::isSVN $migrationModel $excludeListFileName]
		set listOfRSMPrjFiles [getListOfProjectFiles $secondTag $rsmCheckoutDir *.csproj $listOfRSMFiles $::DEBUG]
	}
	
	set listOfRSMBinFiles [getListOfBin $phereloc/MapFile.txt $listOfRSMPrjFiles ]
	
	puts "INFO: RSM files being copied to radmaint..."
	set i 0
			set rsmbl [open RSMbinlist.log a]
	while {[llength $listOfRSMBinFiles ] > $i} {
		#file copy -force $rsmCheckoutDir/RadUIShell/bin/Release/[lindex  $listOfRSMBinFiles $i]  $::cfg(-raddir)
			puts $rsmbl "[lindex  $listOfRSMBinFiles $i]"
		set i [expr $i + 1]
	}
   	return 0
}

set DEBUG 0
set isSVN 1
exit [main]

