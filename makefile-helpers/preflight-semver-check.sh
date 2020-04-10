MIN_VERSION=$1
CURRENT_VERSION=$2
APP_NAME=$3
. makefile-helpers/print-messages.sh

if [ -z ${APP_NAME} ]; then 
    print_failure "Unable to determine version of $2.  Please ensure it is installed"
    exit 0
fi

# Function taken from https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

vercomp $MIN_VERSION $CURRENT_VERSION
version_compare=$?

if [[ $version_compare == 0 ]]; then
    print_success "$APP_NAME $CURRENT_VERSION is equal to $MIN_VERSION"
elif [[ $version_compare == 1 ]]; then
    print_failure "$APP_NAME $CURRENT_VERSION does not meet minimum $MIN_VERSION"
elif [[ $version_compare == 2 ]]; then
    print_success "$APP_NAME $CURRENT_VERSION is newer than $MIN_VERSION"
else
    print_failure "Unforseen error."
    exit 1
fi
exit 0