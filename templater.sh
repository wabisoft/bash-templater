#!/bin/bash
# Replaces all {{VAR}} by the $VAR value in a template file and outputs it
# Use with -h to output all variables
readonly PROGNAME=$(basename $0)

config_file="<none>"
print_only="false"
silent="false"

usage="${PROGNAME} [-h] [-d] [-f] [-s] -- 

where:
    -h, --help
        Show this help text
    -p, --print
        Don't do anything, just print the result of the variable expansion(s)
    -f, --file
        Specify a file to read variables from
    -s, --silent
        Don't print warning messages (for example if no variables are found)
    -d, --delimiter
        Specify a delimiter to separate output from multiple files (defaults to '\n---\n')

examples:
    VAR1=Something VAR2=1.2.3 ${PROGNAME} test.txt 
    ${PROGNAME} test.txt -f my-variables.txt
    ${PROGNAME} test.txt -f my-variables.txt > new-test.txt"

if [ $# -eq 0 ]; then
  echo "$usage"
  exit 1    
fi

if [[ ! -f "${1}" ]] && [[ ! -d "${1}" ]]; then
    echo "You need to specify a template file or directory" >&2
    echo "$usage"
    exit 1
fi

function load_env_file() {
    local env_file="$1"
    if [[ -f "$env_file" ]]; then
        local variables
        if [[ "$BSD" ]]; then
            variables=$(grep -v '^#' "$env_file" | xargs -0)
        else
            variables=$(grep -v '^#' "$env_file" | xargs -d '\n')
        fi
        for var in $variables; do
            export "${var?}"
        done
    fi
}

function parse_args() {
  template_path="${1}"
  delimiter="\n---\n" 
  if [ "$#" -ne 0 ]; then
      while [ "$#" -gt 0 ]
      do
            case "$1" in
                -h|--help)
                    echo "$usage"
                    exit 0
                    ;;        
                -p|--print)
                    print_only="true"
                    ;;
                -f|--file)
                    load_env_file "$2"
                    ;;
                -s|--silent)
                    silent="true"
                    ;;
                -d|--delimiter)
                   delimiter="$2"
                   ;;
                --)
                    break
                    ;;
                -*)
                    echo "Invalid option '$1'. Use --help to see the valid options" >&2
                    exit 1
                    ;;
                # an option argument, continue
                *)  ;;
            esac
            shift
        done
    fi

}

function main() {

    template="$1"
    vars=$(grep -oE '\{\{\s*[A-Za-z0-9_]+\s*\}\}' "$template" | sort | uniq | sed -e 's/^{{//' -e 's/}}$//')

    if [[ -z "$vars" ]] && [[ "$silent" == "false" ]]; then
        echo "Warning: No variable was found in $template, syntax is {{VAR}}" >&2
    fi

    if [[ -f "./.env" ]]; then
        load_env_file "./.env"
    fi

    var_value() {
        var="${1}"
        eval echo \$"${var}"
    }

    ##
    # Escape custom characters in a string
    # Example: escape "ab'\c" '\' "'"   ===>  ab\'\\c
    #
    function escape_chars() {
        local content="${1}"
        shift

        for char in "$@"; do
            content="${content//${char}/\\${char}}"
        done

        echo "${content}"
    }

    function echo_var() {
        local var="${1}"
        local content="${2}"
        local escaped="$(escape_chars "${content}" "\\" '"')"

        echo "${var}=\"${escaped}\""
    }

    declare -a replaces
    replaces=()

    # Reads default values defined as {{VAR=value}} and delete those lines
    # There are evaluated, so you can do {{PATH=$HOME}} or {{PATH=`pwd`}}
    # You can even reference variables defined in the template before
    defaults=$(grep -oE '^\{\{[A-Za-z0-9_]+=.+\}\}$' "${template}" | sed -e 's/^{{//' -e 's/}}$//')
    IFS=$'\n'
    for default in $defaults; do
        var=$(echo "${default}" | grep -oE "^[A-Za-z0-9_]+")
        current="$(var_value "${var}")"

        # Replace only if var is not set
        if [[ -n "$current" ]]; then
            eval "$(echo_var "${var}" "${current}")"
        else
            eval "${default}"
        fi

        # remove define line
        replaces+=("-e")
        replaces+=("/^{{${var}=/d")
        vars="${vars} ${var}"
    done

    vars="$(echo "${vars}" | tr " " "\n" | sort | uniq)"

    if [[ "$2" = "-h" ]]; then
        for var in $vars; do
            value="$(var_value "${var}")"
            echo_var "${var}" "${value}"
        done
        exit 0
    fi

    # Replace all {{VAR}} by $VAR value
    for var in $vars; do
        value="$(var_value "${var}")"
        if [[ -z "$value" ]]; then
            echo "Warning: $var is not defined and no default is set, replacing by empty" >&2
        fi

        # Escape slashes
        value="$(escape_chars "${value}" "\\" '/' ' ')";
        replaces+=("-e")
        replaces+=("s/{{\s*${var}\s*}}/${value}/g")
    done

    sed "${replaces[@]}" "${template}"

}

parse_args "$@"
if [[ -f "$template_path" ]]; then
  main "$template_path"
elif [[ -d "$template_path" ]]; then
  read -r -a templates <<< $(find "$template_path" -mindepth 1)
  len=${#templates[@]}
  len=$((len-1))
  for i in $(seq 0 $len); do
    main "${templates[i]}"
    if [ $i -lt $len ]; then
      echo -e "$delimiter"
    fi
  done
fi