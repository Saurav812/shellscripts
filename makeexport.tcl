#--------------------------------------------------------------------#
#  M a k e E x p o r t                                               #
#--------------------------------------------------------------------#
#
# $Header: /cvs/nvd/MakeExport/makeexport.tcl,v 1.22 2009/09/07 14:37:05 jangow Exp $
#
#
# $Log: makeexport.tcl,v $
# Revision 1.22  2009/09/07 14:37:05  jangow
# Enabled compression for hot-fixes and patches
#
# Revision 1.21  2009/08/11 06:12:52  jangow
# Rebranding changes, replaced Radia with Client Automation, Radia was showing up in PRODUCT.* files
#
# Revision 1.20  2009/08/02 10:25:14  jangow
# Added support for digital signing of modules, see make_export.doc for details
#
# Revision 1.19  2009/08/02 09:50:40  jangow
# Added support for digital signing of modules, see make_export.doc for details
#
# Revision 1.18  2009/08/02 07:36:06  jangow
# Added support for digital signing of modules, see make_export.doc for details
#
# Revision 1.17  2009/06/24 21:00:32  frank
# Added info on the valid names for -os switch
#
# Revision 1.16  2009/06/19 21:43:28  frank
# Fixed issue with the naming of rcs db hotfix instances
#
# Revision 1.15  2009/06/19 00:56:19  frank
# added support to create a hotfix
#
# Revision 1.14  2009/06/15 17:14:24  frank
# Fixed issue with matching the module name due to the case of the file.
#
# Revision 1.13  2009/06/11 16:51:37  frank
# add _NONE_ to ZDELETE for all promoted resources
#
# Revision 1.12  2009/06/09 16:18:27  frank
# created objxfer in rootpath
#
# Revision 1.11  2009/06/08 18:04:25  frank
# Fix issue with setting _ALLWAYS_ to _NULL_ not _NONE_
#
# Revision 1.10  2009/06/01 22:37:39  frank
# Change matching for product files.
#
# Revision 1.9  2009/05/29 01:43:05  frank
# added raddbutil log file names
#
# Revision 1.8  2009/05/22 20:00:13  frank
#
# Fixed issued with XPath searching
#
# Revision 1.7  2009/05/22 17:41:59  frank
#
# Fixed issued with post-promote procesing of the ZRSCCFIL attribute
#
# Revision 1.6  2009/05/22 15:08:29  frank
#
# Fixed issued with sub-directories within the scope context of the source
# directory, which included a correct value for zrsccfil in the export deck.
#
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
set cfg(signutil)                 HPSign.bat
set cfg(tempsigndir)       __tempsigndir__

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
#  g e t p r o m o t e d f i l e s       #
#----------------------------------------#
proc getpromotedfiles { FDCI } {

  global cfg

  set tp [ connectrcs ]

  set rc [ catch { $tp get $FDCI } info ]
  if { $rc } {
    done "Can't find $FDCI - $info"
  }

  lassign $info template heap

  set prefix [ pget $heap ZOBJID ]

  if { "unix" == $cfg(thisos) } {
   set class UNIXFILE
  } else {
   set class FILE
  }

  lassign [ split $FDCI "." ] F D C I

  set search [ format "%s.%s.%s.%s_*" $F $D $class $prefix ]
  set ltemp  [ $tp enum $search ]

  set items  [ lrange $ltemp 1 end ]

  set modules {}
  foreach item  $items {

   set module [ pget $item ALIAS ]
   set inst   [ pget $item INSTANCE ]

   set temp   [ file normalize $module ]
   set module [ file tail $temp ]

   lappend modules $module [ format "%s.%s.%s.%s" $F $D $class $inst ]
  }

  $tp close

  return $modules
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
#  m o d i f y i n s t a n c e           #
#----------------------------------------#
proc modifyinstance { tp FDCI attrs { skip 0 } } {

global cfg

if { 0 == $skip } {
  lassign [ $tp get $FDCI ] ltemp lheap
 array set heap $lheap

  set allconnects [ findconnects $ltemp ]

# this module is move into the IDMSYS, not IDMSYS/_MAINT_
  set a(ZRSCVRFY)   RU
  set a(LOCATION)   {&(ZMASTER.ZSYSDRV)&(ZMASTER.ZSYSDIR)}

# Set connections that point to something to _NULL_
  foreach connect $allconnects {
   if { $heap($connect) != "" } {
     set a($connect) _NULL_
   }
  }
}

# override any values
if { "" != $attrs } {
  array set a $attrs
}

if { [ info exists a ] } {
  echo "Modifying $FDCI"
  set cmd [ lconcat [ list $tp modify $FDCI ] [ array get a ] ]
  echo "Running $cmd"
  eval $cmd
}
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
#  p o s t p r o m o t e                 #
#----------------------------------------#
proc postpromote { promotedfiles } {

  global cfg

  echo "Promote files"
  foreach { item FDCI } $promotedfiles {
    echo "FDCI -> $FDCI $item"
  }

  set search [ format {//Module[@Attrs]}]
  set nodes [ $cfg(xnode) selectNode $search ]

  set search [ format {//Module[@Stamp]}]
  set stamps [ $cfg(xnode) selectNode $search ]

  set tp [ connectrcs ]

  foreach { module FDCI } $promotedfiles {

   # special processing for well-known agent module -
   switch -regexp -- $module {
    "PRODUCT\..+" {
     set attrs [ list ZDELETE _NONE_ ZRSCVRFY Y ]
     echo "Post-Promote - found $module in $FDCI"
     modifyinstance $tp $FDCI $attrs
    }

   # special processing for well-known agent module -
    "(?i)upgrdmaint" {
     set attrs [ list ZDELETE _NONE_ ]
     echo "Post-Promote - found $module in $FDCI"
     modifyinstance $tp $FDCI $attrs
    }
   }

   # Make sure that the 'R' flag in zrcsvrfy is correct
   # Find the node that the altname is module
   foreach stamp $stamps {
    set altname  [ $stamp getAttribute AltName "?" ]
    set stampval [ $stamp getAttribute Stamp 'No' ]

    if { "?" == $altname } { done "Internal error" }

    if { [ string equal -nocase $module $altname ] } {
     echo "Post-Promote - checking ZRSCVRFY for 'R' flag"
     fixverifyflags $tp $FDCI $stampval
     break
    }
   }

   # override attributes via contents of the xml file
   # Find the node that the altname is module
   foreach node $nodes {
    set altname [ $node getAttribute AltName "?" ]

    if { "?" == $altname } { done "Internal error" }

    if { [ string equal -nocase $module $altname ] } {
     set attrs   [ eval list [ $node getAttribute Attrs "?" ] ]
     echo "Post-Promote - Attributes '$attrs' for $module in $FDCI"
     modifyinstance $tp $FDCI $attrs 1
     break
    }
   }
  }

 $tp close
}


#----------------------------------------#
#  p r o m o t e                         #
#----------------------------------------#
proc promote { tdir } {

  global cfg

  set product $cfg(prd)
  set pmt     [ fixtkd $cfg(rootpath) promote.tkd ]

  if { 0 == [ file exists $pmt ] } {
   done "Can't find promote.tkd"
  }

  set ppath "PRIMARY.PRDMAINT"
  set cfile [ file join [ tmpdir ] [ format "cfg%d.tmp" [ random 99999 ] ] ]
  set pdir  [ file dirname $pmt ]

  if { "unix" == $cfg(thisos) } {
   set split 3
   set class unixfile
  } else {
   set class file
   set split 2
  }

  set os $cfg(osPackage)

  if { 0 == $cfg(fixno) } {
   set pInstanceName [ format "%s_%s_%d_%d_%d" $product $os $cfg(major) $cfg(xMinor) $cfg(sp) ]
  } else {
   set pInstanceName [ format "%s_%s_%d_%d_HF_%s" $product $os $cfg(major) $cfg(iMinor) $cfg(fixname) ]
  }
  set pInstanceName [ string toupper $pInstanceName ]

  set logfile     [ file join $pdir promote.log ]
  set location    "&(ZMASTER.ZROOTDRV)&(ZMASTER.ZROOTDIR)_MAINT_"

  if { [ file exists $logfile ] } {
   filedelete  $logfile
  }

  set fid [ file join $pdir pkgs.dat ]
  if { [ file exists $fid ] } {
   filedelete  $fid
  }

  set cfid  [ open $cfile w ]

  puts $cfid  "path $ppath"
  puts $cfid  "compress 1"
  puts $cfid  "intype SCAN"
  puts $cfid  "loglvl $cfg(loglvl)"
  puts $cfid  "logfile [ qq $logfile ]"

  puts $cfid  "filescan {"
  puts $cfid  " dir [ qq $tdir ]"
  puts $cfid  " distroot [ bb $location ]"
  puts $cfid  " numsplit $split"
  puts $cfid  " depth -1"
  puts $cfid  "}"

  puts $cfid  "filters file {"
  puts $cfid  " type   file"
  puts $cfid  " class  $class"
  puts $cfid  " exclude [ qq "" ]"
  puts $cfid  " include [ qq "*" ]"
  puts $cfid  " attr {"
  puts $cfid  "  PRODUCT  $product"
  puts $cfid  "  LOCATION $location"
  puts $cfid  "  LEVEL    [ format "%d.%d.%d.%d"  $cfg(major) $cfg(iMinor) $cfg(sp) 0 ]"
  puts $cfid  "  RELEASE  [ format "%d.%d" $cfg(major) $cfg(iMinor) ]"
  puts $cfid  "  SPLEVEL  $cfg(sp)"
  puts $cfid  "  FIXNUM   $cfg(fixno)"
  puts $cfid  "  ZRSCVRFY RMU"
  puts $cfid  "  ZDELETE  _NONE_"

  if { 0 == [ string compare -nocase unixfile $class ] } {
   puts $cfid  "  ZPERGID   sys"
   puts $cfid  "  ZPERUID   root"
   puts $cfid  "  ZRSCRASH  755"
  }

  puts $cfid  " }"
  puts $cfid  "}"

  puts $cfid  "expression {"
  puts $cfid  " 1"
  puts $cfid  "}"

  close $cfid

  set k(-replacepkg)   1
  set k(-cfg)          $cfile

  set k(-host)         $cfg(rcs):$cfg(port)
  set k(-package)      $pInstanceName

  if { "" == $cfg(pass) } {
   set cmd [ lconcat [ list $cfg(KIT) $pmt -user $cfg(user) ] [ array get k ] ]
  } else {
   set cmd [ lconcat [ list $cfg(KIT) $pmt -user $cfg(user) -pass $cfg(pass) ] [ array get k ] ]
  }

  echo "Promting files ..."
  run $cmd

  filedelete  $cfile

  return [ string toupper [ format "%s.%s.%s" $ppath package $pInstanceName ] ]
}

#----------------------------------------#
#  u p d a t e p r d m a i n t           #
#----------------------------------------#
proc updateprdmaint { MaintOS packageFDCI } {

global cfg

set tp [ connectrcs ]

lassign [ split $packageFDCI "." ] pF pD pC pI

# domain and class are the same name
set iName     [ format "%s_%s_%d_%d" $cfg(prd) $MaintOS $cfg(major) $cfg(iMinor) ]
set maintFDCI [ join [ list $pF $pD $pD $iName  ] "." ]
set BASEINST  [ join [ list $pF $pD $pD _BASE_INSTANCE_  ] "." ]

echo "Processing $maintFDCI"

set rc [ catch { $tp get $maintFDCI } instinfo ]
# add new instance
if { $rc } {
  echo "Copying $BASEINST"
  set rc [ catch { $tp copy $BASEINST $maintFDCI } ]
  if { $rc } { done "Can't copy $BASEINST to $maintFDCI"
  } else {
   set rc [ catch { $tp get $maintFDCI } instinfo ]
   if { $rc } { done "Can't read $maintFDCI"
   }
  }
}

lassign $instinfo ltemp lheap
array set heap $lheap

set tlist [ lassign [ lsort -dictionary [ findconnects $ltemp ] ] pHotfix pCustom ]
set pPatch [ lindex $tlist end ]

set base [ format "%s.%s.%s_%s_%d_%d" $pD PACKAGE $cfg(prd) $MaintOS $cfg(major) $cfg(iMinor) ]

if { "" == $heap(NAME) } {
  set uheap(NAME) $iName
  echo "Set NAME to $iName"
}

if { "" == $heap($pHotfix) } {
  set uheap($pHotfix) "${base}_HOTFIX"
  echo "Set $pHotfix to $uheap($pHotfix)"
}

if { "" == $heap($pCustom) } {
  set uheap($pCustom) "${base}_CUSTOM"
  echo "Set $pCustom to $uheap($pCustom)"
}

set pp [ string first "." $packageFDCI ]
if { $pp < 0 } {
  set uheap($pPatch) $packageFDCI
} else {
  incr pp
  set uheap($pPatch) [ string range $packageFDCI $pp end ]
}
echo "Set $pPatch to $uheap($pPatch)"

set rc [ catch { $tp modify $maintFDCI [ array get uheap ] } instinfo ]

if { $rc } { done "Can't update $maintFDCI" }

$tp close

return $maintFDCI

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
   set o(-set:Fixnum)  $cfg(fixno)

   set cmd [ lconcat [ list $cfg(KIT) $StampTkd set ] [ array get o ] $files ]
   run $cmd

   set cmd [ lconcat [ list $cfg(KIT) $StampTkd get ] $files ]
   run $cmd
  }
}

#----------------------------------------#
#  sign                                  #
#----------------------------------------#
proc sign { tdir } {

                global cfg

                set allfiles [ glob -nocomplain -directory $tdir * ]

                set files {}
                foreach file $allfiles {

                   set name       [ file tail $file ]
                   set altname    [ string tolower $name ]

                   set searchname [ string tolower $name ]

                   set xlate [ format $cfg(xlatefunc) "@AltName" ]
                   set search [ format {//Module[%s='%s' and @Product='%s']} @AltName $searchname $cfg(prd) ]
                   echo "XPath(Sign) -- $search"

                   set nodes [ $cfg(xnode) selectNode $search ]

                   if { "" == $nodes } {
                    echo "Sign: skipping $file (not found)"

                   } else {
                    set match 0
                    set count 0

                    foreach node $nodes {
                     incr match
                     set name  [ $node getAttribute Name ]
                     set alt   [ $node getAttribute AltName ]
                     echo "Match $match item($file) name($name) altname($alt)"

                     set Sign [ $node getAttribute Sign "?" ]
                                echo "node = $node getAttribute Sign"
                     switch -exact -- $Sign {
                      Yes     { incr count }
                      No      { echo "Sign: skipping $file (No Sign)" }
                      "?"     { echo "Sign: skipping $file (Undefined)" }
                      default { echo "Sign: skipping $file (<Nill>)" }
                     }
                    }
                    if { $count > 0 } { lappend files $file }
                   }
                  }

                                if { [ llength $files ] > 0 } {
                                echo "Signing $files"
                                
                                set lastchar [string index $cfg(target) [expr [string length $cfg(target)] - 1]]
                                if { "/" == $lastchar } {
                                                set outputsigndir [format {%s%s} $cfg(target) $cfg(tempsigndir)]
                                } else {
                                                set outputsigndir [format {%s/%s} $cfg(target) $cfg(tempsigndir)]
                                }
                                
#                             set rc [ catch { exec $cfg(signutil) } ]
#                             if { $rc } {
#                                             done "Cannot launch HPSign.bat, ensure HPCSS client is installed and path to HPSign.bat is set in the PATH environment variable"
#                             }
                                
                                echo "Temporary output directory for signed files is: $outputsigndir"                                      
                                set rc [ catch { file mkdir $outputsigndir } ]
                                if { $rc } {
                                                done "Can't create directory $outputsigndir"
                                }
                                
                                foreach inputfile $files {
                                                set cmd [concat $cfg(signutil) -r ClientAutomationSigntool -c "HPSign.Conf" -i $inputfile  -o $outputsigndir -obj executable_batch_sign_local]
                                                run $cmd
                                                #echo "Overwriting input file $inputfile with signed version of the file [format {%s/%s} $outputsigndir [lindex [file split $inputfile] [expr [llength [file split $inputfile]] - 1]]]"
                                                
                                                set outputfile [format {%s/%s} $outputsigndir [lindex [file split $inputfile] [expr [llength [file split $inputfile]] - 1]]]
                                                if { [ file exists $outputfile ] } { 
                                                                set rc [ catch { file copy -force $outputfile $inputfile } ]
                                                                if { $rc } {
                                                                                if { [ file exists $outputsigndir ] } { 
                                                                                                file delete -force $outputsigndir
                                                                                done "Could not overwrite stamped file($inputfile) with the signed version($outputfile)."
                                                                                }
                                                                }
                                                } else {                                                  
                                                                if { [ file exists $outputsigndir ] } { 
                                                                                file delete -force $outputsigndir
                                                                }
                                                                done "Digital signing of $inputfile failed."
                                                }              
                                                                                
                                                if { [ file exists $outputsigndir ] } { 
                                                                file delete -force $outputsigndir 
                                                }
                                }
                }
}

#----------------------------------------#
#  c o n n e c t f t p                   #
#----------------------------------------#
#
# This part of the code assumes that there is a ftpserver running on the host.  In
# addition it assumes that a ftp client can connect via port 21 (ftp std) with the
# user abuilder and the password edm123.  Lastly, it assums that the "home"
# directory for abuilder is the rcs logfile directory, where the raddbutil output is
# written to.
#
proc connectftp {} {
global cfg

if { [ info exists ::env(FTPUSER) ] } {
  set ftpuser $::env(FTPUSER)
} else {
  set ftpuser abuilder
}

if { [ info exists ::env(FTPPASS) ] } {
  set ftppass $::env(FTPPASS)
} else {
  set ftppass edm123
}

echo "Connecting to $cfg(rcs) as $ftpuser"

set ftp [ ::ftp::Open $cfg(rcs) $ftpuser $ftppass ]

if { $ftp < 0 } {
  done "Can't get a FTP connection to $cfg(rcs)"
} else {
  echo "Connect to FTP server $cfg(rcs)"
}

return $ftp

}

#----------------------------------------#
#  g e t f t p                           #
#----------------------------------------#
proc getftp {} {

global cfg

set ftp [ connectftp ]

set ftpfiles [ ::ftp::NList $ftp ]

echo "Created FTP files"
foreach file $ftpfiles {
   echo "ftpfile - $file"
}

if { $cfg(havelog) } {
  set logdir [ file dirname $cfg(log) ]
} else {
  set logdir [ pwd ]
}

foreach file $ftpfiles  {
  switch -regexp -- $file {

   "(?i)^raddbutil"      {
     set outfile [ file join $logdir $file ]
   }

   "(?i)(xpi|xpr)\$" {
    set outfile [ file join $cfg(expdir) $file ]
   }

   default               {
    set outfile {}
   }
  }

  if { "" != $outfile } {
   echo "Found FTP file $file to copy ..."

   set rc [ catch { open $outfile w } fhandle ]

   if { $rc } {
    done "Can't open file $outfile for output"

   } else {
    fconfigure $fhandle -translation binary
    echo "Writting file $file from FTP server $cfg(rcs) to $outfile"
    set rc [ ::ftp::Type $ftp binary ]
    set rc [ catch { ::ftp::Get $ftp $file -channel $fhandle } einfo ]

    if { $rc } {
     catch { close $fhandle }
     catch { ::ftp::Close $ftp }
     done "Error writing file $outfile $einfo"

    } else {
     catch { close $fhandle }
     set mtime [ ::ftp::ModTime $ftp $file ]
     file mtime $outfile $mtime
     echo "Touched $outfile -- [ clock format $mtime ]"
    }
   }
  }
}

catch { ::ftp::Close $ftp }
}

#----------------------------------------#
#  c l e a n f t p                       #
#----------------------------------------#
proc cleanftp {} {

global cfg

set ftp [ connectftp ]

set ftpfiles [ ::ftp::NList $ftp ]

echo "Current ftp files"
foreach file $ftpfiles {
  echo "ftpfile - $file"
}

foreach file $ftpfiles  {

   switch -regexp -- $file {

   "(?i)^raddbutil" {
    echo "Deleting FTP file $file"
    ::ftp::Delete $ftp $file
   }

   "(?i)(xpc|xpi|xpr)\$" {
    echo "Deleting FTP file $file"
    ::ftp::Delete $ftp $file
   }
  }
}

catch { ::ftp::Close $ftp }

}

#----------------------------------------#
#  r a d d b u t i l                     #
#----------------------------------------#
proc raddbutil { packageFDCI maintFDC MaintInsts } {

  global cfg

# timestamp on when the object was created
  set a(_TS_)     [ clock format [ clock seconds ]  ]

# this object name is required -- its the name of a process on the rcs
  set object      "CAFIX"
  set a(ZOBJREQ)  "CAFIX0"


# get maint instances (patch)
  if { 0 == $cfg(fixno) } {
    lassign         [ split $maintFDC "." ] a(MF) a(MD) a(MC)

    set ii  0
    foreach mInst $MaintInsts {
     incr ii
     set log            [ format "%s.%d" $cfg(prd) $ii ]
     set index          "MI$ii"
     set a($index)      $mInst
     set a(maint$ii)    "&(MF).&(MD).&(MC).&($index)"
     set a(mOutput$ii)  [ qq "&(zcvt.logdir)\\&(MC)_&($index)" ]
     set a(log$ii)      [ qq "&(zcvt.logdir)\\raddbutil.${log}.log" ]
     set cmd($ii)       "cmd raddbutil export -walk 0 -logfile &(log$ii) -output &(mOutput$ii) &(maint$ii)"
    }
  } else {
    set ii 0
  }

  lassign            [ split $packageFDCI "." ] a(PF) a(PD) a(PC) a(PI)

  set a(package)     {&(PF).&(PD).&(PC).&(PI)}
  set a(pOutput)     [ qq "&(zcvt.logdir)\\&(PC)_&(PI)" ]

  incr ii
  set log            [ format "%s.%d" $cfg(prd) $ii ]
  set a(log$ii)      [ qq "&(zcvt.logdir)\\raddbutil.${log}.log" ]
  set cmd($ii)       "cmd raddbutil export -walk 1 -logfile &(log$ii) -data 1 -output &(pOutput) &(package)"

  set cmds {}
  set ii 0
  foreach item [ lsort -dictionary [ array names cmd ] ] {
   incr ii
   lappend cmds [ format "cmd%d" $ii ] $cmd($item)
  }

  set rfid [ file join [ tmpdir ] $a(ZOBJREQ).EDM ]
  filedelete  $rfid

  set ofid [ file join [ tmpdir ] ${object}.EDM ]
  filedelete  $ofid

  set cafix [ nvdobj #auto -file $ofid -mode rw -bsize 6144 ]

  eval [ lconcat [ list $cafix insert end ] [ array get a ] $cmds ]
  $cafix commit

  echo "Sending object $object to $cfg(rcs)"
  foreach { var val }  [ $cafix get 0 ] {
   echo "$var :: $val"
  }

  set logfile [ file join $cfg(rootpath) objxfer.log ]
  filedelete  $logfile

  if { [ info exists ::env(IDMLIB) ] } {
   set exist 1
   set idmlib $::env(IDMLIB)
  } else {
   set exist 0
  }

  set ::env(IDMLIB) [ file dirname $ofid ]

  echo "Running object transfer"
  run [ list $cfg(KIT) objxfer $object -host $cfg(rcs) -port $cfg(port) -logfile $logfile -loglvl $cfg(loglvl) ]

  getftp

  set cafix0 [ nvdobj #auto -file $rfid -mode r ]

  echo "Raddbutil -- Ending Status"

  set p1 {(?i)rc(\d+)}
  set p2 {^(\d+)}


  echo "Return object $a(ZOBJREQ) from $cfg(rcs)"
  foreach { var val }  [ $cafix0 get 0 ] {
   echo "$var :: $val"
   if { [ regexp $p1 $var match cmdno ] } {
    regexp $p2 $val match rc
    if { $rc != 0 } {
     done "Raddbutil failed -- RC($rc) -- $cmd($cmdno)"
    }
   }
  }
  $cafix0 commit

  if { $exist } {
   set ::env(IDMLIB) $idmlib
  }

  $cafix  close
  $cafix0 close

  filedelete $rfid
  filedelete $ofid
}

#----------------------------------------#
#  a r c h i v e                         #
#----------------------------------------#
proc archive { afile sdir } {

global cfg

set ext   [ file extension $afile ]

if { [ file exists $afile ] } {
  filedelete $afile
}

set cwd [ pwd ]
cd $sdir

switch -exact -- $cfg(thisos) {
  unix {
   echo "Changing from $cwd to [ pwd ]"
   set tarsh [ file join $cfg(rootpath) tar.sh ]

   if { 0 == [ file executable $tarsh ] } {
     done "Can't execute $tarsh"
   }

   if { "" == $ext } {
    set afile "${afile}.tar"
   } else {
    if { [ string compare $ext ".tar" ] } {
     set afile "${afile}.tar"
    }
   }

   run [ list $tarsh $afile  $sdir ]
   echo "[ pwd ] restored to $sdir"
  }

  windows {
   echo "Changing from [ file attributes $cwd -longname ] to [ file attributes [ pwd ] -longname ]"

   if { "" == $ext } {
    set afile "${afile}.zip"
   } else {
    if { [ string compare -nocase $ext ".zip" ] } {
     set afile "${afile}.zip"
    }
   }

   run [ list $cfg(KIT) zip "-9r" $afile . ]
   echo "[ file attributes [ pwd ] -longname ] restored"
  }
  default { done "internal error" }
}

cd $cwd

return $afile
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
#  m a k e e x p o r t s                 #
#----------------------------------------#
proc makeexports { } {

  global cfg

  fixmoddir $cfg(moddir)

  set moduleszip [ file join $cfg(expdir) "modules" ]
  set moduleszip [ archive $moduleszip $cfg(moddir) ]


  ##  set line "VERB=IMPORT_INSTANCE,FILE=$cfg(-FIXNAME).xpi,XPR=$cfg(-FIXNAME).xpr,PREVIEW=NO,REPLACE=YES,CONTINUE=YES,DUPLICATES=MANAGE,COMMIT_CHANGES=YES,LOGFILE=$cfg(-FIXNAME).LOG"

  set i0 "VERB=IMPORT_INSTANCE,PREVIEW=NO,REPLACE=YES,CONTINUE=YES,DUPLICATES=MANAGE,COMMIT_CHANGES=YES,LOGFILE=%s.LOG,%s"

  set i1 "FILE=%s.xpi,XPR=%s.xpr"
  set i2 "FILE=%s.xpi"

  # open/create ams file
  set amsfile [ file join $cfg(expdir) import.txt ]
  filedelete $amsfile

  set fid [ open $amsfile w ]
  fconfigure $fid -translation auto

  set xpifiles [ glob -nocomplain -directory $cfg(expdir) "*.xpi" ]

  foreach xpi $xpifiles {
   set root [ file rootname $xpi ]
   set xpr  "${root}.xpr"
   set name [ file tail $root ]

   if { [ file exists $xpr ] } {
    set wstr [ format $i1 $name $name ]
   } else {
    set wstr [ format $i2 $name ]
   }
   set out [ format $i0 $name $wstr ]
   echo $out
   puts $fid $out
  }
  close $fid

  set files [ glob -nocomplain -directory $cfg(target) "*" ]
  foreach file $files {
   filedelete $file
  }

  if { 0 == $cfg(fixno) } {
    set archivefile [ file join $cfg(target) [ format "PATCH_%d_%d_%d" $cfg(major) $cfg(xMinor) $cfg(sp) ] ]
  } else {
    set archivefile [ file join $cfg(target) $cfg(fixname) ]
  }
  set archivefile [ archive $archivefile $cfg(expdir) ]

  echo "Created -- $archivefile"

  catch { deldir $cfg(moddir) }
  catch { deldir $cfg(expdir) }
}

#----------------------------------------#
#  i n t s                               #
#----------------------------------------#
set cfg(fixno)          0

package require ftp
package require tdom

#----------------------------------------#
#  m a i n                               #
#----------------------------------------#
#
# switches
set switches [ list -fixno:0 -fixname:? -source -target -sp -release -os -log:? -xml -sign:no -rcs:ftc-ca-fix-rcs.fc.usa.hp.com -port:3464 -user:rad_mast -pass:? ]

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
if { $cfg(log) == "" } {
set cfg(log) [ file join $cfg(rootpath) ${cfg(scriptname)}.log ]
} else {
set cfg(log) [ file normalize $cfg(log) ]
}

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

# test sp
if { 0 == [ string is integer $cfg(sp) ] } {
done "sp is not an integer"
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
 }  else {
   set cfg(iMinor) [ csubstr $minor 0 1 ]
   set cfg(xMinor) $minor
  }
}
}

# set target os
if { [ regexp "(?i)^win.*" $cfg(os) ] } {
set unixos         0
set cfg(os)        "WIN"
set cfg(osPackage) "WIN_ALL"
set cfg(osMaint)   "WIN32_NT"

} else {
set unixos         1
set cfg(os)        [ string toupper $cfg(os) ]
set cfg(osPackage) $cfg(os)
set cfg(osMaint)   $cfg(os)
}

# set fix number
if { 0 == [ string is integer -strict $cfg(fixno) ] } {
done "Fix number is not an integer"
} else {
if { $cfg(major) < 5 } {
  if { $cfg(fixno) > 9999 } {
   done "Invalid value $cfg(fixno) for fix number"
  }
} else {
  if { $cfg(fixno) > 999 } {
   done "Invalid value $cfg(fixno) for fix number"
  }
}
}

# process xml file
set productnames [ loadxml $cfg(xml) ]

#set/user fixname
if { $cfg(fixname) == "" } {
  switch -regexp -- $cfg(os) {
   "(?i)unixlnux" { set prefix LNX }
   "(?i)unixsol"  { set prefix SOL }
   "(?i)unixsx86" { set prefix SX86 }
   "(?i)unixaix"  { set prefix AIX }
   "(?i)unixhpux" { set prefix HP0 }
   "(?i)unix"     { set prefix UNX }
   "(?i)^win.*"   { set prefix WIN }
   "(?i)^mac.*"   { set prefix MAC }
   default        { done "Invalid os $cfg(os) specified" }
  }

  if { $cfg(major) > 4 } {
   if { "WIN" == $prefix } { set prefix WIN }
   set cfg(fixnametemplate) [ format "%s%%s%d%d%03d" $prefix $cfg(major) $cfg(xMinor) $cfg(fixno) ]
   set cfg(fixnameupdate) 1
  } else {
   set cfg(fixnameupdate) 0
   if { "WIN" == $prefix } {
    set prefix R320
   } else {
    set prefix "R${prefix}"
   }
   set cfg(fixname) [ format "%s%04d" $prefix $cfg(fixno) ]
  }
} else {
set cfg(fixnameupdate) 0
}

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

    if { $cfg(fixno) > 0 } {
     if { $subtotal > 1 } {
      echo "Processing $errortext"
      done "Multiple products requite multiple fixes"
    }
    }

    if { $count > 0 } {
     echo "Processing $count files for product $prod"
    } else {
     echo "No files to process for product $prod"
     continue
    }

# stamp the files
                stamp              $cfg(target)

# sign the files
                if { "YES" == [string toupper $cfg(sign)] } {
                                sign $cfg(target)
                } else {
                                echo "Modules shall not be digitally signed. For signing specify -sign = yes on makeexport command-line."
                }

# create the product file (patch)
    if { 0 == $cfg(fixno) } { productfile $cfg(target) }

# promote the files

    if { $cfg(fixnameupdate) > 0 } {
      set tag {}
      foreach item [ array names cfg -glob Have* ] {

       switch -regexp -- $item {
        "(?i)haverim\$"  { set tag "I" }
        "(?i)havecore\$" { set tag "A" }
        "(?i)havesvr\$"  { set tag "S" }
        default          {}
       }

       if { $tag != "" } { break }
      }

      if { $tag == "" } { set tag "X" }
      set cfg(fixname) [ format $cfg(fixnametemplate) $tag ]
    }

    set packageinst    [ promote $cfg(target) ]

# get list of promoted files with component instances
    set promotedfiles  [ getpromotedfiles $packageinst ]

# do any post processing of the attributes ie verify flags
    postpromote        $promotedfiles

# add extras prdmaint instances? (patch)
    if { 0 == $cfg(fixno) } {
      switch -regexp -- $cfg(os) {
       "(?i)WIN.*" {
        echo "Processing additional PRDMAINT instances for $cfg(os)"
        set m(1) [ updateprdmaint $cfg(osMaint)   $packageinst ]
        set m(2) [ updateprdmaint $cfg(os)X64_NT  $packageinst ]
        set m(3) [ updateprdmaint $cfg(os)IA64_NT $packageinst ]
       }

       "(?i)UNIX(LNUX|HPUX)" {
        echo "Processing additional PRDMAINT instances for $cfg(os)"
        set m(1)  [ updateprdmaint $cfg(os)      $packageinst ]
        set m(2)  [ updateprdmaint $cfg(os)_IA64 $packageinst ]
       }

       default {
        set m(1)  [ updateprdmaint $cfg(os)      $packageinst ]
       }
      }

      lassign [ split $m(1) "." ] F D C I

      set maintFDC   [ join [ list $F $D $C ] "." ]
      set maintInsts [ list $I ]

      for { set ii 2 } { [ info exists m($ii) ] } { incr ii } {
       lappend maintInsts [ lindex [ split $m($ii) "." ] 3 ]
      }
    } else {
      set maintFDC   "?"
      set maintInsts "?"
    }

# delete any left over export files
    cleanftp

# export the instances
    raddbutil          $packageinst $maintFDC $maintInsts

# save modules for later archive
    savemodules        $cfg(target) $cfg(moddir)
}

if { $totalcount > 0 } {


if { $cfg(fixno) > 0 } {
  echo "Building fix $cfg(fixno) -- Name $cfg(fixname)"
} else {
  echo "Building patch ${cfg(major)}.${cfg(xMinor)}.$cfg(sp)"
}

makeexports
}

$cfg(xdoc) delete

set now  [ clock seconds ]
set diff [ expr $now - $cfg(starting) ]

echo "Finished -- duration [ clock format $diff -format {%H:%M:%S} -gmt 1 ]"

log.close

exit 0
