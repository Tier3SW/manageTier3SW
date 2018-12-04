#! /bin/bash 
#!----------------------------------------------------------------------------
#!
#!  updateManageTier3SW.sh
#!
#!  This script will update the manageTier3SW package from svn and do updates
#!
#!  Usage:
#!    updateManageTier3SW.sh
#!
#!  History:
#!    24Jun2008: A. De Silva, first version.
#!
#!----------------------------------------------------------------------------

mt3sw_progname=updateManageTier3SW.sh

mt3sw_mySvnroot="http://svn.cern.ch/guest/atcansupport/"

mt3sw_userSupportDir="`eval echo ~/userSupport`"

let mt3sw_ThisStep=0
mt3sw_SummaryAr=()

if [ -z $mt3sw_manageTier3SWDir ]; then
    export mt3sw_manageTier3SWDir="$mt3sw_userSupportDir/manageTier3SW"
    mt3sw_manageTier3SWDir=`eval \echo $mt3sw_manageTier3SWDir`
fi
source $mt3sw_manageTier3SWDir/functions.sh

mt3sw_configDir="$mt3sw_userSupportDir/cfgManageTier3SW"

\echo "Updating manageTier3SW ..."

if [ "`whoami`" = "root" ]; then
    mt3sw_fn_initSummary "User check"
    \echo "Error: updateManageTier3SW cannot be run as root."
    mt3sw_fn_addSummary 64 "exit"    
fi

if [ ! -z $ATLAS_LOCAL_ROOT ]; then
    mt3sw_fn_initSummary "SetupATLAS check"
    \echo "Error: setupATLAS should not be setup."
    mt3sw_fn_addSummary 64 "exit"    
fi

mt3sw_fn_updateParseOptions $@

if [[ "$mt3sw_installOnly" != "" ]] && [[ "$mt3sw_skipInstall" != "" ]]; then
    \echo "Error: both installOnly and skipInstall cannot be spcified"
    exit 64
fi

mt3sw_lockFile="$mt3sw_manageTier3SWDir/lockManageTier3SW.lock"
if [ "$mt3sw_ignoreLock" != "YES" ]; then
    mt3sw_fn_initSummary "Setting or waiting for manageTier3SW lock to clear"
    mt3sw_thisPid=$$
    mt3sw_thisHost=`hostname -f`
    if [ -e $mt3sw_lockFile ]; then
	mt3sw_oldPid=`\cat $mt3sw_lockFile | \cut -f 1 -d "|"`
	mt3sw_oldHost=`\cat $mt3sw_lockFile | \cut -f 2 -d "|"`
	if [ "mt3sw_oldHost" = "$mt3sw_thisHost" ]; then
	    mt3sw_result=`ps -p $mt3sw_oldPid 2>&1`
	    if [ $? -ne 0 ]; then
		\rm -f $mt3sw_lockFile
	    fi
	fi
    fi

    \echo " lockfile: $mt3sw_lockFile"
    lockfile -60 -r 10 $mt3sw_lockFile
    mt3sw_fn_addSummary $? "exit"
    chmod +w $mt3sw_lockFile
    \echo "$mt3sw_thisPid|$mt3sw_thisHost" >> $mt3sw_lockFile
    chmod -w $mt3sw_lockFile
fi

if [ "$mt3sw_mVersion" = "" ]; then    
    mt3sw_fn_initSummary "Getting mnageTier3SW trunk for latestVersion"
    svn switch $mt3sw_mySvnroot/manageTier3SW/trunk $mt3sw_manageTier3SWDir
    mt3sw_fn_addSummary $? "exit"
    mt3sw_mVersion=`\cat $mt3sw_manageTier3SWDir/latestVersion`
else
    mt3sw_mVersion=$mt3sw_mVersion
fi

mt3sw_fn_initSummary "Upgrading manageTier3SW to $mt3sw_mVersion"
svn switch $mt3sw_mySvnroot/manageTier3SW/tags/$mt3sw_mVersion $mt3sw_manageTier3SWDir
mt3sw_fn_addSummary $? "exit"

\mkdir -p ~/bin
cd ~/bin
\rm -f ~/bin/updateManageTier3SW.sh
ln -s $mt3sw_manageTier3SWDir/updateManageTier3SW.sh

source $mt3sw_manageTier3SWDir/functions.sh

mt3sw_fn_continueUpdate
exit $?

