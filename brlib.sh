#!/bin/bash
#Bernhard Brunners bash scripting utility library. 
#Symlink to $HOME/bin or 
# /usr/local/lib/brlib.sh and use with "source /usr/local/lib/brlib.sh"
# Command line switch -BRDBG will set BRDEBUG=1
#Last modified: 2020-05-28 08:19
#if [ ! -z "${brVersion-}" ]; then
#    return 0
#fi
brVersion="1.0"

#xdbus="/home/brb/.config/Xdbus"
#[ -e $xdbus ] && source $xdbus

# It's easier than hand-coding color.
#[ -z "$TERM" ] && TERM=dumb
if [[ "$TERM" != "" && "$TERM" != "dumb" && "$TERM" != "unknown" ]] ; then  # && ( hash tput ) ; then
    #    echo valid [$TERM]
    ansibold="$(tput bold)"
    ansinormal="$(tput sgr0)"
    ansired="$ansibold$(tput setaf 1)"
    ansilightred="$(tput setaf 1)"
    ansigreen="$(tput setaf 2)"
    ansiblue="$(tput setaf 4)"
    ansicyan="$(tput setaf 6)"
    ansipurple="$(tput setaf 5)"
    ansibrown="$(tput setaf 1)"
    ansiyellow="$(tput setaf 3)"
    ansiwhite="$(tput setaf 8)"
    function ansiColumns() 
    {
        echo "$(tput cols)"
    }
else
    #    echo Invalid [$TERM]
    ansibold=""
    ansinormal=""
    ansired=""
    ansilightred=""
    ansigreen=""
    ansiblue=""
    ansicyan=""
    ansipurple=""
    ansibrown=""
    ansiyellow=""
    ansiwhite=""
    ansicolumns=80
    function ansiColumns() { 
        echo 80 
    }
fi

# default values
BRERRORCOUNT=0
BRERRORABORT=1

#! read config file $1
#  sets variables from config file
#  - ignores commens, trailing spaces
#  - much safer than sourcing, since only variable definitions will be read
function brReadConfig()
{
	shopt -s extglob
	local configfile="$1" # set the actual path name of your (DOS or Unix) config file
	[ -r "$configfile" ] || return
#    tr -d '\r' < $configfile > $configfile.unix
	while IFS='= ' read lhs rhs
	do
		if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
			rhs="${rhs%%\#*}"    # Del in line right comments
			rhs="${rhs%%*( )}"   # Del trailing spaces
			rhs="${rhs%\"*}"     # Del opening string quotes 
			rhs="${rhs#\"*}"     # Del closing string quotes 
			export $lhs="$rhs"
		fi
	done < $configfile
}

# Config file variables, with example values
BRNOTIFYHOST=uranus
brReadConfig $HOME/.config/brlib.cfg

