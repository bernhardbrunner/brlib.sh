#Bernhard Brunners bash scripting utility library. 
#Symlink to $HOME/bin or 
# /usr/local/lib/brlib.sh and use with ". /usr/local/lib/brlib.sh"
# Command line switch -BRDEBUG will set BRDEBUG=1
#Last modified: 2014-01-03 17:32
if [ -z "${brVersion-}" ]; then
brVersion="1.0"

# It's easier than hand-coding color.
ansibold="\033[1;32m"
ansinormal="\033[0m"
ansired="\033[1;31m"
ansilightred="\033[0;31m"
ansigreen="\033[1;32m"
ansiblue="\033[1;34m"
ansicyan="\033[1;36m"
ansipurple="\033[1;35m"
ansibrown="\033[0;33m"
ansiyellow="\033[1;33m"
ansiwhite="\033[1;37m"


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
    date "$@" '+%Y-%m-%d_%H:%M'
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

# display error and exit
function brLog()
{
    echo -e "$*"
    logger "$*"
}

# display info
function brInfo()
{
    echo -e "[${ansibold}info${ansinormal}] $*"
}

# display error and exit
function brWarn()
{
    echo -e "[${ansiyellow}warn${ansiyellow}] $*"
}

# display debug
function brDebug()
{
    [ $BRDEBUG == 1 ] && echo -e "$*"
}

# display error and exit
function brError()
{
    echo -e "$ansired*** $ansinormal $*"
    logger "*** ERROR: $*"
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

# check if a file exists and run it, abort with error message if not
function brRunFile()
{
    [ -e "$1" ] || brError Running file $1 failed: not found
    eval "$1"
}

# center text and pad it 
function brCenterpad()
{
    local LEN=70
    let topad=($LEN-${#1})/2
    let topadd=($LEN-${#1}-${topad})
    pad=`printf '%0.1s' "-"{1..60}`
    echo -e "${ansibold}${pad:1:$topad}$1${pad:1:$topadd}${ansinormal}"
}

fi

# if first argument on command line is -BRDEBUG, enable debug mode
if [ "$1" == "-BRDEBUG" ] ; then
    BRDEBUG=1
    shift
fi

