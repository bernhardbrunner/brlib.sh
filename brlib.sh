#Bernhard Brunners bash scripting utility library. 
#Symlink to $HOME/bin or 
# /usr/local/lib/brlib.sh and use with ". /usr/local/lib/brlib.sh"
# Command line switch -BRDEBUG will set BRDEBUG=1
#Last modified: 2014-02-23 19:09
if [ -z "${brVersion-}" ]; then
brVersion="1.0"

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
brspinstr=( "-" "\\" "|" "/" )
brspinvar=0
function brspin()
{
    printf "%c\b" ${brspinstr[$brspinvar]}
    let brspinvar=$((brspinvar + 1))
    let brspinvar=$((brspinvar % 4))
}

######################################################################
# Environment information

function brGetLocalIP
{
    ip route get 8.8.8.8 | awk '{ print $NF; exit }'
}

# get DISTRIB_ID and DISTRIB_RELEASE
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

# check if distrib is "Ubuntu" or "Debian"
function brIsDistrib
{
    [ $DISTRIB_ID != "" ] || brGetDistrib
    if [ $DISTRIB_ID == "$1" ] ; then
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

function bfFnLn()
{
    if [[ "$3" == "-d" ]] ; then
        [ $BRDEBUG != 0 ] && echo "$2:$1"
    else
        echo "$2:$1"
    fi
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
    brStatusOut "$*" "$(bfFnLn $(caller) -d) [ WARN  ]" ${ansiyellow}
}

# display debug
function brDebug()
{
#    [ $BRDEBUG == 1 ] && brOutputHook "[${ansicyan}DEBUG${ansinormal}] $* ($(caller))"
[ $BRDEBUG == 1 ] && brStatusOut "$*" "$(bfFnLn $(caller)) [ DEBUG ]" "${ansicyan}"
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
    brStatusOut "$*" "$(bfFnLn $(caller) -d) [ ERROR ]" ${ansilightred}
    logger "*** ERROR: $* ($(caller))"
    BRERRORCOUNT=$((BRERRORCOUNT + 1 ))
    if [ $BRERRORABORT == 1 ] ; then 
        exit 1
    fi
}

function brErrorCheck()
{
    if [ $BRERRORCOUNT -gt 0 ] ; then
        BRERRORABORT=1
        brError Errors occured: $BRERRORCOUNT, aborting.
    fi
}

########### FILE Utility functions################3

# return size of file
function brFileSize()
{
    local fs=0$(stat --printf="%s" "$*" 2>/dev/null)
    echo $fs
}

# check for programs required by a script
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

# run if a file exists, abort with error message if not
function brRunFile()
{
    [ -e "$1" ] || brError Running file $1 failed: not found
    eval "$*"
}

############ FORMATTED OUTPUT #################3

# center text and pad it 
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

function brPressAnyKey
{
    local prompt="${ansibold}Press any key to continue${ansinormal}"
    printf $prompt
    read -n -1 -r
    echo
}

function brYesNo
{
    local prompt
    local default
    if [ "${1:-}" = "-Y" ]; then
        prompt="${ansibold}Y${ansinormal}n"
        default=Y
        shift
    elif [ "${1:-}" = "-N" ]; then
        prompt="y${ansibold}N${ansinormal}"
        default=N
        shift
    else
        prompt="yn"
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

fi
#echo -e brVersion=$brVersion ${ansired}TERM=$TERM${ansinormal} $(ansiColumns)

if [ "$1" == "-BRDEBUG" ] ; then
    BRDEBUG=1
    brDebug "Debug mode enabled"
    shift
fi

