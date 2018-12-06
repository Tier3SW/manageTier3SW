#!----------------------------------------------------------------------------
#!
#!  functions.sh
#!
#!  Various functions that are needed for manageTier3SW package
#!
#!  Usage:
#!    source functions.sh
#!
#!  History:
#!    02Dec2016: A. De Silva, first version.
#!
#!----------------------------------------------------------------------------


#!----------------------------------------------------------------------------
mt3sw_fn_initSummary() 
# args: 1: description
#!----------------------------------------------------------------------------
{
    let mt3sw_ThisStep+=1
    mt3sw_SkipTest="NO"
    mt3sw_TestDescription=$1
    printf "\n\n\033[7m%3s\033[0m %-60s\n" "${mt3sw_ThisStep}:" "${mt3sw_TestDescription} ..."

    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_addSummary() 
# args: 1: exit code, 2: exit or continue (only $1 != 0)
#!----------------------------------------------------------------------------
{
    local mt3sw_exitCode=$1
    local mt3sw_next=$2
    local mt3sw_status

    if [ "$mt3sw_exitCode" -eq 0 ]; then
	mt3sw_status="OK"
	printf "%-70s [\033[32m  OK  \033[0m]\n" "$mt3sw_TestDescription"
    else
	mt3sw_status="FAILED"
	printf "%-70s [\033[31mFAILED\033[0m]\n" "$mt3sw_TestDescription"
    fi
    
    mt3sw_SummaryAr=( "${mt3sw_SummaryAr[@]}" "$mt3sw_ThisStep:$mt3sw_TestDescription:$mt3sw_status" ) 
    
    if [[ "$mt3sw_next" = "exit" ]] && [[ $mt3sw_exitCode -ne 0 ]]; then
	mt3sw_fn_printSummary
	mt3sw_fn_cleanup
	exit $mt3sw_exitCode
    fi
    
    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_printSummary() 
#!----------------------------------------------------------------------------
{
    
    if [ ${#mt3sw_SummaryAr[@]} -gt 0 ]; then
	printf "\n\n%4s %-65s %6s\n" "Step" "Description ($ALRB_OSTYPE)" "Result"
    fi
    local mt3sw_item
    for mt3sw_item in "${mt3sw_SummaryAr[@]}"; do
	local mt3sw_step=`\echo $mt3sw_item | \cut -d ":" -f 1`
	local mt3sw_descr=`\echo $mt3sw_item | \cut -d ":" -f 2`
	local mt3sw_result=`\echo $mt3sw_item | \cut -d ":" -f 3`
	printf "%4s %-65s %6s\n" "$mt3sw_step" "$mt3sw_descr" "$mt3sw_result"
	if [[ "$mt3sw_descr" = "Update Tools" ]] && [[ -e $ALRB_installTmpDir/toolInstallSummary ]]; then
	    \cat $ALRB_installTmpDir/toolInstallSummary
	fi
    done
    if [ ${#mt3sw_SummaryAr[@]} -gt 0 ]; then
	\echo  " "
    fi
    
    return 0
}

#!----------------------------------------------------------------------------
mt3sw_fn_createTmpScratch()
#!----------------------------------------------------------------------------
{
    
    local mt3sw_tmpScratch="/tmp/`whoami`/.mt3sw"
    \mkdir -p $mt3sw_tmpScratch > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	mt3sw_tmpScratch="$HOME/.mt3sw"
	\mkdir -p $mt3sw_tmpScratch /dev/null 2>&1
	if [ $? -ne 0 ]; then
	    exit 64
	fi
    fi

    mt3sw_Workarea=`\mktemp -d $mt3sw_tmpScratch/XXXXXX`
    export ALRB_installTmpDir=$mt3sw_Workarea

}


#!----------------------------------------------------------------------------
mt3sw_fn_continueUpdate() 
#!----------------------------------------------------------------------------
{

    mt3sw_fn_createTmpScratch    
    if [ $? -ne 0 ]; then
	exit 64
    fi

    mt3sw_fn_initSummary "Get default $mt3sw_cVersion configs"
    mt3sw_fn_getConfigs "$mt3sw_cVersion"
    mt3sw_fn_addSummary $? "exit"
    
    mt3sw_fn_initSummary "Update ATLASLocalRootBase"
    mt3sw_fn_updateALRB
    mt3sw_fn_addSummary $? "exit"

    mt3sw_fn_initSummary "Update Tools"
    mt3sw_fn_updateTools
    mt3sw_fn_addSummary $? "continue"

    mt3sw_fn_initSummary "Post Installation Jobs"
    $ATLAS_LOCAL_ROOT_BASE/utilities/postInstallChanges.sh
    mt3sw_fn_addSummary $? "continue"

    mt3sw_fn_initSummary "Cleanups"
    mt3sw_fn_doCleanup
    mt3sw_fn_addSummary $? "continue"

    if [ -e $ALRB_installTmpDir/installDirCleanup.txt ]; then
	\echo ""
	\echo " Contaminents found:"
	\cat $ALRB_installTmpDir/installDirCleanup.txt
    fi

    if [ -e "$mt3sw_configDir/default/motd" ]; then
	mt3sw_fn_initSummary "Update motd"
	\cp $mt3sw_configDir/default/motd $ATLAS_LOCAL_ROOT_BASE/etc/motd
	mt3sw_fn_addSummary $? "continue"
    fi

    mt3sw_fn_initSummary "Update dependencies file"    
    if [ -e "$mt3sw_configDir/default/dependencies.txt" ]; then
	\cp $mt3sw_configDir/default/dependencies.txt $ATLAS_LOCAL_ROOT_BASE/etc/dependencies.txt
    else
	\rm -f $ATLAS_LOCAL_ROOT_BASE/etc/dependencies.txt
    fi
    mt3sw_fn_addSummary $? "continue"
    
    \echo "`date +%Y%b%d\\ %H:%M` | `hostname -f` | `date +%s`" >> $ATLAS_LOCAL_ROOT_BASE/logDir/lastUpdate

    mt3sw_fn_printSummary
    
    mt3sw_fn_cleanup
    
    printf "%-70s [\033[32m DONE  \033[0m]\n" "ManageTier3SW update"

    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_updateHelp()
#!----------------------------------------------------------------------------
{

    \cat <<EOF

Usage: updateManageTier3SW.sh [options]

    Options:

    -m --mVersion=string         Version of manageTier3SW to use
    -c --cVersion=string         Config version to use 
    -L --localConfig=string      Local dir containing config fies (overwrite)

    -a --alrbInstall=string      Path to install ALRB 

    -i --installOnly=string      Install only these tools (comma seperated)
    -s --skipInstall=string      Skip installing these tools (comma seperated)
    -A --installArchived         Install archived tools

    -l --ignoreLock              Ignore lockfile
    -j --noCronJobs              Do not setup cron jobs

    -p --pacmanOptions=string    Pacman options

EOF

    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_updateParseOptions()
#!----------------------------------------------------------------------------
{

    local mt3sw_shortopts="h,m:,n:,c:,a:,i:,s:,l,j,p:,A,L:"
    local mt3sw_longopts="help,dryRun,mail:,defaultConfigVer:,testVer:,installOnly:,ignoreLock,noCronJobs,skipInstall:,overrideConfig:,pacmanOptions:,overrideConfigVer:,sVersion:,cName:,cVersion:,alrbInstall:,installArchived,localConfig:"

    local mt3sw_result
    local mt3sw_opts
    mt3sw_result=`getopt -T >/dev/null 2>&1`
    if [ $? -eq 4 ] ; then # New longopts getopt.
	mt3sw_opts=$(getopt -o $mt3sw_shortopts --long $mt3sw_longopts -n "$mt3sw_progname" -- "$@")
	local mt3sw_returnVal=$?
    else # use wrapper
	mt3sw_opts=`$mt3sw_manageTier3SWDir/wrapper_getopt.py $mt3sw_shortopts $mt3sw_longopts "$@"`
	local mt3sw_returnVal=$?
	if [ $mt3sw_returnVal -ne 0 ]; then
	    \echo $mt3sw_opts 1>&2
	fi
    fi
    
# do we have an error here ?
    if [ $mt3sw_returnVal -ne 0 ]; then
	\echo "'$mt3sw_progname --help' for more information" 1>&2
	exit 1
    fi
    
    eval set -- "$mt3sw_opts"

    mt3sw_cVersion=""
    mt3sw_mVersion=""
    mt3sw_installOnly=""
    mt3sw_skipInstall=""

    mt3sw_result=`which lockfile 2>&1`
    if [ $? -eq 0 ]; then
	mt3sw_ignoreLock=""
    else
	mt3sw_ignoreLock="YES"
    fi
    mt3sw_noCronJobs=""
    mt3sw_cName="default"
    mt3sw_pacmanOptions=""
    mt3sw_alrbInstallPath=""
    mt3sw_installArchived=""
    alrb_noCronJobs=""
    mt3sw_localConfig=""

    while [ $# -gt 0 ]; do
	: debug: $1
	case $1 in
            -h|--help)
		mt3sw_fn_updateHelp
		exit 0
		shift
		;;
            --dryRun)
		\echo "option dryRun is obsolete"
		shift
		;;		
            --mail)
		\echo "option mail is obsolete"
		shift 2
		;;		
            --defaultConfigVer|--overrideConfigVer|-c|--cVersion)
		mt3sw_cVersion=$2
		shift 2
		;;		
            --testVer|-m|-mVersion)
		mt3sw_mVersion=$2
		shift 2
		;;		
	    --installOnly|-i)
		mt3sw_installOnly=",$2,"
		shift 2
		;;		
            --skipInstall|-s)
		mt3sw_skipInstall=",$2,"
		shift 2
		;;		
            --ignoreLock|-l)
		mt3sw_ignoreLock="YES"
		shift
		;;		
            --noCronJobs|-j)
		mt3sw_noCronJobs="YES"
		alrb_noCronJobs=$mt3sw_noCronJobs
		shift
		;;		
            --overrideConfig|-n|--cName)
		\echo "Warning: overrideConfig is obsolete"
		shift 2
		;;		
            -p|--pacmanOptions)
		mt3sw_pacmanOptions="$2"
		shift 2
		;;				
            -a|--alrbInstall)
		mt3sw_alrbInstallPath=`\echo $2 | \sed -e 's|/ATLASLocalRootBase$||'`
		shift 2
		;;				
	    -A|--installArchived)
		mt3sw_installArchived="YES"
		alrb_installArchived=$mt3sw_installArchived
		shift
		;;
            --localConfig|-L)
		mt3sw_localConfig="$2"
		if [ ! -d $mt3sw_localConfig ]; then
		    \echo "Error: $mt3sw_localConfig not found"
		    exit 64
		fi
		shift 2
		;;		
            --)
		shift
		break
		;;
            *)
		\echo "Internal Error: option processing error: $1" 1>&2
		exit 1
		;;
	esac
    done
 
    

    return 0

}


