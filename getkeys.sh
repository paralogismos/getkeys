#! /usr/bin/env sh
# getkeys.sh
# A script for collecting public keys from web pages.
#
# Tested with:
# getkeys -o pubkeys.asc https://www.sbcl.org/keys.html
# getkeys -o pubkeys.asc https://phrack.org/
# getkeys -o pubkeys.asc https://services.google.com/corporate/publickey.txt
set -e

gk_version=0.3.0

usage() {
    printf "getkeys version %s\n" $gk_version
    printf "\n"
    printf "%s\n" "Usage:"
    printf "%s\n" "------"
    printf "%s\n" "getkeys [options] [URL]"
    printf "%s\n" ""
    printf "%s\n" "Options:"
    printf "%s\n" "--------"
    printf "%s\n" "-o | --output ... Specifies an output file"
    printf "%s\n" "-h | --help   ... Show this help screen"
}

script_fail() {
    printf "*** %s : %s ***\n" "$1" "$2" >&2
    usage
    exit 2
}

# Performs initial tilde expansion on a path string.
tilde_expand() {
    expanded=
    no_tilde=${1#"~/"}
    if [ "$no_tilde" = "$1" ] ; then       # possible logname expansion
        no_tilde=${1#"~"}
        if [ "$no_tilde" =  "$1" ] ; then  # no tilde expansion to perform
            expanded="$no_tilde"
        elif [ -z "$no_tilde" ] ; then     # simple $HOME expansion
            expanded="$HOME"
        else                               # possible logname expansion
            logname=${no_tilde%%/*}
            logpath=${no_tilde#*/}
            if [ "$logpath" = "$no_tilde" ] ; then logpath='' ; fi  # no path after logname
            # Linux only:
            expanded=$(cat /etc/passwd | grep "$logname" | cut -d: -f6)
            # Fall back to unexpanded path if logname is not found.
            # Otherwise, if there is a logpath add it to the expanded logname.
            if [ -z "$expanded" ] ; then expanded="$1"
            elif ! [ -z "$logpath" ] ; then expanded="$expanded/$logpath"
            fi
        fi
    else  # Just a simple $HOME expansion.
        expanded="$HOME/$no_tilde"
    fi
    # Remove trailing slashes before printing results.
    printf '%s' "${expanded%/}"
}

# Parse script options.
output=  # `-o, --output` specifies an output file

# Check long options for required arguments.
require_arg() {
    if [ -z "$OPTARG" ] ; then
        script_fail "Argument required" "--$OPT"
    fi
}

while getopts o:h-: OPT
do
    if [ $OPT = "-" ]  ; then
        OPT=${OPTARG%%=*}      # get long option
        OPTARG=${OPTARG#$OPT}  # get long option argument
        OPTARG=${OPTARG#=}
    fi
    case "$OPT" in
        o | output )
            require_arg ; output=$(tilde_expand "$OPTARG") ;;
        h | help )
            usage
            exit 0 ;;
        \?)
            usage
            exit 2 ;;  # short option fail reported by `getopts`
        *)
            script_fail "Unrecognized option" "--$OPT" ;;  # long option fail
    esac
done

# Get URL.
shift $((OPTIND - 1))
keys_url="$1"
if [ -z "$keys_url" ] ; then
    script_fail "URL required"
fi

GET_KEYS=$(cat <<'EOF'
/-----BEGIN PGP PUBLIC KEY BLOCK-----/ { print "-----BEGIN PGP PUBLIC KEY BLOCK-----" ; inblock = 2 }
/-----END PGP PUBLIC KEY BLOCK-----/ { print "-----END PGP PUBLIC KEY BLOCK-----" ; inblock = 0 }
{ if (inblock == 1) print }
{ if (inblock == 2) inblock = 1 }
EOF
        )

raw_html=$(curl -L --silent "$keys_url")
if [ -n "$output" ] ; then
    echo "$raw_html" | awk "${GET_KEYS}" > "$output"
else
    echo "$raw_html" | awk "${GET_KEYS}"
fi
