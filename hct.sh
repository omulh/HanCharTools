#! /bin/sh

readonly progName='hct'
readonly helpHint="Try '$progName --help' for more information."
readonly helpText="Usage: $progName [-h][--help] | [command]
Get information about Chinese characters.

Options:
  -h, --help    show this text help and exit

Available commands:
  composition"

# Get the script's source dir.
SOURCE_DIR=$(dirname -- "$(readlink -f "$0")")

# Process the comand line arguments
if [[ -z $1 || $1 == -h || $1 == --help ]]; then
    echo "$helpText"
    exit 0
else
    if [[ $1 == composition ]]; then
        exec $SOURCE_DIR/lib/hct-$1 "${@:2}"
    else
        echo "$progName: invalid option '$1'"
        echo "Try '$scriptName --help' for more information."
        exit 1
    fi
fi
