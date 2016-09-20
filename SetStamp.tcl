#--------------------------------------------------------------------#
#  M a k e E x p o r t                                               #
#--------------------------------------------------------------------#
#
# $Header: /cvs/nvd/MakeExport/SetStamp.tcl,v 1.1 2009/08/26 20:33:25 galis Exp $
#
#
# $Log: SetStamp.tcl,v $
# Revision 1.1  2009/08/26 20:33:25  galis
# *** empty log message ***
#
#
global                  cfg

set cfg(starting)       [ expr wide(  [ clock seconds ] ) ]
set cfg(loglvl)         3
set cfg(havelog)        0
set cfg(thisos)         $::tcl_platform(platform)
set cfg(excludeext)     {(?i)\.(exe|dll|so|sl|dylib|bundle)$}
set cfg(xlatefunc)      {translate(%s,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz')}
set cfg(altchar)        "@"
set wstr                [ file normalize $argv0 ]
set cfg(rootpath)       [ file dirname $wstr ]
set cfg(scriptname)     [ file tail [ file rootname $wstr ] ]

if { $cfg(thisos) == "unix" } {
 set kit [ info nameofexe ]
} else {
 set kit [ file attributes [ info nameofexe ] -shortname ]
}
set cfg(KIT)            $kit


#----------------------------------------#
#  d u m p n a m e                       #
#----------------------------------------#
proc dumpname { _var } {
 upvar 1 $_var var
 puts "$_var :: $var"
}

#----------------------------------------#
#  p r o d u c t s                       #
#----------------------------------------#
proc products { product } {
  switch -- $product {
   RAM   { set ans "Client Automation Application Manager" }
   RSM   { set ans "Client Automation Software Manager"    }
   RIM   { set ans "Client Automation Inventory Manager"   }
   ROM   { set ans "Client Automation OS Manager Server"   }
   SRV   { set ans "Client Automation Server Manager"      }
   PATCH { set ans "Client Automation PATCH Manager"       }
   default {
    set ans "?"
    echo "$product is not defined"
   }
  }
  return $ans
}

#----------------------------------------#
#  l o a d x m l                         #
#----------------------------------------#
proc loadxml { xmlfile } {
  global cfg

  set rc [ catch { open $xmlfile r } handle ]
  if { $rc } { done "Can't open $xmlfile - $handle" }

  echo "Processing XML file $xmlfile"

  set rc [ catch { dom parse -channel $handle } doc  ]
  if { $rc } { done "XML syntax error - $doc" }

  close $handle

  set cfg(xdoc) $doc
  $doc documentElement node

  set cfg(xnode) $node

  set tagname [ $node nodeName ]

  if { [ string compare $tagname "Modules" ] } {
   Done "Expected tag 'Modules' not found"
  }

  if { 0 == [ $node hasChildNodes ] } {
   Done "Expected children not found"
  }

  set xlate(/)  $cfg(altchar)
  set xlate(\\) $cfg(altchar)
  set xtable    [ array get xlate ]

  for { $node firstChild item } { "" != $item } { $item nextSibling item } {
   if { 0 == [ $item hasAttribute Name ] } {
    done "Attribute 'Name' is missing"
   }

   set wstr [ string tolower [ $item getAttribute Name ] ]
   set name [ string map $xtable $wstr ]

   $item setAttribute AltName $name

   if { [ info exists altname($name) ] } {
    incr altname($name)
   } else {
    set altname($name) 1
   }

   if { 0 == [ $item hasAttribute Product ] } {
    done "Attribute 'Product' is missing"
   }
   set prod [ $item getAttribute Product ]
   set prodID($name) $prod

   echo "Processing item $name -- $prod"

   if { [ info exists P($prod) ] } {
    incr P($prod)
   } else {
    set P($prod) 1
   }

   if { 0 == [ $item hasAttribute Stamp ] } {
    echo "Attribute 'Stamp' add with value 'No'"
    $item setAttribute Stamp No
   }

   if { [ $item hasAttribute Attrs ] } {
    set attrs [ $item getAttribute Attrs ]
    set wlist [ eval list $attrs ]
    set rc [ catch { array set test $wlist } ]
    if { $rc } {
     done "Attribues -- $attrs -- not a key/value pair"
    }
    unset test attrs wlist
   }
  }

  set dups 0
  foreach name [ array names altname ] {
   if { $altname($name) > 1 } {
    echo "The file $name occurs $altname($name) times"
    incr dups
   } else {
    echo "$name -- Added to the modules DB($prodID($name))"
   }
  }
  if { $dups > 0 } {
   done "Duplicate filename in xml file"
  }

  set cfg(products) [ array names P ]

  foreach prod $cfg(products) {
   echo "$prod  has $P($prod) items"
  }

  return $cfg(products)
}

#----------------------------------------#
#  p r o d u c t f i l e s               #
#----------------------------------------#
proc productfiles { product } {
 global cfg

 set search [ format {//Module[@Product='%s']} $product ]
 set nodes [ $cfg(xnode) selectNode $search ]

 set files {}
 set altfiles {}
 foreach node $nodes {
  set name [ $node getAttribute Name "?" ]
  lappend files $name
  set name [ $node getAttribute AltName "?" ]
  lappend altfiles $name
 }
 return [ list $files $altfiles ]
}

#----------------------------------------#
#  f i x t k d                           #
#----------------------------------------#
proc fixtkd { root name } {
 global cfg

 set wstr [ file join $root $name ]

 if { "unix" == $cfg(thisos) } {
  set fid $wstr

 } else {
  set rc [ catch { file attributes $wstr -shortname } fid ]
  if { $rc } {
   set fid $wstr
  }
 }

 return $fid
}

#----------------------------------------#
#  c l e a n n a m e                     #
#----------------------------------------#
proc cleanname { file } {

  global cfg

  if { [ regexp $cfg(excludeext) $file ] } {
   set ans [ file rootname $file ]
  } else {
   set ans $file
  }

  return $ans
}

#----------------------------------------#
#  c l e a n n a m e s                   #
#----------------------------------------#
proc cleannames { files } {
  set ans {}
  foreach file $files {
   lappend ans [ cleanname $file ]
  }
  return $ans
}

#----------------------------------------#
#  f i l e d e l e t e                   #
#----------------------------------------#
proc filedelete { file } {
 if { [ file exists $file ] } {
  echo "Deleting file $file"
  catch { file delete -force $file }
 }
}

#----------------------------------------#
#  d e l d i r                           #
#----------------------------------------#
proc deldir { dirname } {
  global cfg
  if { [ file exists $dirname ] } { file delete -force $dirname }
}

#----------------------------------------#
#  c r e d i r                           #
#----------------------------------------#
proc credir { dirname } {
 set name [ file join [ tmpdir ] [ format "%s.%d.%d" $dirname [ pid ] [ random 99999 ] ] ]
 deldir $name
 set rc [ catch { file mkdir $name } ]
 if { $rc } {
  done "Can't create directory $name"
 }
 return $name
}

#----------------------------------------#
#  c o p y f i l e                       #
#----------------------------------------#
proc copyfile { sfile tfile } {

  if { [ file exists $sfile ] } {

   if { [ file exists $tfile ] } { filedelete  $tfile }

   set rc [ catch { file copy -force $sfile $tfile } ans ]
   if { $rc } {
    done "Error $ans while copying $sfile to $tfile"
   } else {
    echo "Copied $sfile to $tfile"
   }

  } else {
   done "Can't find $sfile"
  }
}

#----------------------------------------#
#  u p d a t e c f i l                   #
#----------------------------------------#
proc updatecfil { fullname } {

 global cfg

 set pp [ string first $cfg(altchar) $fullname ]

 if { $pp >= 0 } {

   if { "unix" == $cfg(thisos) } {
    set m($cfg(altchar)) "/"
   } else {
    set m($cfg(altchar)) "\\"
   }

   set wstr       [ file tail $fullname ]
   set searchname [ string tolower $wstr ]
   set cfil       [ string map [ array get m ] $wstr ]

   echo "Searching -- $fullname -- $searchname"

   set xlate [ format $cfg(xlatefunc) "@AltName" ]
   set search [ format {//Module[%s='%s' and @Product='%s']} @AltName $searchname $cfg(prd) ]

   echo "XPath(cfil) -- $search"

   set node [ $cfg(xnode) selectNode $search ]

   set count [ llength $node ]

   if { $count > 1 } {
    done "Duplicate names -- $searchname"

   } elseif { $count == 0 } {
    done "Not found -- $searchname"

   } else {
    set attrs [ $node getAttribute Attrs "?" ]

    if { "?" != $attrs } { array set a $attrs }

    set a(ZRSCCFIL) [ format "%s%s" $m($cfg(altchar)) $cfil ]

    $node setAttribute Attrs [ array get a ]

    set updated [ $node getAttribute Attrs "?" ]

    if { "?" ==  $updated } {
     done "Internal error -- no attributes"
    } else {
     echo "Update/Added database attributes for $fullname -- $updated"
    }
   }
 }
}


#----------------------------------------#
#  f l a t n a m e                       #
#----------------------------------------#
proc flatname { file } {

  global cfg

  set pp [ string first "/" $file ]

  if { $pp < 0 } {
   set ans $file
  } else {
   set map [ list "/" $cfg(altchar) ]
   set ans [ string map $map $file ]
   echo "Flatname -- $file -- $ans"
  }
  return $ans
}

#----------------------------------------#
#  c o p y f i l e s                     #
#----------------------------------------#
proc copyproductfiles { sdir tdir { ProductFilenames "*" } } {
 global cfg

 set sfiles [ glob -nocomplain -directory $tdir * ]
 foreach tfile $sfiles {
  filedelete  $tfile
 }


 if { "" == $ProductFilenames || "*" == $ProductFilenames } {
  echo "Copying all file from $sdir"
 } else {
  foreach item $ProductFilenames {
   set wstr [ string tolower $item ]
   set table($wstr) 1
  }
 }

 set count 0

 for_recursive_glob sfile $sdir "*" {

  set copied 0
  if { 0 == [ file isdirectory $sfile ] } {

   set fid   [ filetailex $sfile $sdir ]
   set flat  [ flatname $fid ]

   set tfile [ file join $tdir $flat ]

   if { "" == $ProductFilenames || "*" == $ProductFilenames } {
    copyfile $sfile $tfile
    incr count
    incr copied

   } else {
    set name [ file tail $tfile ]
    set wstr [ string tolower $name ]
    if { [ info exists table($wstr) ] > 0 } {
     copyfile $sfile $tfile
     incr count
     incr copied
    } else {
     echo "Skipping $sfile (not part of $cfg(prd))"
    }
   }

   if { $copied > 0 } { updatecfil $tfile }
  }

 }
 return $count
}

#----------------------------------------#
#  e c h o                               #
#----------------------------------------#
proc echo { text } {
  global cfg
  if { $cfg(havelog) } {
   syslog 0 $text
  } else {
   puts $text
  }
}

#----------------------------------------#
#  d o n e                               #
#----------------------------------------#
proc done { text } {
 global cfg
 if { "" != $text } {
  echo $text
 }
 if { 1 == $cfg(havelog) } log.close
 exit -1
}

#----------------------------------------#
#  f i l e t a i l                       #
#----------------------------------------#
proc filetailex { file { prefix "" } } {

 global cfg

 if { "" == $prefix | "unix" == $cfg(thisos) } {
  set ans [ file tail $file ]

 } else {

  if { 0 == [ catch { file attributes $file -longname } lfile ] } {
    set file $lfile
  }

  if { 0 == [ catch { file attributes $prefix -longname } lprefix  ] } {
    set prefix $lprefix
  }

  set patten [ format {(?i)^%s(.+)$} $prefix ]
  set state  [ regexp $patten $file match tail ]

  if { $state } {
   if { "/" == [ string range $tail 0 0 ] } {
    set ans [ string range $tail 1 end ]
   } else {
    set ans $tail
   }

  } else {
   set [ file tail $lfile ]
  }
 }

 return $ans
}

#----------------------------------------#
#  t m p d i r                           #
#----------------------------------------#
proc tmpdir {} {
   global cfg

   if { [ info exists ::env(TEMP) ] } {
    set tmp $::env(TEMP)
   } elseif { [ info exists ::env(TMP) ] } {
    set tmp $::env(TMP)
   } else {
    set tmp {}
   }

   if { "" == $tmp } {
    switch -- $cfg(thisos) {
     windows {
      set tmp "c:/"
     }
     unix {
      set tmp "/tmp"
     }
     default {
       set tmp "./"
     }
    }
   }

   return $tmp
}

#----------------------------------------#
#  r u n                                 #
#----------------------------------------#
proc run { cmd } {

  set wstr $cmd
  set tfid [ file join [ tmpdir ] [ format "out%d.tmp" [ random 99999 ] ] ]
  set cmd  [ lconcat exec $cmd ">&" $tfid ]
  set rc [ catch { eval $cmd } errortext ]

  set l [ string repeat "<" 20 ]
  set r [ string repeat ">" 20 ]

  echo "$l $wstr $r"

  if { [ file exists $tfid ] } {
   set f [ open $tfid ]
   while {1} {
    set line [gets $f]
    if {[eof $f]} {
      close $f
      break
    }
    echo "$line"
   }
  }
  filedelete  $tfid

  if { $rc } {
   done "Error ($errortext) running ($cmd)"
  }
}

#----------------------------------------#
#  q q                                   #
#----------------------------------------#
proc qq { text } {
 return [ format "\"%s\"" $text ]
}

#----------------------------------------#
#  b b                                   #
#----------------------------------------#
proc bb { text } {
 return [ format "{%s}" $text ]
}

#----------------------------------------#
#  c o n n e c t r c s                   #
#----------------------------------------#
proc connectrcs {} {

  global cfg

  if { "" == $cfg(pass) } {
   set auth [ list -user $cfg(user)  ]
  } else {
   set auth [ list -user $cfg(user) -pass $cfg(pass) ]
  }

  set tp [ lconcat [ list nvdadm #auto -host $cfg(rcs) -port $cfg(port) ] $auth ]
  set tp [ eval $tp ]

  set rc [ catch { $tp connect } reason ]
  if { $rc } {
   done "Can't connect to the RCS $cfg(rcs)"
  }

  return $tp
}


#----------------------------------------#
#  f i n d c o n n e c t s               #
#----------------------------------------#
proc findconnects { ltemp } {

   array set temp $ltemp

   set connects {}
   foreach name [ array names temp ] {
    set type [ lindex $temp($name) end ]
    set type [ format "%c" $type ]
    switch -exact -- $type {
      C -
      A -
      I -
      R -
      O { lappend connects $name }
      default {}
    }
   }
   return $connects
}


#----------------------------------------#
#  f i x v e r i f y f l a g s           #
#----------------------------------------#
proc fixverifyflags { tp FDCI stamp } {

  lassign [ $tp get $FDCI ] ltemp lheap
  array set heap $lheap

  if { [ info exists heap(ZRSCVRFY) ] } {

   set stamppos -1
   set len      [ clength $heap(ZRSCVRFY) ]
   for { set ii 0 } { $ii < $len } { incr ii } {
    if { "R" == [ cindex $heap(ZRSCVRFY) $ii ] } {
     set stamppos $ii
     break
    }
   }

   if { "Yes" == $stamp } {

    if { $stamppos < 0 } {
     echo "Modifying $FDCI -- adding 'R' flag to ZRSCVRFY"
     set wstr [ format "R%s" $heap(ZRSCVRFY) ]
     set cmd [ lconcat [ list $tp modify $FDCI ] ZRSCVRFY $wstr ]
     echo "Running $cmd"
     eval $cmd
    } else {
      echo "Instance $FDCI has 'R' flag in ZRSCVRFY"
    }

   } elseif { "No" == $stamp } {

    if { $stamppos >= 0 } {
     echo "Modifying $FDCI -- removing 'R' flag from ZRSCVRFY"

     set wstr {}
     set len  [ clength $heap(ZRSCVRFY) ]
     for { set ii 0 } { $ii <  $len } { incr ii } {
      if { $ii != $stamppos } {
       set wstr [ format "%s%s" $wstr [ cindex $heap(ZRSCVRFY) $ii ] ]
      }
     }
     set cmd [ lconcat [ list $tp modify $FDCI ] ZRSCVRFY $wstr ]
     echo "Running $cmd"
     eval $cmd
    } else {
      echo "Instance $FDCI attribute ZRSCVRFY is correct"
    }

   } else {
    done "Internal error - no stamp value"
   }

  }
}




#----------------------------------------#
#  p r o d u c t f i l e                 #
#----------------------------------------#
proc productfile { tdir } {

 global cfg

 set product $cfg(prd)

 set pdesc [ products $product ]
 if { "?" == $pdesc } {
  set pdesc "Product :: $product"
 }

 set pfile [ file join $tdir [ format "PRODUCT.%s" $product ] ]
 filedelete  $pfile

 set now   [ clock seconds ]
 set ts    [ clock format $now -format "%Y%m%d" ]

 set pfid [ open $pfile w ]
 fconfigure $pfid -translation auto

 puts $pfid "ID=$product"
 puts $pfid "Name=$pdesc"
 puts $pfid [ format "Release=%d.%d" $cfg(major) $cfg(iMinor) ]
 puts $pfid [ format "Level=%d.%d.%d" $cfg(major) $cfg(iMinor) $cfg(sp) ]
 puts $pfid "SPLevel=$cfg(sp)"
 puts $pfid "Fixpack=$cfg(sp)"
 puts $pfid "LastUpdated=$ts"
 puts $pfid "Created=$ts"

 close $pfid
}

#----------------------------------------#
#  s t a m p                             #
#----------------------------------------#
proc stamp { tdir } {

  global cfg

  set product $cfg(prd)

  set StampTkd [ fixtkd $cfg(rootpath) stamp.tkd ]

  set rel [ format "%d.%d" $cfg(major) $cfg(iMinor) ]

  if { 0 == [ file exists $StampTkd ] } {
   done "Can't find stamp.StampTkd"
  }

  set allfiles [ glob -nocomplain -directory $tdir * ]

  set files {}
  foreach file $allfiles {

   set name       [ file tail $file ]
   set altname    [ string tolower $name ]

   set searchname [ string tolower $name ]

   set xlate [ format $cfg(xlatefunc) "@AltName" ]
   set search [ format {//Module[%s='%s' and @Product='%s']} @AltName $searchname $cfg(prd) ]
   echo "XPath(stamp) -- $search"

   set nodes [ $cfg(xnode) selectNode $search ]

   if { "" == $nodes } {
    echo "Stamp: skipping $file (not found)"

   } else {
    set match 0
    set count 0

    foreach node $nodes {
     incr match
     set name  [ $node getAttribute Name ]
     set alt   [ $node getAttribute AltName ]
     echo "Match $match item($file) name($name) altname($alt)"

     set stamp [ $node getAttribute Stamp "?" ]
     switch -exact -- $stamp {
      Yes     { incr count }
      No      { echo "Stamp: skipping $file (No Stamp)" }
      "?"     { echo "Stamp: skipping $file (Undefined)" }
      default { echo "Stamp: skipping $file (<Nill>)" }
     }
    }
    if { $count > 0 } { lappend files $file }
   }
  }

  if { [ llength $files ] > 0 } {
   echo "Stamping $files"

   set cmd [ lconcat [ list $cfg(KIT) $StampTkd trim ] $files ]
   run $cmd

   set o(-product)     $product
   set o(-set:SPLevel) $cfg(sp)
   set o(-set:Release) $rel
   set o(-set:Fixnum)  0

   set cmd [ lconcat [ list $cfg(KIT) $StampTkd set ] [ array get o ] $files ]
   run $cmd

   set cmd [ lconcat [ list $cfg(KIT) $StampTkd get ] $files ]
   run $cmd
  }
}


#----------------------------------------#
#  s a v e m o d u l e s                 #
#----------------------------------------#
proc savemodules { sdir tdir } {

 global cfg

 echo "Saving product $cfg(prd) modules"
 foreach sfile  [ glob -nocomplain -directory $sdir * ] {
  set name  [ file tail $sfile ]
  set tfile [ file join $tdir $name ]
  copyfile $sfile $tfile
 }
}

#----------------------------------------#
#  f i x m o d d i r                     #
#----------------------------------------#
proc fixmoddir { dir } {

   global cfg
   set m($cfg(altchar)) "/"

   set files [ glob -nocomplain -directory $dir * ]

   foreach file $files {
    set pp [ string first $cfg(altchar) $file ]
    if { $pp >= 0 } {

     set realfile [ string map [ array get m ] $file ]
     echo "Move: $file -- $realfile"

     set realpath [ file dirname $realfile ]
     file mkdir $realpath
     echo "Creating $realpath ..."

     file copy $file  $realfile
     file delete -force $file
    }
   }

   if { "unix" == $cfg(thisos) } {
     set files [ recursive_glob $dir "*"  ]
     echo "chxxx files - $files"
     catch {  chgrp sys $files }
     catch {  chmod 755 $files }
     catch {  chown root $files }
   }
}



#----------------------------------------#
#  m a i n                               #
#----------------------------------------#
#
# switches
set switches [ list -source -target -sp -release -xml ]

# command line
if { "" == $argv } {
 echo "Switches are:"
 foreach item $switches {
  lassign [ split $item ":" ] name
  echo " $name"
 }
 exit 0
}

set rc [ catch { array set args $argv } ]
if { $rc } {
 done "Invalid command line syntax: $argv"
}

# process switches
foreach wstr $switches {
 lassign [ split $wstr ":" ] item ival
 if { [ info exists args($item) ] } {
  if { [ string length args($item) ] > 0 } {
   set name [ string range $item 1 end ]
   set cfg($name) $args($item)
  } else {
   done  "NULL value specified for $item"
  }
 } else {
  if { "" == $ival } {
   done "$item not specified"
  } else {
   set name [ string range $item 1 end ]
   if { "?" == $ival } {
    set cfg($name) {}
   } else {
    set cfg($name) $ival
   }
  }
 }
}

# set log file
set cfg(log) [ file join $cfg(rootpath) ${cfg(scriptname)}.log ]

# open log file
log.init
log.configure -level $cfg(loglvl) -file $cfg(log) -mode w
set cfg(havelog) 1


# test input
set cfg(source) [ file normalize $cfg(source) ]
if { 0 == [ file isdir $cfg(source) ] } {
 done "Source $cfg(source) is not a directory"
}

# test target
set cfg(target) [ file normalize $cfg(target) ]
if { 0 == [ file isdir $cfg(target) ] } {
 done "Target $cfg(target) is not a directory"
}

# test release
if { [ ctype -failindex offset digit $cfg(release) ] } {
 done "Minor value not specified in release $cfg(release)"
} else {
 set breakchar [ csubstr $cfg(release) $offset 1 ]
 lassign [ split $cfg(release) $breakchar ] major minor
}

# set major
if { 0 == [ string is integer -strict $major ] } {
 done "release/major $major is not an integer"
} else {
 set cfg(major) $major
}

# set iMinor xMinor
if { 0 == [ string is integer -strict $minor ] } {
 done "release/minor $minor is not an integer"
} else {
 if { $minor > 99 } {
  done "Minor value $minor need to be no more than two digits"
 } else {
  if { 1 == [ clength $minor ] } {
   set cfg(iMinor) $minor
   set cfg(xMinor) "${minor}0"
  } else {
   set cfg(iMinor) [ csubstr $minor 0 1 ]
   set cfg(xMinor) $minor
  }
 }
}


# process xml file
set productnames [ loadxml $cfg(xml) ]

# build work directories
set cfg(moddir) [ credir moddir ]
set cfg(expdir) [ credir expdir ]

echo "Source directory $cfg(source)"
echo "Target directory $cfg(target)"
set  totalcount 0

#--------------------------------------------------------------------#
#  p r o c e s s                                                     #
#--------------------------------------------------------------------#

set cfg(HaveCORE) 0
foreach prod $productnames {

    echo "++++ Processing product $prod ++++"

    set cfg(prd) $prod

    lassign [ productfiles $prod ] productfilenames altproductfilenames

    set count [ copyproductfiles $cfg(source) $cfg(target) $altproductfilenames ]
    incr totalcount $count

    if { $count > 0 } {
      if { "RAM" == $prod || "RSM" == $prod } {
       if { $cfg(HaveCORE) == 0 } { set cfg(HaveCORE) 1 }
      } else {
       set cfg(Have$prod) 1
      }
    }

    set errortext ""
    set have [ array names cfg -glob Have* ]
    set subtotal 0
    foreach item $have {
     set errortext [ format "%s %s=%d " $errortext $item $cfg($item) ]
     incr subtotal $cfg($item)
    }
    
    if { $count > 0 } {
     echo "Processing $count files for product $prod"
    } else {
     echo "No files to process for product $prod"
     continue
    }

# stamp the files
	stamp              $cfg(target)

# create the product file (patch)
productfile $cfg(target) 


# save modules for later archive
  savemodules         $cfg(target)  $cfg(moddir)

}
  savemodules         $cfg(moddir)  $cfg(target)

set now  [ clock seconds ]
set diff [ expr $now - $cfg(starting) ]

echo "Finished -- duration [ clock format $diff -format {%H:%M:%S} -gmt 1 ]"

log.close

exit 0