# rotating spinner for long during processes
brspinvar=0
function brSpin()
{
    local brspinstr=( "-" "\\" "|" "/" )
#    printf "%c\b" ${brspinstr[$brspinvar]}
    local text="$*"
    let arglen=${#text}+2
#    echo $arglen
    printf "%c %s" "${brspinstr[$brspinvar]}" "$text"
    for i in $(seq 1 $arglen); do 
        printf "\b"
    done
    let brspinvar=$((brspinvar + 1))
    let brspinvar=$((brspinvar % 4))
}

# deprecated
function brspin()
{
    brSpin
}

######################################################################
# Environment information

##! get available disk space
# $1 path
# [$2] optional value in KB to check for. Use: if brDiskAvail . 123 ; then
function brDiskAvail()
{
    [ -d "$1" ] || brWarn "[$1] is not a path"
    local avail=$(df --output=avail $1 | tail -1)

    # if check size $2 is present, do so
    if [ -z "$2" ] ; then
        echo $avail
    else
        [ $avail -lt "$2" ] && return 1
    fi
    return 0
}

##! directory where the script is running
function brBaseDir
{
    echo "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
}

##! name of the script, symlinks not resolved, without path
function brScriptName
{
    echo $(basename $0 .sh)
}

##! determine public ip
function brGetPublicIP
{
    dig +short myip.opendns.com @resolver1.opendns.com || curl -s http://whatismyip.akamai.com/
}

##! return active dns server
function brGetDNS
{
    if hash nmcli ; then
        nmcli dev show | grep DNS | head -n 1 | awk '{print $2}'
    else
        brWarn "(no nmcli)"
    fi
}

##! return local ip address
function brGetLocalIP
{
    ip route get 8.8.8.8 | awk '{ print $NF; exit }'
}

##! get DISTRIB_ID and DISTRIB_RELEASE
function brGetDistrib
{
    if [ -e /etc/debian_version ] ; then
        DISTRIB_ID="Debian"
        DISTRIB_RELEASE=`cat /etc/debian_version`
    else
        [ -e /etc/lsb-release ] && source /etc/lsb-release
    fi
    [ "$DISTRIB_ID" != "" -a "$DISTRIB_RELEASE" != "" ] || brError "brGetDistrib failed"
}

##! Print distribution 
function brPrintDistrib
{
    brGetDistrib
    echo "$DISTRIB_ID:$DISTRIB_RELEASE"
}

##! check if distrib is "Ubuntu" or "Debian"
function brIsDistrib
{
    [ "$DISTRIB_ID" != "" ] || brGetDistrib
    if [ "$DISTRIB_ID" == "$1" ] ; then
        return 0
    else
        return 1
    fi
}

# check is system has a graphical desktop
function brIsGUI
{
    test "$DISPLAY" != ""
    return $?
}

############# DATE FUNCTIONS #######################################

#return date in standard format
function brDate()
{
    date "$@" '+%Y-%m-%d'
}

# echo text in boldface
function brBold()
{
    echo -e "${ansibold}$*${ansinormal}"
}

# return date_time in standard format
function brDateTime()
{
    date "$@" '+%Y-%m-%d_%H%M'
    #    date '+%F'
}

# return time
function brTime()
{
    date "$@" '+%H:%M'
}

# get current year
function brYear()
{
    date "$@" '+%Y'
}

# get current month
function brMonth()
{
    date "$@" '+%m'
}

############ LOGGING AND INFO ######################################33

# output function for info, warnings. may be overwritten by programs
# to customize debug output
function brOutputHook()
{
    echo -e "$*" >&2 
}

# display error and exit
brLogFile=${brLogFile:-}
brLogging=0
function brLog()
{
    if [ "$brLogFile" == "" ] ; then
        logger "$*"
    else
        echo "`date +'%F %T'` `hostname` $brScriptName: $*" >> $brLogFile
    fi
}

# call: text class color
# outputs messages to stderr
function brStatusOut()
{
    let col=$(( $(ansiColumns) - ${#1} - ${#2} + ${#3})) 

    #    echo "cols=$(tput cols) #1=${#1} #2=${#2} fill=$col"
    printf '%s%*s%s%s%s\n' "$1" "$col" "$3" "$2" "$ansinormal" 1>&2 
    [ $brLogging != 0 ] && brLog "$1"
}

function brFnLn()
{
    if [[ "${3-}" == "-d" ]] ; then
        [ $BRDEBUG != 0 ] && echo "$2:$1"
    else
        echo "$2:$1"
    fi
}

# notification on desktop
function brNotify()
{
    if [ -z "$BRNOTIFYHOST" -o "$BRNOTIFYHOST" == "$hostname" ] ; then
        notify-send "$*"
    else
        ssh $BRNOTIFYHOST 'DISPLAY=:0 notify-send "'$*'"'
    fi
    brInfo "$*"
}

# display info
function brInfo()
{
    #    echo "$*"
    brStatusOut "$*" "[ INFO  ]" "${ansinormal}"
}

# display error and exit
function brWarn()
{
    brStatusOut "$*" "$(brFnLn $(caller) -d) [ WARN  ]" ${ansiyellow}
}

# display debug
function brDebug()
{
    #    [ $BRDEBUG == 1 ] && brOutputHook "[${ansicyan}DEBUG${ansinormal}] $* ($(caller))"
    [ $BRDEBUG == 1 ] && brStatusOut "$*" "$(brFnLn $(caller)) [ DEBUG ]" "${ansicyan}"
}

function brCatchErrors()
{
    trap "brCleanup" HUP INT ABRT QUIT SEGV TERM
    set -e
}

# register trap function, which will get signal name as first argument
# ref: http://stackoverflow.com/questions/2175647/is-it-possible-to-detect-which-trap-signal-in-bash
# syntax: brTrapWithArg func signals
# example: 
function brTrapWithArg() {
func="$1" ; shift
for sig ; do
    trap "$func $sig" "$sig"
    echo setting trap: "$func $sig" for $sig
done
}

# function that can/should be overloaded for cleanup purposes
function brCleanup()
{
    # placeholder
    echo "dummy" > /dev/null
}

function brTrap()
{
    BRERRORABORT=0
    brError Trapped signal: $1
    brCleanup
}

function brTrapsOn()
{
    BRACTIVETRAPS="$@"
    [ ! -z "$BRACTIVETRAPS" ] || BRACTIVETRAPS="EXIT"
    brTrapWithArg brTrap $BRACTIVETRAPS
    set -e
}

function brTrapsOff()
{
    if [ ! -z "$BRACTIVETRAPS" ] ; then
        set +e
        trap - $BRACTIVETRAP
        BRACTIVETRAPS=""
    fi
}

# display error and exit
function brError()
{
    brStatusOut "$*" "$(brFnLn $(caller) -d) [ ERROR ]" ${ansilightred}
    logger "*** ERROR: $* ($(caller))"
    BRERRORCOUNT=$((BRERRORCOUNT + 1 ))
    if [ $BRERRORABORT == 1 ] ; then 
        exit 1
    fi
}

function brErrorMail()
{
    local mailadr="root"

    grep -q "^brb_admin_red:" /etc/aliases && mailadr=brb_admin_red
    brError "$*"
    echo "error in $0: $*" | mail -s "`hostname` `basename $0` error" $mailadr
    exit 1
}

function brWarnMail()
{
    local mailadr="root"

    grep -q "^brb_admin_red:" /etc/aliases && mailadr=brb_admin_red
    brWarn "$*"
    echo "Warn in $0: $*" | mail -s "`hostname` `basename $0` error" $mailadr
}

# display error and exit
function brAbort()
{
    brStatusOut "$*" "$(brFnLn $(caller) -d) [ ERROR ]" ${ansilightred}
    logger "*** ABORT: $* ($(caller))"
    exit 1
}

# echo nonobstrusive alert 
function brBeep()
{
    local SOUND=""
    local PLAYER=""

    [ -e /usr/share/sounds/pop.wav ] && SOUND=/usr/share/sounds/pop.wav
    [ -e $HOME/bin/sounds/pop.wav ] && SOUND=$HOME/bin/sounds/pop.wav
    #    brIsRunnable "aplay" && PLAYER="aplay -q "
    #    brIsRunnable "paplay" && PLAYER="paplay "
    PLAYER="paplay "
    [ -e $SOUND ] && $PLAYER $SOUND
}

function brErrorCheck()
{
    if [ $BRERRORCOUNT -gt 0 ] ; then
        BRERRORABORT=1
        brError Errors occured: $BRERRORCOUNT, aborting.
    fi
}

########### OS UTILITIES ################3

function brIsRoot()
{
    [ $(id -u) -ne 0 ] && return 1
    return 0
}

function brAssertRoot()
{
    if [ $(id -u) -ne 0 ] ; then
        brAbort "$(brScriptName) must be run as root"
    fi
}

##! get gecos field number $1
# https://en.wikipedia.org/wiki/Gecos_field
# can be change by users using chfn
# frwh (1=full,2=room,3=work,4=home,5=other1,6=other2,7=other3)
# Fullname,Building+room,officephone,homephone,
function brGetGecos()
{
    getent passwd $2 | cut -d: -f5 | cut -d, -f$1
}

function brGetUserFull()
{
    brGetGecos 1 $1
}

function brGetUserEmail()
{
    brGetGecos 4 $1
}

##! Set user enviroment variables EMAIL and FULLNAME from /etc/passwd, if not already set
function brSetUserVars()
{
    local emdef="$EMAIL"
    local fndef="$FULLNAME"

    local emval=`brGetGecos 4 $USER`
    local fnval="`brGetGecos 1 $USER`"
    [ ! -z "$emval" ] || emval=$emdef 
    [ ! -z "$fnval" ] || fnval=$fndef 

    export EMAIL="$emval"
    export FULLNAME="$fnval"
}

##! add $1 to path if $1 exists and is not in path
function brAddToPath()
{
    if [ -d "$1" ] ; then
        [[ ":$PATH:" != *":$1:"* ]] && export PATH="$1:${PATH}"
        #        echo $PATH , $1 added
    fi
}

##! kill process and its children
function brKillProcessTree
{
    for p in $(pstree -p $1 | grep -o "([[:digit:]]*)" |grep -o "[[:digit:]]*" | tac);do
        echo Terminating: $p 
        kill $p
    done

    kill $1
}

##! run process and kill it after timeout
# $1: timeout in seconds
# $2*: process to start
# Ref: https://stackoverflow.com/questions/10028820/bash-wait-with-timeout
function brTimeoutProcess
{
    local pidFile=`mktemp`
    local res=1
    local timeOut=$1
    shift
    ( exec $* ; rm $pidFile ; ) &
    pid=$!
    echo $pid > $pidFile
#    ( sleep $timeOut ; if [[ -e $pidFile ]]; then brWarn "timeout $pid $*" ; brKillProcessTree $pid ; fi ; echo leaving wait loop) &
    ( sleep $timeOut ; if [[ -e $pidFile ]]; then brWarn "timeout $pid $*" ; kill $pid ; fi ) &
    killerPid=$!
    wait $pid
    res=$?
    kill $killerPid
    brLazyRm $pidFile
    return $res
}


########### FILE/SYSTEM Utility functions################3

function brCPUCores
{
    grep -c ^processor /proc/cpuinfo
}

function brBenchCPU
{
nice -1 sysbench --num-threads=`brCPUCores` --test=cpu run --max-requests=20000 | awk '/^[ ]+approx./{ print $4}'
}

##! Get CPU Load
function brLoad()
{
    if [ -z "$1" ] ; then
        echo $(cut -d ' ' -f 2 < /proc/loadavg | cut -f 1 -d ".")
    else
        ssh $1 "cut -d ' ' -f 2 < /proc/loadavg | cut -f 1 -d \".\""
    fi
    #uptime | cut -f 14 -d " " | cut -f 1 -d "."
}

##! Determine current internet speed
function brNetSpeed()
# return download speed in Kb/s
{
    #    local url="http://garuda.epr.ch/speedtest"
    #    local url="http://speedtest.pixelwolf.ch"
    local url="http://www.google.ch"
    wget $url -O /dev/null 2>&1 | tail -n 2 | awk '{
    kbps=substr($3,2)
    if ($4=="MB/s)")
        kbps*=1024
        printf("%ld", kbps)
    }
    '
}

# Script writing support

##! get command line arguments of current script
#
# parse command cases between #<--args--> .. #<--/args-->
# useful for adding to bash_completion
# Template for argument parsing loop.
#  while [ ! -z "$1" ] ; do
#      #echo "[$1]"
#  #--begin-args--
#      case "$1" in· 
#         --list-cmd-args)
#             brListCommands $brScriptFile
#             ;;  
#         bootstrap)
#             bootstrap $1
#             shift
#             shift
#             ;;  
#         en-command)
#             ;;  
#         dis-command)
#             ;;  
#         *)  
#             info
#             ;;  
#      esac
#  #--end-args--
#  done
#
#awk '/^#--begin-args-->/,/^#--end-args--/{
function brListCommands
{
    local mark="args"
    [ -z "$2" ] || mark=$2
#	echo File: $0
	#gawk '/^#--begin-args-->/,/^#--end-args--/{
	gawk '/--begin-'$mark'/,/--end-'$mark'/{
		if (match($0, /^[ ]+([A-Za-z0-9-][ |]*)+\)[ ]*$/)){
			patsplit(substr($0,1, length($0)-1), cmds, /\|/, seps)
			for (i in seps) {
                gsub(/[[:blank:]]/, "", seps[i])
                gsub(/\)/, "", seps[i])
				if (seps[i] != "--list-cmd-args")
					printf seps[i] " "
			}
		}
} ' < $1
}

