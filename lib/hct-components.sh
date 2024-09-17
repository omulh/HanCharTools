#! /bin/sh

readonly progName='components'
readonly helpHint="Try 'hct $progName --help' for more information."
readonly helpText="Usage: hct $progName [OPTION]... FILE|CHARACTER
Decompose Chinese characters into their basic components.

Input:
  A single input argument is accepted, and it must be one of two types:
  A single character or a file containing a list of single characters separated by newlines.
  If the input argument is longer than one character, it is assumed to be a file.

Output:
  For a single character: print the basic components for the given character to the stdout stream.
  For a character list: for each of the listed characters, print the character and
    its basic components separated by a single tab character to the stdout stream.

Options:
  -q, --quiet       suppress error messages from the stderr stream
  -v, --verbose     print verbose messages to the stderr stream
  -h, --help        show this help message and exit"

SOURCE_DIR=$(dirname -- "$(readlink -f "$0")")
IDS_FILE="$SOURCE_DIR/../IDS/IDS.TXT"

QUIET=false
VERBOSE=false

# Parse the command line arguments
GIVEN_ARGS=$(getopt -n hct-$progName -o qs:vh -l "quiet,source:,verbose,help" -- "$@")

# Deal with invalid command line arguments
if [ $? != 0 ]; then
    echo "$helpHint"
    exit 1
fi
eval set -- "$GIVEN_ARGS"

# Process the command line arguments
while true; do
    case "$1" in
        -q | --quiet )
            QUIET=true; shift ;;
        -s | --source )
            SOURCE_LETTERS="$2"; shift 2 ;;
        -v | --verbose )
            VERBOSE=true; shift ;;
        -h | --help )
            echo "$helpText"; exit 0 ;;
        -- )
            shift; break ;;
        * )
            break ;;
    esac
done

# Process the source option letters
if [[ -n $SOURCE_LETTERS ]]; then
    if [[ -n $(echo $SOURCE_LETTERS | sed 's/[GHMTJKPVUSBXYZ]//g') ]]; then
        if [[ $QUIET == false ]]; then
            echo "htc-$progName: invalid argument for the option 's|source'" >&2
            echo "$helpHint" >&2
        fi
        exit 2
    fi
fi

# Process the positional arguments
if [[ -z $1 ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: no input character or file provided." >&2
        echo "$helpHint" >&2
    fi
    exit 2
elif [[ -n $2 ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: only one character or file can be provided." >&2
        echo "$helpHint" >&2
    fi
    exit 2
else
    if [[ ! -e $1 && ${#1} != 1 ]]; then
        if [[ $QUIET == false ]]; then
            echo "htc-$progName: input file does not exist." >&2
            echo "$helpHint" >&2
        fi
        exit 2
    else
        INPUT="$1"
    fi
fi

# Deal with an invalid IDS database file
if [[ ! -e $IDS_FILE ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: IDS database file not found, aborting" >&2
    fi
    exit 3
fi

get_character_components () {
    local givenChar=$1
    local nestLevel=1

    # Give the initial verbose feedback
    if [[ -z $2 ]]; then
        if [[ $VERBOSE == true ]]; then
            echo "$givenChar <- working on it" >&2
        fi
    else
        nestLevel=$2
    fi

    # Only accept one character at a time
    if [ ${#givenChar} != 1 ]; then
        return 1
    fi

    # Get the composition(s) for the given character
    local compositionString
    local errCode
    if [[ -z $SOURCE_LETTERS ]]; then
        compositionString=$($SOURCE_DIR/hct-composition.sh -q $givenChar)
    else
        compositionString=$($SOURCE_DIR/hct-composition.sh -q -s $SOURCE_LETTERS $givenChar)
    fi
    errCode=$?
    if [[ $errCode != 0 ]]; then
        return $errCode
    fi

    # Remove any 'ideographic description characters'
    compositionString=$(echo "$compositionString" | sed 's/[⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿼⿽⿻㇯⿾⿿〾]//g')

    # Create an array with the IDS sources, i.e., the region letter codes
    # between parentheses, for each of the available composition options
    local compositionSources=()
    read -a compositionSources <<< "$compositionString"
    for idx in "${!compositionSources[@]}"; do
        compositionSources[idx]=$(echo "${compositionSources[$idx]}" | sed 's/.*(//; s/).*//')
    done

    # Create an array with each of the available composition options
    local compositionOptions=()
    read -a compositionOptions <<< "$compositionString"
    for idx in "${!compositionOptions[@]}"; do
        compositionOptions[idx]=$(echo "${compositionOptions[$idx]}" | sed 's/([^)]*)//')
    done

    # Check if the given character can't be decomposed any further, i.e.,
    # if the character is composed of itself according to the IDS database
    if [[ ${compositionOptions[0]} == "$givenChar" ]]; then
        if [[ $VERBOSE == true ]]; then
            for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
            echo "$givenChar <- component found (from IDS database)" >&2
        fi
        echo "$givenChar"
        return 0
    fi

    local validComponentsOptions=()
    local validSourceOptions=()
    # Iterate over every composition option for the given character
    for idx in "${!compositionOptions[@]}"; do
        if [[ $VERBOSE == true ]]; then
            local extra
            if [[ ${#compositionOptions[@]} -gt 1 ]]; then
                extra=" (opt. $((idx+1)))"
            fi
            for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
            echo "$givenChar <- composition = ${compositionOptions[$idx]}$extra" >&2
        fi

        local subComponents=''
        local validComponents=''
        # Iterate over every 'child' character in a composition option
        while read -n1 testedChar; do
            # Use recursion to get all the basic components
            subComponents=$(get_character_components "$testedChar" $((++nestLevel)))
            local exitCode=$?

            # If the 'child' character was successfully decomposed, add its
            # components to the list of the 'parent' character's components
            if [[ $exitCode == 0 ]]; then
                validComponents+="$subComponents"
            else
                break
            fi
        done < <(echo -n "${compositionOptions[$idx]}")

        # If a composition option was successfully decomposed, add
        # its components to the list of valid components options
        if [[ $exitCode == 0 ]]; then
            validComponentsOptions+=("$validComponents")
            validSourceOptions+=("${compositionSources[$idx]}")
        fi
    done

    # If no valid components option was found
    if [[ -z ${validComponentsOptions[*]} ]]; then
        return 30
    fi

    # Chose the first valid components option
    chosenComponentsOption="${validComponentsOptions[0]}"
    if [[ $VERBOSE == true ]]; then
        for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
        echo "$chosenComponentsOption <- chosen components option" >&2
    fi

    echo "$chosenComponentsOption"
    return 0
}

components=$(get_character_components "$INPUT")
echo "$components"
