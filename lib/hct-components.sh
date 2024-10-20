#! /bin/sh

readonly progName='components'
readonly progVersion=1.0
readonly helpHint="Try 'hct $progName --help' for more information."
readonly helpText="Usage: hct $progName [OPTION]... FILE|CHARACTER
Decompose Han characters, aka Chinese characters, into their basic components.

Input:
  A single input argument is accepted, and it must be one of the following:
  A single character, a file containing a list of single characters
  separated by newlines, or a '-' character to allow reading from stdin.
  If the input argument is longer than one character, it is assumed to be a file.

Output:
  For a single character: print the basic components for the given character to stdout.
  For a character list: for each of the listed characters, print the character
  and its basic components separated by a single tab character to stdout.

Options:
  -c, --components=FILE
                    an existing file must be provided; when used, the characters in the
                    file are to be considered as basic components, in addition to the IDS
                    database components (single stroke characters); the provided file
                    should consist of a list of single characters separated by newlines

  -q, --quiet       suppress error messages from the stderr stream
  -s, --source={GHMTJKPVUSBXYZ}
                    a string containing the desired source region letter(s) must be provided;
                    this option is directly passed to the 'composition' hct command,
                    which is used to get the composition of a given character; refer
                    to that command's help text for more information on this option

  -t, --tiebreaker={fl}
                    a single character must be provided, out of f or l;
                    if used, this defines how a character decomposition
                    is chosen when there is more than one valid option;
                    f -> first, always use the first available option
                    l -> length, use the shortest available option
                    the default value for this option is 'f'

  -u, --unencoded   make use of the unencoded characters from the Han PUA font;
                    this option is directly passed to the 'composition' hct command,
                    which is used to get the composition of a given character; refer
                    to that command's help text for more information on this option

  -v, --verbose     print verbose messages to the stderr stream; when this option
                    is used, the --no-progress option is implicitly enabled

      --no-progress suppress the progress status from the stderr stream;
                    this option has no effect when the input is a single character

  -V, --version     show version information and exit
  -h, --help        show this help message and exit"

readonly SOURCE_DIR=$(dirname -- "$(readlink -f "$0")")
readonly IDS_FILE="$SOURCE_DIR/../IDS/IDS.TXT"

QUIET=false
SHOW_PROGRESS=true
TIEBREAKER_RULE='f'
UNENCODED_OPT=''
VERBOSE=false

# Process the environment variables
if [[ -n $HCT_SOURCE_LETTERS && -z $(echo "$HCT_SOURCE_LETTERS" | sed 's/[GHMTJKPVUSBXYZ]//g') ]]; then
    SOURCE_LETTERS="$HCT_SOURCE_LETTERS"
fi

if [[ -n $HCT_COMPONENTS_FILE && -e $HCT_COMPONENTS_FILE ]]; then
    COMPONENTS_FILE="$HCT_COMPONENTS_FILE"
fi

# Parse the command line arguments
GIVEN_ARGS=$(getopt -n hct-$progName -o c:qs:t:uv''Vh -l "components:,quiet,source:,tiebreaker:,unencoded,verbose,no-progress,version,help" -- "$@")

# Deal with invalid command line arguments
if [ $? != 0 ]; then
    echo "$helpHint"
    exit 1
fi
eval set -- "$GIVEN_ARGS"

# Process the command line arguments
while true; do
    case "$1" in
        -c | --components )
            COMPONENTS_FILE="$2"; shift 2 ;;
        -q | --quiet )
            QUIET=true; shift ;;
        -s | --source )
            SOURCE_LETTERS="$2"; shift 2 ;;
        -t | --tiebreaker )
            TIEBREAKER_RULE="$2"; shift 2 ;;
        -u | --unencoded )
            UNENCODED_OPT="--unencoded"; shift ;;
        -v | --verbose )
            VERBOSE=true;
            SHOW_PROGRESS=false;
            shift ;;
        --no-progress )
            SHOW_PROGRESS=false; shift ;;
        -V | --version )
            echo "hct $progVersion"; exit 0 ;;
        -h | --help )
            echo "$helpText"; exit 0 ;;
        -- )
            shift; break ;;
        * )
            break ;;
    esac
done