function brFullFilePath
{
    echo $(cd $(dirname "$1") && pwd -P)/$(basename "$1")
}

##! get file extension
function brFileExtension
{
    local filename=$(basename "$*")
    echo ${filename##*.}
}

##! get file name without extension 
function brFileName
{
    local filename=$(basename "$*")
    echo ${filename%.*}
}

##! get file owner
function brFileOwner
{
    stat -c '%U' "$1"
}

##! remove file if it exists
function brLazyRm()
{
    if [ -e "$*" ] ; then
        rm "$*" || brWarn error removing $*
    fi
}

##! make directory if it does not exist
function brLazyMkDir()
{
    [ -d "$*" ] || mkdir -p "$*" || brWarn error removing $*
}

##! return size of file
function brFileSize()
{
    local fs=0$(stat --printf="%s" "$*" 2>/dev/null)
    echo $fs
}

#check if program is available
function brIsRunnable()
{
#    [ -x $1 ] && return 0
        which $1 > /dev/null && return 0
        return 1
}

#check if file exists or raise error
function brAssertFile()
{
    [ -e "$1" ] || brError "File $1 does not exist"
}

##! check for programs required by a script
function brRequire()
{
    local sbre=$BRERRORABORT
    BRERRORABORT=0
    for p in $*; do 
        which $p > /dev/null || brError "[$p] not found in path, install it"
    done
    if [ $BRERRORCOUNT -gt 0 ] ; then
        BRERRORABORT=1
        brError Required programs missing thus aborting.
    fi
    BRERRORABORT=$sbre
}

##! Source if a file exists, abort with error message if not
# brSourceFile -q test will silently skip running the file
function brSourceFile()
{
    if [ "$1" == "-q" ] ; then
        shift
        [ -e "$1" ] && source "$*"
    else
        [ -e "$1" ]  || brWarn "source $1 failed: not found"
        source "$*"
    fi
}

##! run if a file exists, abort with error message if not
# brRunFile -q test will silently skip running the file
function brRunFile()
{
    local silent=0
    if [ "$1" == "-q" ] ; then
        silent=1
        shift
    fi
    [ -e "$1" ] || test silent == 0 && brError Running file $1 failed: not found
    eval "$*"
}

##! redirect standard input to $@ files, using sudo right
## <command writing to stdout> | brSuWrite [-a] <output file 1> ..."
function brSudoWrite()
{
    if [ $# = 0 ] ; then
        brError "USAGE: <command writing to stdout> | suwrite [-a] <output file 1> ..."
    fi
    for arg in "$@" ; do
        if [ ${arg#/dev/} != ${arg} ] ; then
            brError "Found dangerous argument ‘$arg’. Will exit."
        fi
    done
    sudo tee "$@" > /dev/null
}

############ FORMATTED OUTPUT #################3

##! center text and pad it 
function brCenterpad

{
#    local LEN=$ansiColumns
    let topad=$(( ($LEN-${#1})/2 ))
    let topadd=$(( $LEN-${#1}-${topad} ))

    local charmap=$(locale charmap)

    if [ "$charmap" == "UTF-8" ] ; then
        local dash="q"
        local ldon="\033(0"
        local ldoff="\033(B"
    else
        local dash="-"
        local ldon=""
        local ldoff=""
    fi

    pad=$(printf '%0.1s' "$dash"{1..200})
    echo -e "${ansibold}${ldon}${pad:1:$topad}$ldoff$*${ldon}${pad:1:$topadd}${ldoff}${ansinormal}"
}

##! wait for any key before continuing
function brPressAnyKey
{
    local prompt="${ansibold}Press any key to continue${ansinormal}"
    printf "%s" "$prompt"
    read -n 1 -r
    echo
}

##! request yes or no answer. First parameter may be -Y or -N default
function brYesNo
{
    local prompt
    local default
    if [ "${1:-}" == "-Y" ]; then
        prompt="${ansibold}Y/${ansinormal}n"
        default=Y
        shift
    elif [ "${1:-}" == "-N" ]; then
        prompt="y${ansibold}N/${ansinormal}"
        default=N
        shift
    else
        prompt="y/n"
        default=
    fi
    while true; do
        # Ask the question
        printf "%s [%s]? " "$*" "$prompt"
        read -n 1 -r
        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi
        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*|J*|j*) echo ; return 0 ;;
            N*|n*) echo ; return 1 ;;
        esac
        echo "?"
    done    
    #    local REPLY="?"
    #    local default="?"
    #    while [[ ! $REPLY =~ ^[YyJjNn]$ ]] ; do
    #        read -p "$* [yn]?" -n 1 -r
    #        echo
    #    done
    #    if [[ $REPLY =~ ^[YyJj]$ ]] ; then
    #        exit 0
    #    else
    #        exit 1
    #    fi
}

#echo -e brVersion=$brVersion ${ansired}TERM=$TERM${ansinormal} $(ansiColumns)

# Parse yaml files
# https://gist.github.com/pkuczynski/8665367
# Sample file: zconfig.yml
#development:
#  adapter: mysql2
#  encoding: utf8
#  database: my_database
#  username: root
#  password:
#Testing
#!/bin/sh
## include parse_yaml function
#. brlib.sh
#
## read yaml file
#eval $(brParseYaml zconfig.yml "config_")
#
## access yaml content
#echo $config_development_database

function brParseYaml() {
local prefix=$2
local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
    -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  "$1" |
awk -F$fs '{
indent = length($1)/2;
vname[indent] = $2;
for (i in vname) {if (i > indent) {delete vname[i]}}
    if (length($3) > 0) {
        vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
        printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
    }
}'
}

# save active scriptfilepath 
brScriptFile="$0"
[ -x realpath ] && brScriptFile=`realpath $0`

if [ "${1-}" == "-BRDBG" ] || [ "${1-}" == "-BRDEBUG" ] || [ "$BRDEBUG" == "1" ] ; then
    BRDEBUG=1
    brDebug "Debug mode enabled"
    brIfDebug=brDebug
    shift
else
    BRDEBUG=0
    brIfDebug="BRDEBUG=0 "
fi

#[ -e $HOME/.config/Xdbus ] && source $HOME/.config/Xdbus

