#Bernhard Brunners bash scripting utility library. 
#Symlink to $HOME/bin or 
# /usr/local/lib/brlib.sh and use with ". /usr/local/lib/brlib.sh"
# Command line switch -BRDEBUG will set BRDEBUG=1
#Last modified: 2017-03-22 08:36
if [ ! -z "${brVersion-}" ]; then
    return 0
fi
brVersion="1.0"

#xdbus="/home/brb/.config/Xdbus"
#[ -e $xdbus ] && source $xdbus

# It's easier than hand-coding color.
#[ -z "$TERM" ] && TERM=dumb
if [[ "$TERM" != "" && "$TERM" != "dumb" ]] ; then  # && ( hash tput ) ; then
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
    ansiwhite="$(tput setaf 7)"
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
BRDEBUG=0
BRERRORCOUNT=0
BRERRORABORT=1

# spinner for long during processes
brspinvar=0
function brspin()
{
    local brspinstr=( "-" "\\" "|" "/" )
    printf "%c\b" ${brspinstr[$brspinvar]}
    let brspinvar=$((brspinvar + 1))
    let brspinvar=$((brspinvar % 4))
}

######################################################################
# Environment information

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
    dig +short myip.opendns.com @resolver1.opendns.com &>/dev/null || curl -s http://whatismyip.akamai.com/
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
function brLog()
{
    brOutputHook $*
    logger "$*"
}

# call: text class color
function brStatusOut()
{
    let col=$(( $(ansiColumns) - ${#1} - ${#2} + ${#3})) 

    #    echo "cols=$(tput cols) #1=${#1} #2=${#2} fill=$col"
    printf '%s%*s%s%s%s\n' "$1" "$col" "$3" "$2" "$ansinormal"
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
    notify-send "$*"
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
    trap "cleanup" HUP INT ABRT QUIT SEGV TERM
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
    if [ ! z "$BRACTIVETRAPS" ] ; then
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
    kill -- -$(ps -o pgid= $PID | grep -o [0-9]*)
}

##! run process and kill it after timeout
# $1: timeout in seconds
# $2*: process to start
# Ref: https://stackoverflow.com/questions/10028820/bash-wait-with-timeout
function brTimeoutProcess
{
    local pidFile=`mktemp`
    local timeOut=$1
    shift
    ( exec $* ; rm $pidFile ; ) &
    pid=$!
    echo $pid > $pidFile
    ( sleep $timeOut ; if [[ -e $pidFile ]]; then brKillProcessTree $pid ; fi ; ) &
    killerPid=$!
    wait $pid
    kill $killerPid
    brLazyRm $pidFile
}


########### FILE Utility functions################3

##! Get CPU Load
function brLoad()
{
    echo $(cut -d ' ' -f 2 < /proc/loadavg | cut -f 1 -d ".")
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
#function brIsRunnable()
#{
#        which $p > /dev/null && return 0
#        return 1
#}

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

##! run if a file exists, abort with error message if not
function brRunFile()
{
    [ -e "$1" ] || brError Running file $1 failed: not found
    eval "$*"
}

############ FORMATTED OUTPUT #################3

##! center text and pad it 
function brCenterpad()
{
    local LEN=$(ansiColumns)
    let topad=($LEN-${#1})/2
    let topadd=($LEN-${#1}-${topad})

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

    pad=`printf '%0.1s' "$dash"{1..200}`
    echo -e "${ansibold}${ldon}${pad:1:$topad}$ldoff$*${ldon}${pad:1:$topadd}${ldoff}${ansinormal}"
}

##! wait for any key before continuing
function brPressAnyKey
{
    local prompt="${ansibold}Press any key to continue${ansinormal}"
    printf "$prompt"
    read -n 1 -r
    echo
}

##! request yes or no answer. First parameter may be -Y or -N default
function brYesNo
{
    local prompt
    local default
    if [ "${1:-}" = "-Y" ]; then
        prompt="${ansibold}Y/${ansinormal}n"
        default=Y
        shift
    elif [ "${1:-}" = "-N" ]; then
        prompt="y${ansibold}N/${ansinormal}"
        default=N
        shift
    else
        prompt="y/n"
        default=
    fi
    while true; do
        # Ask the question
        printf "$* [$prompt]? "  
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
        echo ?
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
    -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
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

if [ "${1-}" == "-BRDEBUG" ] ; then
    BRDEBUG=1
    brDebug "Debug mode enabled"
    shift
fi

#[ -e $HOME/.config/Xdbus ] && source $HOME/.config/Xdbus