# Process the components option file
if [[ -n $COMPONENTS_FILE && ! -e $COMPONENTS_FILE ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: invalid argument for the option 'c|components'" >&2
        echo "$helpHint" >&2
    fi
    exit 2
fi

# Process the source option letters
if [[ -n $SOURCE_LETTERS ]]; then
    if [[ -n $(echo "$SOURCE_LETTERS" | sed 's/[GHMTJKPVUSBXYZ]//gI') ]]; then
        if [[ $QUIET == false ]]; then
            echo "htc-$progName: invalid argument for the option 's|source'" >&2
            echo "$helpHint" >&2
        fi
        exit 2
    fi
    SOURCE_LETTERS=$(echo "$SOURCE_LETTERS" | tr '[:lower:]' '[:upper:]')
fi

# Process the tiebreaker option letters
if [[ ${#TIEBREAKER_RULE} -gt 1 ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: only one argument may be given for the option 't|tiebreaker'" >&2
        echo "$helpHint" >&2
    fi
    exit 2
elif [[ -n $(echo "$TIEBREAKER_RULE" | sed 's/[fl]//g') ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: invalid argument for the option 't|tiebreaker'" >&2
        echo "$helpHint" >&2
    fi
    exit 2
fi

# Process the positional arguments
if [[ -z $1 ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: no input character or file provided." >&2
        echo "$helpHint" >&2
    fi
    exit 3
elif [[ -n $2 ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: only one character or file can be provided." >&2
        echo "$helpHint" >&2
    fi
    exit 3
elif [[ $1 == - ]]; then
    if [ -t 0 ]; then
        echo "htc-$progName: argument '-' specified without input on stdin." >&2
        echo "$helpHint" >&2
    else
        read -d '' INPUT
    fi
else
    if [[ ${#1} != 1 && ! -e $1 ]]; then
        if [[ $QUIET == false ]]; then
            echo "htc-$progName: input file does not exist." >&2
            echo "$helpHint" >&2
        fi
        exit 3
    else
        INPUT="$1"
    fi
fi

# Deal with an invalid IDS database file
if [[ ! -e $IDS_FILE ]]; then
    if [[ $QUIET == false ]]; then
        echo "htc-$progName: IDS database file not found, aborting" >&2
    fi
    exit 4
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
        if [[ $VERBOSE == true ]]; then
            for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
            echo "$givenChar <- aborting, string has more than one character" >&2
        fi
        return 10
    fi

    # If using a dedicated components file, check if the given character
    # is not a component already according to the components file
    if [[ -n $COMPONENTS_FILE ]]; then
        if grep -q "$givenChar" "$COMPONENTS_FILE"; then
            if [[ $VERBOSE == true ]]; then
                for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
                echo "$givenChar <- component found (from components file)" >&2
            fi
            echo "$givenChar"
            return 0
        fi
    fi

    # Get the composition(s) for the given character
    local compositionString
    local errCode
    if [[ -z $SOURCE_LETTERS ]]; then
        compositionString=$("$SOURCE_DIR/hct-composition.sh" -q "$UNENCODED_OPT" "$givenChar")
    else
        compositionString=$("$SOURCE_DIR/hct-composition.sh" -q -s "$SOURCE_LETTERS" "$UNENCODED_OPT" "$givenChar")
    fi
    errCode=$?
    if [[ $errCode != 0 ]]; then
        if [[ $VERBOSE == true ]]; then
            for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
            if [[ $errCode == 11 ]]; then
                echo "$givenChar <- aborting, character is not present in the IDS database" >&2
            elif [[ $errCode == 12 ]]; then
                echo "$givenChar <- aborting, character has no valid composition options" >&2
            elif [[ $errCode == 13 ]]; then
                echo "$givenChar <- aborting, character has no composition options for the selected source(s)" >&2
            fi
        fi
        return $errCode
    fi

    # Create an array with each of the available composition options
    local compositionOptions=()
    read -a compositionOptions <<< "$compositionString"

    # Check if the given character can't be decomposed any further, i.e.,
    # if the character is composed of itself according to the IDS database
    if [[ $(echo "${compositionOptions[0]}" | sed 's/(.*)//') == "$givenChar" ]]; then
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

        # Remove any 'ideographic description characters' and the
        # source information from the evaluated composition
        compositionOptions[idx]=$(echo "${compositionOptions[$idx]}" | sed 's/[⿰⿱⿲⿳⿴⿵⿶⿷⿸⿹⿺⿼⿽⿻㇯⿾⿿〾]//g')
        compositionOptions[idx]=$(echo "${compositionOptions[$idx]}" | sed 's/(.*)//')

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

    # If there is only one valid components option, choose it
    if [[ ${#validComponentsOptions[@]} == 1 ]]; then
        chosenComponentsOption="${validComponentsOptions[*]}"
    # Otherwise, use one of the tiebreaker rules
    else
        # If tiebreaker rule is set to 'f', chose the first components option
        if [[ $TIEBREAKER_RULE == f ]]; then
            chosenComponentsOption="${validComponentsOptions[0]}"
            if [[ $VERBOSE == true ]]; then
                for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
                echo "$givenChar <- decomposition = $chosenComponentsOption (chosen by 'first' tiebreaker rule)" >&2
            fi
        # Otherwise, tiebreaker rule is set to 'l',
        # chose the shortest components option
        elif [[ $TIEBREAKER_RULE == l ]]; then
            local shortestComponentsOption="${validComponentsOptions[0]}"
            for idx in "${!validComponentsOptions[@]}"; do
                if [[ ${#validComponentsOptions[$idx]} -lt ${#shortestComponentsOption} ]]; then
                    shortestComponentsOption="${validComponentsOptions[$idx]}"
                fi
            done
            chosenComponentsOption="$shortestComponentsOption"
            if [[ $VERBOSE == true ]]; then
                for _ in $(seq $((nestLevel*4))); do echo -n ' ' >&2; done
                echo "$givenChar <- decomposition = $chosenComponentsOption (chosen by 'length' tiebreaker rule)" >&2
            fi
        fi
    fi

    echo "$chosenComponentsOption"
    return 0
}

# If input is a file
if [[ -e $INPUT ]]; then
    lineCount=$(sed -n '$=' "$INPUT")
    processCount=0
    if [ ! -t 1 ]; then
        echo "# Used options"
        echo "# TIEBREAKER_RULE=$TIEBREAKER_RULE"
        [[ -n $SOURCE_LETTERS ]] && echo "# SOURCE_LETTERS=$SOURCE_LETTERS"
        [[ -n $COMPONENTS_FILE ]] && echo "# COMPONENTS_FILE=$COMPONENTS_FILE"
    fi
    while read testedChar; do
        ((processCount++))
        if [[ $SHOW_PROGRESS == true ]]; then
            echo -ne "\r\033[0KProcessing line $processCount/$lineCount" >&2
        fi
        components=$(get_character_components "$testedChar")
        exitCode=$?
        if [ $exitCode == 0 ]; then
            [ -t 1 ] && echo -en "\r\033[0K"
            echo -e "$testedChar\t$components"
        else
            [ -t 1 ] && echo -en "\r\033[0K"
            echo -e "$testedChar\t$exitCode"
        fi
    done < "$INPUT"
    if [[ $SHOW_PROGRESS == true ]]; then
        echo -e "\r\033[0KProcessing done" >&2
    fi
    exit 0
# If input is a single character
elif [[ ${#INPUT} == 1 ]]; then
    components=$(get_character_components "$INPUT")
    exitCode=$?
    if [[ $exitCode == 0 ]]; then
        echo "$components"
    elif [[ $QUIET == false ]]; then
        case $exitCode in
            20)
                echo "The given character is not present in the IDS database." >&2 ;;
            21)
                echo "The given character has no valid composition options." >&2 ;;
            22)
                echo "The given character has no composition options for the selected source(s)." >&2 ;;
            30)
                echo "The given character has no valid decomposition for the selected source(s)." >&2 ;;
        esac
    fi
    exit $exitCode
# Otherwise, input comes from stdin
else
    lineCount=$(echo "$INPUT" | sed -n '$=')
    processCount=0
    if [ ! -t 1 ]; then
        echo "# Used options"
        echo "# TIEBREAKER_RULE=$TIEBREAKER_RULE"
        [[ -n $SOURCE_LETTERS ]] && echo "# SOURCE_LETTERS=$SOURCE_LETTERS"
        [[ -n $COMPONENTS_FILE ]] && echo "# COMPONENTS_FILE=$COMPONENTS_FILE"
    fi
    while read testedChar; do
        ((processCount++))
        if [[ $SHOW_PROGRESS == true ]]; then
            echo -ne "\r\033[0KProcessing line $processCount/$lineCount" >&2
        fi
        components=$(get_character_components "$testedChar")
        exitCode=$?
        if [ $exitCode == 0 ]; then
            [ -t 1 ] && echo -en "\r\033[0K"
            echo -e "$testedChar\t$components"
        else
            [ -t 1 ] && echo -en "\r\033[0K"
            echo -e "$testedChar\t$exitCode"
        fi
    done < <(echo "$INPUT")
    if [[ $SHOW_PROGRESS == true ]]; then
        echo -e "\r\033[0KProcessing done" >&2
    fi
    exit 0
fi