#!----------------------------------------------------------------------------
mt3sw_fn_cleanup() 
#!----------------------------------------------------------------------------
{
    if [ -e $mt3sw_lockFile ]; then
	\rm -f $mt3sw_lockFile
    fi
    if [ ! -z $ALRB_installTmpDir ]; then
	\rm -rf $ALRB_installTmpDir
    fi

    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_getConfigs() 
#!----------------------------------------------------------------------------
{
    local mt3sw_configVersion=$1

    if [ ! -e $mt3sw_configDir/.git ]; then
	\echo  " Cloning Tier3SWConfig from git ..."
	\rm -rf $mt3sw_configDir
	git clone $mt3sw_myGitURL/Tier3SWConfig.git $$mt3sw_configDir
	if [ $? -ne 0 ]; then
	    return 64
	fi
    fi
    
    cd $$mt3sw_configDir

    \echo  " updating Tier3SWConfig master ..."
    git checkout master
    if [ $? -ne 0 ]; then
	return 64
    fi
    git pull
    if [ $? -ne 0 ]; then
	return 64
    fi

    if [ "$mt3sw_configVersion" = "" ]; then
	\echo  " Getting Tier3SWConfig $mt3sw_configName version ..."
	git checkout tags/$mt3sw_configName
	if [ $? -ne 0 ]; then
	    return 64
	fi
    fi

    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_getConfigFile() 
#!----------------------------------------------------------------------------
{
    local mt3sw_file=$1
    local mt3sw_os=$2

    if [ "$mt3sw_localConfig" != "" ]; then
	if [ -e "$mt3sw_localConfig/$mt3sw_file-$mt3sw_os.sh" ]; then
	    \echo $mt3sw_localConfig/$mt3sw_file-$mt3sw_os.sh
	    return 0
	elif [ -e "$mt3sw_localConfig/$mt3sw_file.sh" ]; then
	    \echo $mt3sw_localConfig/$mt3sw_file.sh
	    return 0
	fi
    fi
 
    if [ -e "$mt3sw_configDir/tools/$mt3sw_file-$mt3sw_os.sh" ]; then
	\echo "$mt3sw_configDir/tools/$mt3sw_file-$mt3sw_os.sh"
	return 0
    elif [ -e "$mt3sw_configDir/tools/$mt3sw_file.sh" ]; then
	\echo "$mt3sw_configDir/tools/$mt3sw_file.sh"
	return 0
   else
	\echo "Error: Unable to find config $mt3sw_file.sh"
	return 64
    fi

    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_updateALRB() 
#!----------------------------------------------------------------------------
{
    local mt3sw_configFile
    mt3sw_configFile=`mt3sw_fn_getConfigFile alrb ""`
    if [ $? -ne 0 ]; then
	\echo "Error: Unable to get config file for alrb"
	return 64
    else
	source $mt3sw_configFile
    fi

    local mt3sw_alrbChanged=""
    if [ -e $ATLAS_LOCAL_ROOT_BASE/logDir/version ]; then
	local mt3sw_currentALRBVersion=`\cat $ATLAS_LOCAL_ROOT_BASE/logDir/version | \sed -e 's/ //g'`
	if [ "$mt3sw_currentALRBVersion" != "$mt3sw_alrbInstallVersion" ]; then
	    local mt3sw_alrbChanged="YES"
	fi
    fi

    if [ -z $ATLAS_LOCAL_ROOT_BASE ]; then
	if [ "$mt3sw_alrbInstallPath" = "" ]; then
	    \echo "Error: No \$ATLAS_LOCAL_ROOT_BASE and no install opt given"
	    return 64
	else
	    \mkdir -p $mt3sw_alrbInstallPath
	    if [ $? -ne 0 ]; then
		\echo "Error: Cannot create ALRB home dir"
		return 64
	    fi
	fi
	local mt3SW_alrbPath="$mt3sw_alrbInstallPath/ATLASLocalRootBase"
	
    elif [ "$mt3sw_alrbInstallPath" != "" ]; then
	if [ "$mt3sw_alrbInstallPath/ATLASLocalRootBase" != "$ATLAS_LOCAL_ROOT_BASE" ]; then
	    \echo "Error: \$ATLAS_LOCAL_ROOT_BASE != set installation option"
	    return 64
	fi	
	local mt3SW_alrbPath=$ATLAS_LOCAL_ROOT_BASE

    elif [ ! -d "$ATLAS_LOCAL_ROOT_BASE/.git" ]; then
	\echo "Error: ALRB is not installed.  Use the installation option"
	return 64

    else
	local mt3SW_alrbPath=$ATLAS_LOCAL_ROOT_BASE
    fi

    if [ ! -e $mt3SW_alrbPath/.git ]; then
	\echo " Cloning ATLASLocalRootBase from git"
	git clone $mt3sw_myGitURL/ATLASLocalRootBase.git $mt3SW_alrbPath
	if [ $? -ne 0 ]; then
	    return 64
	fi
    fi
    
    \echo " ATLASLocalRootBase version: $mt3sw_alrbInstallVersion"
    cd $mt3SW_alrbPath
    
    git checkout master
    if [ $? -ne 0 ]; then
	return 64
    fi
    git pull
    if [ $? -ne 0 ]; then
	return 64
    fi

    git checkout $mt3sw_alrbInstallVersion
    if [ $? -ne 0 ]; then
	return 64
    fi

    export ATLAS_LOCAL_ROOT_BASE=$mt3SW_alrbPath

    \mkdir -p $ATLAS_LOCAL_ROOT_BASE/etc
    \mkdir -p $ATLAS_LOCAL_ROOT_BASE/logDir
    \mkdir -p $ATLAS_LOCAL_ROOT_BASE/config
    \mkdir -p $ATLAS_LOCAL_ROOT_BASE/x86_64
    \mkdir -p $ATLAS_LOCAL_ROOT_BASE/x86_64-MacOS

    \rm -f $ATLAS_LOCAL_ROOT_BASE/logDir/version
    \echo "$mt3sw_alrbInstallVersion" >> $ATLAS_LOCAL_ROOT_BASE/logDir/version

    if [ "$mt3sw_alrbChanged" != "" ]; then
	mt3sw_fn_doLogEntry ATLASLocalRootBase $mt3sw_alrbInstallVersion
    fi
    
    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_doLogEntry()
#!----------------------------------------------------------------------------
{
    \echo -e "`date +%Y%b%d\ %H:%M`\t$1\t$2" >> $ATLAS_LOCAL_ROOT_BASE/logDir/installed 
    return 0
}


#!----------------------------------------------------------------------------
mt3sw_fn_updateTools()
#!----------------------------------------------------------------------------
{

    source $ATLAS_LOCAL_ROOT_BASE/utilities/checkAtlasLocalRoot.sh

    source $ATLAS_LOCAL_ROOT_BASE/swConfig/functions.sh
   
    local mt3sw_toolList=( `\egrep -v "\#" $ATLAS_LOCAL_ROOT_BASE/swConfig/synonyms.txt | \cut -f 4 -d ","` )

    local mt3sw_tool
    local mt3sw_result
    for mt3sw_tool in ${mt3sw_toolList[@]}; do	
	if [ "$mt3sw_installOnly" != "" ]; then
	    mt3sw_result=`\echo $mt3sw_installOnly | \grep -e ",$mt3sw_tool,"`
	    if [ $? -ne 0 ]; then
		continue
	    fi
	fi
	if [ "$mt3sw_skipInstall" != "" ]; then
	    mt3sw_result=`\echo $mt3sw_skipInstall | \grep -e ",$mt3sw_tool,"`
	    if [ $? -eq 0 ]; then
		continue
	    fi
	fi

	local mt3sw_doHeader=""
	local mt3sw_configFile
	mt3sw_configFile=`mt3sw_fn_getConfigFile "$mt3sw_tool" "$ALRB_OSTYPE"`
	if [ $? -eq 0 ]; then
	    if [ "$mt3sw_doHeader" = "" ]; then
		\echo " "
		printf '\n%70s\n' | \tr ' ' -
		printf " \e[1;34m%-70s\e[m\n" "$mt3sw_tool $ALRB_OSTYPE"
		printf '%70s\n' | \tr ' ' -
		mt3sw_doHeader="done"
	    fi
	    alrb_fn_sourceFunctions $mt3sw_tool
	    source $mt3sw_configDir/default/masterConfigs.sh
	    local alrb_Tool=$mt3sw_tool
            source $mt3sw_configFile
	    alrb_fn_installCreateDefaultsAr 
	    alrb_fn_installSetDefaults $mt3sw_tool
	    \echo " "
	    alrb_fn_createReleaseMap $mt3sw_tool
	    if [ ! -e $ALRB_installTmpDir/toolInstallFailed ]; then
		alrb_fn_cleanToolDir $mt3sw_tool
	    fi
	fi
    done
    \echo " "

    if [ -e $ALRB_installTmpDir/toolInstallFailed ]; then
	return 64
    else
	return 0
    fi
}


mt3sw_fn_doCleanup()
{
    if [ -z $ATLAS_LOCAL_ROOT_BASE ]; then
	\echo "Error: unable to cleanup as ATLAS_LOCAL_ROOT_BASE is undefined."
	return 64
    fi
    if [ "$mt3sw_configDir/default/cleanup.sh" ]; then
	source $mt3sw_configDir/default/cleanup.sh
	local mt3sw_item
	for mt3sw_item in ${mt3sw_CleanupAr[@]}; do
	    \rm -rf $ATLAS_LOCAL_ROOT_BASE/$mt3sw_item
	done
    fi
    return 0
}
