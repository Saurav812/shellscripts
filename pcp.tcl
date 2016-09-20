#  Azher Modified 08302012
# Patch Creation Project
# File pcp.tcl
# Version 1.0
# Date: 3-May-2010
# Description : This file contains functions that attempts to find list of files that have changed
# between any two CVS/SVN branches. The list of files are then searched in various vcproj files under
# nvd/agent to find where they are being used. Once that dependency is resolved, the list of modules to
# be built is created. These modules will be built as part of the patch process.
# Caveat :
# For CVS both tags and branches are supported. But for SVN only branches are supported. As the URL
# formation function always constructs it with the 'branches' in the path.
#

########################################################
# Functions that perform the patch pre-creation logic 
# of finding the files that have changed and then search 
# the map file to look for affected modules.
########################################################

proc getModifiedFileList {tag1 isTag1ATag tag2 isTag2ATag project dir DEBUG isSVN migModel excludeListFileName} {

	set pathRecs [split $dir "\\"]
	set convertedPath ""
	set pathElemLen [llength $pathRecs]
	set baseSVNURI {https://svn1.fc.hp.com/rg0203/bsaca-dev}
	set username {tsg-bsaca-dev-build}
	set password {caSVNbu1ldID}

	#
	# below piece of code runs if the dir parameter is a path element.
	# CVS directories are passed this way. But SVN is split into project
	# and dir parameters. If svn "dir" parameter has a path element we are 
	# not processing it.
	#
	if {$isSVN == 0} {
		foreach prec $pathRecs {
			append convertedPath $prec
			if {$pathElemLen == 1} {
				continue
			} else {
				append convertedPath "/"
			}
			set pathElemLen [expr $pathElemLen - 1]
		}
		if {[string length $convertedPath] > 0} {
			set ::dir $convertedPath
		}
	}
	
	#
	# Step 1: Find the files that have changed between two tags/branches.
	#
	set outFileName ""
	if {$isSVN == 0} {
		set outFileName [findChangedFilesInCVS $tag1 $tag2 $dir]
	} else {
		set svnFirstURI  [constructSVNURI $baseSVNURI $project $dir $tag1 $migModel $isTag1ATag]
		set svnSecondURI [constructSVNURI $baseSVNURI $project $dir $tag2 $migModel $isTag2ATag]
		set outFileName  [findChangedFilesInSVN $svnFirstURI $svnSecondURI $username $password $dir]
	}
	
	set outFileSize [file size $outFileName]
	set listOfFiles [list]
	set newListOfFiles [list]
	if {$outFileSize > 0} {
		#
		# Step 2: 
		#   Parse CVS outfile (created in step 1) and cut-out file names.
		#     -- or --
		#   Parse SVN outfile (created in step 1) and cut-out file names.
		#
		if {$isSVN == 0} {
			set listOfFiles [parseCVSOutFileAndReturnFileList $outFileName]
		} else {
			set listOfFiles [parseSVNOutFileAndReturnFileList $outFileName]
		}

		#
		# Process exclusion list
		#
		
		set newListOfFiles [processExclusionList $excludeListFileName $listOfFiles]
		
		puts "INFO: [llength $newListOfFiles] files have changed between $tag1 and $tag2 in $dir"
		set i 0
		if {$::DEBUG == 1} {
			while {[llength $newListOfFiles] > $i} {
				puts "DEBUG: [lindex $newListOfFiles $i]"
				set i [expr $i + 1]
			}
		}
	}
	return 	$newListOfFiles
}

proc getListOfBin {MapFile listOfPrjFiles} {

	set listOfFiles [list] 
	set lenOfWords 0

	set fd [open $MapFile r]
	while {[gets $fd line] >= 0} {
		set words [split $line " "]
		set fpName [lindex $words 0]
		set i 0
		while {[llength $listOfPrjFiles] > $i} {
			if {$fpName == [lindex $listOfPrjFiles $i]} {
				set lenOfWords [llength $words]	
				set numRemaining [expr $lenOfWords - 1]
				# lappend listOfFiles [lrange $words 1 $numRemaining]
				set listOfFiles [concat $listOfFiles [lrange $words 1 $numRemaining]]
				break
			} 
			set i [expr $i + 1]
		}
	}
	close $fd
	set i 0
	puts "INFO: List of detected binaries..."
	while {[llength $listOfFiles ] > $i} {
		puts "INFO: [lindex  $listOfFiles $i]"
		set i [expr $i + 1]
	}
	return $listOfFiles
}

proc getListOfProjectFiles {tag2 modulePath projFile listOfFiles DEBUG} {
	
	set affectedModuleCount 0
	set listOfAffectedModules [list]
	
	if {[llength $listOfFiles] > 0} {

		# checkoutFiles $modulePath $tag2
		#
		# Step 4: Now look for vcproj files under agent project folder.
		#
		set findPattern $projFile 
		set findFolder $modulePath 
		puts "INFO: Invoking findFiles $findFolder $findPattern"
		set listOfVcprojFiles [findFiles $findFolder $findPattern]
		puts "INFO: findFiles returned [llength $listOfVcprojFiles] $projFile files"
		set i 0
		if {$::DEBUG == 1} {
			while {[llength $listOfVcprojFiles] > $i} {
				puts "DEBUG: [lindex $listOfVcprojFiles $i]"
				set i [expr $i + 1]
			}
		}
		
		#
		# Step 5: Now shortlist the affected modules for patch by searching the list of
		# files changed identified in Step 2, and search/grep for each file in that list 
		# in the set of vcproj files identified in Step 4.
		#
		puts "INFO: Searching changed source file names in project files..."
		set iSrcIdx 0
		set iVcprojIdx 0
		set affectedModuleCount 0
		set found 0
		
		set listOfAffectedModules [list] 
		set listOfSourceFiles [list]
		set listOfSourceFiles [list]

		while {[llength $listOfVcprojFiles] > $iVcprojIdx} {
			if {$::DEBUG == 1} {
				puts "DEBUG: Processing [lindex $listOfVcprojFiles $iVcprojIdx]"
			}
			set iSrcIdx 0
			while {[llength $listOfFiles] > $iSrcIdx} {
				set found [findInFile [lindex $listOfVcprojFiles $iVcprojIdx] [lindex $listOfFiles $iSrcIdx] 1]
				if {$found == 1} {
					lappend listOfSourceFiles [lindex $listOfFiles $iSrcIdx]
				}
				set iSrcIdx [expr $iSrcIdx + 1]
			}
			if {$::DEBUG == 1} {
				puts "DEBUG: [lindex $listOfVcprojFiles $iVcprojIdx] has "
				set j 0
				while {[llength $listOfSourceFiles] > $j} {
					puts "DEBUG:  +[lindex $listOfSourceFiles $j]"
					set j [expr $j + 1]
				}
			}
			if {[llength $listOfSourceFiles] > 0} {
				set affectedModuleCount [expr $affectedModuleCount + 1]
				set moduleName [dirname [lindex $listOfVcprojFiles $iVcprojIdx]]
				set modFound [lsearch listOfAffectedModules $moduleName]
				if {$modFound == -1} {
					lappend listOfAffectedModules $moduleName
				}
				
			}
			set iVcprojIdx [expr $iVcprojIdx + 1]
			lset listOfSourceFiles {} {}
		}
	} else {
		puts "INFO: No files have changed for $tag2 in $modulePath"
	}
	puts "INFO: Found $affectedModuleCount affected modules"
	puts "INFO: Affected module names -"
	set i 0
	while {[llength $listOfAffectedModules] > $i} {
		puts "INFO:  [lindex $listOfAffectedModules $i]"
		set i [expr $i + 1]
	}
	return $listOfAffectedModules
}

# 
# processExclusionList
# Input arguments
#  exclusionListFile : path/to/file that contains a list of files to be excluded
#  listOfFiles : list of files from which the files in exclusion should be removed
# Return value
#  modifiedListOfFiles : if matches are found then this is the new exclusion processed list
#
proc processExclusionList {exclusionListFile listOfFilesChanged} {

	set fd 0
	catch { set fd [open $exclusionListFile r] }
	if {$fd == 0} {
		puts "ERROR: File specified for exclusion processing($exclusionListFile) does not exist"
		return 1
	}
	
	if {$::DEBUG == 1} {
		puts "DEBUG: Exclusion processing started, file is $exclusionListFile"
	}

	if {[file size $exclusionListFile] == 0} {
		# exclusionListFile is empty/zero size. So just return the original list
		return $listOfFilesChanged
	}

	while {[gets $fd fileName] >= 0} {
		set indexOfMatchingFile 0		
		set returnIndex [lsearch $listOfFilesChanged $fileName]
		if {$returnIndex != -1} {
			set listOfFilesChanged [lreplace $listOfFilesChanged $returnIndex $returnIndex]			
			if {$::DEBUG == 1} {
				puts "DEBUG: Source file excluded: $fileName"
			}
		}
	}
	close $fd
	return $listOfFilesChanged
}

##############################################################
# Functions that perform actions on the CVS repository
##############################################################

proc checkoutFilesFromCVS {modulePath tagName} {
	
	set cmd {cvs co}
	set commandPart1 {-r}
	set cmdString [format "%s %s %s" $commandPart1 $tagName $modulePath]

	puts "INFO: Command: $cmd $cmdString"
	if {[catch {eval exec $cmd $cmdString} results]} {
		# place-holder
	} else {
		# place-holder
	}
	return 0	
}

proc findChangedFilesInCVS {firstTag secondTag dirName} {
	
	set cmd {cvs rdiff}
	set commandPart1 {-s -r}
	set commandPart3 {-r}
	set cmdString [format "%s %s %s %s %s" $commandPart1 $firstTag $commandPart3 $secondTag $dirName]

	set pathRecs [split $dirName "/"]
	set fileName ""
	foreach prec $pathRecs { 
		append fileName $prec "_"
	}	
	puts "INFO: Command: $cmd $cmdString"
	if {[catch {eval exec $cmd $cmdString > $fileName} results]} {
		# place-holder
	} else {
		# place-holder
	}
	return $fileName
}

proc parseCVSOutFileAndReturnFileList {cvsOutFileName} {

	set fd [open $cvsOutFileName r]
	while {[gets $fd line] >= 0} {
		set words [split $line " "]
		set fpName [lindex $words 1]
		set pathList [split $fpName "/"]
		set fName [lindex $pathList [expr [llength $pathList] - 1]]
		lappend listOfFiles $fName
	}
	close $fd
	return $listOfFiles
}


############################################################
# Functions that perform actions on the SVN repository
############################################################

proc checkoutFilesFromSVN {svnURI username password} {
	
}

proc findChangedFilesInSVN {firstURI secondURI username password module} {

	set cmd {svn}
	set subCmd {diff}
	set usrArg {--username}
	set pwdArg {--password}
	set grepIndex {| grep ^Index}
	
	set svnCmd [format "%s %s %s %s %s %s %s %s" $usrArg $username $pwdArg $password $subCmd $firstURI $secondURI $grepIndex]
	puts "INFO: SVN Command : $cmd $svnCmd"
	
	set fileName ""	
	set pathRecs [split $module "/"]

	if {[llength $pathRecs] == 0} {
		set fileName $module
	} else {
		foreach prec $pathRecs { 
			append fileName $prec "_"
		}	
	}
	set outFileName [format "%s.%s" $fileName "log"]
	puts "INFO: Outfile name $outFileName"
	
	if {[catch {eval exec $cmd $svnCmd > $outFileName} results]} {
		# place-holder
	} else {
		# place-holder
	}
	return $outFileName
}

proc parseSVNOutFileAndReturnFileList {svnOutFileName} {

	set listOfFiles [list]
	
	puts "INFO: parseSVNOutFileAndReturnFileList : svnOutFileName = $svnOutFileName"
	if {[file exists $svnOutFileName] == 1} {
		if {[file size $svnOutFileName] > 0} {
			# file exists and its size is more than 0 bytes
			puts "INFO: File $svnOutFileName exists. Size = [file size $svnOutFileName]"
			set fd [open $svnOutFileName "r"]
			while {[gets $fd line] >= 0} {
				set columns [split $line " "]
				set lastColumnIdx [expr [llength $columns] - 1]
				set URI [lindex $columns $lastColumnIdx]
				set columns [split $URI "/"]
				set lastColumnIdx [expr [llength $columns] - 1]
				set fName [lindex $columns $lastColumnIdx]
				lappend listOfFiles $fName
			}
		}
	}
	close $fd
	return $listOfFiles
}

proc constructSVNURI {baseURI project module branch model isTag} {
	
	set branchesKeyword "branches"
	set retSVNURI $baseURI

	if {$isTag == 1} {
		set branchesKeyword "tags"
	} else {
		set branchesKeyword "branches"
	}
	
	if {$model == 1} {
		set retSVNURI [format "%s/%s/%s/%s/%s" $baseURI $project $branchesKeyword $branch $module]
	}
	
	if {$model == 2} {
		set retSVNURI [format "%s/%s/%s/%s/%s" $baseURI $project $module $branchesKeyword $branch]
	}
	
	return $retSVNURI 
}

###########################################################
# Functions below are general utility functions
###########################################################

proc dirname {pathName} {
		
		set pathList [split $pathName "/"]
		set fName [lindex $pathList [expr [llength $pathList] - 1]]
		return $fName
}

proc findFiles { basedir pattern } {

    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
    set basedir [string trimright [file join [file normalize $basedir] { }]]
    set fileList {}

    # Look in the current directory for matching files, -type {f r}
    # means ony readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty
    foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
	lappend fileList $fileName
    }

    # Now look for any sub direcories in the current directory
    foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
	# Recusively call the routine on the sub directory and append any
	# new files to the results
	set subDirList [findFiles $dirName $pattern]
	if { [llength $subDirList] > 0 } {
	    foreach subDirFile $subDirList {
		lappend fileList $subDirFile
	    }
	}
    }
    return $fileList
}

#
# A grep like function that searches for a regular expression
# in a given file.
# The below proc is a bit altered version of searchPattern 
# proc from http://wiki.tcl.tk/8405
#
proc findInFile { fileName searchPattern ignoreCase } {

	set fd [open $fileName "r"]
	set found 0
	set firstPos -1
	set lastPos -1
	
	while {[gets $fd line] >= 0} {
		if {$ignoreCase} {
			set match [regexp -nocase -indices -- $searchPattern $line indices]
		} else {
			set match [regexp -indices -- $searchPattern $line indices]
		}
		if {$match} {
			set  firstPos [lindex $indices 0]
			set  lastPos  [lindex $indices 1]
			set found 1
			break
		} else {
			set firstPos -1
			set lastPos -1
			set found 0
		}
	}
	if {$::DEBUG == 1} {
		if {$found == 1} {
			puts "DEBUG: findInFile $fileName $searchPattern $ignoreCase : FOUND"
		}
	}
	close $fd
	return $found
}

